#!/bin/bash
# Issue #10104: ExpandWhens dominance error with multiple layerblocks and
# implication intrinsics.
#
# Exit 0 iff the bug is FIXED (circt-opt succeeds on the minimal input);
# exit non-zero while the dominance error is still present.
set -o pipefail
cd "$(dirname "$0")"
/workspace/circt/build/bin/circt-opt \
  --pass-pipeline='builtin.module(firrtl.circuit(firrtl.module(firrtl-expand-whens)))' \
  repro.mlir >/dev/null
