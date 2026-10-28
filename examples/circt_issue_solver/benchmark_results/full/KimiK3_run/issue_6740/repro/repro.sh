#!/usr/bin/env bash
# Reproduction for https://github.com/llvm/circt/issues/6740
# [FIRRTLToHW] Conversion failure of invalidated wire of clock type
#
# `firrtl.invalidvalue : !firrtl.clock` is lowered to `hw.bitcast (i1) ->
# !seq.clock`, which fails the hw.bitcast verifier (seq.clock has no known
# hardware bitwidth). The pass should instead emit a legal constant (e.g.
# `seq.clock` zero via `seq.const_clock` or an equivalent lowering).
#
# Exit 0 iff the bug is FIXED (circt-opt -lower-firrtl-to-hw succeeds and
# produces no invalid hw.bitcast to !seq.clock); non-zero while it reproduces.

set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CIRCT_OPT="${CIRCT_OPT:-$DIR/../build/bin/circt-opt}"
INPUT="$DIR/issue6740.mlir"

# The verifier error makes circt-opt exit non-zero today.
if ! OUT="$("$CIRCT_OPT" -lower-firrtl-to-hw "$INPUT" 2>&1)"; then
  echo "REPRODUCED: circt-opt -lower-firrtl-to-hw failed:" >&2
  echo "$OUT" >&2
  exit 1
fi

# Also guard against a miscompile that exits 0 but still emits the illegal op.
if echo "$OUT" | grep -q 'hw.bitcast.*!seq.clock'; then
  echo "REPRODUCED: illegal hw.bitcast to !seq.clock still emitted:" >&2
  echo "$OUT" >&2
  exit 1
fi

echo "PASS: invalidated clock wire lowered cleanly."
exit 0
