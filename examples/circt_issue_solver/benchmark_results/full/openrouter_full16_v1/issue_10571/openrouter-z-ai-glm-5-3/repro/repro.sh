#!/usr/bin/env bash
# Repro for issue #10571: [HWAggregateToComb] mux of hw.union fails to legalize.
# Exits 0 iff the bug is fixed (pass succeeds); non-zero while bug present.
set -o pipefail
CIRCT_OPT=/workspace/circt/build/bin/circt-opt
IN="$(dirname "$0")/minimal.mlir"
$CIRCT_OPT "$IN" --hw-aggregate-to-comb 2>&1
