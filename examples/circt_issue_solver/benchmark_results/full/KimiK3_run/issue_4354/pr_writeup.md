[LowerToHW] Emit an error when ForceNameAnnotation would force a non-unique instance name

## Root cause

`LowerToHW` applies `chisel3.util.experimental.ForceNameAnnotation`s in `FIRRTLModuleLowering::handleForceNameAnnos`, recording the requested name for each targeted instance (later materialized as an instance rename / `hw.verilogName`). It never checked whether that forced name was unique within the parent module. As a result, two instances in the same module could be forced to the same name — as in the issue's reproducer — and a forced name could also collide with the plain name of another instance in the module.

Neither case was diagnosed. The collision only surfaced much later, when `PrepareForEmission`/ExportVerilog silently uniqued the colliding names, producing `Foo`, `Foo_0`, `Foo_1` — i.e. Verilog in which the names the user explicitly requested are not the names that appear, with no indication anything went wrong.

## Fix

Two small additions in `lib/Conversion/FIRRTLToHW/LowerToHW.cpp`:

- While `handleForceNameAnnos` processes force-name annotations, it now records `(parent module, forced name, instance inner symbol)` triples in a new `CircuitLoweringState::instanceForcedNames` list.
- After all modules have been processed, `runOnOperation` calls a new `verifyForceNameAnnos`, which walks each new HW module body — at this point the FIRRTL bodies have been moved over and still contain the original, not-yet-lowered `firrtl.instance` ops — to build per-module maps of instance name → location and inner symbol → instance name. It then checks every recorded forced name:
  - the forced name must not equal the name of a *different* instance in the same module, and
  - no two instances in the same module may be forced to the same name.

A collision is reported as an error at the forced instance's location with a note pointing at the other instance, and the pass fails.

This is correct and minimal because the check runs exactly once, after all annotation processing, so every forced name (including non-local ones resolved through `hw.hierpath`) is known; it reads names/symbols directly from the still-unlowered `firrtl.instance` ops rather than reverse-engineering lowered IR; and it fails the pass before any Verilog emission, so silently-uniqued output can never be produced. Both collision classes are covered because they manifest identically in emission. Valid designs are unaffected — the only new behavior is diagnostics on input that previously produced silently-wrong names.

## Testing

The reproducer from the issue now errors instead of silently producing colliding `verilogName`s:

```
$ circt-opt --lower-firrtl-to-hw issue.mlir
issue.mlir: error: multiple instances in module 'ForceNameTop' are forced to the same name, "Foo"
issue.mlir: note: another instance is forced to this name here
```

Added two new tests to `test/Conversion/FIRRTLToHW/lower-to-hw-errors.mlir`:

1. Two instances in one module forced to the same name → error `multiple instances in module '...' are forced to the same name, "Foo"` with a note on the first forced instance.
2. An instance forced to the name of an existing instance in the same module → error `instance '...' is forced to a name, "Foo", which is not unique within module '...'` with a note on the instance already using the name.

Full ninja build passes. Full lit regression suite passes: 1022 passed, 0 failed across `test/Analysis`, `test/Conversion`, `test/Dialect`, `test/Scheduling`, `test/Target`, `test/Tools`, `test/Transforms`, `test/Unit`, and the tool-specific suites. To be candid: an earlier iteration of this change was flagged in an initial lit run on the newly added test file while the diagnostics were being finalized; the final diff passes the complete suite with no failures. No remaining unverified areas or known risks — the verification only inspects forced-name records and instance names/symbols that are guaranteed present at that point in the pass.

## Existing-test changes

No existing tests were modified. The only test changes are two new `// -----`-split cases appended to the end of `test/Conversion/FIRRTLToHW/lower-to-hw-errors.mlir`; no pre-existing lines, inputs, or expectations were edited or removed.

Fixes #4354