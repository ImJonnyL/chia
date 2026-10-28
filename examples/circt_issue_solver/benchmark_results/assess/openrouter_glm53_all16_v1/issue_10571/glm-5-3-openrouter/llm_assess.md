[Thinking]
Let me analyze this issue carefully.

The issue: `[HWAggregateToComb] Mux of unions` — running `circt-opt minimal.mlir --aggregate-to-comb` on a module with a `comb.mux` over `!hw.union<a: i1>` fails to legalize the operation.

Key facts from the issue:
1. The reporter says "Muxes of `hw.struct` work fine."
2. The maintainer (uenoku) responded: "It's not simply implemented 👍 Please feel free to implement. Basically what you can do is to insert bitcast hw.union, and construct union_extract/create based on the bit layout."

So this is a case where a transform pass (`--aggregate-to-comb`) does not support `hw.union` types in `comb.mux` operations. The maintainer explicitly says it's "not simply implemented" — i.e., it's an unimplemented feature, not a defect in existing behavior.

Now, is this a BUG? The definitions given:
- A bug is a defect where CIRCT behaves incorrectly: crash, assertion failure, miscompile, wrong output, missing/incorrect verifier, or clear violation of spec.
- It is NOT a bug if it is a feature request or enhancement, design proposal/RFC, usage question, build/CI/packaging issue, documentation request, or behavior working as intended.

The pass fails to legalize `comb.mux` on unions with a clear error message ("failed to legalize operation 'comb.mux' that was explicitly marked illegal"). This isn't a crash or assertion — it's a clean diagnostic error saying the pass can't handle this input. The maintainer confirms it's just not implemented — this is an unimplemented feature / feature request.

Hmm, but wait. Let me think more carefully. There's a nuance here: the pass accepts `hw.struct` muxes but not `hw.union` muxes. Is the failure mode a "clean diagnostic" (making it "working as intended" for unions) or is it an "unhandled valid input" bug?

The error message "failed to legalize operation that was explicitly marked illegal" is a generic MLIR conversion error. The pass `--aggregate-to-comb` is meant to lower aggregate types (structs and unions) to comb operations. If the pass's contract is to handle all hw aggregate types, then failing on unions could be considered a bug (missing handling of a valid case).

But the maintainer's response is key: "It's not simply implemented. Please feel free to implement." This is an explicit statement that this is a feature request / unimplemented functionality, not a defect. The maintainer even offers guidance on how to implement it.

Let me investigate the codebase to understand the pass and see how unions are handled.

Let me look at:
- `lib/Dialect/HW/Transforms/AggregateToComb.cpp` (or similar path)
- The pass documentation

Actually, I should use the bash tool to investigate. Let me do that.

Plan:
1. Find the AggregateToComb pass source.
2. Check how it handles structs vs unions.
3. Check git log/blame for hints.
4. Decide: bug vs feature request.

Based on the issue text alone: the reporter asks "If this is a bug/unimplemented feature then I'm happy to try to implement the fix myself" — hedging. The maintainer says it's not implemented and invites an implementation. This is a feature request / unimplemented-feature situation.

However, Part A says: "A bug is a defect where CIRCT behaves incorrectly: a crash, an assertion failure, a miscompile, wrong output, a missing or incorrect verifier, or a clear violation of the FIRRTL/MLIR/CIRCT spec."

Is "pass fails with legalization error on valid IR" a bug? Hmm. There's a gray area: an unhandled case in a conversion pass produces an error rather than a crash. The pass produces a clean-ish error (though it's the generic MLIR "failed to legalize" message, which is not a great diagnostic but is the standard behavior for incomplete conversions).

The categorization guidance explicitly includes "feature request or enhancement" as NOT a bug. The maintainer's comment strongly signals this is an enhancement request: "It's not simply implemented 👍 Please feel free to implement." The reporter's own framing is "bug/unimplemented feature" — i.e., they themselves are unsure.

Also Part B: even if we considered it a bug, is the correct behavior clear? The maintainer sketched an approach: "insert bitcast hw.union, and construct union_extract/create based on the bit layout." That gives implementation guidance, and the expected output would be the pass successfully lowering the mux of unions into scalarized operations. But is the exact expected output clear? For structs, the pass scalarizes; for unions, one would need to decide representation. Actually, hmm — the maintainer's guidance gives a fair amount of specification: bitcast the union and construct union_extract/union_create based on bit layout. But the exact IR produced is still a design decision with multiple valid encodings.

Let me think about whether this is genuinely "unimplemented feature" vs "bug":

- The pass `--aggregate-to-comb` lowers aggregate types (hw.struct, hw.union) to comb-level operations. Wait — actually, does it handle unions at all? Let me check the source. If the pass handles unions in other operations (e.g., `hw.union_extract`, `hw.union_create`) but not `comb.mux`, then it's a gap in an otherwise-union-aware pass. If the pass doesn't handle unions at all, then it's clearly a feature request to extend the pass.

I recall in CIRCT there's `lib/Dialect/HW/Transforms/AggregateToComb.cpp` — hmm, actually I think the pass might be in `lib/Dialect/Comb/Transforms/` or `lib/Dialect/HW/...`. Let me search.

Actually the pass name is "aggregate-to-comb" and there's a file `lib/Dialect/Comb/Transforms/AggregateToComb.cpp` I believe. Hmm, or `lib/Dialect/HW/AggregateToComb.cpp`. I'll grep.

Key question for Part A: Is this a bug or a feature request?

Arguments for NOT_A_BUG:
1. The maintainer explicitly said "It's not simply implemented. Please feel free to implement." — treating it as an implementation opportunity, i.e., an enhancement.
2. The pass produces a clean error, not a crash/assertion/miscompile. The IR is valid; the pass just doesn't support that case. A conversion pass failing to legalize with a diagnostic is arguably "working as intended" for unsupported input.
3. The reporter hedged: "If this is a bug/unimplemented feature..." and "If it's not a bug, advice on what I should be doing differently would be great also!" — the reporter themselves framed it as possibly a usage question.
4. The pipeline guidance: "It is NOT a bug if it is a feature request or enhancement".

Arguments for BUG:
1. If the pass's documented contract is to lower all aggregate-typed operations to comb, then failing on a valid input could be seen as a defect (missing handling). The pass advertises handling aggregates; unions are aggregates.
2. The failure mode is the generic "failed to legalize" which is arguably a poor diagnostic, but still an error, not silent misbehavior.

Hmm, this is a judgment call. Let me look at the actual pass code and its docs to determine the contract.

Let me investigate the code. I'll use the bash tool.

Let me think about what the pass does. In CIRCT, `--aggregate-to-comb` is a pass in the HW dialect (I think it's `lib/Dialect/HW/Transforms/AggregateToComb.cpp`). Actually, I recall it's under `lib/Dialect/HW/Transforms/`. The pass doc: "Flattens aggregates types to scalar operations." Hmm, or maybe "Convert aggregate types into comb operations". Let me check.

I recall there's a pass "hw-legalize-modules"... no. Let me just grep in the container.

The important detail: does the pass already handle `hw.union` for other ops? I believe `AggregateToComb` handles `hw.union_extract`/`hw.union_create`? Hmm. Let me check.

Actually, I remember the pass AggregateToComb handles: array gets/sets, struct fields, etc., and it has type converters for hw.struct, hw.array, and maybe hw.union. Let me verify by reading the code.

Also, `comb.mux` over aggregate types — the pass needs to lower muxes of aggregates. For structs, it presumably scalarizes the mux into per-field muxes. For unions, a union's value is "one of" the fields; a mux of unions could be lowered as a mux of the underlying bit representation, or via bitcast to an integer, mux on that, and bitcast back — that's what uenoku suggests.

The failure: the comb dialect's mux on a union type is marked illegal by the conversion target, and there's no conversion pattern for it.

OK so let me now do the investigation with the tools. Steps:

1. `grep -rn "aggregate-to-comb" /workspace/circt/lib /workspace/circt/include` — find the pass.
2. Read the pass source, focusing on the conversion target setup and patterns; check whether unions are handled anywhere.
3. Check the pass doc in the .td (Transforms/Passes.td under HW).
4. git log for the pass.
5. Check tests: `test/Dialect/HW/aggregate-to-comb.mlir` or similar — see if unions are covered.

Then decide.

My leaning: This is an unimplemented feature (feature request), per the maintainer's explicit response. The pass cleanly rejects (errors out on) an input it doesn't support. Under the given taxonomy, "feature request or enhancement" → NOT_A_BUG.

But wait — I need to be careful. There's a subtlety: some pipelines treat "transform fails on valid input it claims to handle" as a bug. The question hinges on the pass's contract. Let me check the pass documentation.

From CIRCT's Passes.td (HW dialect), I recall:

```
def HWAggregateToComb : Pass<"aggregate-to-comb", "hw::ModuleOp"> {
  ...
  let summary = "Flatten aggregate types to comb operations";
  let description = [{
    ...
  }];
}
```

Hmm, I don't remember exactly. Let me look.

Also note: the pipeline says the decision gates automated fix. Even if it were a bug, would the correct behavior be clear? The maintainer gave implementation guidance (bitcast + union_extract/create based on bit layout). But there are materially different ways: (a) implement mux lowering for unions in the pass (maintainer's suggestion), (b) reject with a better diagnostic. The maintainer's comment strongly suggests (a). And the semantics are fairly well-defined: mux of unions = select one of two unions... but wait, actually there's a subtlety with unions: unions have "one active field" semantics but the underlying bits are just a storage; a union value's bits are only meaningful for the field it was created with. A mux of two unions with different active fields — what does it mean? In HW, unions are bit-level type punning; the value is just the bits. So mux = bitwise select, which is well-defined at the bit level. The maintainer's approach (bitcast to int, mux ints, bitcast back) matches that.

Hmm, so actually if I consider it a bug ("pass fails on valid input it should handle"), the correct behavior is reasonably clear: lower the mux like it does for structs — produce comb.mux on the flattened/bit representation. The maintainer has specified the approach. But the exact output IR still has freedom (per-field mux vs bitcast-mux-bitcast).

But Part A comes first: is it a bug at all? The taxonomy says feature requests/enhancements are NOT bugs. The maintainer's response ("It's not simply implemented 👍 Please feel free to implement") is about as explicit a signal as you can get that the CIRCT community considers this an unimplemented feature / enhancement request rather than a defect. Also, the pass errors out with a diagnostic rather than crashing or producing wrong output. That's "behaving as intended" for an unsupported construct.

Let me also consider: does the pass claim to support unions at all? If the pass already handles other union ops (e.g., union_extract on arrays inside muxes, etc.) but misses mux, one could argue partial support indicates intended support and the mux case is a "gap" = bug. If the pass has zero union handling, it's clearly "not implemented yet" = feature request.

Let me check the code now. I'll run some commands.

Actually, I want to be careful about the tool environment: "You have access to a circt_bash MCP tool" — the tool is named `bash_10571_bash_10571_run_command`. Working directory is /home/ray/llm_env, but the CIRCT tree is at /workspace/circt. I need to use absolute paths or cd first.

Let me plan commands:
1. `grep -rn "aggregate-to-comb" /workspace/circt/lib /workspace/circt/include /workspace/circt/test` (find pass definition and tests)
2. Read the pass file.
3. Check union handling.
4. git log on the pass file.

Let me do these.

After investigation, I'll decide. Let me draft the likely decision now and refine after seeing code:

Most likely: NOT_A_BUG — this is an unimplemented feature / enhancement request. The pass emits a clean legalization error on the unsupported construct; the maintainer confirmed it's simply not implemented and invited an implementation. The taxonomy explicitly excludes feature requests/enhancements.

But hmm, let me think about this more. There's a real tension in these triage tasks. Consider: "a missing or incorrect verifier" is a bug. "wrong output" is a bug. "crash" is a bug. A pass that fails with a diagnostic on valid IR — is that "incorrect behavior"? The pass is invoked explicitly by the user (`--aggregate-to-comb`). The user wants the lowering. The pass supports the analogous construct for structs. For unions, it fails. The maintainer says "not implemented".

The strongest signal for NOT_A_BUG: the maintainer's comment and the fact that this is asking for new functionality (support for a type the pass currently doesn't handle). The error is graceful. The reporter's framing includes "If it's not a bug, advice on what I should be doing differently would be great also!" — and the answer is: there's nothing else you can do differently; it's just not implemented. So it's a feature request with maintainer endorsement.

Also the task says: "A bug is a defect where CIRCT behaves incorrectly... It is NOT a bug if it is a feature request or enhancement". "Mux of unions should be supported by aggregate-to-comb" is an enhancement: extending the pass to handle a construct it never handled. There's no defect in existing behavior — existing behavior (error) is the intended behavior for unimplemented cases (generic conversion infra behavior).

Hmm, but one could argue "the pass is supposed to handle aggregates; unions are aggregates; therefore failing is a defect in the pass's contract". Let me check the pass description to see what it promises. Let me actually look at the code.

Let me also check: does AggregateToComb handle unions for other operations? I recall the type converter in AggregateToComb handles hw.array and hw.struct. Hmm, does it handle hw.union? Let me look.

From memory of the CIRCT source: `lib/Dialect/HW/Transforms/AggregateToComb.cpp`. Hmm wait, actually I think there is a pass "hw-aggregate-to-comb"? Hmm. Let me recall Passes.td in include/circt/Dialect/HW/Transforms/Passes.td. I don't remember exactly. Let me just run the commands.

Actually, I also recall that there's a similar FIRRTL pass "LowerTypes". The HW `aggregate-to-comb` pass... Let me recall. I believe there's `lib/Dialect/HW/Transforms/AggregateToComb.cpp` with a comment:

```
//===----------------------------------------------------------------------===//
// AggregateToComb Pass
//===----------------------------------------------------------------------===//
```

Hmm, not sure. Let me just investigate.

Also worth checking: how are `comb.mux` on struct handled — via a pattern that scalarizes. And the conversion target marks `comb.mux` with aggregate result types as illegal. For unions, no pattern exists → error.

Also check whether unions are handled for other ops in this pass: search for "UnionCreate"/"UnionExtract"/"UnionType" in the pass file.

Alright, let me start.

One more consideration for the final decision: even if I lean "bug" (gap in coverage), Part B's "correct behavior" — is it clear? The maintainer sketched an approach, which is quite specific: "insert bitcast hw.union, and construct union_extract/create based on the bit layout". But what does that mean exactly for a mux? I think: bitcast both union operands to an integer, comb.mux on the integers, bitcast back to union? Or: for each field, create union_create of per-field muxes? The latter doesn't make sense for unions (a union value isn't all fields). Actually for unions, since they're bit-level punning, bitcast → mux ints → bitcast back is the clean approach. The maintainer's phrasing "construct union_extract/create based on the bit layout" suggests: extract each union's bits (via bitcast or union_extract on each field?), mux, then union_create. Hmm.

Anyway — multiple defensible output shapes exist, but the semantics are pinned. For an automated pipeline, "extend the pass to lower mux of unions, following the maintainer's guidance" is a fairly well-specified task. But Part A gate: feature request → NOT_A_BUG → stop.

Hmm, I keep going back and forth. Let me look at the code and the pass docs first, then decide. The key evidence will be:

1. Pass description/contract (does it promise union support?).
2. Whether the pass handles unions at all elsewhere.
3. Whether there's a test showing union ops being intentionally rejected/skipped.

Let me run the investigation.

Additional thought: the pipeline's framing matters a lot: "only DECISION: CLEAR proceeds to reproduce + fix." The bar for CLEAR is high. Even under the most bug-favorable reading (pass should support all aggregate ops), the "correct behavior" would be fairly clear (lower the mux; don't reject valid input). But the maintainer's explicit "not implemented, please implement" comment makes this read as a feature request, which the taxonomy puts firmly in NOT_A_BUG territory.

Hmm, but wait. Let me reconsider. There's a subtle point: is `comb.mux` on `!hw.union` even legal IR? If yes, and the pass's job is to eliminate aggregate-typed comb ops, then failing means the pass cannot complete its documented job on valid IR. MLIR conversion passes are "all or nothing": they either fully convert or fail. An incompletely-implemented converter is... a work in progress. Most maintainers would call the missing case "unimplemented", not "a bug". E.g., "LowerTypes doesn't support X" — unimplemented feature.

I'm fairly settled on NOT_A_BUG, but let me verify with code inspection that:
- unions are indeed otherwise handled or not (to characterize accurately),
- the failure is a clean diagnostic (yes, from the issue),
- the pass doc doesn't promise union support.

Let me also check git history: when was union support added to aggregate-to-comb (if at all)? Maybe there was a PR "Support unions in aggregate-to-comb"? Hmm, actually wait. I recall CIRCT has a `hw.union` type that's relatively new (added ~2023-2024 for SV structs?). Hmm, `hw.union` — unions in HW dialect... Let me check. There's `UnionCreateOp`, `UnionExtractOp` in HW dialect. I believe union support in HW came from the "SV union" lowering work.

Hmm, actually I now recall the AggregateToComb pass might be relatively recent (added by uenoku? — the commenter is uenoku, who might be the pass author). If uenoku wrote the pass, their comment "It's not simply implemented" is authoritative: the pass author says unions aren't implemented.

Let me now check the code.

Plan of commands (batch independent ones):

1. `find /workspace/circt -name "*AggregateToComb*"` 
2. `grep -rn "aggregate-to-comb" /workspace/circt/include /workspace/circt/lib /workspace/circt/test /workspace/circt/docs --include=*`

Let me run them together.

Then read the pass file.

Then check tests for union coverage: `grep -rn "union" test/.../aggregate-to-comb*`.

Then git log.

Let me go.

Also — the environment note says "If you intend to call multiple tools and there are no dependencies between the calls, make all of the independent calls in the same block". Good, I'll batch.

Let me start with finding the pass.

[Response]
I'll investigate this issue in the CIRCT tree to understand what's going on before making a triage decision.

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "find /workspace/circt -name \"*AggregateToComb*\" -not -path \"*/build/*\" 2>/dev/null"}

[Tool Result]
/workspace/circt/lib/Dialect/HW/Transforms/HWAggregateToComb.cpp


[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "grep -rn \"aggregate-to-comb\" /workspace/circt/include /workspace/circt/lib /workspace/circt/test /workspace/circt/docs 2>/dev/null | grep -v Binary | head -40"}

[Tool Result]
/workspace/circt/include/circt/Dialect/HW/Passes.td:123:def HWAggregateToComb : Pass<"hw-aggregate-to-comb", "hw::HWModuleOp"> {
/workspace/circt/lib/Dialect/Synth/Analysis/LongestPathAnalysis.cpp:558:      "hw.module(hw-aggregate-to-comb,convert-comb-to-synth,cse,canonicalize)";
/workspace/circt/test/Dialect/HW/hw-aggregate-to-comb.mlir:1:// RUN: circt-opt %s -hw-aggregate-to-comb | FileCheck %s


[Usage]
{"total": 7621, "input": 2935, "output": 136, "reasoning": 4550, "cache": {"write": 0, "read": 0}, "cost_usd": 0.0067655565, "reason": "tool-calls"}

[Thinking]
Interesting — the pass is actually named `hw-aggregate-to-comb` in this tree (firtool-1.148.0), while the issue says `--aggregate-to-comb`. Maybe there was a rename, or the issue's version had a different name. Let me check the Passes.td definition and the pass source.

Wait, the issue says `circt-opt minimal.mlir --aggregate-to-comb`. Hmm, but in this tree it's `hw-aggregate-to-comb`. Maybe there's an alias. Let me check git log for a rename. Actually, the issue is dated 2026-06-01 and the tree is firtool-1.148.0 — let me check what date that corresponds to. Anyway, the pass is HWAggregateToComb in lib/Dialect/HW/Transforms/HWAggregateToComb.cpp.

Let me read the pass definition and the source.

[Response]
The pass exists as `hw-aggregate-to-comb` in this tree. Let me read its definition and the pass source.

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "sed -n 100,175p /workspace/circt/include/circt/Dialect/HW/Passes.td"}

[Tool Result]
    trigger a specialization procedure which resolves all parametric types and
    values within the module based on the set of provided parameters to the
    `hw.instance` operation. This specialized module is created as a new
    `hw.module` and the referring `hw.instance` operation is rewritten to
    instantiate the newly specialized module.
  }];
}

def VerifyInnerRefNamespace : Pass<"hw-verify-irn"> {
  let summary = "Verify InnerRefNamespaceLike operations, if not self-verifying.";
}

/**
 * Tutorial Pass, doesn't do anything interesting
 */
def FooWires : Pass<"hw-foo-wires", "hw::HWModuleOp"> {
  let summary = "Change all wires' name to foo_<n>.";
  let description = [{
    Very basic pass that numbers all of the wires in a given module.
    The wires' names are then all converte to foo_<that number>.
  }];
}

def HWAggregateToComb : Pass<"hw-aggregate-to-comb", "hw::HWModuleOp"> {
  let summary = "Lower aggregate operations to comb operations";
  let description = [{
    This pass lowers aggregate *operations* to comb operations within modules.
    Note that this pass does not lower ports. Ports lowering is handled
    by FlattenIO.

    This pass will change the behavior of out-of-bounds access of arrays,
    specifically the last element of the array is used as a value for
    out-of-bounds access.
  }];
  let dependentDialects = ["comb::CombDialect"];
}

def HWVectorization : Pass<"hw-vectorization", "hw::HWModuleOp"> {
  let summary = "Vectorizes bit-level operations in HW dialect";
  let description = [{
   This pass performs structural vectorization of hardware modules,
    merging scalar bit-level assignments into vectorized operations.
  }];
  let dependentDialects = ["circt::comb::CombDialect", "circt::hw::HWDialect"];
}

def HWParameterizeConstantPorts : Pass<"hw-parameterize-constant-ports",
                                       "mlir::ModuleOp"> {
  let summary = "Parametize constant ports on private modules";
  let description = [{
    This p
... [truncated]

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "wc -l /workspace/circt/lib/Dialect/HW/Transforms/HWAggregateToComb.cpp && sed -n 1,120p /workspace/circt/lib/Dialect/HW/Transforms/HWAggregateToComb.cpp"}

[Tool Result]
311 /workspace/circt/lib/Dialect/HW/Transforms/HWAggregateToComb.cpp
//===- HWAggregateToComb.cpp - HW aggregate to comb -------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "circt/Dialect/Comb/CombOps.h"
#include "circt/Dialect/HW/HWOps.h"
#include "circt/Dialect/HW/HWPasses.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Transforms/DialectConversion.h"
#include "llvm/ADT/APInt.h"

namespace circt {
namespace hw {
#define GEN_PASS_DEF_HWAGGREGATETOCOMB
#include "circt/Dialect/HW/Passes.h.inc"
} // namespace hw
} // namespace circt

using namespace mlir;
using namespace circt;

namespace {

// Lower hw.array_create and hw.array_concat to comb.concat.
template <typename OpTy>
struct HWArrayCreateLikeOpConversion : OpConversionPattern<OpTy> {
  using OpConversionPattern<OpTy>::OpConversionPattern;
  using OpAdaptor = typename OpConversionPattern<OpTy>::OpAdaptor;
  LogicalResult
  matchAndRewrite(OpTy op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    rewriter.replaceOpWithNewOp<comb::ConcatOp>(op, adaptor.getInputs());
    return success();
  }
};

struct HWAggregateConstantOpConversion
    : OpConversionPattern<hw::AggregateConstantOp> {
  using OpConversionPattern<hw::AggregateConstantOp>::OpConversionPattern;

  static LogicalResult peelAttribute(Location loc, Attribute attr,
                                     ConversionPatternRewriter &rewriter,
                                     APInt &intVal) {
    SmallVector<Attribute> worklist;
    worklist.push_back(attr);
    unsigned nextInsertion = intVal.getBitWidth();

    while (!worklist.empty()) {
      auto current = worklist.pop_back_val();
      if (auto innerArray = dyn_cast<ArrayAttr>(current)
... [truncated]

[Usage]
{"total": 8101, "input": 4957, "output": 140, "reasoning": 188, "cache": {"write": 0, "read": 2816}, "cost_usd": 0.0009997167, "reason": "tool-calls"}

[Thinking]
Let me read the rest of the pass file to see the conversion target setup and what's marked legal/illegal, and whether unions are handled anywhere.

[Response]
Let me read the rest of the pass, especially the conversion target setup and patterns.

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "sed -n 120,311p /workspace/circt/lib/Dialect/HW/Transforms/HWAggregateToComb.cpp"}

[Tool Result]

  LogicalResult
  matchAndRewrite(hw::ArrayInjectOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto arrayType = cast<hw::ArrayType>(op.getInput().getType());
    auto elemType = arrayType.getElementType();
    auto numElements = arrayType.getNumElements();
    auto elemWidth = hw::getBitWidth(elemType);
    if (elemWidth < 0)
      return rewriter.notifyMatchFailure(op.getLoc(), "unknown element width");

    Location loc = op.getLoc();

    // Extract all elements from the input array
    SmallVector<Value> originalElements;
    auto inputArray = adaptor.getInput();
    for (size_t i = 0; i < numElements; ++i) {
      originalElements.push_back(rewriter.createOrFold<comb::ExtractOp>(
          loc, inputArray, i * elemWidth, elemWidth));
    }

    // Create 2D array: each row represents what the array would look like
    // if injection happened at that specific index
    SmallVector<Value> arrayRows;
    arrayRows.reserve(numElements);
    for (int injectIdx = numElements - 1; injectIdx >= 0; --injectIdx) {
      SmallVector<Value> rowElements;
      rowElements.reserve(numElements);

      // Build the row: array[n-1], array[n-2], ..., but replace element at
      // injectIdx with newVal
      for (int originalIdx = numElements - 1; originalIdx >= 0; --originalIdx) {
        if (originalIdx == injectIdx) {
          rowElements.push_back(adaptor.getElement());
        } else {
          rowElements.push_back(originalElements[originalIdx]);
        }
      }

      // Concatenate elements to form this row
      Value row = hw::ArrayCreateOp::create(rewriter, loc, rowElements);
      arrayRows.push_back(row);
    }

    // Create the 2D array by concatenating all rows
    // arrayRows[0] corresponds to injection at index 0
    // arrayRows[1] corresponds to injection at index 1, etc.
    Value array2D = hw::ArrayCreateOp::create(rewriter, loc, arrayRows);

    // Create array_get operation to select the row
... [truncated]

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "grep -rn -i \"union\" /workspace/circt/lib/Dialect/HW/Transforms/HWAggregateToComb.cpp /workspace/circt/test/Dialect/HW/hw-aggregate-to-comb.mlir | head -30; echo ---; grep -rn \"UnionType\\|hw.union\" /workspace/circt/test/Dialect/HW/hw-aggregate-to-comb.mlir | head"}

[Tool Result]
---


[Usage]
{"total": 10033, "input": 2154, "output": 169, "reasoning": 30, "cache": {"write": 0, "read": 7680}, "cost_usd": 0.0009583166, "reason": "tool-calls"}

[Thinking]
Now I have a clear picture of the pass:

1. The type converter handles `hw::ArrayType` and `hw::StructType` — NOT `hw::UnionType`. So union types are not converted to integer types.
2. The patterns handle: ArrayGet, ArrayCreate, ArrayConcat, AggregateConstant, ArrayInject, StructCreate, StructExtract, and MuxOp (which just re-creates the mux with converted operands).
3. The conversion target marks `comb::MuxOp` dynamically legal only if result type is IntegerType. So a mux over union type is illegal, and the MuxOpConversion pattern re-creates it with type-converted operands. For a struct, the operands get converted to iN, so the re-created mux is legal. For a union, the type converter has no union conversion, so the union type stays union → the re-created mux still has union type → still illegal → "failed to legalize" error.

Wait, interesting: MuxOpConversion actually matches comb::MuxOp and rewrites it. But since the type converter doesn't convert hw::UnionType, adaptor operands remain union-typed, and the new mux is still illegal. Actually, would the pattern apply and re-create, then fail because the new op is still illegal? The error says "failed to legalize operation 'comb.mux' that was explicitly marked illegal" — yes.

So the pass simply has no union support at all — no type conversion, no union_extract/union_create patterns. Interesting: the target doesn't even mark `hw::UnionCreateOp`/`hw::UnionExtractOp` illegal, so those pass through unchanged (they're in HWDialect which is legal). So the pass currently just leaves unions alone... except a mux on union types errors out because the mux's dynamic legality check requires an integer result type.

Hmm, so actually the pass errors on mux-over-union even though it would happily leave the union ops alone otherwise. Is that a bug? The pass explicitly declares comb::MuxOp with non-integer (aggregate) result type illegal. Unions are aggregates. There's no pattern to handle it. So the pass fails. That's an unimplemented feature: "aggregate ops on unions".

The test file: no union tests at all in hw-aggregate-to-comb.mlir. Let me double check by grepping the test file for "union" — the grep showed nothing for the first command (no output before ---? Actually the first grep printed nothing at all — wait, the first command was `grep -rn -i "union" <pass file> <test file> | head -30; echo ---; ...`. Output shows just `---` then nothing for the second grep. So there are ZERO mentions of "union" in either the pass source or the test file. The pass has no union support whatsoever.

Let me also check git history of this file to understand when it was added and by whom, and whether there's a TODO about unions.

Also check: does `hw::getBitWidth` support union types? Let me check. In HWDialect, UnionType — let me check where union is defined and whether getBitWidth handles it.

Let me also verify the repro actually fails in this tree — well, I can run circt-opt on the repro. That's allowed ("investigate READ-ONLY" — running the tool is read-only w.r.t. the tree, fine).

Wait, the issue says `--aggregate-to-comb` but this tree has `hw-aggregate-to-comb`. Hmm. Let me check: maybe there's also a pass alias or the issue just used a different name. Let me check git log — maybe the pass was renamed. Actually the issue is from 2026-06-01, and this tree is firtool-1.148.0. Let me check the date of the firtool-1.148.0 tag. Actually, let me check `git log -1` in the tree.

Hmm, interesting — also possible: there are TWO passes: `hw-aggregate-to-comb` in HW and maybe a comb-level "aggregate-to-comb"? The grep for "aggregate-to-comb" only found Passes.td with "hw-aggregate-to-comb", the test file, and the Synth mention. So in this tree, only `hw-aggregate-to-comb`. The issue's `--aggregate-to-comb` may be from a different version, or the reporter abbreviated. Let me check git log for renames: `git log --follow --oneline lib/Dialect/HW/Transforms/HWAggregateToComb.cpp`.

Let me run the repro with the actual pass name.

Also let me check the git history to see when this pass was created and by whom (uenoku?). And check whether there's an upstream PR implementing union support already (can't check GitHub, but git log might show).

Let me also look at how unions work in the HW dialect: hw::UnionType, UnionCreateOp, UnionExtractOp — and getBitWidth support. And check FlattenIO / other passes for how they treat unions — do they support unions? E.g., does LoweringHW (FlattenIO) handle unions? Let me grep for UnionType in lib/Dialect/HW.

Key triage question: PART A — bug or not?

Evidence:
1. The pass's description: "This pass lowers aggregate *operations* to comb operations within modules." It doesn't say which aggregate types. Arrays and structs are handled; unions are not (zero mentions).
2. The pass fails with a clean MLIR legalization error (not a crash, not wrong output).
3. The maintainer (uenoku, likely pass author) explicitly said: "It's not simply implemented 👍 Please feel free to implement." — i.e., unimplemented feature, invited as a contribution.
4. The reporter hedged: "If this is a bug/unimplemented feature..."

So per the taxonomy: "It is NOT a bug if it is a feature request or enhancement". This is a feature request to extend the pass to support unions. The current behavior (error out with a diagnostic when encountering an unsupported construct) is not a miscompile/crash/assertion — it's graceful rejection.

Hmm, but let me consider the counter-argument seriously: the input is valid IR; the user explicitly asked for the lowering; the pass errors. Is "error on valid input" a defect? The pass is a conversion pass; conversion passes in MLIR fail if they can't fully convert. The pass author deliberately marked comb.mux on aggregate types illegal — including unions — but only wrote a converter for structs and arrays. So it's an incomplete implementation. Is that a "bug"?

The guidance: "A bug is a defect where CIRCT behaves incorrectly: a crash, an assertion failure, a miscompile, wrong output, a missing or incorrect verifier, or a clear violation of the FIRRTL/MLIR/CIRCT spec."

- Not a crash: it's a clean error.
- Not miscompile/wrong output: it refuses rather than producing wrong output.
- Not a missing verifier.
- Not a spec violation: there's no spec saying aggregate-to-comb must support unions.

"It is NOT a bug if it is a feature request or enhancement" — the maintainer's comment makes it explicit this is unimplemented functionality, i.e., an enhancement request: "Please feel free to implement."

So PART A: NOT_A_BUG. This is an unimplemented feature / enhancement request, acknowledged as such by the maintainer, with a clean diagnostic rather than incorrect behavior.

Hmm, but hold on. Let me think about whether there's a subtlety: the reporter said "Muxes of hw.struct work fine". One could argue the pass intends to support ALL aggregate types and unions are just a gap — a defect in coverage. But "gap in coverage of an optional, explicitly-invoked lowering pass" = unimplemented feature. The pass even has a TODO in the source: "// TODO: Add ArraySliceOp and struct operatons as well." — acknowledging incomplete coverage. That TODO is about other ops, but it shows the pass is acknowledged as a work-in-progress with incremental op/type support.

Also important: does the pass SILENTLY do something wrong for unions in other cases? E.g., union_extract/union_create are legal (addLegalDialect<hw::HWDialect>), so they pass through — the pass leaves them alone. That's "graceful partial support". Only mux-on-union trips the dynamic legality check. So the "failure" is: pass refuses to complete. Clean error.

Now, let me also double check the claim that this pass errors for mux on union — let me actually run the repro to confirm the failure mode in this tree (read-only operation, allowed: "You MAY use the circt bash tool to investigate /workspace/circt READ-ONLY"). Running circt-opt doesn't modify the tree. I'll do that to ground my analysis.

Also check git log to see if unions were added to hw dialect recently and whether this pass predates them.

Also, importantly: is there any indication that the pass SHOULD support unions — e.g., does FlattenIO support unions? Let me check where union types are handled elsewhere: `grep -rn "UnionType" lib/Dialect/HW | head -50`. If most of the pipeline (e.g., FlattenIO, ExportVerilog) already handles unions, then aggregate-to-comb's failure is a gap relative to the ecosystem — but still an unimplemented-feature situation, not a defect in implemented behavior.

Let me run these investigations.

Then the final decision: NOT_A_BUG, reason: unimplemented feature / enhancement request — the pass cleanly rejects (with a legalization diagnostic) an input construct (comb.mux over hw.union) it never claimed to support; the maintainer confirmed "not simply implemented" and invited an implementation. Per the taxonomy, feature requests/enhancements are not bugs.

Wait — but I should be careful about one thing: the pipeline says "NOT_A_BUG and UNCLEAR are LOGGED with your reason and skipped". I need to be honest. Let me consider once more whether a reasonable maintainer would call this a bug. In the CIRCT repo, issues like "LowerTypes doesn't support X" or "pass Y doesn't handle Z op" are usually labeled "enhancement" or "feature". The maintainer's response here literally frames it as an implementation opportunity ("Please feel free to implement"). There's no incorrect behavior — no wrong output, no crash. The pass correctly diagnoses that it can't legalize. So NOT_A_BUG is right.

Actually hmm, one more consideration. Let me re-read the task's definition once more:

"A bug is a defect where CIRCT behaves incorrectly: a crash, an assertion failure, a miscompile, wrong output, a missing or incorrect verifier, or a clear violation of the FIRRTL/MLIR/CIRCT spec. It is NOT a bug if it is a feature request or enhancement, a design proposal / RFC, a usage question, a build / CI / packaging / infrastructure issue, a documentation request, or behavior that is actually working as intended."

The pass's behavior on union mux: it emits a conversion-failure diagnostic and signalPassFailure. That IS the intended MLIR behavior for unhandled ops in a conversion pass. And the intended long-term behavior (support unions) is an enhancement. So NOT_A_BUG.

But wait, let me also consider: is `comb.mux` on `!hw.union` even valid IR per the comb dialect? Let me check the mux op definition — `comb::MuxOp` operands: does it require int types or any type? From the pass, `target.addDynamicallyLegalOp<comb::MuxOp>([](comb::MuxOp op) { return hw::type_isa<IntegerType>(op.getType()); })` — the pass author's own check implies mux can have aggregate types (struct muxes work). So mux on union is presumably valid IR (comb is type-polymorphic-ish; mux requires same types on true/false and result). Let me check the comb.mux op def to be sure. If mux-on-union were invalid IR, then this would be a verifier gap — a different issue. But the reporter says structs work, so mux on aggregate is supported; union is an aggregate type in hw. So the IR is valid.

Let me confirm the repro runs and fails in this tree, check git history, and check union handling elsewhere. Then finalize.

Commands:
1. Create the repro file in /tmp (not in the tree — read-only tree) and run `/workspace/circt/build/bin/circt-opt /tmp/minimal.mlir --hw-aggregate-to-comb`.
2. `git -C /workspace/circt log --oneline --follow -- lib/Dialect/HW/Transforms/HWAggregateToComb.cpp | head -20`
3. `grep -rn "UnionType" /workspace/circt/lib/Dialect/HW --include=*.cpp | grep -v "UnionCreate\|UnionExtract" | head -30` — where unions are supported.
4. Check the version/date: `git -C /workspace/circt log -1 --format="%H %cd %s"`.

Let me batch these.

[Response]
The pass has zero union handling — no `UnionType` conversion, no union patterns. Let me verify the repro behavior in this tree, check the git history, and see how unions are treated elsewhere in the codebase.

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cat > /tmp/minimal.mlir <<'EOF'\nmodule {\n  hw.module @demo(in %a : !hw.union<a: i1>, in %b : !hw.union<a: i1>, in %c : i1, out d : !hw.union<a: i1>) {\n    %0 = comb.mux %c, %a, %b : !hw.union<a: i1>\n    hw.output %0 : !hw.union<a: i1>\n  }\n}\nEOF\necho \"=== union mux ===\"; /workspace/circt/build/bin/circt-opt /tmp/minimal.mlir --hw-aggregate-to-comb 2>&1 | head -20; echo \"=== struct mux (control) ===\"; cat > /tmp/struct.mlir <<'EOF'\nmodule {\n  hw.module @demo(in %a : !hw.struct<a: i1>, in %b : !hw.struct<a: i1>, in %c : i1, out d : !hw.struct<a: i1>) {\n    %0 = comb.mux %c, %a, %b : !hw.struct<a: i1>\n    hw.output %0 : !hw.struct<a: i1>\n  }\n}\nEOF\n/workspace/circt/build/bin/circt-opt /tmp/struct.mlir --hw-aggregate-to-comb 2>&1 | head -20"}

[Tool Result]
=== union mux ===
/tmp/minimal.mlir:3:10: error: failed to legalize operation 'comb.mux' that was explicitly marked illegal: %0 = "comb.mux"(%arg2, %arg0, %arg1) : (i1, !hw.union<a: i1>, !hw.union<a: i1>) -> !hw.union<a: i1>
    %0 = comb.mux %c, %a, %b : !hw.union<a: i1>
         ^
/tmp/minimal.mlir:3:10: note: see current operation: %0 = "comb.mux"(%arg2, %arg0, %arg1) : (i1, !hw.union<a: i1>, !hw.union<a: i1>) -> !hw.union<a: i1>
=== struct mux (control) ===
module {
  hw.module @demo(in %a : !hw.struct<a: i1>, in %b : !hw.struct<a: i1>, in %c : i1, out d : !hw.struct<a: i1>) {
    %0 = hw.bitcast %b : (!hw.struct<a: i1>) -> i1
    %1 = hw.bitcast %a : (!hw.struct<a: i1>) -> i1
    %2 = comb.mux %c, %1, %0 : i1
    %3 = hw.bitcast %2 : (i1) -> !hw.struct<a: i1>
    hw.output %3 : !hw.struct<a: i1>
  }
}



[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && git log --oneline --follow -- lib/Dialect/HW/Transforms/HWAggregateToComb.cpp | head -25 && echo === && git log -1 --format=\"%H %cd\" && git tag --contains HEAD 2>/dev/null | head -3"}

[Tool Result]
5dc7f10 [Synth] Move three-input op boilerplate to ODS (#10540)
===
5dc7f103d714aa40e13cae4fcf7ab98a1912f845 Sun May 24 17:14:51 2026 -0700
firtool-1.148.0


[Usage]
{"total": 15043, "input": 2095, "output": 437, "reasoning": 2783, "cache": {"write": 0, "read": 9728}, "cost_usd": 0.0053246997, "reason": "tool-calls"}

[Thinking]
Confirmed the repro in this tree: union mux fails with the same legalization error; struct mux lowers to bitcast → comb.mux → bitcast. This matches the issue exactly.

Interesting: the git log --follow with only one commit shown? That's odd — "--follow" showed just one commit (5dc7f10 is the HEAD commit for a different file?). Wait, the output shows "5dc7f10 [Synth] Move three-input op boilerplate to ODS (#10540)" — hmm, that seems to be the HEAD commit (5dc7f103... matches the second output's %H). So `git log --oneline --follow -- lib/Dialect/HW/Transforms/HWAggregateToComb.cpp | head -25` printed only the HEAD commit? That would mean... hmm, maybe the file was created recently and only touched once, but then --follow should show its creation commit at least. Unless the file was created in the HEAD commit? No wait — HEAD is "[Synth] Move three-input op boilerplate to ODS" which wouldn't touch this file.

Hmm, maybe the checkout is a shallow clone (depth=1), so there's only one commit in history! That would explain it. Let me check `git rev-parse --is-shallow-repository`.

If it's a shallow clone, git log/blame won't give me useful history. Fine — not critical.

Let me still gather a bit more evidence on union support elsewhere in the codebase to characterize the state of union support:
1. Does `hw::getBitWidth` support UnionType? (Check TypeSize / HWDialect implementation.)
2. Do other passes (e.g., FlattenIO in LoweringHW, or the SV export) handle unions?
3. Is comb.mux on union valid IR (verifier)? The mux's verifier presumably requires true/false/result same type. Let me check quickly.

Let me check these.

Actually, for the triage decision the key facts are already established:
1. The input IR is valid (mux on aggregate types is a supported comb construct — structs work).
2. The pass has NO union support whatsoever (zero mentions of "union" in the pass; the type converter handles only ArrayType and StructType).
3. The failure is a clean MLIR legalization diagnostic + pass failure, not a crash/assert/miscompile.
4. The maintainer (uenoku) explicitly stated it's not implemented and invited a contribution ("It's not simply implemented 👍 Please feel free to implement. Basically what you can do is to insert bitcast hw.union, and construct union_extract/create based on the bit layout.").

So: this is an unimplemented feature / enhancement request, not a defect. Under the taxonomy given, NOT_A_BUG.

Let me quickly double-check the two remaining points (mux validity for union types, and whether unions are supported elsewhere) to make my reason statement accurate and to rule out that the pass *should* already handle unions per some documented contract.

Check 1: comb.mux op def. In include/circt/Dialect/Comb/CombOps.td — MuxOp. Let me check its constraints.

Check 2: getBitWidth on UnionType — in lib/Dialect/HW/HWTypes.cpp or TypeSize.cpp. Let me grep.

Check 3: Other passes handling unions: grep UnionCreateOp/UnionExtractOp in lib/.

Also check FlattenIO (LoweringHW.cpp?) for union handling to see how mature union support is in the pipeline. If FlattenIO also doesn't support unions, then unions are generally a newer/less-supported type, reinforcing "feature request".

Let me run these greps.

[Response]
The repro is confirmed in this tree, matching the issue exactly. Let me check how mature union support is elsewhere (getBitWidth, other passes, comb.mux's type constraints) to rule out that unions are already part of this pass's contract.

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && git rev-parse --is-shallow-repository; grep -rn \"UnionType\" lib/Dialect/HW/TypeSize.cpp lib/Dialect/HW/*.cpp 2>/dev/null | grep -i \"bitwidth\\|getBitWidth\" | head; echo \"=== getBitWidth impl ===\"; grep -rn -A4 \"getBitWidth(UnionType\\|UnionType.*getBitWidth\" lib/Dialect/HW/ include/circt/Dialect/HW/ 2>/dev/null | head -20"}

[Tool Result]
true
lib/Dialect/HW/HWTypes.cpp:517:std::optional<int64_t> UnionType::getBitWidth() const {
=== getBitWidth impl ===
lib/Dialect/HW/HWTypes.cpp:517:std::optional<int64_t> UnionType::getBitWidth() const {
lib/Dialect/HW/HWTypes.cpp-518-  int64_t maxSize = 0;
lib/Dialect/HW/HWTypes.cpp-519-  for (auto field : getElements()) {
lib/Dialect/HW/HWTypes.cpp-520-    int64_t fieldSize = hw::getBitWidth(field.type);
lib/Dialect/HW/HWTypes.cpp-521-    if (fieldSize < 0)


[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && grep -rln \"union_create\\|union_extract\\|UnionCreateOp\\|UnionExtractOp\\|UnionType\" lib/ --include=*.cpp | head -20; echo \"=== comb.mux ODS ===\"; grep -n -B2 -A12 \"def Comb_MuxOp\\|def MuxOp\" include/circt/Dialect/Comb/CombOps.td | head -40"}

[Tool Result]
lib/Dialect/FIRRTL/FIRRTLUtils.cpp
lib/Dialect/Moore/MooreOps.cpp
lib/Dialect/Moore/MooreTypes.cpp
lib/Dialect/HW/HWOps.cpp
lib/Dialect/HW/HWDialect.cpp
lib/Dialect/HW/HWTypes.cpp
lib/Dialect/LLHD/IR/LLHDOps.cpp
lib/Dialect/LLHD/Transforms/Mem2Reg.cpp
lib/Dialect/ESI/ESITypes.cpp
lib/Dialect/ESI/Passes/ESILowerTypes.cpp
lib/Dialect/ESI/Passes/ESIBuildManifest.cpp
lib/Dialect/ESI/ESIOps.cpp
lib/Dialect/ESI/runtime/cpp/lib/Manifest.cpp
lib/Dialect/ESI/runtime/cpp/lib/Types.cpp
lib/Dialect/ESI/runtime/python/esiaccel/esiCppAccel.cpp
lib/Dialect/Arc/Interfaces/RuntimeCostEstimateInterfaceImpl.cpp
lib/Dialect/Arc/Transforms/RemoveI0Types.cpp
lib/Dialect/Arc/Transforms/LowerArrays.cpp
lib/Bindings/Python/HWModule.cpp
lib/Conversion/ImportVerilog/Expressions.cpp
=== comb.mux ODS ===

STDERR:
grep: include/circt/Dialect/Comb/CombOps.td: No such file or directory


[Usage]
{"total": 16521, "input": 3748, "output": 299, "reasoning": 762, "cache": {"write": 0, "read": 11712}, "cost_usd": 0.002554342, "reason": "tool-calls"}

[Thinking]
The CombOps.td is at a different path. Let me find it. Also the repo is a shallow clone so git history is limited to one commit — no blame info available. That's fine.

Let me find comb's ODS for MuxOp and check its type constraints, and also check whether the HW FlattenIO pass handles unions (to gauge union maturity in the pipeline).

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && find include -name \"*.td\" -path \"*Comb*\" && grep -n -B4 -A20 \"def MuxOp\" include/circt/Dialect/Comb/*.td | head -50"}

[Tool Result]
include/circt/Dialect/Comb/Combinational.td
include/circt/Dialect/Comb/Comb.td
include/circt/Dialect/Comb/Passes.td
include/circt/Dialect/Comb/Combinational.td-279-  }];
include/circt/Dialect/Comb/Combinational.td-280-}
include/circt/Dialect/Comb/Combinational.td-281-
include/circt/Dialect/Comb/Combinational.td-282-// Select one of two values based on a condition.
include/circt/Dialect/Comb/Combinational.td:283:def MuxOp : CombOp<"mux", 
include/circt/Dialect/Comb/Combinational.td-284-  [Pure,   AllTypesMatch<["trueValue", "falseValue", "result"]>,
include/circt/Dialect/Comb/Combinational.td-285-   DeclareOpInterfaceMethods<InferIntRangeInterface, 
include/circt/Dialect/Comb/Combinational.td-286-                            ["inferResultRangesFromOptional"]>]> {
include/circt/Dialect/Comb/Combinational.td-287-  let summary = "Return one or the other operand depending on a selector bit";
include/circt/Dialect/Comb/Combinational.td-288-  let description = [{
include/circt/Dialect/Comb/Combinational.td-289-    ```
include/circt/Dialect/Comb/Combinational.td-290-      %0 = mux %pred, %tvalue, %fvalue : i4
include/circt/Dialect/Comb/Combinational.td-291-    ```
include/circt/Dialect/Comb/Combinational.td-292-  }];
include/circt/Dialect/Comb/Combinational.td-293-
include/circt/Dialect/Comb/Combinational.td-294-  let arguments = (ins I1:$cond, AnyType:$trueValue,
include/circt/Dialect/Comb/Combinational.td-295-                       AnyType:$falseValue, UnitAttr:$twoState);
include/circt/Dialect/Comb/Combinational.td-296-  let results = (outs AnyType:$result);
include/circt/Dialect/Comb/Combinational.td-297-
include/circt/Dialect/Comb/Combinational.td-298-  let assemblyFormat =
include/circt/Dialect/Comb/Combinational.td-299-    "(`bin` $twoState^)? $cond `,` $trueValue `,` $falseValue  attr-dict `:` qualified(type($result))";
include/circt/Dialect/Comb/Combinational.td-300-
include/circt/Dialect/Comb/Combinational.td-301-  let hasFolder = true;
include/circt/Dialect/Comb/C
... [truncated]

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && grep -rn -i \"union\" lib/Dialect/HW/Transforms/*.cpp | head -20; echo \"=== union ops in ODS ===\"; grep -rn \"UnionCreateOp\\|UnionExtractOp\" include/circt/Dialect/HW/HWOps.td | head -5; echo \"=== union tests for aggregate-to-comb ===\"; grep -rn -il \"union\" test/Dialect/HW/*.mlir | head -10"}

[Tool Result]
lib/Dialect/HW/Transforms/HWConvertBitcasts.cpp:55:  // TODO: Add support for: union, packed array, enum
=== union ops in ODS ===
=== union tests for aggregate-to-comb ===
test/Dialect/HW/basic.mlir
test/Dialect/HW/errors.mlir
test/Dialect/HW/hw-convert-bitcasts-errors.mlir
test/Dialect/HW/hw-convert-bitcasts.mlir
test/Dialect/HW/inline.mlir
test/Dialect/HW/typedecls.mlir
test/Dialect/HW/types.mlir


[Usage]
{"total": 17249, "input": 1621, "output": 190, "reasoning": 78, "cache": {"write": 0, "read": 15360}, "cost_usd": 0.0015468119, "reason": "tool-calls"}

[Thinking]
Very interesting. Key findings:

1. `comb.mux` is `AnyType` for true/false/result with `AllTypesMatch` — so mux on `!hw.union` is valid IR (any type allowed). Confirmed the input is valid.

2. Union support across the HW pipeline is generally immature: even `hw-convert-bitcasts` has "TODO: Add support for: union, packed array, enum". No union ops exist in HWOps.td?? Wait — grep for "UnionCreateOp|UnionExtractOp" in HWOps.td returned nothing! Let me check where union ops are defined. Maybe they're in a different .td (HWOpsGeneric?). Hmm, but earlier I saw `lib/Dialect/HW/HWOps.cpp` matched "union_create|union_extract|UnionCreateOp|UnionExtractOp|UnionType". Let me check for union op definitions.

Actually wait — uenoku's comment says "construct union_extract/create based on the bit layout", implying union_extract/union_create ops exist. Let me check. Maybe they're defined in `include/circt/Dialect/HW/HWOps.td` under different naming, e.g., `HW_UnionCreateOp`. The grep was case-sensitive for "UnionCreateOp" — perhaps the td uses `def UnionCreateOp : HWOp<"union_create"...`. Hmm, that would match. Let me search more broadly.

Actually let me check: `grep -rn "union" include/circt/Dialect/HW/*.td | head -20`.

Not critical for the decision but let me be accurate about whether union ops exist.

3. The pass itself: zero union handling. The type converter only handles ArrayType and StructType. The pass's docs don't mention unions. The pass even has a TODO about other ops: "TODO: Add ArraySliceOp and struct operations as well."

So the picture: `hw.union` support is generally incomplete/immature across the HW lowering pipeline (bitcast conversion pass also lacks union support with an explicit TODO), and `hw-aggregate-to-comb` simply never implemented unions. The failure mode is a clean MLIR conversion error (diagnostic + pass failure), not a crash/miscompile.

And the maintainer's comment explicitly frames it as an unimplemented feature to be contributed: "It's not simply implemented 👍 Please feel free to implement."

Now the decision per the given taxonomy:

PART A: Is this a bug?
- The pass produces a clear, correct diagnostic failure on a construct it doesn't support. No crash, no assertion, no miscompile, no wrong output.
- The pass never claimed union support (no mention in docs, no test, no code).
- The maintainer explicitly confirmed it's an unimplemented feature and invited implementation — the canonical signature of a feature request/enhancement.
- Reporter's framing was hedged ("If this is a bug/unimplemented feature...").

→ NOT_A_BUG (feature request / enhancement: extend hw-aggregate-to-comb to support hw.union, following the maintainer's sketch: bitcast + union_extract/create based on bit layout).

Since PART A says STOP at NOT_A_BUG, I don't need Part B. But I could briefly mention that even if one wanted to treat it as a bug, the fix is a new-feature implementation, which the automated fix pipeline shouldn't attempt... Actually no — I should follow the format: if not a bug, report NOT_A_BUG with REASON (1-3 sentences). I should end with exactly that footer.

Let me do one more sanity check on whether union ops exist (union_create/union_extract) to make my reason precise. And maybe check if there's any doc describing the pass's intended scope for unions. Let me do a quick grep for union in the docs folder too.

Also, let me quickly verify: is there a "aggregate-to-comb" (without hw- prefix) pass name anywhere? The issue used `--aggregate-to-comb`. In this tree it's `hw-aggregate-to-comb`. Let me check if `circt-opt --help` shows both. Actually, might be that the issue reporter is using a future/older version where the pass was named differently. Not critical for the decision. But let me check quickly whether `--aggregate-to-comb` exists as an alias in this build.

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && grep -rn \"union_create\\|union_extract\" include/circt/Dialect/HW/*.td | head -5; echo \"=== pass name check ===\"; /workspace/circt/build/bin/circt-opt --help 2>&1 | grep -i \"aggregate-to-comb\"; echo \"=== union in docs ===\"; grep -rn -i \"union\" docs/*.md 2>/dev/null | head -5"}

[Tool Result]
include/circt/Dialect/HW/HWAggregates.td:343:def UnionCreateOp : HWOp<"union_create", [Pure]> {
include/circt/Dialect/HW/HWAggregates.td:351:      %z = hw.union_create "bar", %x : !hw.union<bar: i3, baz: i8>
include/circt/Dialect/HW/HWAggregates.td:381:def UnionExtractOp : HWOp<"union_extract", [Pure, 
include/circt/Dialect/HW/HWAggregates.td:392:      %v = hw.union_extract %u["foo"] : !hw.union<foo: i3, bar: i16>
=== pass name check ===
      --hw-aggregate-to-comb                                       -   Lower aggregate operations to comb operations
=== union in docs ===


[Usage]
{"total": 19102, "input": 1186, "output": 116, "reasoning": 904, "cache": {"write": 0, "read": 16896}, "cost_usd": 0.0026750358, "reason": "tool-calls"}

[Thinking]
All the facts are established now. Let me summarize my findings:

1. **The input IR is valid**: `comb.mux` accepts `AnyType` operands/results (with `AllTypesMatch`), so a mux over `!hw.union` is legitimate IR. `UnionCreateOp`/`UnionExtractOp` exist in HWAggregates.td and are legal within this pass (they're not marked illegal), so union values flow through fine — only the mux trips it.

2. **The failure mode**: `hw-aggregate-to-comb` fails with a clean MLIR legalization diagnostic and `signalPassFailure`. No crash, no assertion, no miscompile, no wrong output — it refuses to proceed on a construct it cannot handle. I reproduced this exactly in this tree (same error as the issue), and confirmed the struct analog lowers cleanly (bitcast → i-mux → bitcast).

3. **Why**: The pass has zero union support — `AggregateTypeConverter` only converts `hw::ArrayType` and `hw::StructType` to integer types; the conversion patterns only cover array/struct aggregate ops. There is no union type conversion and no union op pattern. The dynamic legality check on `comb::MuxOp` (result must be `IntegerType`) makes mux-of-union illegal, and nothing legalizes it. The pass docs make no claim about unions. The source even contains an explicit TODO acknowledging incomplete coverage ("TODO: Add ArraySliceOp and struct operations as well."), and union support is similarly immature elsewhere (e.g., `hw-convert-bitcasts` has "TODO: Add support for: union, packed array, enum").

4. **Maintainer's verdict**: uenoku explicitly said "It's not simply implemented 👍 Please feel free to implement" and sketched an approach — the canonical signature of a feature request / enhancement, not a defect. The reporter also hedged ("If this is a bug/unimplemented feature...").

**Decision — PART A**: This is NOT a bug. It is an unimplemented feature / enhancement request: extending `hw-aggregate-to-comb` to handle `hw.union`. The pass behaves *correctly* for what it implements — it cleanly diagnoses and rejects a construct outside its (documented, tested) coverage rather than producing wrong output or crashing. Per the taxonomy: "It is NOT a bug if it is a feature request or enhancement." The maintainer's comment confirms the project treats it exactly that way.

Per instructions: if NOT_A_BUG, STOP — do not analyze further (Part B not needed).

The footer format:

DECISION: NOT_A_BUG
REASON: <1-3 sentences>

Let me write a concise final response with the footer exactly as required. Note the instruction: "End your response with EXACTLY one of these footers, each field on its own line." So the last lines of my response must be:

DECISION: NOT_A_BUG
REASON: ...

Let me write up the analysis summary before the footer, then the footer.

[Response]
I have everything needed for a triage decision. Here is my analysis.

## Findings

**Reproduction (confirmed in this tree, firtool-1.148.0):** Running the issue's input through `circt-opt --hw-aggregate-to-comb` (the pass's name at this tag) reproduces the exact same legalization error, while the struct analog lowers cleanly (`hw.bitcast` → integer `comb.mux` → `hw.bitcast`). The input is valid IR: `comb.mux` takes `AnyType` operands, and `hw.union_create`/`hw.union_extract` are well-defined HW ops.

**Root cause of the behavior:** `lib/Dialect/HW/Transforms/HWAggregateToComb.cpp` has *zero* union support:
- `AggregateTypeConverter` only converts `hw::ArrayType` and `hw::StructType` to integer types — `hw::UnionType` passes through unconverted.
- The conversion patterns cover only array/struct aggregate ops plus a trivial mux re-creation pattern; with union operands unconverted, the re-created mux is still non-integer, so `addDynamicallyLegalOp<comb::MuxOp>(... type_isa<IntegerType> ...)` marks it illegal and the pass fails with MLIR's standard "failed to legalize" diagnostic.
- No mention of unions exists in the pass docs (`Passes.td`), its source, or its test file; the source even carries a `// TODO: Add ArraySliceOp and struct operatons as well.` acknowledging incomplete coverage. Union support is similarly immature elsewhere (e.g., `HWConvertBitcasts.cpp` has `// TODO: Add support for: union, packed array, enum`).

**How to classify this:**
- There is **no crash, no assertion, no miscompile, no wrong output**. The pass correctly diagnoses that it cannot legalize the construct and fails with a clean diagnostic — the standard, intended behavior of an MLIR conversion pass for a case it does not implement.
- The pass never claimed or attempted union support anywhere, so nothing implemented behaves incorrectly; what's missing is new functionality (a union type conversion + union-aware mux/extract/create lowering).
- The maintainer (uenoku) explicitly confirmed the framing: *"It's not simply implemented 👍 Please feel free to implement"* — an invitation to contribute an enhancement, and the reporter hedged between "bug/unimplemented feature" from the start.

This is squarely a feature request / enhancement — extending `--hw-aggregate-to-comb` to also lower `hw.union`-typed aggregates (per the maintainer's sketch: bitcast the union and rebuild with `union_extract`/`union_create` based on the bit layout) — not a defect in existing behavior. Per the instructions, Part B analysis stops here.

DECISION: NOT_A_BUG
REASON: This is an unimplemented-feature/enhancement request, not a defect: the `hw-aggregate-to-comb` pass never supported `hw.union` (its type converter and patterns handle only arrays and structs, and its docs/tests make no union claim), and it behaves correctly for what it does implement by cleanly failing with a legalization diagnostic rather than crashing or miscompiling. The maintainer explicitly confirmed "It's not simply implemented" and invited a contribution, which is the canonical signature of a feature request rather than a bug.

[Usage]
{"total": 20631, "input": 1310, "output": 708, "reasoning": 629, "cache": {"write": 0, "read": 17984}, "cost_usd": 0.0032024666, "reason": "stop"}

[Result]
{"num_turns": 8, "input_tokens": 20006, "output_tokens": 2195, "reasoning_tokens": 9924, "cache_read": 82176, "cache_write": 0, "cost_usd": 0.0240269458}

