#!/usr/bin/env bash
# Reproduction for CIRCT issue #8508:
#   [FIRRTL] InjectDUTHierarchy Creates Names that Conflict with ExtModule
#   Defnames
#
# InjectDUTHierarchy renames the DUT (here an extmodule whose defname is "Bar")
# to the injected hierarchy name "logic", then creates a new wrapper module
# named "Bar". The extmodule's defname ("Bar") then conflicts with the wrapper
# module's name, producing the verifier error:
#   error: 'firrtl.extmodule' op attribute 'defname' with value "Bar" conflicts
#          with the name of another module in the circuit
#
# Contract: exit 0 iff the bug is FIXED (firtool runs cleanly), non-zero while
# the bug is present.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIRTOOL=/workspace/circt/build/bin/firtool
INPUT="$SCRIPT_DIR/inject-dut-hierarchy-extmodule.fir"

# Run firtool on the reproducer. While the bug exists, firtool fails with the
# defname-conflict verifier error (non-zero exit). Once fixed, it compiles
# cleanly and exits 0.
if "$FIRTOOL" "$INPUT" > /dev/null 2>&1; then
  echo "PASS: firtool compiled the circuit cleanly (bug is fixed)"
  exit 0
else
  echo "FAIL: firtool rejected the circuit (bug #8508 still present)"
  "$FIRTOOL" "$INPUT" 2>&1 | head -5 || true
  exit 1
fi
