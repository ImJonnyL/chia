[Thinking]
Let me analyze the situation carefully.

The issue: InjectDUTHierarchy creates names that conflict with ExtModule defnames. When the DUT is an external module (weird but possible), the pass renames the extmodule to the wrapper name but leaves `defname = Bar`, then creates a new FModuleOp named "Bar". This creates a conflict because the defname "Bar" of the extmodule conflicts with the module named "Bar".

My diff attempts to fix this but:
1. The verification says `fixed: false` — the fix did NOT work
2. Lit regressed: 4 test failures
3. The diff contains DEBUG code (`llvm::errs() << "DBG ..."`) that should never be in a PR

Let me look at what's in the diff:
- Changes `addHierarchy` to take `FModuleLike wrapper, StringAttr wrapperInstName` instead of `InstanceOp wrapperInst`
- Changes `FModuleOp wrapper` to `FModuleLike wrapper`
- Changes `FModuleOp dut` to `FModuleLike dutLike`
- Contains debug prints with `llvm::errs()` — DBG statements
- Handles the extmodule case: updates defname if it matches the old DUT name
- Uses `InstanceChoiceOp` for extmodule wrappers since instance must be passive
- Uses `wrapper.setName(wrapperNameAttr)` on FModuleLike — wait, does FModuleLike have setName? Actually FModuleLike has `setModuleName`... Hmm, the diff shows `wrapper.setName(wrapperNameAttr)` — FModuleLike interface has a `setName`? Actually igraph::ModuleOpInterface has setModuleNameAttr. FModuleLike... In CIRCT, FModuleLike has methods like getModuleName, setModuleName... Actually, there is `setName` in FModuleLike? Let me not worry about verifying compilability — the build succeeded per verification (`build_ok: true`).

But the important facts:
- `fixed: false` — the repro did not flip. The automated verification says the fix did not fix the issue.
- `lit_ok: false` with 4 failures:
  - test/firtool/extract-instances.fir
  - test/Dialect/FIRRTL/SFCTests/ExtractSeqMems/Compose.fir
  - test/Dialect/FIRRTL/inject-dut-hierarchy.mlir
  - test/Dialect/FIRRTL/extract-instances-inject-dut-hier.mlir

Also the diff has debug output statements (`llvm::errs() << "DBG ..."`) which would pollute stderr and break FileCheck tests that check stderr or that use `-verify-diagnostics`... Actually the DBG prints would definitely break tests since they print to stderr unconditionally. That's likely a major cause of the lit failures.

Also, did I modify any test files? Looking at the diff — only `lib/Dialect/FIRRTL/Transforms/InjectDUTHierarchy.cpp` was modified. No test files changed.

So the PR description must be honest:
- The fix is incomplete/incorrect: verification says `fixed: false` and lit regressed with 4 failures.
- The diff still contains debug prints.

Wait — the task says "You have finished working on the CIRCT issue below. Write the GitHub Pull Request description you WOULD submit for your change." So I need to write the PR description for the change as-is. But given verification failed, I should be honest about it. The instructions say: "Call out honestly anything left unverified or any remaining risk (e.g. if the diff is empty, the repro did not flip, or lit regressed, say so plainly)."

Should I go back and fix it? The prompt says "You have finished working" — this is the step where I write the PR description, not continue fixing. The instructions for the PR description say to be candid. So I write the PR description honestly stating that the repro did not flip and lit regressed.

Hmm, but wait. Actually, let me think about whether I should keep working. The prompt structure: "You have finished working on the CIRCT issue below. Write the GitHub Pull Request description you WOULD submit for your change." So this turn is specifically to write the PR description. I shouldn't keep editing. I should output only the PR description.

Let me analyze the diff more carefully to describe the root cause and fix accurately.

Root cause: `InjectDUTHierarchy` assumed the DUT is always a regular `firrtl.module` (FModuleOp). When the DUT is an external module (`firrtl.extmodule`) with an explicit or default `defname`:

1. The pass renames the DUT module to the wrapper name (e.g., `logic`) and creates a new module with the DUT's original name (`Bar`). But the extmodule's `defname` attribute still says `Bar`, which now conflicts with the newly created `firrtl.module @Bar` — defnames must not conflict with any module name in the circuit (FIRRTL verifier check: "attribute 'defname' with value \"Bar\" conflicts with the name of another module in the circuit").

2. With assertions enabled, the pass crashed because it did `cast<FModuleOp>(instanceInfo.getDut())` — casting an FExtModuleOp to FModuleOp trips the `cast<Ty>` assertion.

Wait, actually looking at the stack trace, the crash was in `runOnOperation()` — `(anonymous namespace)::InjectDUTHierarchy::runOnOperation() + 5980`. The cast `cast<FModuleOp>(instanceInfo.getDut())` would be the assertion failure point.

The fix in the diff:
1. Generalize from FModuleOp to FModuleLike so an extmodule DUT doesn't crash the cast.
2. When the wrapper (old DUT) is an extmodule whose defname equals the old DUT name (the default defname), rename the defname to the wrapper's new name to avoid conflict with the newly created DUT module.
3. Instantiate an extmodule wrapper with `firrtl.instance_choice` (no options) instead of `firrtl.instance` — the rationale in the diff comment is that instance expressions must be passive and an extmodule may have non-passive ports... Hmm, actually wait. Let me think. Is that right? In FIRRTL, `firrtl.instance` requires the referenced module's ports to be passive? Actually the constraint is on the instance's result types... An extmodule can have analog or non-passive ports? Extmodule ports are always passive? Hmm. Actually in the FIRRTL dialect, `firrtl.instance` can only instantiate FModuleOp? Let me check... The InstanceOp in CIRCT has a constraint on the referenced module? In recent CIRCT, InstanceOp's results are built from the module's ports and I believe instances require passive types for probe... Actually the diff comment says "instance expressions must be composed of passive types and an external module may have non-passive ports." Hmm, I recall that FIRRTL `inst` expressions require the module to have passive ports — that's a spec thing. And `instchoice` is used for extmodules with non-passive ports. OK.

4. Update `addHierarchy` to not depend on `InstanceOp` (since wrapperInst may now be an InstanceChoiceOp, i.e., FInstanceLike).

However, verification says the fix didn't work (`fixed: false`) and 4 lit tests fail. Why might the repro not flip? Possibly:
- The debug prints to stderr cause firtool to still error? No, debug prints don't cause errors. But the verification "fixed" check probably runs the repro and checks it succeeds. With debug prints the output would have junk but not fail... unless the pass crashes or the verifier still fails.

Hmm, why would it still fail? Let's think about `wrapper.setName(wrapperNameAttr)` on an FExtModuleOp — wait, in the `moveDut=false` branch: `wrapper.setName(wrapperNameAttr)`. FModuleLike::setName? There's `setModuleName` maybe. Actually FModuleLike in CIRCT (FIRRTLOpInterfaces) has `setModuleName(StringAttr)`? I recall `FModuleLike` has methods: getModuleName(), getModuleNameAttr(), setModuleNameAttr? Hmm. There's `hw::HWModuleLike::setModuleName`. And igraph::ModuleOpInterface has setModuleName. OK whatever, build succeeded so it compiles.

Why would the repro not be fixed? Possibly the defname conflict check also involves `getDefnameAttr()` — for an extmodule without explicit defname, the defname defaults to the module name. In the repro, `defname = Bar` is explicit. The code checks `defname.getValue() == oldDutNameAttr.getValue()` and renames defname to a fresh name. That should resolve the conflict...

Wait, but also there might be an issue with `wrapper.setName(...)` — for an extmodule, changing sym name to `logic` while creating `firrtl.module @Bar`. Then defname set to `logic`? Actually `wrapperDefnameAttr = circuitNS.newName(wrapperNameAttr.getValue())` → "logic" presumably. Then extmodule @logic with defname "logic". New module @Bar. No conflict. Hmm.

But wait — maybe the verifier also checks that defname doesn't conflict... it checks defname against all module names and defnames of other modules. "logic" defname vs module @logic — hmm, is a defname equal to its own module's name allowed? Yes, that's the default. The check excludes self presumably.

Actually, maybe the verification failure is due to something else — the `InstanceChoiceOp` creation might produce invalid IR or the wiring might be wrong. Or maybe the crash still occurs elsewhere. We can't know precisely without more info. The notes field is null, so I don't know the failure mode.

Also the debug prints (`llvm::errs()`) — these would break lit tests that check output? Most FileCheck tests check stdout only, but some use `2>&1`. The 4 failing tests: inject-dut-hierarchy.mlir is the direct test for this pass; extract-instances tests exercise the pass in firtool pipelines. The failures could be from the debug prints or from actual behavioral changes.

Actually wait — the debug prints print the entire op with `*dutLike` — for an FModuleLike. That's fine.

Hmm, but actually there's a subtle bug in the diff: in the `moveDut` branch, `dut.setName(wrapperNameAttr)` — but then the defname fixup uses `oldDutNameAttr` comparison... In moveDut mode, the wrapper keeps the old name (wrapper = original dut which keeps its name since only `dut` is renamed). Then the defname of the extmodule wrapper would be the old dut name, and `dut` is renamed to wrapperName ("logic"). Then no conflict: extmodule @Bar defname=Bar, new module @logic. Wait but in moveDut mode, does the defname need updating? The new DUT gets name "logic", the wrapper (extmodule) keeps name "Bar" and defname "Bar". That's fine. But the diff's defname fixup runs unconditionally in both branches: if defname == oldDutNameAttr ("Bar"), it sets defname to newName("logic")... In moveDut mode that would change defname from "Bar" to "logic" unnecessarily — changing the emitted Verilog module name of the extmodule! That's a behavioral regression... but wait, in moveDut mode, hmm, actually would that break extract-instances tests? extract-instances uses moveDut mode (InjectDUTHierarchy with moveDut=true is used by extract instances? Actually `InjectDUTHierarchyAnnotation` with `moveDut`... The extract-instances flow sets moveDut). Hmm, but that only matters when the DUT is an extmodule, which is rare.

Actually, more likely the lit failures come from the unconditional debug prints polluting stderr, and tests like `firtool/extract-instances.fir` that might merge stderr, or from the fact that the repro still fails.

Hold on — actually, let me reconsider. Maybe the tests fail because... `inject-dut-hierarchy.mlir` has CHECK lines and the pass behavior changed? The pass behavior only changes for extmodule DUTs. The test file inject-dut-hierarchy.mlir at that version — does it have an extmodule DUT test? Possibly not. So failures there would be from debug prints if the test checks stderr... `circt-opt` tests use FileCheck on stdout. Debug prints go to stderr, which lit captures separately and doesn't fail on. Hmm.

Wait — but `llvm::errs() << "DBG dutLike op: " << *dutLike` — printing the operation... `*dutLike` where dutLike is FModuleLike — fine.

Hmm, actually maybe the failures are real behavioral ones. Let me think about `inject-dut-hierarchy.mlir` in 1.148.0. It contains tests for the pass including NLAs. The diff changed `addHierarchy` signature and behavior subtly? Let's check: original code:

```cpp
newNamepath.push_back(hw::InnerRefAttr::get(dut.getModuleNameAttr(), getInnerSymName(wrapperInst)));
...
newNamepath.push_back(hw::InnerRefAttr::get(wrapperInst.getModuleNameAttr().getAttr(), dutRef.getName()));
...
newNamepath.push_back(FlatSymbolRefAttr::get(wrapperInst.getModuleNameAttr().getAttr()));
```

New code:

```cpp
newNamepath.push_back(hw::InnerRefAttr::get(dut.getModuleNameAttr(), wrapperInstName));
...
newNamepath.push_back(hw::InnerRefAttr::get(wrapper.getModuleNameAttr(), dutRef.getName()));
...
newNamepath.push_back(FlatSymbolRefAttr::get(wrapper.getModuleNameAttr()));
```

`wrapperInst.getModuleNameAttr().getAttr()` is the module name of the instanced module = wrapper's module name. So `wrapper.getModuleNameAttr()` is equivalent. OK, semantically equivalent.

But wait — for the InstanceChoiceOp path, `wrapperInstName` is passed as the `innerSym`? InstanceChoiceOp constructor signature: (build module... ). The InstanceChoiceOp::create with `wrapperInstName` — is that parameter an inner sym? InstanceChoiceOp has a `sym_name`? InstanceChoiceOp in FIRRTL: it has `moduleName` attr... Let me recall. InstanceChoiceOp is like an instance with option cases; it has an inner sym? I believe InstanceChoiceOp does have a sym (inner sym) — `firrtl.instance_choice` has sym_name? Hmm. In FIRRTL dialect, InstanceChoiceOp: "instance_choice" op has attributes: caseNames? targetInfo... Actually it has `inner_sym`? Not sure. If it lacks an inner sym, then `getInnerSymName` on it would be null, which is why the diff captures `wrapperInstName` separately and the NLA references it. If InstanceChoiceOp has no inner sym, referencing it via InnerRefAttr would be broken... but that's only for extmodule DUT case.

OK — the details don't matter that much for writing the PR description. What matters is honesty: the change as given does NOT pass verification. The automated result says `fixed: false`, `lit_ok: false`, 4 failures.

So the PR description must:
- Describe root cause and intended fix.
- Be candid that the repro did not flip and 4 lit tests regressed, that the diff still contains debug `llvm::errs()` instrumentation that must be removed, and that this is not ready to merge.

Also "Existing-test changes" — the diff modifies no test files. So state "No existing tests were modified."

Now, should the PR description be written as if submitting (polished) but with honest caveats? Yes. The instructions: "Call out honestly anything left unverified or any remaining risk (e.g. if the diff is empty, the repro did not flip, or lit regressed, say so plainly)."

Let me also try to diagnose likely reasons the verification failed, to be precise:

1. Leftover debug printing (`llvm::errs()` DBG lines) — unconditionally prints to stderr on every run of the pass; this alone makes the patch unsubmittable and likely breaks tests that are sensitive to stderr (e.g., tests using `--verify-diagnostics` won't care, but `firtool` tests that capture all output or use `-o /dev/null` with error checks might). Actually more importantly, the failing tests may fail because the pass now misbehaves.

2. Possible real bug: in the `moveDut=true` branch the defname rewrite fires when it shouldn't (wrapper keeps old name "Bar", defname "Bar" is fine there — rewriting it to "logic" changes the extmodule's Verilog defname unnecessarily). Hmm wait, actually in moveDut mode: original DUT keeps its name as wrapper. dut (new module) renamed to "logic". Conflict: new module @logic vs extmodule defname "Bar" — no conflict. So defname rewrite not needed; doing it renames the extmodule's Verilog name from "Bar" to "logic", which changes emitted Verilog. That's a bug in the patch.

Actually wait, in moveDut mode is there any conflict at all? New module @logic (FModuleOp). extmodule @Bar defname=Bar. No conflict. So moveDut mode was never broken? The issue example uses InjectDUTHierarchyAnnotation without moveDut... The annotation in the issue is `InjectDUTHierarchyAnnotation` with `name: "logic"` — the non-moveDut path ("legacy behavior"). In that path: new dut gets old name "Bar", wrapper renamed to "logic". Extmodule wrapper @logic defname=Bar → conflict with module @Bar. That's the bug.

3. Why might the repro still fail (`fixed: false`)? Possible reasons:
   - The `AnnotationSet::removeAnnotations(wrapper.getOperation(), ...)` on an FModuleLike — fine.
   - `wrapper.setPrivate()` — FModuleLike has setPrivate? There's `setVisibility`... FModuleLike interface — hmm.
   - Maybe verification runs firtool on the repro and the pipeline still errors because... the InstanceChoiceOp with no option cases — is that legal? `firrtl.instance_choice` with zero cases: the verifier might require at least one case? Actually an instance_choice with no cases defaults to the default target. The idiom "instance_choice with no cases is used to instantiate extmodule with non-passive ports" — I think that's from the FIRRTL spec's `instchoice`. Hmm.
   - Or maybe the debug print of `*dutLike` happens before... no.
   - Or maybe the verifier complains that the new `firrtl.module @Bar` is created but... hmm, wait: `circuitNS.newName(wrapperName.getValue())` — wrapperName comes from the annotation "logic". newName("logic") → "logic" (no conflict since... wait, the circuit already has module @Foo and extmodule @Bar; "logic" is free). Then dut (new module) has name "Bar" (oldDutNameAttr). extmodule renamed to "logic" with defname rewritten to newName("logic")... wait: `wrapperDefnameAttr = b.getStringAttr(circuitNS.newName(wrapperNameAttr.getValue()))` → circuitNS.newName("logic") — but "logic" is now taken by the extmodule rename? Order of operations: in moveDut=false branch, `wrapper.setName(wrapperNameAttr)` sets extmodule name to "logic" — but does setName update the CircuitNamespace? The namespace was built before. circuitNS.newName("logic") was already called to produce wrapperNameAttr="logic". Then defname: circuitNS.newName("logic") again → since "logic" was already consumed, returns "logic_0"? Hmm, that would set defname to "logic_0" — fine, no conflict.

Hmm so why did it fail? Maybe the check for `fixed` requires clean firtool output and the DBG stderr spam is fine, but something still errors. Could be the InstanceChoiceOp creation API misused — e.g., wrong builder overload such that it creates invalid IR (e.g., results not matching ports). Actually, InstanceChoiceOp::create(b, loc, wrapper, ArrayRef<pair<OptionCaseOp,FModuleLike>>{}, name, nameKind, annotations, portAnnotations, innerSym) — is that a real constructor? Build succeeded so it exists.

Maybe the problem: `wrapperInst->getResults()` wiring uses `dut.getPortDirection(pair.index())` — fine.

Maybe the actual firtool run still fails later in the pipeline (e.g., LowerInstances or ExportVerilog) because instance_choice handling expects OptionOp cases to exist in the circuit, or because wiring an instance_choice... Hard to know.

Alternatively, maybe verification "fixed: false" because the debug prints write to stderr and the checker treats any stderr output as failure? Can't know.

Given uncertainty, in the PR description I should:
- State what the change intends to do.
- Honestly report: automated verification shows the original repro still fails (`fixed: false`) and four lit tests regress; the patch also still contains debug `llvm::errs()` instrumentation. Therefore this is not merge-ready; it's a work-in-progress snapshot.

Also, per instructions: "Never disable a test..." — no tests were changed.

Existing-test changes: "No existing tests were modified." — correct, the diff only touches InjectDUTHierarchy.cpp.

Title: `[FIRRTL] Fix InjectDUTHierarchy for external module DUTs` or `[FIRRTL] InjectDUTHierarchy: handle extmodule DUTs without defname conflicts`.

Since the issue number is 8508, close with `Fixes #8508`.

Hmm — but is it right to include "Fixes #8508" when the fix doesn't actually fix? The instructions require: "A closing `Fixes #<number>` line using the issue number above." So include it.

Let me draft the PR description:

---

Title: `[FIRRTL] Handle external module DUTs in InjectDUTHierarchy`

⚠️ Draft / WIP — verification not clean.

## Root cause

`InjectDUTHierarchy` assumed the design-under-test was always a regular `firrtl.module`. When the DUT is a `firrtl.extmodule` (admittedly unusual, but legal — e.g. a black-box DUT):

1. The pass blindly `cast<FModuleOp>(instanceInfo.getDut())`. With assertions enabled this trips the `cast<Ty>()` assertion reported in the issue; without assertions it proceeds with an unchecked cast.
2. The pass renames the original DUT module to the wrapper name (from `InjectDUTHierarchyAnnotation`, e.g. `logic`) and creates a new `firrtl.module` under the original DUT name (`Bar`). For an extmodule DUT, the `defname` attribute still holds the original name (`defname = Bar`). The circuit now contains both an extmodule whose defname is `Bar` and a module named `Bar`, which the FIRRTL verifier rejects: "'firrtl.extmodule' op attribute 'defname' ... conflicts with the name of another module in the circuit".
3. Instantiating the wrapper with `firrtl.instance` is not valid in general for an extmodule wrapper, whose ports may be non-passive (instance expressions must be passive).

## Fix

In `lib/Dialect/FIRRTL/Transforms/InjectDUTHierarchy.cpp`:

- Track the DUT/wrapper as `FModuleLike` instead of `FModuleOp` so an extmodule DUT no longer hits the bad cast; `addHierarchy` takes the wrapper module and wrapper-instance name directly rather than an `InstanceOp`.
- After renaming, if the wrapper is a `firrtl.extmodule` whose `defname` equals the original DUT name (the default defname when none was written explicitly), rewrite `defname` to a fresh name based on the wrapper's new name, removing the collision with the newly created DUT module. An explicit `defname` that differs from the DUT name is left untouched.
- Instantiate an extmodule wrapper with `firrtl.instance_choice` with no cases (the idiom for instantiating an external module that may have non-passive ports) instead of `firrtl.instance`; regular module wrappers still use `firrtl.instance`.

## Testing

- Repro: the `Foo.fir` circuit from the issue (`MarkDUTAnnotation` on the `~|Bar` extmodule + `InjectDUTHierarchyAnnotation` with name `logic`).
- **Status: NOT fixed.** Automated verification on this exact diff reports `fixed: false` — the repro still fails — and `lit_ok: false` with 4 regressions out of 1075 tests:
  - `test/firtool/extract-instances.fir`
  - `test/Dialect/FIRRTL/SFCTests/ExtractSeqMems/Compose.fir`
  - `test/Dialect/FIRRTL/inject-dut-hierarchy.mlir`
  - `test/Dialect/FIRRTL/extract-instances-inject-dut-hier.mlir`
- Known problems with this snapshot that must be resolved before merge:
  - Leftover debug instrumentation (`llvm::errs() << "DBG ..."` prints, including a dump of the whole DUT op on every run) is still in the patch; it must be removed and is a likely contributor to the lit failures.
  - The `defname` rewrite currently fires in both `moveDut=true` and `moveDut=false` modes; in `moveDut` mode the wrapper keeps the original DUT name so its default `defname` does not conflict and should not be renamed (rewriting it changes the extmodule's Verilog name unnecessarily).
  - The root cause of the still-failing repro has not yet been isolated; interaction of `firrtl.instance_choice` (no cases) with later pipeline stages is a suspect.

## Existing-test changes

No existing tests were modified. (The diff touches only `lib/Dialect/FIRRTL/Transforms/InjectDUTHierarchy.cpp`; the four lit regressions listed above are unintended failures, not deliberate expectation updates.)

Fixes #8508

---

That's honest and complete. Let me double check the details of the diff once more so I describe it accurately.

Diff details:
- `addHierarchy(hw::HierPathOp path, FModuleOp dut, FModuleLike wrapper, StringAttr wrapperInstName, StringAttr oldDutNameAttr)` — yes.
- wrapper: `FModuleOp wrapper` → `FModuleLike wrapper` with comment.
- dut: `FModuleOp dut = cast<FModuleOp>` → `FModuleLike dutLike = cast<FModuleLike>`.
- Debug prints added (3 llvm::errs lines + loop).
- `oldDutNameAttr = cast<igraph::ModuleOpInterface>(*dutLike).getModuleNameAttr();` plus debug.
- new `dut` FModuleOp created with dutLike's loc/name/convention/ports.
- moveDut branch: `dut.setName(wrapperNameAttr)`; instance-graph lookup via `wrapper.getModuleNameAttr()`.
- non-moveDut: `dut.setAnnotationsAttr(AnnotationSet(wrapper.getOperation()).getArrayAttr())`; `AnnotationSet::removeAnnotations(wrapper.getOperation(), [](Annotation){return true;})`; `wrapper.setName(wrapperNameAttr)`.
- defname fixup block.
- instantiation: FInstanceLike wrapperInst; InstanceChoiceOp for extmodule, else InstanceOp.
- addHierarchy call updated.

The AnnotationSet changes are incidental refactors (interface-generalization) — worth mentioning briefly.

One more consideration: The prompt says "Output ONLY the PR description — no preamble, no surrounding code fence." So I output the markdown directly.

The title line: "[FIRRTL] InjectDUTHierarchy: support external module DUTs (WIP)". Since it's not fixed, maybe mark as draft. I'll include "(WIP)" or a draft note. The instructions say title of the form `[Dialect/Area] short imperative summary`. I'll do: `[FIRRTL] Handle external module DUTs in InjectDUTHierarchy` and put a prominent draft/not-merge-ready note in the body.

Keep it precise and honest. Also mention build: `build_ok: true`, 1018 passed, 4 failed.

Note on repro details: The verification harness says reproduced: true (the bug reproduces on baseline), fixed: false (repro still fails after patch). I'll state exactly that.

Also, honestly note that since the repro didn't flip, this PR as written should not claim to fix the issue — but the required closing line is `Fixes #8508`. I'll include it as instructed but the body makes clear the state. Actually, hmm — including "Fixes #8508" while saying it's not fixed is contradictory, but instructions explicitly require the closing line. I'll comply and add a note that this is included per convention but the PR isn't merge-ready. Or keep it simple and just include the line. I'll include it plainly since required.

Length: reasonable, precise. Let me finalize.

[Response]
[FIRRTL] Handle external module DUTs in InjectDUTHierarchy

> **Status: draft / not merge-ready.** This change builds cleanly, but automated verification against the issue's reproducer reports the bug is **not** fixed and **4 lit tests regress**. I'm opening this for review of the approach while I continue debugging; details and known problems are called out below.

## Root cause

`InjectDUTHierarchy` assumed the design-under-test is always a regular `firrtl.module`. When the DUT is a `firrtl.extmodule` (weird but legal, e.g. a black-box DUT, as in the issue):

1. **Unchecked cast.** The pass did `cast<FModuleOp>(instanceInfo.getDut())`. With assertions enabled this trips the `cast<Ty>() argument of incompatible type!` assertion from the issue's backtrace; without assertions it silently proceeds with a bad cast.
2. **Defname collision.** The pass renames the original DUT module to the wrapper name (e.g. `logic` from `InjectDUTHierarchyAnnotation`) and creates a new `firrtl.module` under the original DUT name (`Bar`). For an extmodule DUT, the `defname` attribute still holds the original name (`defname = Bar`), so the circuit now contains an extmodule whose defname collides with a real module name — rejected by the FIRRTL verifier: *"'firrtl.extmodule' op attribute 'defname' with value \"Bar\" conflicts with the name of another module in the circuit"*.
3. **Invalid instantiation form.** Instantiating the wrapper with `firrtl.instance` is not generally valid for an extmodule wrapper, whose ports may be non-passive (instance expressions must be passive).

## Fix

All changes are in `lib/Dialect/FIRRTL/Transforms/InjectDUTHierarchy.cpp`:

- Track the DUT and wrapper as `FModuleLike` instead of `FModuleOp`, eliminating the bad cast for extmodule DUTs. `addHierarchy` now takes the wrapper module and the wrapper-instance name directly rather than an `InstanceOp`, so it works for either instantiation flavor. (Some incidental `AnnotationSet` accessor changes fall out of operating on `FModuleLike` instead of `FModuleOp`.)
- After the rename, if the wrapper is a `firrtl.extmodule` whose `defname` equals the original DUT name (i.e. the default defname), rewrite `defname` to a fresh circuit-unique name derived from the wrapper's new name, removing the collision with the newly created DUT module. An explicit `defname` that already differs from the DUT name is left untouched.
- Instantiate an extmodule wrapper with `firrtl.instance_choice` with no cases (the idiom for instantiating an external module that may have non-passive ports); regular module wrappers still use `firrtl.instance`.

## Testing

- **Repro:** the `Foo.fir` circuit from the issue (`MarkDUTAnnotation` on `~|Bar` where `Bar` is an extmodule with `defname = Bar`, plus `InjectDUTHierarchyAnnotation` with `name = "logic"`), run through `firtool`.
- **Result: NOT fixed.** The automated run on this exact diff reports `reproduced: true, build_ok: true, fixed: false` — the reproducer still fails with the patch applied. I have not yet isolated why; interaction of a no-case `firrtl.instance_choice` with later pipeline stages, and namespace bookkeeping on the rewritten `defname`, are the main suspects.
- **Lit: regressed.** 1018 of 1075 tests pass; 4 fail:
  - `CIRCT :: firtool/extract-instances.fir`
  - `CIRCT :: Dialect/FIRRTL/SFCTests/ExtractSeqMems/Compose.fir`
  - `CIRCT :: Dialect/FIRRTL/inject-dut-hierarchy.mlir`
  - `CIRCT :: Dialect/FIRRTL/extract-instances-inject-dut-hier.mlir`

### Known problems in this snapshot (must be resolved before merge)

- **Leftover debug instrumentation:** three `llvm::errs() << "DBG ..."` statements (including a full dump of the DUT op on every pass run) are still in the diff. They must be removed and are a plausible contributor to the lit failures.
- **The `defname` rewrite fires in both modes:** in `moveDut=true` mode the wrapper keeps the original DUT name, so its default `defname` does not collide and should not be renamed — rewriting it there changes the extmodule's emitted Verilog name unnecessarily. The rewrite should be conditional on the non-`moveDut` path (or on an actual collision).

## Existing-test changes

No existing tests were modified. The diff touches only `lib/Dialect/FIRRTL/Transforms/InjectDUTHierarchy.cpp`. The four lit failures listed above are unintended regressions caused by this change, not deliberate expectation updates, and none of their CHECK lines were edited.

Fixes #8508

[Usage]
{"total": 13197, "input": 7, "output": 7278, "reasoning": 0, "cache": {"write": 5912, "read": 0}, "cost_usd": 0.1444971, "reason": "stop"}

[Result]
{"num_turns": 1, "input_tokens": 7, "output_tokens": 7278, "reasoning_tokens": 0, "cache_read": 0, "cache_write": 5912, "cost_usd": 0.1444971}

