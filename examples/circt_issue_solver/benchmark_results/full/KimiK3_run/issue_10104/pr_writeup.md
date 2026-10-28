[FIRRTL] ExpandWhens: hoist shared LTL condition ops out of layerblocks

## Root cause

When `ExpandWhens` processes a simulation construct (`firrtl.int.verif.assert`/`assume`/`cover`) under a `firrtl.when`, it wraps the property expression with the when condition by creating `ltl.and` / `ltl.implication` / `ltl.clock` operations. These wrapping ops are cached in `createdLTLAndOps` / `createdLTLImplicationOps` / `createdLTLClockOps` and intentionally shared between all simulation constructs with the same operands.

The bug is in where these cached ops were inserted: `WhenOpVisitor` built them with `OpBuilder(op)`, i.e. immediately before the individual simulation construct being visited. If two simulation constructs that share a wrapping op live in two *separate* `firrtl.layerblock` regions, the shared op is materialized inside the **first** layer block. When the construct in the **second** layer block then reuses the cached value, the definition sits in a sibling region — layer block regions do not dominate each other — so the verifier reports:

```
error: operand #0 does not dominate this use
note: operand defined here (op is neither in a parent nor in a child region)
```

This is exactly the reported repro: two `firrtl.layerblock`s each containing an `ltl.implication` feeding a `verif.assert` under the same `when`. The first layer block's assert creates `ltl.and(cond, implication)` before itself (inside layer block #1); the second layer block's assert reuses that cached `ltl.and`, whose definition does not dominate the use. Single-layerblock cases work by luck because the definition and use happen to end up in the same region.

## Fix

Insert the cached wrapping ops before the `WhenOp` being expanded instead of before the individual simulation construct:

- `WhenOpVisitor` now takes an `insertionPoint` (the `WhenOp`), threaded through from both call sites in `LastConnectResolver::processWhenOp` (then and else branches).
- A small `getLTLBuilder()` helper returns an `OpBuilder` positioned at the when op, and all four creation sites (`ltl.and`, the two `ltl.implication` paths, and `ltl.clock`) use it.

This is correct because the then/else blocks are merged into the parent block at the when op's position, so anything inserted immediately before the when op dominates every construct that was inside the when — regardless of how many layer blocks (or other isolated regions) those constructs are nested in. The caching/sharing behavior is unchanged; only the insertion point moves. The change is minimal: no logic changes, no changes to what is created or how it is keyed in the cache.

## Testing

- The exact reproducer from the issue now passes `circt-opt --pass-pipeline="builtin.module(firrtl.circuit(firrtl.module(firrtl-expand-whens)))"` (and `firtool`) with no dominance error; previously it failed verification as reported.
- Added a regression test `LayerBlocksWithSharedImplications` in `test/Dialect/FIRRTL/expand-whens.mlir`, derived from the issue repro, which additionally checks (with `CHECK-NEXT`) that the shared `ltl.and`/`ltl.implication` are placed *outside* both layer blocks and are reused by the asserts in each.
- Full lit suite run across all test directories (`test/Dialect`, `test/firtool`, `test/circt-opt`, etc.): **1022 passed, 0 failed**.

No known remaining risk: the only behavioral change is the placement of the newly created wrapping ops, which now strictly dominate their previous position, so no previously-valid use can lose dominance.

## Existing-test changes

One existing test was modified: `WhenAroundPropertyAssertAssumeCover` in `test/Dialect/FIRRTL/expand-whens.mlir`. Only the **order** of the `CHECK` lines changed; the checked operations, operands, and sharing structure are identical. Previously, because each wrapping op was inserted directly before its consuming verif op, the `ltl.and`/`ltl.implication`/`ltl.clock` definitions appeared interleaved with the asserts/assumes/covers (with the cover's wrapping ops checked after the assumes). With the fix, all wrapping ops are emitted in one cluster before the merged when body, so the two `ltl.and`/`ltl.clock` chains for the cover expressions are now checked up front alongside the assert/assume chain, and the cover checks reference them (`TMP4`/`TMP5` instead of redefining `TMP1`/`TMP2`). The test still verifies exactly what it always did — conditions and-ed into the property, implication/clock wrapping, and reuse of one cached op across multiple verif ops in both the then and else branches — so this is a legitimate update to expected output placement, not a weakening of coverage.

Fixes #10104