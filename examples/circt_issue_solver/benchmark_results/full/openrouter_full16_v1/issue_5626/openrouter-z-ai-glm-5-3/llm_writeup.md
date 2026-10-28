[Thinking]
Write PR description. Note: test file change was appended only (new test case added to existing file — no existing lines modified, so "No existing tests were modified" applies since only additions).

[Response]
[FIRRTL] LowerToHW: rename colliding explicit inner symbols against the module namespace

## Root cause

`LowerToHW` uses an `hw::InnerSymbolNamespace` (`moduleNamespace`) to invent unique inner symbol names, but not every path that mints a name consults it. In particular, LowerToHW invents inner symbols for dontTouch-annotated **ports** without recording them in (or checking against) `moduleNamespace` in a way that body operations see. Meanwhile, `lowerInnerSymbol()` passed explicitly-specified FIRRTL inner symbols through verbatim, assuming they were already unique within the module. That assumption is false: an explicitly-named body operation (e.g. a `firrtl.wire sym @__DTPortBodySym__DONTTOUCH__0__a`) can collide with the symbol LowerToHW just invented for a dontTouch'd port, producing two `hw.wire`s with the identical `inner_sym` — exactly the class of bug reported in #5626, surviving the partial fix in #5703 for the "fail to use the moduleNamespace at all" case.

## Fix

In `lowerInnerSymbol()`:

- Keep the existing `getOrAddInnerSym` path (which correctly goes through `moduleNamespace`) for operations that merely *require* an inner symbol but don't have one.
- For operations that carry an **explicitly specified** inner symbol, check each of its names against the rest of the module via a new helper, `innerSymNameTakenByOther()`. The helper walks the lowering module's `hw::InnerSymbolTable` and reports whether the name is claimed by anything other than the operation itself (e.g., a port, or another operation).
- If a name is taken, mint a fresh unique name with `moduleNamespace.newName("sym")`, preserving the field ID and visibility, and rebuild/re-sort the `InnerSymAttr`. Otherwise the user-specified symbol is passed through unchanged.

This is minimal and local: it only touches the point where explicit FIRRTL inner symbols are lowered into HW, uses the module's existing namespace as the uniqueness oracle, and does not change symbol invention for ports or any other lowering behavior. Renaming can, in principle, invalidate references (`hw::InnerRefAttr`s); that hazard is pre-existing and is called out in the retained TODO — fixing it requires a rename map for inner refs, which is beyond the scope of this bug fix.

## Testing

Repro (from the issue, plus the port/body-symbol collision variant):

```mlir
firrtl.module @DTPortBodySym(
  in %a: !firrtl.uint<1> [{class = "firrtl.transforms.DontTouchAnnotation"}]
) {
  %w = firrtl.wire sym @__DTPortBodySym__DONTTOUCH__0__a : !firrtl.uint<1>
  firrtl.connect %w, %a : !firrtl.uint<1>, !firrtl.uint<1>
}
```

Before the fix, lowering with `circt-opt -pass-pipeline="builtin.module(lower-firrtl-to-hw)"` produced a port inner symbol `@__DTPortBodySym__DONTTOUCH__0__a` and a body wire with the *same* inner symbol. After the fix, the body wire is renamed to a fresh unique symbol (`@sym`), and no duplicate inner symbols remain in the output.

- Added this case as a new test in `test/Conversion/FIRRTLToHW/lower-to-hw-module.mlir`.
- Rebuilt `circt-opt` and re-ran the repro through it (build passes, repro flips).
- Ran the full lit suite over `test/` (Analysis, Conversion, Dialect, Scheduling, Target, Tools, Transforms, Unit, arcilator, circt-*, firtool, etc.): **1022 passed, 0 failed**.

Remaining risk: renamed body symbols are not reflected in any `InnerRefAttr` that points at them (the pre-existing TODO); and explicit FIRRTL inner symbols that deliberately matched across modules (none are legal, but users do odd things) will now be renamed rather than emitting colliding HW.

## Existing-test changes

No existing tests were modified. The only test change is an appended new case in `test/Conversion/FIRRTLToHW/lower-to-hw-module.mlir`; no existing CHECK lines, inputs, or expectations were touched.

Fixes #5626

[Usage]
{"total": 4684, "input": 2425, "output": 955, "reasoning": 24, "cache": {"write": 0, "read": 1280}, "cost_usd": 0.0016282995, "reason": "stop"}

[Result]
{"num_turns": 1, "input_tokens": 2425, "output_tokens": 955, "reasoning_tokens": 24, "cache_read": 1280, "cache_write": 0, "cost_usd": 0.0016282995}

