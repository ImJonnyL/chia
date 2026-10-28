#!/usr/bin/env bash
# Reproduction for CIRCT issue #10104:
#   [FIRRTL] ExpandWhens dominance error with multiple layerblocks and
#   implication intrinsics
#
# The ExpandWhens pass used to emit IR with a verifier dominance error when
# two separate `firrtl.layerblock`s inside the same `firrtl.when` each
# contained an identical `firrtl.int.ltl.implication` feeding an
# `firrtl.int.verif.assert`.
#
# Exit status:
#   0      - the bug is FIXED (pass succeeds and produces valid IR)
#   non-0  - the bug is still present (verifier dominance error)
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CIRCT_OPT=/workspace/circt/build/bin/circt-opt

# The pass must run cleanly (no verifier/dominance errors) on the minimal
# reproducer.
"$CIRCT_OPT" \
  --pass-pipeline="builtin.module(firrtl.circuit(firrtl.module(firrtl-expand-whens)))" \
  "$DIR/repro.mlir" -o /dev/null
