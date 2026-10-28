#!/usr/bin/env bash
# Reproduction for https://github.com/llvm/circt/issues/7949
# "[DCToHW] Pass creates invalid ESI connections"
#
# --lower-dc-to-hw used to emit an `esi.wrap.vr` op whose channel result had
# more than one consumer, producing invalid IR:
#   error: 'esi.wrap.vr' op channels must have at most one consumer
#
# Exit 0 iff the bug is fixed (lowering succeeds and produces valid IR),
# non-zero while the bug is present.
set -u

CIRCT_OPT=/workspace/circt/build/bin/circt-opt
INPUT=/workspace/circt/.circtissues/dc7949.mlir
LIT_TEST=/workspace/circt/build/test/Conversion/DCToHW/fork-multiple-consumers.mlir

# 1. Direct check: lowering the minimal repro must succeed (the verifier runs
#    as part of the pass pipeline, so invalid `esi.wrap.vr` connections cause
#    a non-zero exit).
if ! "$CIRCT_OPT" "$INPUT" --lower-dc-to-hw -o /dev/null; then
  echo "FAIL: --lower-dc-to-hw rejected the valid DC program (issue #7949)" >&2
  exit 1
fi

# 2. Lit regression test guarding against regressions.
if ! lit -v "$LIT_TEST"; then
  echo "FAIL: lit regression test failed" >&2
  exit 1
fi

echo "PASS: issue #7949 is fixed"
exit 0
