[Dialect/DC] Convert pack/unpack folds into canonicalization patterns that erase the redundant ops

## Root cause

`dc.pack` and `dc.unpack` were implemented as *folders* rather than canonicalization
patterns. Folding is value-based: when `unpack(pack(t, v))` or `pack(unpack(v))`
matches, the folder replaces the op's *results* with the operands of the other
op but **leaves the defining op in place**. This changes the number of uses of
the surviving token/value:

- `UnpackOp::fold` replaced `unpack(pack(t, v))` with `t` and `v`, but kept the
  `dc.pack` alive. Any other user of the pack's token now sees that token
  consumed twice (once by the pack, once by the replacement) — e.g. a forked
  token like `%0:2 = dc.fork [2] %token` in issue #7949's example.
- `PackOp::fold` replaced `pack(unpack(v))` with `v`, but kept the `dc.unpack`
  alive, so `v` gained an extra consumer.

The DC-to-HW lowering requires every DC value/token to be used exactly once
(it emits `esi.wrap.vr`, which "only supports zero or one use"). After the
greedy folder ran, the IR still *looked* canonicalized but had values with
multiple uses, and `--lower-dc-to-hw` failed verification with:

```
error: 'esi.wrap.vr' op only supports zero or one use
note: Remember to run the fork/sink materialization pass before HW lowering.
```

This explains the behavior reported in the issue: running `--canonicalize`
between `--dc-materialize-forks-sinks` and `--lower-dc-to-hw` *breaks* IR that
otherwise lowers fine, because the folders silently perturb use counts.

## Fix

Replace the two `fold` methods with proper `OpRewritePattern`s in
`getCanonicalizationPatterns`, so the redundant op is actually erased and,
when the partner op has no remaining users, the partner is erased too:

- `EliminatePackUnpackPattern` on `UnpackOp`: `unpack(pack(t, v))` is
  rewritten to `t, v`; the `pack` is erased only if its result became dead,
  which preserves the "zero or one use" invariant.
- `EliminateUnpackPackPattern` on `PackOp`: `pack(unpack(v))` (matching
  data operand) is rewritten to `v`; the `unpack` is erased if dead.

Both patterns only fire on the same structural pattern the old folders
checked (`pack.getToken()` defined by `unpack` with matching data value, and
vice versa), so this is a strictly more correct, minimal change: same
simplifications, but the IR stays valid for the DC-to-HW lowering. The dead-op
erasure uses `use_empty()` before `eraseOp`, per MLIR practice.

## Testing

- Reproduced the failure from the issue: materialized DC IR with a
  forked token feeding a `pack`/`unpack` pair, run through
  `circt-opt --canonicalize --lower-dc-to-hw` → previously emitted
  `'esi.wrap.vr' op only supports zero or one use`; now lowers cleanly.
- Added `test/Conversion/DCToHW/basic.mlir`: `@unpackOfPackFork`, an end-to-end
  lowering test that CHECKs the wrap/unwrap pairs survive as valid single-use
  ESI channels.
- Added `test/Dialect/DC/canonicalization.mlir` cases:
  - `@unpackOfPackMultiUse`: pack result used elsewhere → pack kept, unpack
    eliminated (guards against over-eager erasure).
  - `@packOfUnpack`: both ops eliminated.
- Ran the full CIRCT lit suite (`test/Analysis` … `test/om-linker`, 22
  directories): **1022 passed, 0 failed**.

## Existing-test changes

No existing tests were modified. All test changes are pure additions appended
to `test/Conversion/DCToHW/basic.mlir` and `test/Dialect/DC/canonicalization.mlir`.

Fixes #7949