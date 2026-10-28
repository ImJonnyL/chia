#!/bin/bash
# Reproduction for CIRCT issue #10571: [HWAggregateToComb] Mux of unions.
#
# Exit 0 iff the bug is FIXED, non-zero while it is still present.
#
# Today `circt-opt --hw-aggregate-to-comb` fails with:
#   error: failed to legalize operation 'comb.mux' that was explicitly marked illegal
# because the pass has no lowering for muxes over !hw.union types (struct/array
# muxes work). Once fixed, the pass succeeds and no comb.mux over a !hw.union
# remains.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CIRCT_OPT=/workspace/circt/build/bin/circt-opt

exec "$CIRCT_OPT" "$DIR/issue-10571-mux-of-union.mlir" --hw-aggregate-to-comb | \
  FileCheck "$DIR/issue-10571-mux-of-union.mlir"
