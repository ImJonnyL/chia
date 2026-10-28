[FIRRTL][LowerToHW] Fix crash lowering enumcreate/istag with zero-width types

## Root cause

LowerToHW does not materialize hardware for zero-width FIRRTL values: `getLoweredValue` returns a null `Value` for any value whose type is zero-bit (per `isZeroBitFIRRTLType`). Two enum visitors consumed that possibly-null value as an operation operand without checking:

- `FIRRTLLowering::visitExpr(FEnumCreateOp)` passed the lowered payload directly to `hw::UnionCreateOp` as the union body. For a variant with a zero-width payload — e.g. `None: uint<0>` in `!firrtl.enum<Some: uint<8>, None: uint<0>>` from the issue — the lowered input is null, and constructing an `OpOperand` from a null `Value` dereferences null inside `mlir::IROperandBase::insertInto`. That is exactly the segfault in the reported backtrace (`visitExpr(FEnumCreateOp)` → `OpBuilder::create<hw::UnionCreateOp>` → `IROperandBase::insertInto`).
- `FIRRTLLowering::visitExpr(IsTagOp)` had the same latent bug for a wholly zero-width enum (a single-variant enum whose payload is zero-width, e.g. `!firrtl.enum<A: uint<0>>`): the lowered enum value is null and the subsequent tag extraction would crash identically. The issue's reproducer does not reach this path — its `istag` input is a 9-bit enum (1 tag bit + 8 data bits) and lowers fine once `enumcreate` is fixed — but it is the same null-lowered-value class of bug.

## Fix

`lib/Conversion/FIRRTLToHW/LowerToHW.cpp`:

- In `visitExpr(FEnumCreateOp)`, when the lowered input is null, require the payload type to be zero-width (returning `failure()` otherwise — defensive, unreachable in practice) and materialize an `i0` constant via `getOrCreateIntConstant(0, 0)` as the union-body operand. The lowered HW union still declares the zero-width field (`None: i0`), so `hw.union_create` needs a real `i0` operand to build valid IR; an `i0` constant carries no hardware.
- In `visitExpr(IsTagOp)`, short-circuit zero-width enums before touching the lowered input: a zero-width enum necessarily has exactly one variant (two or more variants require at least one tag bit), so the tag test is trivially true and lowers to `hw.constant true` via `getOrCreateIntConstant(1, 1)`.

## Testing

- The reproducer from #7388 (a module with `firrtl.enumcreate None(%c0_ui0)` where `%c0_ui0 : !firrtl.uint<0>`) previously segfaulted under `circt-opt --lower-firrtl-to-hw`; it now lowers cleanly. The `convention = scalarized` attribute / `LowerSignatures` workaround mentioned in the issue are not needed to trigger the crash or to verify the fix.
- Added two regression tests to `test/Conversion/FIRRTLToHW/lower-to-hw.mlir`:
  - `@DataEnumCreateZeroWidth`: `enumcreate` of a zero-width variant on a data-carrying enum — checks the emitted `hw.constant 0 : i0`, `hw.union_create`, and `hw.struct_create`.
  - `@IsTagZeroWidthEnum`: `istag` on a zero-width single-variant enum — checks it folds to `hw.constant true`.
- Full lit run over all `test/` targets (Analysis, Conversion, Dialect, firtool, circt-opt, Target, Tools, etc.): 1022 passed, 0 failed.

Remaining risk: the `IsTagOp` half fixes a sibling crash not exercised by the original reproducer; it is covered by the new `@IsTagZeroWidthEnum` test. The `return failure()` path for a null lowered value on a non-zero-width payload type is defensive only and has no coverage (it should be unreachable).

## Existing-test changes

No existing tests were modified. The only test-file change is the addition of the two new modules and their CHECK lines to `test/Conversion/FIRRTLToHW/lower-to-hw.mlir`; no pre-existing CHECK lines or input IR were touched.

Fixes #7388