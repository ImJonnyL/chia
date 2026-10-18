# [FIRRTL] Fix ExpandWhens dominance error for LTL intrinsics reused across layerblocks

> **Status: Draft — not ready to merge.** Automated verification of this change reports `fixed: false`: the original repro still fails with the same dominance error. This description documents the root-cause analysis, the attempted fix, and honestly records what remains unverified.

## Root cause

When `ExpandWhens` visits a `firrtl.int.verif.assert/assume/cover` inside a `when`, it folds the when-condition into the property: a property that is already an LTL implication `lhs ==> rhs` is rewritten to `(cond && lhs) ==> rhs` by cloning the implication with a rewritten lhs; other properties are wrapped as `cond ==> prop` (assert/assume) or `cond && prop` (cover). These rewrites are memoized, so encountering an equivalent LTL op again reuses the previously created op instead of building a duplicate.

That memoization is not region-aware. In the repro, two `firrtl.layerblock`s each contain a structurally identical `firrtl.int.ltl.implication` (same operands). Processing the assert in the **second** layerblock reuses the implication op materialized while processing the **first** layerblock. That op lives in the first layerblock's region — neither a parent nor a child of the second layerblock's region — so the rewired assert is fed by a value that does not dominate it, producing exactly the reported `operand #0 does not dominate this use ... op is neither in a parent nor in a child region`.

This explains the issue's peculiar specificity: you need (1) the implication-intrinsic path (the clone-and-cache rewrite), (2) two implications with identical operands so the cache collides, and (3) placement in sibling regions so the reused op cannot dominate both uses.

## Fix

Changed only `lib/Dialect/FIRRTL/Transforms/ExpandWhens.cpp`:

- Added a `moveBefore(Value, Block::iterator)` helper.
- On every cache-hit path in the condition-wrapping helpers (`ltlAndWithCondition`, `ltlImplicationWithCondition`, and their clocked variants), the reused op — and, where a fresh input/lhs was computed, that value's defining op — is moved to immediately before the verif op being rewritten.
- `visitStmt(VerifAssertIntrinsicOp/VerifAssumeIntrinsicOp/VerifCoverIntrinsicOp)` now move the verif op itself to directly after its new property's defining op, intending to guarantee the property dominates it.

**This does not yet work, and the approach is likely flawed.** Relocating a *shared* op next to the second use breaks dominance for its original use in the first layerblock (the error just migrates), and `op->moveAfter(propertyOp)` can drag a verif op across a layerblock boundary, changing which layerblock it belongs to. The correct fix is almost certainly to make the memoization dominance/region-aware: reuse a cached op only if it dominates the use site, otherwise clone a fresh op at the current location — never move shared LTL ops across layerblock boundaries. Additionally, leftover `llvm::errs()` debug tracing in `visitStmt(VerifAssertIntrinsicOp)` must be removed before any merge.

## Testing

- **Repro:** `circt-opt --pass-pipeline="builtin.module(firrtl.circuit(firrtl.module(firrtl-expand-whens)))"` on the issue's IR. Before the change: dominance error as reported. After the change: **still fails** — verification reports `fixed: false`. The repro did not flip.
- **Build:** succeeds (`build_ok: true`).
- **Lit:** no meaningful results — the harness reported `lit_ok: false` with 0 passed / 0 failed, so the suite effectively did not run. There is no regression signal in either direction, and nothing about test-suite health is verified.
- **No new lit test was added.** Once the approach is corrected, a regression test (two layerblocks with identical implication intrinsics under a `when`, checked through `firrtl-expand-whens`) should be added to `test/Dialect/FIRRTL/expand-whens.mlir`.

Remaining risk: the entire change is unverified and will likely be replaced by the region-aware-cache approach described above.

## Existing-test changes

No existing tests were modified. The diff touches only the pass source file.

Fixes #10104