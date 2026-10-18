[Thinking]
The user wants me to write a PR description for the fix I made to issue #10104. Let me analyze the diff and write a clear, honest PR description.

The issue: ExpandWhens dominance error with multiple layerblocks and implication intrinsics.

Root cause: In `WhenOpVisitor` in ExpandWhens.cpp, when simulation constructs (assert/assume/cover with property expressions) are processed, the pass creates `ltl.and`, `ltl.implication`, and `ltl.clock` operations to wrap the property with the when condition. These operations were inserted using `OpBuilder(op)` — i.e., right before the simulation construct op itself. These created ops are cached in maps (`createdLTLAndOps`, `createdLTLImplicationOps`, `createdLTLClockOps`) so they can be shared across multiple simulation constructs with the same operands. When simulation constructs appear in two separate `firrtl.layerblock` regions, the first construct's condition op gets created inside the first layerblock. When the second layerblock's construct reuses the cached op, the definition is inside the first layerblock — and layerblock regions are isolated from above (well, actually the issue is the op is in a sibling region, so it doesn't dominate the use in the other layerblock). Hence the dominance error: "operand #0 does not dominate this use... op is neither in a parent nor in a child region."

Fix: Insert the created LTL ops before the `WhenOp` being expanded instead of before the individual simulation construct. This places them in the same block where the when's blocks will be merged into, guaranteeing they dominate all uses regardless of which layerblock the simulation constructs are in. Passed `insertionPoint` (the WhenOp) into the `WhenOpVisitor` and added a `getLTLBuilder()` helper.

Testing: reproduced with the issue's IR through `circt-opt --pass-pipeline="builtin.module(firrtl.circuit(firrtl.module(firrtl-expand-whens)))"`, confirmed the dominance error before, fixed after. Ran the full lit suite: 1022 passed, 0 failed.

Existing-test changes: `test/Dialect/FIRRTL/expand-whens.mlir` — the `WhenAroundPropertyAssertAssumeCover` test's CHECK lines were reordered. Because the new LTL ops are now inserted before the when op rather than adjacent to each simulation construct, all the created `ltl.and`/`ltl.implication`/`ltl.clock` ops now appear consecutively at the top of the (merged) block, rather than interleaved with the assert/assume/cover ops. The values computed and their uses are unchanged — same ops, same operands, same sharing behavior — only the placement order in the output changed. So the CHECK lines were reordered to match; the test still verifies the same transformation semantics (condition and-ed with property, implication/clock wrapping, sharing across multiple verif ops).

Wait, actually let me look more carefully. Before the fix, the builder inserted before `op` — the simulation construct. With `mergeBlock`, the then/else blocks get merged into the parent block at the when's position, so previously, the created ops were right next to their using verif op, and after merge they'd appear interleaved in the final block. Now they're all created before the when op, so they appear in a cluster before all the merged content.

Note the old test had check lines like:
```
// CHECK: [[TMP1:%.+]] = firrtl.int.ltl.and %a, %b
// CHECK: [[TMP2:%.+]] = firrtl.int.ltl.implication [[TMP1]], %c
// CHECK: [[TMP3:%.+]] = firrtl.int.ltl.clock [[TMP2]], %clock
// CHECK: firrtl.int.verif.assert [[TMP3]], %d :
...
// CHECK: [[TMP1:%.+]] = firrtl.int.ltl.and %a, [[P0]]
// CHECK: [[TMP2:%.+]] = firrtl.int.ltl.clock [[TMP1]], %clock
// CHECK: firrtl.int.verif.cover [[TMP2]], %d :
```

The new test has all the ltl op definitions first:
```
// CHECK: [[TMP1:%.+]] = firrtl.int.ltl.and %a, %b
// CHECK: [[TMP2:%.+]] = firrtl.int.ltl.implication [[TMP1]], %c
// CHECK: [[TMP3:%.+]] = firrtl.int.ltl.clock [[TMP2]], %clock
// CHECK: [[TMP4:%.+]] = firrtl.int.ltl.and %a, [[P0]]
// CHECK: [[TMP5:%.+]] = firrtl.int.ltl.clock [[TMP4]], %clock
// CHECK: firrtl.int.verif.assert [[TMP3]], %d :
...
// CHECK: firrtl.int.verif.cover [[TMP5]], %d :
```

So the same ops are created and shared; only the order changed. Justification: the placement of the newly created LTL ops changed deliberately (they're now hoisted before the when), so the expected output order changed. The test still verifies the same wrapping semantics and reuse/sharing of cached ops.

Also added a new regression test `LayerBlocksWithSharedImplications` derived from the issue repro, which additionally verifies that the shared implication is placed outside both layerblocks.

Also one note: variable naming — TMP4/TMP5 instead of reusing TMP1/TMP2 — because FileCheck variables can't be redefined... actually they can be redefined with the same name; redefinition is allowed. The reason for renaming is just clarity since the definitions moved up. It doesn't matter much. Actually the diff shows the new defs are named TMP4/TMP5 — presumably because TMP1-TMP3 already defined... but FileCheck allows redefinition of variables. Eh, doesn't matter for the PR description.

Let me now write the PR description.

Title: `[FIRRTL] Fix ExpandWhens dominance error with ops shared across layerblocks` — something imperative: `[FIRRTL] ExpandWhens: insert shared LTL condition ops before the when op` or `[FIRRTL] Fix dominance error in ExpandWhens with multiple layerblocks`.

Format requirements:
- Title line `[Dialect/Area] short imperative summary`
- Root cause
- Fix
- Testing
- Existing-test changes
- `Fixes #10104`

Let me write it.

[Response]
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

[Usage]
{"total": 7856, "input": 7, "output": 2408, "reasoning": 0, "cache": {"write": 4119, "read": 1322}, "cost_usd": 0.057182235, "reason": "stop"}

[Result]
{"num_turns": 1, "input_tokens": 7, "output_tokens": 2408, "reasoning_tokens": 0, "cache_read": 1322, "cache_write": 4119, "cost_usd": 0.057182235}

