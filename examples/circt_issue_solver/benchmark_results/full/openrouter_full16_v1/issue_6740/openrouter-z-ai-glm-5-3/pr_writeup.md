[firrtl-to-hw] Lower `firrtl.invalidvalue` of clock type to a low clock constant

**Root cause**

`FIRRTLLowering::visitExpr(InvalidValueOp)` (lib/Conversion/FIRRTLToHW/LowerToHW.cpp) lowered every invalid value through one generic path: emit an integer zero constant of the value's bitwidth and, when the lowered result type is not an integer type, `hw.bitcast` the constant to the result type. That path is illegal for `!firrtl.clock`: its bitwidth is 1, so an `i1` zero constant is created, but the type lowers to `!seq.clock`, and `hw.bitcast` only accepts types with a known bitwidth in hardware. The lowering therefore emits `hw.bitcast` from `i1` to `!seq.clock`, which fails the verifier:

```
error: 'hw.bitcast' op result #0 must be Type wherein the bitwidth in hardware is known, but got '!seq.clock'
```

This is reachable with `circt-opt -lower-firrtl-to-hw` directly on the issue's repro (wire + invalidvalue + strictconnect of `!firrtl.clock`), i.e., without the higher-level firtool pipeline running first. As the issue notes, an invalid surviving to LowerToHW is itself somewhat unexpected (earlier passes usually eliminate them), but LowerToHW must be total over valid FIRRTL regardless of which earlier passes ran — and this input is perfectly valid FIRRTL.

**Fix**

In `visitExpr(InvalidValueOp)`, immediately after the zero-width bail-out and before the integer-constant/bitcast path, check `isa<ClockType>(op.getType())` and lower an invalid clock via `getOrCreateClockConstant(seq::ClockConst::Low)` — i.e., exactly how `firrtl.specialconstant` of clock type is already lowered. Invalid conventionally lowers to "zero", and for a clock, zero is clock low, so an invalid clock is lowered as clock low. Clock is the only FIRRTL ground type whose lowered HW type (`!seq.clock`) has no known bitwidth, so a targeted type check is the complete fix; all other ground/aggregate types (resets lower to `i1`, aggregates bitcast among fixed-width types) keep the existing path. The change is six lines of code plus a test.

**Testing**

- Reproduced with the exact IR from the issue: `circt-opt -lower-firrtl-to-hw` on a circuit containing `%a = firrtl.wire : !firrtl.clock`, `%b = firrtl.invalidvalue : !firrtl.clock`, `firrtl.strictconnect %a, %b` failed verification before the change with the `hw.bitcast ... -> !seq.clock` error above; after the change it compiles cleanly and the invalid clock lowers to a low clock constant driving the wire.
- Appended a case to `test/Conversion/FIRRTLToHW/lower-to-hw.mlir` (inside the existing `Simple` module) covering `firrtl.invalidvalue : !firrtl.clock` connected into a wire, with a CHECK that the wire is driven by the clock-low constant.
- Ran the full lit suite across all CIRCT test directories (test/Analysis, test/Conversion, test/Dialect, test/firtool, test/Target, test/Transforms, …): 1022 passed, 0 failed. No regressions.

Honest caveats: this change does not address *why* invalid values can still be alive at LowerToHW (the SFCCompat question raised in the issue comments) — that is a separate behavioral question about earlier passes and isbed intentionally out of scope. LowerToHW must be correct for any valid FIRRTL it is handed, so fixing the lowering is the right fix for this failure regardless. Behaviorally, an invalid clock now lowers to clock low — the same value `firrtl.specialconstant` 0 of clock type produces — instead of crashing.

**Existing-test changes**

No existing tests were modified. The only test change is appending a new input/CHECK block to the existing `test/Conversion/FIRRTLToHW/lower-to-hw.mlir`; no existing lines were edited, deleted, or retargeted, and no expectations were weakened.

Fixes #6740