#!/usr/bin/env bash
# Reproduction for issue #4354:
#   [LowerToHW] An Error Should Be Generated if ForceNameAnnotation
#   Would Not Be Unique
#
# Two ForceNameAnnotations can force two different instances inside the
# same module to the SAME name.  LowerToHW should error out, but today it
# silently lowers both and ExportVerilog emits a module that instantiates
# `ForceNameSubmodule Foo` twice.
#
# Contract:
#   - exit 0  iff the bug is FIXED (firtool emits an error diagnostic)
#   - exit != 0 while the bug is still present (firtool exits cleanly and
#     the emitted Verilog contains two instances both forced to "Foo")

set -u
cd "$(dirname "$0")/.."
TOOL=build/bin/firtool
INPUT=.circtissues/forcename.mlir

# Bug-present marker: the Verilog output contains more than one instance
# forced to the same name "Foo".
BUGGY_VERILOG_SNIPPET='ForceNameSubmodule Foo'

out=$($TOOL "$INPUT" -verilog 2>&1)
rc=$?

if [ $rc -ne 0 ]; then
  # firtool failed.  Only acceptable if it failed because of the missing
  # uniqueness check (an error mentioning ForceNameAnnotation).
  if grep -q "error:.*ForceNameAnnotation" <<<"$out"; then
    echo "FIXED: firtool rejects duplicate ForceNameAnnotation targets"
    exit 0
  fi
  echo "firtool failed for an unrelated reason:"
  echo "$out" | tail -20
  exit 2
fi

# firtool succeeded: count instances forced to "Foo" in the Verilog output.
count=$(grep -c "$BUGGY_VERILOG_SNIPPET" <<<"$out" || true)

if [ "$count" -ge 2 ]; then
  echo "BUG PRESENT: firtool emitted $count instances all forced to 'Foo':"
  echo "$out" | grep -n "$BUGGY_VERILOG_SNIPPET"
  exit 1
fi

echo "FIXED: no duplicate forced instance names in the emitted Verilog"
exit 0
