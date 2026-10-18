[FIRRTLToHW] Lower invalid values of clock type to seq.const_clock instead of illegal hw.bitcast

**Root cause**

`FIRRTLLowering::visitExpr(InvalidValueOp)` lowers `firrtl.invalidvalue` to a zero integer constant of the FIRRTL bitwidth, and — when the result type is not an integer — bitcasts that constant to the lowered aggregate type with `hw.bitcast`.

That path assumes the lowered type has a known hardware bitwidth. Clock types do not: `!firrtl.clock` has FIRRTL bitwidth 1, but it lowers to `!seq.clock`, for which `hw::getBitWidth` returns -1 (unknown). The same holds for aggregates containing clock fields (e.g. `!hw.struct<a: i2, b: !seq.clock>`). So for an invalidated wire of clock type, LowerToHW emitted

```mlir
%2 = hw.bitcast %0 : (i1) -> !seq.clock
```

which violates `hw.bitcast`'s "bitwidth in hardware is known" constraint and fails verification:

```
error: 'hw.bitcast' op result #0 must be Type wherein the bitwidth in hardware is known, but got '!seq.clock'
```

As noted in the issue, the SFCCompat pass arguably should have folded this invalid value away earlier, but LowerToHW must not produce illegal IR regardless of what ran before it.

**Fix**

In `visitExpr(InvalidValueOp)`, after the existing FIRRTL-bitwidth computation, check whether the *lowered* result type has a known hardware bitwidth (`hw::getBitWidth(resultTy) < 0`). When it does not — i.e. the type is a clock or an aggregate containing clocks — avoid the integer-constant-plus-bitcast path entirely:

- A bare `!firrtl.clock` invalid value lowers to `seq.const_clock low`, reusing the existing `getOrCreateClockConstant(seq::ClockConst::Low)` helper (so the constant is cached/hoisted like other clock constants).
- An aggregate containing clocks lowers to `hw.aggregate_constant` built from a new helper, `getOrCreateAggregateClockConstantAttribute`, which recursively constructs the constant attribute: clock fields become `seq::ClockConstAttr` (low), sized integer fields become zero `IntegerAttr`s of the lowered integer type, vectors are built per-element and reversed (to account for the differing FIRRTL/HW array element ordering), and bundles are built field-by-field.

This is correct because it produces the same "all-zero" value the lowering already promises for `firrtl.invalidvalue`, expressed with the only zero-valued constant available for clock-typed leaves (`seq.const_clock low`), and it never materializes a bitcast to a type of unknown hardware bitwidth. The change is minimal: the existing integer/bitcast path is untouched for all purely integer/aggregate-of-integer types, and zero-width handling (`bitwidth == 0` → `failure()`, letting the caller drop the value) is unchanged.

**Testing**

Repro (from the issue), run against the rebuilt `circt-opt` in `build/bin`:

```mlir
firrtl.circuit "Foo" {
  firrtl.module private @Foo() {
    %a = firrtl.wire : !firrtl.clock
    %b = firrtl.invalidvalue : !firrtl.clock
    firrtl.strictconnect %a, %b : !firrtl.clock
  }
}
```

Before the change, `circt-opt -lower-firrtl-to-hw` fails verification with the `hw.bitcast` error quoted above. After the change, it verifies and produces a `seq.const_clock low` feeding the `hw.wire`.

Added two FileCheck tests to `test/Conversion/FIRRTLToHW/lower-to-hw.mlir` (new test modules only):

- `@InvalidClockValue`: invalid `!firrtl.clock` lowers to `seq.const_clock low` driving the wire.
- `@InvalidClockAggregateValue`: invalid `!firrtl.bundle<a: uint<2>, b: clock>` lowers to `hw.aggregate_constant [0 : i2, #seq<clock_constant low> : !seq.clock]`, covering the mixed int/clock aggregate path.

Full lit regression run over the whole test tree (`test/Analysis`, `test/Conversion`, `test/Dialect`, `test/Scheduling`, `test/Target`, `test/Tools`, `test/Transforms`, `test/Unit`, all tool test dirs): **1022 passed, 0 failed.**

Remaining risk / notes: the fix intentionally does not change SFCCompat (where, per the issue discussion, the invalid value might ideally have been folded to a special constant zero earlier); it only makes LowerToHW robust to such input. Deeply nested aggregates of clocks are handled by the recursive helper but are not separately covered by a dedicated test beyond the one-level bundle case. Zero-width clock-containing types are not constructible (clocks have width 1), so the zero-width early-out is unaffected.

**Existing-test changes**

No existing tests were modified. The only test-file edit appends two new test modules (and their CHECK lines) to the pre-existing `test/Conversion/FIRRTLToHW/lower-to-hw.mlir`; no existing CHECK lines, input IR, or expectations were altered.

Fixes #6740