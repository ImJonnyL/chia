#!/usr/bin/env bash
# Reproduction for CIRCT issue #10104:
# [FIRRTL] ExpandWhens dominance error with multiple layerblocks and
# implication intrinsics.
#
# Exit 0 iff the bug is FIXED, non-zero while it is still present.
#
# The bug is a verifier (dominance) error: circt-opt exits non-zero when
# `firrtl-expand-whens` produces IR where an `firrtl.int.verif.assert` in one
# layerblock uses an `firrtl.int.ltl.implication` defined in another
# layerblock. A clean run after the fix exits 0.

set -u

CIRCT_OPT=/workspace/circt/build/bin/circt-opt
INPUT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/repro.mlir"

"$CIRCT_OPT" \
  --pass-pipeline="builtin.module(firrtl.circuit(firrtl.module(firrtl-expand-whens)))" \
  "$INPUT" >/dev/null 2>&1
status=$?

if [ "$status" -ne 0 ]; then
  echo "BUG PRESENT: firrtl-expand-whens produced invalid IR (dominance error)" >&2
  "$CIRCT_OPT" \
    --pass-pipeline="builtin.module(firrtl.circuit(firrtl.module(firrtl-expand-whens)))" \
    "$INPUT" >/dev/null
  exit 1
fi

echo "BUG FIXED: firrtl-expand-whens ran cleanly"
exit 0
