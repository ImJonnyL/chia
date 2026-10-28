[FIRRTLToHW] Fix crash lowering enum create with a zero-width payload

## Root cause

`FIRRTLLowering::visitExpr(FEnumCreateOp)` in `lib/Conversion/FIRRTLToHW/LowerToHW.cpp` lowers a FIRRTL enum value into `!hw.struct<tag: iN, body: !hw.union<...>>`: an `sv.localparam` for the tag plus an `hw.union_create` for the payload, folded together by an `hw.struct_create`.

The payload operand is first run through `getLoweredValue`. For a zero-width FIRRTL payload — the `None: uint<0>` case from the issue — this returns an **empty** `mlir::Value`, since zero-width FIRRTL values lower to nothing. That empty value was then passed straight into `hw::UnionCreateOp::create(...)` at the crash site in the issue's backtrace (LowerToHW.cpp:2868). Building an operation with a null operand value is undefined behavior: MLIR constructs an `OpOperand` for it and inserts it into the value's use list, dereferencing null — hence the release-build segfault inside `IROperandBase::insertInto` rather than a clean diagnostic.

Note that the HW union type itself still declares an `i0` field for the zero-width case (the enum→struct/union type mapping preserves zero-width fields), so the `hw.union_create` genuinely needs an `i0`-typed operand; the lowering just never materialized one.

## Fix

In `visitExpr(FEnumCreateOp)`, handle the empty lowered payload:

- If the payload's FIRRTL type is zero-width (`isZeroBitFIRRTLType`), materialize the missing operand as `hw.constant 0 : i0` of the union field's lowered type and feed that to the `hw.union_create`. The constant carries no bits but gives the union create a well-typed, non-null operand.
- If the payload lowered to nothing but its type is *not* zero-width, that's a genuine lowering failure: emit a diagnostic on the op (`"input lowering failed"`) instead of fabricating a constant or crashing.

This is ~8 lines, confined to the enum-create case. An alternative would be to drop zero-width fields from the lowered union type entirely, but that changes the enum type mapping used elsewhere and is a much larger, riskier change; materializing the zero constant is the minimal fix consistent with the existing representation.

Formatting note: the diff also carries two clang-format-only reformats of pre-existing lines in `LowerToHW.cpp` (the `emitGuard` helper in `lowerFileHeader` and the `sv::IfOp::create` in `addToAlwaysBlock`) — running `clang-format -i` on the edited file joined two previously over-wrapped calls onto single lines. Zero functional change; happy to split them out if reviewers want a pure diff.

## Testing

- Repro: the IR from the issue, run through `circt-opt --lower-firrtl-to-hw` (equivalently the `firtool` pipeline), segfaults on `firtool-1.148.0` before the change and lowers cleanly after. The regression test is the minimized crashing form — the `enumcreate` of the zero-width case; the `istag`/`mux` tail of the original repro only consumed the result and is unaffected by the fix.
- Added a regression test appended to `test/Conversion/FIRRTLToHW/lower-to-hw.mlir` (`Issue7388`), CHECKing the lowered `sv.localparam` tag, the new `hw.constant 0 : i0` placeholder, the `hw.union_create "None"`, the `hw.struct_create`, and the module output type.
- Full lit suite re-run across `build/test` (Analysis, Conversion, Dialect, Scheduling, Target, Tools, Transforms, Unit, arcilator, circt-*, firld, firtool, hlstool, kanagawatool, lib, om-linker): **1022 passed, 0 failed**.

Honest caveats:

- This makes the FIRRTL→HW lowering emit well-formed HW IR instead of crashing; it does not change how an `i0` union field is treated downstream (HW→SV/Verilog emission of zero-width union fields is exercised only insofar as existing tests cover it).
- The separate signature-lowering problem referenced in the report (#7106) is not addressed here.
- I did not audit pre-existing coverage of the non-zero-width enum paths; the new test covers only the zero-width-payload case that crashed.

## Existing-test changes

No existing tests were modified. The only test-file change is an append: a new `// -----`-separated `Issue7388` case at the end of `test/Conversion/FIRRTLToHW/lower-to-hw.mlir`. No existing RUN lines, inputs, or CHECK expectations were touched.

Fixes #7388