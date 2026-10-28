[Thinking]
Write PR description.

[Response]
# [FIRRTLToHW] Error on duplicate ForceNameAnnotations forcing the same instance name

## Root cause

`ForceNameAnnotation` overrides the name of a specific instance during
`LowerToHW` by writing an `hw.verilogName` attribute on the lowered
`hw.instance`. When two annotations inside the same module target two
*different* instances but force the *same* name, `LowerToHW` happily emitted
two instances with identical `hw.verilogName` attributes. The collision was
only resolved later, silently, by the name uniquing in
`PrepareForEmission`/`ExportVerilog` (`Foo_0`, `Foo`, `Foo_1` in the issue's
repro). Nothing ever told the user that their annotations conflicted; the
renaming was invisible until it showed up (or didn't) in the emitted Verilog.

## Fix

In `FIRRTLModuleLowering::handleForceNameAnnos` (lib/Conversion/FIRRTLToHW/LowerToHW.cpp),
where each `ForceNameAnnotation` is resolved to its target instance, I added a
per-circuit map from `(parent module, forced name)` to the instance that
already claimed it. If a second, *different* instance in the same module tries
to claim a name that is already taken, we now emit an op error on the old
FIRRTL module:

- the error states that multiple `chisel3.util.experimental.ForceNameAnnotation`s
  share the same name while targeting different instances,
- a note points at the instance already using the forced name,
- a note prints the conflicting annotation dict.

The same (module, name) pair targeting the same instance (i.e. a duplicated
annotation that is a no-op) is still allowed, so this only rejects genuine
conflicts. The check lives exactly where the annotations are already being
walked and validated, so the added state (one `DenseMap` member on the
lowering state, mirroring the existing `instanceForceNames` map) is the only
plumbing needed. Failed validation propagates through the existing `failed`
flag and the pass continues to collect any further errors before bailing out,
consistent with the surrounding error-handling style.

## Testing

- Reproduced the issue's IR (two `ForceNameAnnotation`s with `name = "Foo"`
  targeting different instances via two NLA paths) and confirmed it used to
  lower silently to two identically-named `hw.instance`s; it now produces the
  new error.
- Added a new case to `test/Conversion/FIRRTLToHW/lower-to-hw-errors.mlir`
  covering exactly this, with `expected-error` plus two `expected-note`s.
- Ran lit across `test/Analysis`, `test/Conversion`, `test/Dialect`,
  `test/Scheduling`, `test/Target`, `test/Tools`, `test/Transforms`,
  `test/Unit`, `test/firtool`, and the remaining test directories:
  **1022 passed, 0 failed**.

Remaining risk is minimal: nothing previously valid is rejected, since the
only newly-erroring input is one that would have produced a silent name
collision at export time.

## Existing-test changes

No existing tests were modified. The diff only *appends* a new test case to
`test/Conversion/FIRRTLToHW/lower-to-hw-errors.mlir`; all pre-existing
expectations in that file are untouched.

Fixes #4354

[Usage]
{"total": 4216, "input": 3470, "output": 745, "reasoning": 1, "cache": {"write": 0, "read": 0}, "cost_usd": 0.001286953, "reason": "stop"}

[Result]
{"num_turns": 1, "input_tokens": 3470, "output_tokens": 745, "reasoning_tokens": 1, "cache_read": 0, "cache_write": 0, "cost_usd": 0.001286953}

