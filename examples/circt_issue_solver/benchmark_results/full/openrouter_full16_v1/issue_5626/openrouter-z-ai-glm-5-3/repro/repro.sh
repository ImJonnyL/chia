#!/usr/bin/env bash
# Repro for https://github.com/llvm/circt/issues/5626
#
# LowerToHW picks the inner symbol name for dontTouch'd ports
# ("__<module>__DONTTOUCH__<n>__<port>") without consulting (or populating)
# the hw::ModuleNamespace, so it can collide with an inner symbol on an
# operation inside the module body. The pass exits 0 but emits two ops with
# the same inner_sym -> miscompile.
#
# Exit 0 iff the bug is FIXED (the dontTouch port symbol is unique).

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CIRCT_OPT="$ROOT/build/bin/circt-opt"
INPUT="$ROOT/.circtissues/issue5626.mlir"

OUT=$("$CIRCT_OPT" -pass-pipeline="builtin.module(lower-firrtl-to-hw)" "$INPUT")

# The port's dontTouch symbol must appear exactly once: on the port.
COUNT=$(grep -o "@__Test__DONTTOUCH__0__x" <<<"$OUT" | wc -l)

if [ "$COUNT" -ne 1 ]; then
  echo "BUG PRESENT: inner symbol '@__Test__DONTTOUCH__0__x' used $COUNT times"
  echo "$OUT"
  exit 1
fi

echo "OK: no inner symbol collision"
exit 0
