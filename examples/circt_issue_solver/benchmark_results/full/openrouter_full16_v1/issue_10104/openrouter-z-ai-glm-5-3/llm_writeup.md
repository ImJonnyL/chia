[Thinking]
Write PR description.

[Response]
[FIRRTL] Fix dominance violations when reusing LTL property ops across layerblocks in ExpandWhens

## Root cause

`ExpandWhens`' `WhenOpVisitor` merges the `when` condition into assert/assume properties by rewriting the property's LTL intrinsic (e.g. `ltl.implication`) into a new intrinsic with the condition `ltl.and`-ed onto its input. To avoid creating duplicate ops, it caches these synthesized intrinsics in maps (`createdLTLAndOps`, `createdLTLClockOps`, `createdLTLImplicationOps`) keyed by their operands, and reuses a cached op whenever an entry already exists.

The cache lookup ignored *where* the cached op was created. Since the visitor processes a `when` region in program order and inserts each synthesized op immediately before the operation currently being visited, a cached op is only valid for later uses in the *same* block or in blocks it encloses. When the same property appears in a second, *sibling* `layerblock` (or after the first one), the cached op from the first layerblock does not dominate the reuse site — hence the "operand #0 does not dominate this use" verifier error from issue #10104. This is why the bug needed two separate `firrtl.layerblock`s with the same implication intrinsic: the first layerblock populated the cache, and the second one (or the trailing region) reused a non-dominating value.

## Fix

Add two small helpers to `ExpandWhens.cpp`:

- `blockDominatesUse(defBlock, use)` — walks the block chain of the use's enclosing operations and checks whether `defBlock` appears. Because the visitor creates every cached op directly before the op being visited and visits ops in program order, "def block is the use's block or an enclosing block" is exactly equivalent to dominance for these cached values.
- `valueDominatesUse(value, use)` — same check for a `Value` (op result or block argument).

Then, at each of the four cache-reuse sites (`ltlAndWithCondition`, `ltlImplicationWithCondition`, and the two clock-intrinsic paths), reuse a cached op only if it actually dominates the current use:

```cpp
if (!newOp || !valueDominatesUse(newOp, op))
  newOp = OpBuilder(op).createOrFold<...>(...);
```

If the cached op doesn't dominate, a fresh op is synthesized at the current position and replaces the cache entry. The keys used in the maps are operand pairs, so re-writing the entry with an equivalent op preserves the intended CSE behavior for subsequent uses in the same block (the second layerblock's assert reuses `[[IMPL1]]` in the test below).

The change is confined to the reuse decision; the synthesis logic itself is untouched, making this the minimal fix.

## Testing

- Repro from the issue (two sibling `layerblock`s inside a `when`, each containing `int.ltl.implication` + `int.verif.assert`): previously failed with `operand #0 does not dominate this use`; now compiles cleanly through `circt-opt --pass-pipeline="builtin.module(firrtl.circuit(firrtl.module(firrtl-expand-whens)))"` and `firtool`.
- Added a new test `@WhenAroundLayerblockPropertyAsserts` in `test/Dialect/FIRRTL/expand-whens.mlir` covering:
  - a property asserted inside a layerblock,
  - the same property asserted in the enclosing `when` block (cache created here),
  - the same property asserted again in a *sibling* layerblock (which now reuses the dominating op synthesized in the `when` block, rather than the non-dominating one from the first layerblock).

  The CHECKs pin down both that the `when` is expanded away and that a single dominating `ltl.and`/`ltl.implication` pair is reused where legal.

- Full lit run across all CIRCT test directories: **1022 passed, 0 failed** (see verification result). Build clean.

Remaining risk: the dominance-equivalence argument relies on the visitor's create-before-visit discipline; the helpers are documented with that invariant so future edits keep it honest.

## Existing-test changes

No existing tests were modified. The diff to `test/Dialect/FIRRTL/expand-whens.mlir` is purely additive (a new `@WhenAroundLayerblockPropertyAsserts` module appended before `@ClassWithInput`).

Fixes #10104

[Usage]
{"total": 5291, "input": 3055, "output": 955, "reasoning": 1, "cache": {"write": 0, "read": 1280}, "cost_usd": 0.0016401365, "reason": "stop"}

[Result]
{"num_turns": 1, "input_tokens": 3055, "output_tokens": 955, "reasoning_tokens": 1, "cache_read": 1280, "cache_write": 0, "cost_usd": 0.0016401365}

