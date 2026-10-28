[Thinking]
Let me analyze this issue carefully.

The issue is about FIRRTL's DropConst pass. When a type alias like `type X = { a: const UInt<1> }` is used, and the DropConst pass removes `const` from the type, the type alias apparently gets dropped from the output (or something happens to it). The reporter says "Dropping 'const' from the example above (modify the FIRRTL's text) and the type alias makes it to the output."

Let me read that sentence carefully: "Dropping "const" from the example above (modify the FIRRTL's text) and the type alias makes it to the output." — I think this means: if you edit the source FIRRTL to remove `const`, then the type alias appears in the output. But when the input has `const`, the alias is dropped from the output (because DropConst pass mutates the type, and the alias becomes unrepresentable or gets lost).

Wait, actually let me think about it. In FIRRTL SIR, type aliases are handled. When DropConst runs, it strips `const` qualifiers from types. Type aliases are... Let me investigate the code.

Let me look at the DropConst pass in the CIRCT source tree.

Let me use the tool to explore.

Actually I should investigate:
1. `lib/Dialect/FIRRTL/Transforms/DropConst.cpp`
2. How type aliases are stored/serialized. In FIRRTL, type aliases are represented via a "TypeAliasOp" (hw.struct or an op in a firrtl.module body?). Actually type aliases in FIRRTL are handled in the parser and stored in the circuit's metadata; they're serialized back out in the `firrtl` output. Type aliases are represented as `an unbound` ... hmm.

In CIRCT, FIRRTL type aliases are stored as `AliasAnnotation` or as attributes. The `FIRRTL` dialect has `TypeAliasOp`? Let me recall. There's `circt.mlir` FIRRTL — the parser records types and aliases via "AliasAttr"? I recall in CIRCT there is handling in `lib/Dialect/FIRRTL/IR/FIRRTLAnnotations.cpp`? No.

Actually, type aliases in FIRRTL text: `type X = ...` is parsed and stored as a TypeAliasOp — there is an op `firrtl.typealias`? Hmm. I recall that the FIRRTL parser handles `type` declarations and creates `hw.typedecl` operations. Yes! `hw.typedecl` is the op used for type aliases in export. Type aliases are `hw::TypedeclOp` operations that hold a type attribute. The printer then can print aliases back.

So DropConst strips const from types. If the type alias's stored type contains a const, DropConst needs to update the alias op too. If it doesn't, the alias retains const while the uses don't... or the alias gets dropped.

Let me investigate the actual code. I'll use the bash tool.

The question for the triage: Is this a bug? And if so, is the correct behavior clear?

The issue title: "[FIRRTL][DropConst] Preserve alias?" — with a question mark. The body: "Arguably the type name shouldn't be preserved if mutating it (dropping const), but since that's unrepresentable thereafter (as well as in the lowered/output) there seems to be a reasonable case for keeping the type alias but without the const bits. Low-priority as I don't think `const` is used but FYI."

So the reporter (dtzSiFive, a CIRCT maintainer) is essentially raising a design question: should the type alias be preserved after DropConst mutates the type? This reads like a feature request / design question, not a clear bug. The behavior may be: when DropConst modifies a type referenced via an alias, the alias is dropped (or the alias's type keeps const, causing inconsistency?).

Let me check the code to see what actually happens. Let's do a read-only investigation.

Plan:
1. Look at lib/Dialect/FIRRTL/Transforms/DropConst.cpp.
2. Look at how type aliases (TypedeclOp) are handled.
3. Possibly run the repro (but the instructions say READ-ONLY for investigation — "Do not edit anything — this is analysis only." But I can run firtool from build/bin to see behavior; running a tool doesn't edit the tree. The instructions say grep and read source, git log, etc. I think running the repro is fine and read-only; it helps determine if it's a bug. Hmm, "You MAY use the circt bash tool to investigate /workspace/circt READ-ONLY to understand the intended behavior: grep and read the relevant source..., the dialect docs..., and git log / git blame. Do not edit anything — this is analysis only." Running firtool on a temp file in /tmp doesn't edit the tree. I'll do it to understand behavior. Actually the pipeline says triage BEFORE any attempt to reproduce... "BEFORE any attempt to reproduce or fix it. Decide whether this issue is something the automated pipeline should attempt at all". Hmm — "You are triaging a CIRCT issue BEFORE any attempt to reproduce or fix it." So maybe I shouldn't reproduce. But understanding behavior helps. The tool description says I MAY use bash to investigate source, docs, git log. I think running the repro is still consistent with the spirit (understanding), as long as I don't edit. But to be safe, I can do a light reproduction to determine actual behavior — that's key to deciding if it's a bug. I'd argue reading DropConst.cpp suffices, but running the example would be much more definitive. The prompt says "Read the issue carefully. You MAY use the circt bash tool to investigate /workspace/circt READ-ONLY". Running firtool doesn't modify the repo. I'll do it — it's investigation, read-only with respect to the repo. I'll write the test file to /tmp.

Let me start investigating.

Key considerations for the decision:

PART A: Is it a bug? The issue is: when DropConst runs and a type alias contains a const type, the alias (type name) is lost from the output, whereas without const the alias survives. The behavior is arguably intentional-ish: the pass must mutate the aliased type, and dropping the alias is a safe fallback. Is the output incorrect? The FIRRTL spec doesn't require alias preservation — aliases are purely cosmetic. The output is semantically correct (semantically equivalent), just less readable. There's no crash, no miscompile, no wrong output semantically. The question mark in the title ("Preserve alias?") and the body ("Arguably... there seems to be a reasonable case for...") signal this is a design proposal/question, labeled low priority.

So this is likely NOT_A_BUG (it's an enhancement/design question) or possibly a "cosmetic bug". The key: does DropConst produce incorrect IR? Let me check the code to see whether the alias gets dropped deliberately (e.g., they erase the typedecl if it has const) or whether something inconsistent results (e.g., typedecl still containing const while uses don't — that would be a real inconsistency bug).

Let me look at the code.

I'll run some commands.

Let me plan the bash commands:

1. `ls /workspace/circt/lib/Dialect/FIRRTL/Transforms/DropConst.cpp` and cat it.
2. Grep for `Typedecl` handling in DropConst or in FIRRTL passes.
3. Run the repro.

Let me do it.

Also check git log/blame for DropConst.

Let me start.

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "cat /workspace/circt/lib/Dialect/FIRRTL/Transforms/DropConst.cpp"}

[Tool Result]
//===- DropConst.cpp - Check and remove const types -------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines the DropConst pass.
//
//===----------------------------------------------------------------------===//

#include "circt/Dialect/FIRRTL/FIRRTLInstanceGraph.h"
#include "circt/Dialect/FIRRTL/FIRRTLOps.h"
#include "circt/Dialect/FIRRTL/FIRRTLTypes.h"
#include "circt/Dialect/FIRRTL/FIRRTLUtils.h"
#include "circt/Dialect/FIRRTL/Passes.h"
#include "mlir/IR/Threading.h"
#include "mlir/Pass/Pass.h"

namespace circt {
namespace firrtl {
#define GEN_PASS_DEF_DROPCONST
#include "circt/Dialect/FIRRTL/Passes.h.inc"
} // namespace firrtl
} // namespace circt

using namespace circt;
using namespace firrtl;

/// Returns null type if no conversion is needed.
static FIRRTLBaseType convertType(FIRRTLBaseType type) {
  auto nonConstType = type.getAllConstDroppedType();
  return nonConstType != type ? nonConstType : FIRRTLBaseType{};
}

/// Returns null type if no conversion is needed.
static Type convertType(Type type) {
  if (auto base = type_dyn_cast<FIRRTLBaseType>(type)) {
    return convertType(base);
  }

  if (auto refType = type_dyn_cast<RefType>(type)) {
    if (auto converted = convertType(refType.getType()))
      return RefType::get(converted, refType.getForceable(),
                          refType.getLayer());
  }

  return {};
}

namespace {
class DropConstPass : public circt::firrtl::impl::DropConstBase<DropConstPass> {
  void runOnOperation() override {

    // Update signatures of all module-likes.
    auto moduleLikes = getOperation().getOps<FModuleLike>();
    for (auto mod : moduleLikes) {
      //// Update the module signature with non-'const' ports
      SmallVector<Attribute
... [truncated]

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "grep -rn \"Typedecl\\|TypeAlias\\|typedecl\" /workspace/circt/lib/Dialect/FIRRTL --include=*.cpp -l | head -30"}

[Tool Result]
/workspace/circt/lib/Dialect/FIRRTL/FIRRTLUtils.cpp
/workspace/circt/lib/Dialect/FIRRTL/Import/FIRParser.cpp
/workspace/circt/lib/Dialect/FIRRTL/FIRRTLTypes.cpp


[Response]
I'll investigate this issue in the CIRCT source tree. Let me start by looking at the DropConst pass and how type aliases are handled.

[Usage]
{"total": 4512, "input": 2764, "output": 128, "reasoning": 1620, "cache": {"write": 0, "read": 0}, "cost_usd": 0.0026404036, "reason": "tool-calls"}

[Thinking]
Now, type aliases. In CIRCT FIRRTL, type aliases from the parser are handled in FIRParser.cpp. Let me see how `type X = ...` is handled and stored — likely via `hw.typedecl` ops or some alias map. Let me check where typedecl ops live and how they interact with const-dropping. Also, how the firrtl printer prints aliases back out. Let me grep for "Typedecl" in the parser and printer.

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "grep -rn \"typedecl\\|TypeAliasOp\\|TypeAlias\" /workspace/circt/lib/Dialect/FIRRTL/Import/FIRParser.cpp | head -40"}

[Tool Result]
6331:    type = BaseTypeAliasType::get(name, base);


[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "grep -rn \"Typedecl\" /workspace/circt/lib/Dialect/HW/*.cpp /workspace/circt/lib/Dialect/HW/*.cpp.inc 2>/dev/null | head; grep -rn \"TypedeclOp\" /workspace/circt/lib/Dialect/FIRRTL --include=*.cpp | head -20"}

[Tool Result]
/workspace/circt/lib/Dialect/HW/HWOps.cpp:2975:// TypedeclOp
/workspace/circt/lib/Dialect/HW/HWOps.cpp:2978:StringRef TypedeclOp::getPreferredName() {
/workspace/circt/lib/Dialect/HW/HWOps.cpp:2982:Type TypedeclOp::getAliasType() {
/workspace/circt/lib/Dialect/HW/HWTypes.cpp:808:/// Return the Typedecl referenced by this TypeAlias, given the module to look
/workspace/circt/lib/Dialect/HW/HWTypes.cpp:810:TypedeclOp TypeAliasType::getTypeDecl(const HWSymbolCache &cache) {
/workspace/circt/lib/Dialect/HW/HWTypes.cpp:817:  return typeScope.lookupSymbol<TypedeclOp>(ref.getLeafReference());


[Usage]
{"total": 5655, "input": 928, "output": 148, "reasoning": 99, "cache": {"write": 0, "read": 4480}, "cost_usd": 0.0007193392, "reason": "tool-calls"}

[Thinking]
So in the current pinned version, type aliases are handled via `BaseTypeAliasType` — a FIRRTL-specific alias type that wraps a base type, and the alias ops are `hw::TypedeclOp`. The FIRParser stores the alias as a `BaseTypeAliasType` and creates `hw::Typedecl` op. Let me look at the FIRParser around line 6331 and how typedecl ops are created, and then what happens in DropConst — the pass shown above doesn't touch Typedecl ops or BaseTypeAliasType at all!

So a `hw::Typedecl` op holds a `type` attribute which could be a `BaseTypeAliasType` wrapping... hmm, actually how does it work? Let's check: `TypedeclOp` gets a type which is the aliased type. In FIRRTL, the alias type is `BaseTypeAliasType` which wraps an alias ref + the aliased type? Let me check.

If DropConst doesn't handle `hw::Typedecl` operations, then the typedecl still contains a type with `const` while the uses (ports) have const dropped. That could leave an inconsistent IR — the typedecl says `const` but the uses don't. Is that a verifier error, or just a cosmetic inconsistency? Let me look at FIRParser code and HWTypes around BaseTypeAliasType.

Also, what does the printer do? The FIRRTL printer (lib/Dialect/FIRRTL/IR/FIRRTLAttributes.cpp? or FIRPrinter) prints `type` decls based on typedecl ops. Let me search.

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "grep -rn \"BaseTypeAliasType\\|Typedecl\" /workspace/circt/lib/Dialect/FIRRTL/FIRRTLTypes.cpp | head -30; echo ---; sed -n 6280,6360p /workspace/circt/lib/Dialect/FIRRTL/Import/FIRParser.cpp"}

[Tool Result]
157:      .Case<BaseTypeAliasType>([&](BaseTypeAliasType alias) {
547:               BaseTypeAliasType::get(StringAttr::get(context, name), type),
725:      .Case<BaseTypeAliasType>([](BaseTypeAliasType alias) {
765:            RefType, BaseTypeAliasType>(
792:      .Case<BundleType, FVectorType, FEnumType, BaseTypeAliasType>(
805:      .Case<BundleType, FVectorType, FEnumType, BaseTypeAliasType>(
817:            UIntType, BundleType, FVectorType, FEnumType, BaseTypeAliasType>(
830:      .Case<BundleType, FVectorType, FEnumType, BaseTypeAliasType>(
860:      .Case<BaseTypeAliasType>([](BaseTypeAliasType base) {
896:      .Case<BaseTypeAliasType>([](BaseTypeAliasType type) {
918:      .Case<BaseTypeAliasType>([](BaseTypeAliasType type) {
936:      .Case<BaseTypeAliasType>(
2412:// BaseTypeAliasType
2441:auto BaseTypeAliasType::get(StringAttr name, FIRRTLBaseType innerType)
2442:    -> BaseTypeAliasType {
2446:auto BaseTypeAliasType::getName() const -> StringAttr {
2450:auto BaseTypeAliasType::getInnerType() const -> FIRRTLBaseType {
2454:FIRRTLBaseType BaseTypeAliasType::getAnonymousType() {
2461:FIRRTLBaseType BaseTypeAliasType::getPassiveType() {
2465:RecursiveTypeProperties BaseTypeAliasType::getRecursiveTypeProperties() const {
2474:BaseTypeAliasType::getModifiedType(FIRRTLBaseType newInnerType) const {
2481:FIRRTLBaseType BaseTypeAliasType::getAllConstDroppedType() {
2485:FIRRTLBaseType BaseTypeAliasType::getConstType(bool isConst) const {
2490:BaseTypeAliasType::getSubTypeByFieldID(uint64_t fieldID) const {
2494:uint64_t BaseTypeAliasType::getMaxFieldID() const {
2499:BaseTypeAliasType::projectToChildFieldID(uint64_t fieldID,
2504:uint64_t BaseTypeAliasType::getIndexForFieldID(uint64_t fieldID) const {
2508:uint64_t BaseTypeAliasType::getFieldID(uint64_t index) const {
2513:BaseTypeAliasType::getIndexAndSubfieldID(uint64_t fieldID) const {
---
    if (requireFeature({1, 2, 0}, "intrinsic modules") ||
        removedFeature({4, 0, 0}, "intrinsic modules"))
     
... [truncated]

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "grep -rn \"TypedeclOp\\|hw::Typedecl\" /workspace/circt/lib/Dialect/FIRRTL/Export/FIRPrinter.cpp /workspace/circt/lib/Dialect/FIRRTL/Export/*.cpp | head -20"}

[Tool Result]

STDERR:
grep: /workspace/circt/lib/Dialect/FIRRTL/Export/FIRPrinter.cpp: No such file or directory


[Usage]
{"total": 6359, "input": 231, "output": 159, "reasoning": 337, "cache": {"write": 0, "read": 5632}, "cost_usd": 0.0010985917, "reason": "tool-calls"}

[Thinking]
So `BaseTypeAliasType` has `getAllConstDroppedType()`. Let me look at that function and `getModifiedType`. It seems there is already machinery: `BaseTypeAliasType::getModifiedType(FIRRTLBaseType newInnerType)` and `getAllConstDroppedType()`. Let me read lines 2412-2520 of FIRRTLTypes.cpp.

Also I need to find where typedecl ops are created (`hw::TypedeclOp`) and where DropConst handles (or fails to handle) them. The DropConst pass above only iterates module-likes (port types) and walks module bodies. Typedecl ops are placed at the circuit level (outside modules?), so `hw::TypedeclOp` ops are in the circuit body. Wait — where are Typedecl ops created? In the parser, after parseTypeDecl, it inserts into aliasMap; the typedecl ops are created elsewhere. Let me search for TypedeclOp::create in FIRParser.

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "sed -n 2400,2520p /workspace/circt/lib/Dialect/FIRRTL/FIRRTLTypes.cpp"}

[Tool Result]
  if (!impl->recProps.containsTypeAlias)
    return impl->anonymousType = *this;

  SmallVector<FEnumType::EnumElement, 4> elements;

  for (auto element : getElements())
    elements.push_back(
        {element.name, element.value, element.type.getAnonymousType()});
  return impl->anonymousType = FEnumType::get(getContext(), elements);
}

//===----------------------------------------------------------------------===//
// BaseTypeAliasType
//===----------------------------------------------------------------------===//

struct circt::firrtl::detail::BaseTypeAliasStorage
    : circt::firrtl::detail::FIRRTLBaseTypeStorage {
  using KeyTy = std::tuple<StringAttr, FIRRTLBaseType>;

  BaseTypeAliasStorage(StringAttr name, FIRRTLBaseType innerType)
      : detail::FIRRTLBaseTypeStorage(innerType.isConst()), name(name),
        innerType(innerType) {}

  bool operator==(const KeyTy &key) const { return key == getAsKey(); }

  KeyTy getAsKey() const { return KeyTy(name, innerType); }

  static llvm::hash_code hashKey(const KeyTy &key) {
    return llvm::hash_value(key);
  }

  static BaseTypeAliasStorage *construct(TypeStorageAllocator &allocator,
                                         KeyTy key) {
    return new (allocator.allocate<BaseTypeAliasStorage>())
        BaseTypeAliasStorage(std::get<0>(key), std::get<1>(key));
  }
  StringAttr name;
  FIRRTLBaseType innerType;
  FIRRTLBaseType anonymousType;
};

auto BaseTypeAliasType::get(StringAttr name, FIRRTLBaseType innerType)
    -> BaseTypeAliasType {
  return Base::get(name.getContext(), name, innerType);
}

auto BaseTypeAliasType::getName() const -> StringAttr {
  return getImpl()->name;
}

auto BaseTypeAliasType::getInnerType() const -> FIRRTLBaseType {
  return getImpl()->innerType;
}

FIRRTLBaseType BaseTypeAliasType::getAnonymousType() {
  auto *impl = getImpl();
  if (impl->anonymousType)
    return impl->anonymousType;
  return impl->anonymousType = getInnerType().getAnonymousType();
}

FIRRTLBaseType BaseTypeAl
... [truncated]

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "grep -rn \"Typedecl\\|alias\" /workspace/circt/lib/Dialect/FIRRTL/Import/FIRParser.cpp | grep -in \"typedecl\" "}

[Tool Result]

[exit code: 1]

[Usage]
{"total": 7959, "input": 1306, "output": 105, "reasoning": 212, "cache": {"write": 0, "read": 6336}, "cost_usd": 0.0009716398, "reason": "tool-calls"}

[Thinking]
Interesting. So `BaseTypeAliasType::getAllConstDroppedType()` → `getModifiedType(getInnerType().getAllConstDroppedType())` → if the modified type differs from the inner type, the alias is dropped and replaced by the new (non-alias) inner type. That's exactly the behavior described in the issue: when a type alias's aliased type contains `const`, dropping const changes the inner type, so `getModifiedType` returns the bare type without the alias, so the alias is lost (the type alias `X` disappears from the output). If no const is present, the alias survives.

So this is deliberate, existing behavior: "If a given `newInnerType` is identical to innerType, return `*this` because we can reuse the type alias. Otherwise return `newInnerType`." — i.e., alias is preserved only if the modification doesn't change the type. This is a design decision already in the code: the alias is dropped when it's mutated because the alias as declared (`{ a: const UInt<1> })` can no longer be represented faithfully after dropping const.

Now, in this version (firtool-1.148.0), where are the typedecl ops created? Let me check how aliases are exported. Search for where BaseTypeAliasType is resolved for the printer — HW StructType / hw::TypeAliasType and typedecl op. In FIRRTL, BaseTypeAliasType is a FIRRTL-side alias; the hw typedecl is created at lowering to HW (FinalLowering?) or in the parser? The FIRParser inserts into aliasMap; then typedecl ops... let me grep for "TypedeclOp::create" in the parser.

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "grep -rn \"Typedecl\\|createTypeAlias\\|TypeAlias\" /workspace/circt/lib/Dialect/FIRRTL/Import/FIRParser.cpp | head -30; echo ===; grep -rn \"Typedecl\" /workspace/circt/lib/Dialect/FIRRTL --include=*.cpp -l"}

[Tool Result]
6331:    type = BaseTypeAliasType::get(name, base);
===

[exit code: 1]

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "git log --oneline -15 -- lib/Dialect/FIRRTL/Transforms/DropConst.cpp; echo ===; git log --oneline -8 -- \"lib/Dialect/FIRRTL/FIRRTLTypes.cpp\" | head -8"}

[Tool Result]
5dc7f10 [Synth] Move three-input op boilerplate to ODS (#10540)
===
5dc7f10 [Synth] Move three-input op boilerplate to ODS (#10540)


[Usage]
{"total": 9446, "input": 993, "output": 158, "reasoning": 359, "cache": {"write": 0, "read": 7936}, "cost_usd": 0.0013400011, "reason": "tool-calls"}

[Thinking]
Let me check the version / git state of the checkout. Note the issue is from June 2024 (firtool-1.148.0 is... hmm, firtool-1.148.0 would be around late 2025?). Actually the version numbering: firtool-1.148.0 corresponds to a much later version than June 2024. Let me check `git log -1` and whether the current checkout still behaves the same way.

Also let me find where hw::TypedeclOp is created for FIRRTL type aliases. In current CIRCT, the parser creates `hw::TypedeclOp` at the end (finishCircuit?) Let me grep in FIRParser.cpp for "TypedeclOp" — nothing found above (only BaseTypeAliasType::get). So in this version, FIRRTL aliases are kept as `BaseTypeAliasType` (a FIRRTL type, uniqued in the context) and no hw.typedecl is created during parsing. When printing back FIRRTL text, the FIRPrinter prints the alias using... let's check the printer (lib/Dialect/FIRRTL/Export/FIRToText? or wherever). Let me find where aliases are emitted — search for "type " emission and "BaseTypeAliasType" in Export.

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "git log --oneline -3; echo ===; grep -rn \"BaseTypeAliasType\" /workspace/circt/lib/Dialect/FIRRTL/Export/*.cpp | head; echo ===; ls /workspace/circt/lib/Dialect/FIRRTL/Export/ 2>/dev/null; ls /workspace/circt/lib/Dialect/FIRRTL/ | head -40"}

[Tool Result]
5dc7f10 [Synth] Move three-input op boilerplate to ODS (#10540)
===
===
CMakeLists.txt
FIREmitter.cpp
CHIRRTLDialect.cpp
CHIRRTLTypes.cpp
CMakeLists.txt
Export
FIRRTLAnnotationHelper.cpp
FIRRTLAnnotations.cpp
FIRRTLAttributes.cpp
FIRRTLDialect.cpp
FIRRTLFieldSource.cpp
FIRRTLFolds.cpp
FIRRTLInstanceGraph.cpp
FIRRTLInstanceImplementation.cpp
FIRRTLIntrinsics.cpp
FIRRTLIntrinsics.td
FIRRTLOpInterfaces.cpp
FIRRTLOps.cpp
FIRRTLReductions.cpp
FIRRTLTypes.cpp
FIRRTLUtils.cpp
FieldRefCache.cpp
Import
NLATable.cpp
Transforms


[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "grep -rn \"AliasType\\|alias\" /workspace/circt/lib/Dialect/FIRRTL/Export/FIRToText.cpp 2>/dev/null | head; grep -rn \"BaseTypeAlias\\|TypeAlias\" /workspace/circt/lib/Dialect/FIRRTL/Export/*.cpp | head"}

[Tool Result]
(no output)

[Usage]
{"total": 9974, "input": 115, "output": 184, "reasoning": 267, "cache": {"write": 0, "read": 9408}, "cost_usd": 0.0012876497, "reason": "tool-calls"}

[Thinking]
Let me look at Export/FIREmitter.cpp for alias handling and how types print.

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "grep -n \"Alias\\|alias\" /workspace/circt/lib/Dialect/FIRRTL/Export/FIREmitter.cpp | head -40"}

[Tool Result]
1601:  // TODO: Emit type decl for type alias.
1893:  // TODO: Emit type decl for type alias.


[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "grep -rn \"BaseTypeAlias\" /workspace/circt/include/circt/Dialect/FIRRTL/FIRRTLTypes.h | head"}

[Tool Result]
36:struct BaseTypeAliasStorage;
66:class BaseTypeAliasType;
467:    if (auto alias = dyn_cast<BaseTypeAliasType>(type))
492:    if (auto alias = dyn_cast<BaseTypeAliasType>(type))
611:class BaseTypeAliasOr
612:    : public ::mlir::Type::TypeBase<BaseTypeAliasOr<BaseTy>,
617:  using mlir::Type::TypeBase<BaseTypeAliasOr<BaseTy>, firrtl::FIRRTLBaseType,


[Usage]
{"total": 10276, "input": 10158, "output": 100, "reasoning": 18, "cache": {"write": 0, "read": 0}, "cost_usd": 0.0008752442, "reason": "tool-calls"}

[Thinking]
Interesting — the current checkout has a "TODO: Emit type decl for type alias" in the exporter. Hmm, wait — this checkout appears quite different from June 2024 (firtool-1.148.0 is around late 2025). Hmm, but wait: is there an exporter that prints type decls somewhere? Let me check the export code — maybe printing of type decls moved elsewhere. Let me look at lines 1590-1900 in FIREmitter.cpp.

Actually, wait: the git log shows only 1 commit?? "git log --oneline -3" showed only one commit "5dc7f10". Maybe a shallow clone. OK.

Now, the key question is: what is the actual current behavior with this repro, and is this a bug?

Let me trace how the alias survives. The parser: `type X = { a: const UInt<1> }` → aliasMap entry `X -> BaseTypeAliasType(X, {a: const UInt<1>})`. Then ports typed `X` get that alias type.

DropConst: port types get `convertType` → `type.getAllConstDroppedType()` → `BaseTypeAliasType::getAllConstDroppedType()` → `getModifiedType(inner.getAllConstDroppedType())` → inner `{a: const UInt<1>}` → `{a: UInt<1>}` which != `{a: const UInt<1>}`, so the returned type is the plain `{a: UInt<1>}` without the alias. So after DropConst, the port type is no longer an alias — the alias `X` is lost from ports. That matches the issue: "the type alias" doesn't make it to the output (i.e., in the exported FIRRTL the ports print with the fully spelled-out struct type instead of `X`).

Also note: there are TypedeclOp ops? In this version, hw::Typedecl exists but the exporter has a TODO for emitting type decls... Let me check whether the parser creates hw.typedecl ops somewhere — search entire lib for "TypedeclOp::create".

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "grep -rn \"TypedeclOp::create\\|TypedeclOp\\b\" /workspace/circt/lib --include=*.cpp | grep -v HWOps.cpp | head -20; echo ===; sed -n 1590,1615p /workspace/circt/lib/Dialect/FIRRTL/Export/FIREmitter.cpp; sed -n 1885,1900p /workspace/circt/lib/Dialect/FIRRTL/Export/FIREmitter.cpp"}

[Tool Result]
/workspace/circt/lib/Dialect/HW/HWTypes.cpp:810:TypedeclOp TypeAliasType::getTypeDecl(const HWSymbolCache &cache) {
/workspace/circt/lib/Dialect/HW/HWTypes.cpp:817:  return typeScope.lookupSymbol<TypedeclOp>(ref.getLeafReference());
/workspace/circt/lib/Conversion/FSMToSV/FSMToSV.cpp:155:  auto typedeclEnumType = hw::TypedeclOp::create(
/workspace/circt/lib/Conversion/ExportVerilog/ExportVerilog.cpp:4097:  LogicalResult visitStmt(TypedeclOp op);
/workspace/circt/lib/Conversion/ExportVerilog/ExportVerilog.cpp:4476:LogicalResult StmtEmitter::visitStmt(TypedeclOp op) {
/workspace/circt/lib/Conversion/ExportVerilog/LegalizeAnonEnums.cpp:55:    TypedeclOp::create(builder, loc, declName, TypeAttr::get(type), nullptr);
/workspace/circt/lib/Conversion/ExportVerilog/LegalizeNames.cpp:303:    for (auto typeDecl : typeScope.getOps<hw::TypedeclOp>()) {
/workspace/circt/lib/Conversion/FIRRTLToHW/LowerToHW.cpp:466:  /// TypedeclOp inside a single global TypeScopeOp. This structure
/workspace/circt/lib/Conversion/FIRRTLToHW/LowerToHW.cpp:511:      auto typeDecl = hw::TypedeclOp::create(typeScopeBuilder, typeLoc,
===
  ps << "(";
  ps.addAsString(op.getValue());
  ps << ")";
}

void Emitter::emitExpression(SpecialConstantOp op) {
  auto emitInner = [&]() {
    ps << "UInt<1>(";
    ps.addAsString(op.getValue());
    ps << ")";
  };
  // TODO: Emit type decl for type alias.
  FIRRTLTypeSwitch<FIRRTLType>(type_cast<FIRRTLType>(op.getType()))
      .Case<ClockType>([&](auto type) {
        ps << "asClock(";
        emitInner();
        ps << ")";
      })
      .Case<ResetType>([&](auto type) { emitInner(); })
      .Case<AsyncResetType>([&](auto type) {
        ps << "asAsyncReset(";
        emitInner();
        ps << ")";
      });
}

    ps << "const ";
  auto emitWidth = [&](std::optional<int32_t> width) {
    if (width) {
      ps << "<";
      ps.addAsString(*width);
      ps << ">";
    }
  };
  // TODO: Emit type decl for type alias.
  FIRRTLTypeSwitch<Type>(type)
      .Case<
... [truncated]

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "grep -rn \"class TypeAliasEmitter\\|typeAliasMap\\|BaseTypeAliasType\" /workspace/circt/lib/Dialect/FIRRTL/Export/FIREmitter.cpp | head -20"}

[Tool Result]
(no output)

[Usage]
{"total": 11038, "input": 175, "output": 182, "reasoning": 441, "cache": {"write": 0, "read": 10240}, "cost_usd": 0.0015899685, "reason": "tool-calls"}

[Thinking]
Hmm — this checkout's exporter doesn't emit type aliases at all ("TODO: Emit type decl for type alias")? But the issue says "Dropping 'const' from the example above (modify the FIRRTL's text) and the type alias makes it to the output." — so in June 2024, the alias made it to the output. In this pinned version (firtool-1.148.0 — which per the version scheme is much later, maybe late 2025), the exporter has TODOs for emitting type aliases... Hmm, wait, maybe the emitter does emit aliases elsewhere. Let me look more carefully — maybe there's a function that prints types with aliases via "BaseTypeAliasType" in the printer. Grep found no BaseTypeAliasType in Export. Hmm. But the prompt says the issue should be evaluated against this checkout, and pipeline may want to reproduce/fix it. If the current checkout doesn't even emit type aliases, the repro might behave differently.

Wait — actually, maybe the checkout is from June 2024 despite the firtool version? firtool-1.148.0... let me check the actual date of the checkout. `git log -1 --date=iso`. Shallow clone with depth 1. Let me check include/circt/InitFIRRTL? or CMakeLists version. Let me check git show date.

Actually wait — the DropConst pass and BaseTypeAliasType exist. In actual June 2024 CIRCT (circt at ~June 2024), the exporter did have alias emission via "TypeAliasEmitter"? Hmm. Let me check: in mid-2024, FIRRTL export was in lib/Dialect/FIRRTL/Export/FIRToText.cpp with a `TypeAliasEmitter`... Actually I remember `FIRToText.cpp` had "emitType" with alias tracking. But this checkout has FIREmitter.cpp with TODOs. Let me check the git date of the commit and the version in CMakeLists.

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "git log -1 --format='%H %ad %s' --date=iso; grep -n \"CIRCT_VERSION\\|set(FIRTOOL\" CMakeLists.txt | head; cat .git/shallow 2>/dev/null; git branch -a"}

[Tool Result]
5dc7f103d714aa40e13cae4fcf7ab98a1912f845 2026-05-24 17:14:51 -0700 [Synth] Move three-input op boilerplate to ODS (#10540)
5dc7f103d714aa40e13cae4fcf7ab98a1912f845
* (no branch)


[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "grep -rn \"alias\" /workspace/circt/lib/Dialect/FIRRTL/Export/FIREmitter.cpp | head -20; echo ===; grep -rn \"emitPort\\|emitType\" /workspace/circt/lib/Dialect/FIRRTL/Export/FIREmitter.cpp | head"}

[Tool Result]
1601:  // TODO: Emit type decl for type alias.
1893:  // TODO: Emit type decl for type alias.
===
234:  void emitType(Type type, bool includeConst = true);
235:  void emitTypeWithColon(Type type) {
237:    emitType(type);
302:    emitType(type);
582:        emitTypeWithColon(op.getResult().getType());
693:    emitType(port.type);
718:      emitType(fieldAttr.getType());
880:    emitTypeWithColon(op.getResult().getType());
904:    emitTypeWithColon(op.getResult().getType());
918:      emitTypeWithColon(op.getResult().getType());


[Usage]
{"total": 12288, "input": 708, "output": 158, "reasoning": 414, "cache": {"write": 0, "read": 11008}, "cost_usd": 0.0016087404, "reason": "tool-calls"}

[Thinking]
The checkout is dated 2026-05-24 — far newer than the issue (June 2024). So the codebase has evolved substantially. Notably, in this current version, the FIRRTL exporter does not emit type aliases at all ("TODO: Emit type decl for type alias"), and there is no TypeAliasEmitter. Hmm — wait, is that right? Let me check the emitType implementation for BaseTypeAliasType handling.

Let me look at emitType in FIREmitter.cpp (around line 1880-1960).

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "sed -n 1860,1975p /workspace/circt/lib/Dialect/FIRRTL/Export/FIREmitter.cpp"}

[Tool Result]
    ps << "write";
    break;
  case MemDirAttr::ReadWrite:
    ps << "rdwr";
    break;
  }
}

void Emitter::emitAttribute(RUWBehaviorAttr attr) {
  switch (attr.getValue()) {
  case RUWBehavior::Undefined:
    ps << "undefined";
    break;
  case RUWBehavior::Old:
    ps << "old";
    break;
  case RUWBehavior::New:
    ps << "new";
    break;
  }
}

/// Emit a FIRRTL type into the output.
void Emitter::emitType(Type type, bool includeConst) {
  if (includeConst && isConst(type))
    ps << "const ";
  auto emitWidth = [&](std::optional<int32_t> width) {
    if (width) {
      ps << "<";
      ps.addAsString(*width);
      ps << ">";
    }
  };
  // TODO: Emit type decl for type alias.
  FIRRTLTypeSwitch<Type>(type)
      .Case<ClockType>([&](auto) { ps << "Clock"; })
      .Case<ResetType>([&](auto) { ps << "Reset"; })
      .Case<AsyncResetType>([&](auto) { ps << "AsyncReset"; })
      .Case<UIntType>([&](auto type) {
        ps << "UInt";
        emitWidth(type.getWidth());
      })
      .Case<SIntType>([&](auto type) {
        ps << "SInt";
        emitWidth(type.getWidth());
      })
      .Case<AnalogType>([&](auto type) {
        ps << "Analog";
        emitWidth(type.getWidth());
      })
      .Case<OpenBundleType, BundleType>([&](auto type) {
        ps << "{";
        if (!type.getElements().empty())
          ps << PP::nbsp;
        bool anyEmitted = false;
        ps.scopedBox(PP::cbox0, [&]() {
          for (auto &element : type.getElements()) {
            if (anyEmitted)
              ps << "," << PP::space;
            ps.scopedBox(PP::ibox2, [&]() {
              if (element.isFlip)
                ps << "flip ";
              ps << legalize(element.name);
              emitTypeWithColon(element.type);
              anyEmitted = true;
            });
          }
          if (anyEmitted)
            ps << PP::nbsp;
          ps << "}";
        });
      })
      .Case<OpenVectorType, FVectorType, CMemoryType>([&](auto type) {
        emitType(ty
... [truncated]

[Usage]
{"total": 12689, "input": 306, "output": 49, "reasoning": 110, "cache": {"write": 0, "read": 12224}, "cost_usd": 0.001086223, "reason": "tool-calls"}

[Thinking]
Wait — this current checkout's emitType doesn't handle BaseTypeAliasType at all. Hmm — actually, wait, does it? `FIRRTLTypeSwitch<Type>`... `.Default` → `llvm_unreachable`. If a BaseTypeAliasType got through, it would crash! But the parser creates `BaseTypeAliasType` for aliases... and emitType would hit `Default` → llvm_unreachable. Unless the exporter resolves aliases somewhere first, or unless there's special handling before FIRRTLTypeSwitch. Hmm, but there's a "TODO: Emit type decl for type alias". Hmm wait, but there's `isConst(type)`... Let me actually just run the repro. Writing a temp file to /tmp is fine and doesn't modify the checkout — it's investigation of actual behavior, which is important for triage. The instruction says "BEFORE any attempt to reproduce" — hmm. But to determine whether it's a bug, running the example is the natural thing. I believe running the tool counts as investigation; the constraint is "Do not edit anything" (in the tree). I'll run it.

Let me create /tmp/const_alias.fir and run firtool from build/bin.

Note: firtool builds into build/bin. Options from the issue: `-preserve-aggregate=all --scalarize-public-modules=false`. Also check the emitted FIRRTL — firtool emits FIRRTL text only with `--ir-fir` or `-output-final-fir`? Actually firtool by default lowers to Verilog. The issue is about the type alias in the output — likely they ran with something like `--ir-fir` after some passes, or `-preserve-aggregate` affects... Actually there's an option `--output-final-fir`? Hmm, in 2024 there was `--ir-fir` to dump the FIRRTL IR. The alias appears in "the output" — probably means the emitted FIRRTL (firtool ... --ir-fir) or the Verilog? Type aliases don't exist in Verilog. `-preserve-aggregate=all --scalarize-public-modules=false` suggests looking at Verilog output of public ports. Actually the issue title is DropConst; the pass runs in lower-to-hw path. The "type alias makes it to the output" — in hw/verilog? Hmm. With `-preserve-aggregate=all`, ports keep aggregate types and the alias could surface as a typedef in SV output. hw::TypedeclOp is created during lowering (LowerToHW.cpp:511). So the alias makes it to the output as a `typedef` in Verilog presumably.

Let me run it and see. Try:
1. `firtool const_alias.fir --ir-fir` to see FIRRTL after parsing? Actually `--ir-fir` runs the firrtl passes and dumps firrtl IR.
2. `firtool const_alias.fir --preserve-aggregate=all --scalarize-public-modules=false -o out.sv`.

Let me check what happens. Also compare with the const-dropped input variant.

[Response]
The checkout is from May 2026 — much newer than the June 2024 issue. Let me run the repro to see actual current behavior (read-only, writing test files to /tmp only).

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "mkdir -p /tmp/iss7127 && cd /tmp/iss7127 && cat > const_alias.fir <<'EOF'\nFIRRTL version 4.0.0\n\ncircuit ConstAlias:\n  type X = { a: const UInt<1> }\n  public module ConstAlias:\n    input x : X\n    output y : X\n    connect y, x\nEOF\ncat > noconst_alias.fir <<'EOF'\nFIRRTL version 4.0.0\n\ncircuit NoConstAlias:\n  type X = { a: UInt<1> }\n  public module NoConstAlias:\n    input x : X\n    output y : X\n    connect y, x\nEOF\n/workspace/circt/build/bin/firtool const_alias.fir --ir-fir -o /dev/stdout 2>&1 | head -30; echo \"=========== noconst:\"; /workspace/circt/build/bin/firtool noconst_alias.fir --ir-fir -o /dev/stdout 2>&1 | head -30"}

[Tool Result]
=========== noconst:


[Usage]
{"total": 14534, "input": 949, "output": 286, "reasoning": 627, "cache": {"write": 0, "read": 12672}, "cost_usd": 0.0022176359, "reason": "tool-calls"}

[Thinking]
Hmm, `--ir-fir` seems to have produced no output for both. Let me check firtool options. Maybe it's `--ir-fir` writes to a file or it doesn't parse? Actually `--ir-fir` is "output the FIRRTL IR" — the output is written to outputFilename. `-o /dev/stdout` should work. But there was no output at all, even for the noconst case. Let me check the exit code and stderr. Maybe version 4.0.0 FIRRTL requires... hmm, no output at all is strange. Let me run without head and check exit code.

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "cd /tmp/iss7127 && /workspace/circt/build/bin/firtool const_alias.fir --ir-fir -o const_alias.mlir; echo \"exit=$?\"; cat const_alias.mlir; echo ===noconst; /workspace/circt/build/bin/firtool noconst_alias.fir --ir-fir -o noconst.mlir; cat noconst.mlir"}

[Tool Result]
exit=0
module {
  firrtl.circuit "ConstAlias" {
    firrtl.module @ConstAlias(in %x_a: !firrtl.uint<1>, out %y_a: !firrtl.uint<1>) attributes {convention = #firrtl<convention scalarized>} {
      firrtl.matchingconnect %y_a, %x_a : !firrtl.uint<1>
    }
  }
}
===noconst
module {
  firrtl.circuit "NoConstAlias" {
    firrtl.module @NoConstAlias(in %x_a: !firrtl.uint<1>, out %y_a: !firrtl.uint<1>) attributes {convention = #firrtl<convention scalarized>} {
      firrtl.matchingconnect %y_a, %x_a : !firrtl.uint<1>
    }
  }
}


[Usage]
{"total": 14777, "input": 4622, "output": 102, "reasoning": 133, "cache": {"write": 0, "read": 9920}, "cost_usd": 0.0013355658, "reason": "tool-calls"}

[Thinking]
In the current version, the ports got scalarized ("convention scalarized" and individual ports x_a, y_a of type uint<1>). The type alias was inlined because... hmm, in this version, maybe the parser inlines the type? Wait — the port types are `!firrtl.uint<1>` — so bundle X was flattened into ports at the lowering...? No wait, the module port list shows x_a: uint<1> — that means the aggregate got exploded into suffix _a — that's the LowerTypes pass? No — `--ir-fir` dumps after FIRRTL passes including LowerTypes? Hmm, --ir-fir runs the firrtl-only pipeline which includes InferWidths, etc. Actually "convention scalarized" suggests LowerTypes ran and scalarized ports, renaming to x_a. So this dumped IR is post-LowerTypes. The type alias `X` was not preserved in either case. Hmm, but in this version, does the parser keep BaseTypeAliasType at all? Let me try to dump right after parsing: firtool -dump-fir? There's `firtool --split-verilog`... Options: `--parse-only`? Let's check `firtool --help-list | grep -i "parse\|ir-fir\|ir-hw\|ir-firrtl"`. Actually there's `--parse-only` (parse the input and emit IR? maybe `--output-final-fir`? no). Let me check options.

Also the issue's command line was `firtool const_alias.fir -preserve-aggregate=all --scalarize-public-modules=false`. Let me run the full default pipeline to SV output and see whether the alias survives as a typedef, comparing const vs no-const.

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "cd /tmp/iss7127 && /workspace/circt/build/bin/firtool const_alias.fir -preserve-aggregate=all --scalarize-public-modules=false -o /dev/stdout; echo \"===== noconst:\"; /workspace/circt/build/bin/firtool noconst_alias.fir -preserve-aggregate=all --scalarize-public-modules=false -o /dev/stdout"}

[Tool Result]
===== noconst:


[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "/workspace/circt/build/bin/firtool --help-list-hidden 2>/dev/null | grep -iE \"parse-only|ir-fir|lower-types|preserve\" "}

[Tool Result]
      --parse-only                                              - Emit FIR dialect after parsing, verification, and annotation lowering
      --ir-fir                                                  - Emit FIR dialect after pipeline
  --preserve-aggregate=<value>                               - Specify input file format:
    =none                                                    -   Preserve no aggregate
    =1d-vec                                                  -   Preserve only 1d vectors of ground type
    =vec                                                     -   Preserve only vectors
    =all                                                     -   Preserve vectors and bundles
  --preserve-values=<value>                                  - Specify the values which can be optimized away
    =strip                                                   -   Strip all names. No name is preserved
    =none                                                    -   Names could be preserved by best-effort unlike `strip`
    =named                                                   -   Preserve values with meaningful names
    =all                                                     -   Preserve all values


[Usage]
{"total": 15482, "input": 240, "output": 157, "reasoning": 365, "cache": {"write": 0, "read": 14720}, "cost_usd": 0.001761784, "reason": "tool-calls"}

[Thinking]
The default output was empty (no Verilog?). Because output format — firtool defaults to writing `.sv` files; with `-o /dev/stdout`... Hmm, no output at all. Maybe need `--format=fir`? Actually default output is Verilog. Hmm, empty output? Let me check with `-o out.sv` and see the file. Also, both const and noconst produce identical result presumably.

The important comparison: `--parse-only` to see the IR right after parsing, then run `circt-opt` with the DropConst pass on the parsed IR to see how the type alias changes.

Let me do that.

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "cd /tmp/iss7127 && /workspace/circt/build/bin/firtool const_alias.fir --parse-only -o parsed.mlir && cat parsed.mlir; echo \"===== dropconst via circt-opt:\"; /workspace/circt/build/bin/circt-opt --firrtl-drop-const parsed.mlir -o dropconst.mlir && cat dropconst.mlir"}

[Tool Result]
module {
  firrtl.circuit "ConstAlias" {
    firrtl.module @ConstAlias(in %x: !firrtl.alias<X, bundle<a: const.uint<1>>>, out %y: !firrtl.alias<X, bundle<a: const.uint<1>>>) attributes {convention = #firrtl<convention scalarized>} {
      firrtl.matchingconnect %y, %x : !firrtl.alias<X, bundle<a: const.uint<1>>>
    }
  }
}
===== dropconst via circt-opt:
module {
  firrtl.circuit "ConstAlias" {
    firrtl.module @ConstAlias(in %x: !firrtl.bundle<a: uint<1>>, out %y: !firrtl.bundle<a: uint<1>>) attributes {convention = #firrtl<convention scalarized>} {
      firrtl.matchingconnect %y, %x : !firrtl.bundle<a: uint<1>>
    }
  }
}



[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "cd /tmp/iss7127 && /workspace/circt/build/bin/firtool const_alias.fir -preserve-aggregate=all --scalarize-public-modules=false -o const_alias.sv; ls -la const_alias.sv 2>/dev/null; cat const_alias.sv 2>/dev/null; echo \"=== noconst:\"; /workspace/circt/build/bin/firtool noconst_alias.fir -preserve-aggregate=all --scalarize-public-modules=false -o noconst.sv && cat noconst.sv"}

[Tool Result]
-rw-r--r-- 1 root root 155 Oct 27 22:02 const_alias.sv
// Generated by CIRCT 5dc7f10
module ConstAlias(
  input  struct packed {logic a; } x,
  output struct packed {logic a; } y
);

  assign y = x;
endmodule

=== noconst:
// Generated by CIRCT 5dc7f10
`ifndef _TYPESCOPE_NoConstAlias__TYPESCOPE_
`define _TYPESCOPE_NoConstAlias__TYPESCOPE_
  typedef struct packed {logic a; } X;
`endif // _TYPESCOPE_NoConstAlias__TYPESCOPE_
module NoConstAlias(
  input  X x,
  output X y
);

  assign y = x;
endmodule



[Usage]
{"total": 16027, "input": 238, "output": 230, "reasoning": 135, "cache": {"write": 0, "read": 15424}, "cost_usd": 0.0015903498, "reason": "tool-calls"}

[Thinking]
Excellent — I've reproduced the exact issue behavior in the current checkout:

- **With const** (`type X = { a: const UInt<1> }`): the alias `X` is lost after DropConst — the port type becomes `!firrtl.bundle<a: uint<1>>` (alias stripped), and the Verilog output uses an anonymous `struct packed {logic a;}` instead of the typedef `X`.
- **Without const**: the alias survives — Verilog emits `typedef struct packed {logic a;} X;` and ports `input X x`.

So the repro holds in this checkout. The alias is dropped because `BaseTypeAliasType::getModifiedType()` returns the bare type when the modification changes the inner type (i.e., `getAllConstDroppedType` on the inner type produces a different type, so the alias is discarded).

Now: is this a "bug"? Let me consider.

The output is semantically correct (behaviorally equivalent hardware); the alias (a purely cosmetic naming construct) is lost. The issue is titled "Preserve alias?" with a question mark. The reporter (dtzSiFive, a CIRCT maintainer) says: "Arguably the type name shouldn't be preserved if mutating it (dropping const), but since that's unrepresentable thereafter (as well as in the lowered/output) there seems to be a reasonable case for keeping the type alias but without the const bits. Low-priority as I don't think `const` is used but FYI."

This is clearly a design question / enhancement request, not a defect: the code behaves correctly in the sense that no miscompile, no crash, no wrong hardware, no invalid IR results. The behavior is that a name hint (type alias) is dropped when the aliased type must be rewritten. The reporter explicitly hedges: "Arguably the type name shouldn't be preserved if mutating it (dropping const)... there seems to be a reasonable case for keeping the type alias but without the const bits." — i.e., the expected behavior is itself the open question: should the alias be preserved with the const bits removed (mutating the declared type), or should it be dropped (current behavior, which is arguably the conservative-correct choice since the alias name X was declared to denote a type WITH const, and that type is no longer representable)?

Note: keeping the alias but dropping const would change the alias's meaning — the alias `X` was defined as `{a: const UInt<1>}`; after DropConst, there's no const, so the alias would denote a different type. That's exactly what the current implementation declines to do, deliberately (see `getModifiedType`'s comment: "If a given `newInnerType` is identical to innerType, return `*this` because we can reuse the type alias. Otherwise return `newInnerType`" — i.e., the alias is intentionally dropped whenever the type would be modified). This is a deliberate design decision implemented in BaseTypeAliasType::getModifiedType, shared by all modifications (not just const-dropping) — e.g., `getConstType`, `getAllConstDroppedType`, etc.

Also of note: the FIRRTL spec — do aliases have any semantic meaning? They are a naming nicety; the spec (2024+) allows type aliases; there's no requirement that lowering preserve them. The FIRRTL spec says aliases are "type aliases" that can be used interchangeably; whether the tool preserves the alias name in output is a quality-of-implementation issue.

Additionally, in this 2026 checkout, does `DropConst` leave the IR invalid? Let's check: after `--firrtl-drop-const`, the module ports are `!firrtl.bundle<a: uint<1>>` — valid. The hw lowering then produces anonymous struct. Everything valid. So there's no illegal IR, no miscompile, no crash. Output hardware is identical in semantics to the no-const case except for the lost typedef/name.

So Part A: Is this a bug? The observable difference is purely cosmetic/naming: `typedef` and port type naming in output. The output is correct hardware. This is an enhancement request about name preservation ("Preserve alias?" with a question mark, "Low-priority", "FYI"). The correct behavior is unsettled — the reporter themselves presents two defensible options: (a) drop the alias when mutated (current behavior — what happens now), (b) keep the alias but strip const bits. The reporter explicitly says "Arguably the type name shouldn't be preserved if mutating it" — i.e., current behavior is defensible — and then "there seems to be a reasonable case for keeping the type alias but without the const bits". So both options are presented by the reporter as defensible. Nothing in the spec mandates preservation. This is a feature request / design question, not a defect.

So Part A answer: NOT_A_BUG. It's a feature request/design question about preserving a cosmetic alias name. The behavior is intentional (see BaseTypeAliasType::getModifiedType which deliberately returns the unaliased type when the type would change) and the output remains semantically correct.

Even if one were to call the lost alias a "bug" (wrong output in the sense of lost name fidelity), Part B's "correct behavior" is clearly unclear: keep alias vs drop alias is exactly the design decision the reporter poses as a question. The issue is titled "Preserve alias?" — literally a question.

Given Part A says "If it is not a bug, STOP and report NOT_A_BUG", I should report NOT_A_BUG. The behavior is: semantically correct output, alias intentionally dropped when its aliased type is mutated (implemented via BaseTypeAliasType::getModifiedType which conservatively drops the alias rather than mutating its meaning). The issue is an open design question / potential enhancement request, explicitly marked low-priority by the reporter, with the expected behavior itself left open ("Arguably the type name shouldn't be preserved... there seems to be a reasonable case for keeping").

Let me double check one more thing: is there any incorrect IR emitted in a different scenario — e.g., does DropConst leave a dangling typedecl/alias decl referencing const while uses have const dropped, causing verifier failures? In this version, FIRRTL-side BaseTypeAliasType is uniqued in the context, not an op; so no dangling op issue. In the full pipeline, DropConst runs... wait, is DropConst even in the default pipeline? The `-preserve-aggregate=all` run above shows the const variant output `struct packed {logic a;}` directly — consistent with alias dropped. Everything is valid.

Also verify that the no-const case keeps the alias through hw lowering — yes, it emitted typedef X. So behavior matches the issue report exactly: the alias survives without const, is lost with const.

One more consideration: could this be considered "wrong output" in the sense that the alias should be preserved per the FIRRTL spec's output requirements? Check docs: FIRRTL spec says nothing about tools being required to preserve type aliases in output. The CIRCT FIRRTL dialect docs / FIRToText emitter has "TODO: Emit type decl for type alias" — actually in this version the emitter doesn't even emit type decls, so aliases never survive to exported FIRRTL text anyway; they only survive into hw::Typedecl for SV output. So the alias preservation is purely cosmetic in SV output as a typedef name.

Conclusion: NOT_A_BUG. It's a design question/enhancement request about name (type alias) preservation under type-mutating transforms. Behavior is intentional (getModifiedType drops alias when modified), the resulting hardware is semantically identical, and the issue itself poses the desired behavior as an open question with two defensible resolutions. Even under Part B, this would be UNCLEAR, but Part A gates: not a bug → NOT_A_BUG.

Let me write the decision with the evidence:
- Repro confirmed current behavior: alias dropped, hardware output correct.
- Code: BaseTypeAliasType::getModifiedType deliberately returns the unaliased type when a modification changes the aliased type (lib/Dialect/FIRRTL/FIRRTLTypes.cpp:2474-2483), so DropConst (lib/Dialect/FIRRTL/Transforms/DropConst.cpp) strips const and the alias is intentionally not re-attached.
- The issue is titled with a question mark; the reporter lays out two defensible resolutions and marks it low priority, FYI.

Now write the final answer with the footer:

DECISION: NOT_A_BUG
REASON: ...

Format: end response with exactly:

DECISION: NOT_A_BUG
REASON: <1-3 sentences>

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "sed -n 2470,2490p /workspace/circt/lib/Dialect/FIRRTL/FIRRTLTypes.cpp; echo \"=== git log for DropConst/alias behavior:\"; git log --oneline --all -S \"getModifiedType\" -- lib/Dialect/FIRRTL/FIRRTLTypes.cpp | head; echo \"=== does DropConst touch typedecl/alias decls?\"; grep -n \"Typedecl\\|alias\" /workspace/circt/lib/Dialect/FIRRTL/Transforms/DropConst.cpp"}

[Tool Result]

// If a given `newInnerType` is identical to innerType, return `*this`
// because we can reuse the type alias. Otherwise return `newInnerType`.
FIRRTLBaseType
BaseTypeAliasType::getModifiedType(FIRRTLBaseType newInnerType) const {
  if (newInnerType == getInnerType())
    return *this;
  return newInnerType;
}

// FieldIDTypeInterface implementation.
FIRRTLBaseType BaseTypeAliasType::getAllConstDroppedType() {
  return getModifiedType(getInnerType().getAllConstDroppedType());
}

FIRRTLBaseType BaseTypeAliasType::getConstType(bool isConst) const {
  return getModifiedType(getInnerType().getConstType(isConst));
}

std::pair<Type, uint64_t>
BaseTypeAliasType::getSubTypeByFieldID(uint64_t fieldID) const {
=== git log for DropConst/alias behavior:
5dc7f10 [Synth] Move three-input op boilerplate to ODS (#10540)
=== does DropConst touch typedecl/alias decls?

[exit code: 1]

[Tool Call: bash_7127_bash_7127_run_command]
Args: {"command": "cd /tmp/iss7127 && /workspace/circt/build/bin/firtool noconst_alias.fir --parse-only -o /dev/stdout && /workspace/circt/build/bin/circt-opt --firrtl-drop-const /dev/stdin < /dev/null 2>/dev/null; echo ---; /workspace/circt/build/bin/firtool noconst_alias.fir --parse-only -o noconst_parsed.mlir && /workspace/circt/build/bin/circt-opt --firrtl-drop-const noconst_parsed.mlir | grep -o \"alias<[^\\\"]*>\" | sort -u"}

[Tool Result]
module {
}

---
alias<X, bundle<a: uint<1>>>
alias<X, bundle<a: uint<1>>>, out %y: !firrtl.alias<X, bundle<a: uint<1>>>) attributes {convention = #firrtl<convention scalarized>


[Response]
Now I can see the exact behavior in this checkout. Let me confirm the root cause in the source: `BaseTypeAliasType::getModifiedType` (lib/Dialect/FIRRTL/FIRRTLTypes.cpp:2474-2483).

[Usage]
{"total": 18556, "input": 400, "output": 339, "reasoning": 1817, "cache": {"write": 0, "read": 16000}, "cost_usd": 0.00414876, "reason": "tool-calls"}

[Thinking]
The behavior is fully confirmed:

1. With const in the aliased type: `!firrtl.alias<X, bundle<a: const.uint<1>>>` → after DropConst → `!firrtl.bundle<a: uint<1>>` — the alias `X` is stripped because `getModifiedType` deliberately returns the bare (unaliased) new inner type when the modification changes the aliased type.
2. Without const: the alias `X` survives DropConst, lowers to an `hw::Typedecl`, and emits a `typedef ... X` in Verilog.
3. The resulting hardware is semantically identical either way (the const case just loses the `X` typedef/name in the output — anonymous `struct packed {logic a;}`).

This is intentional, documented-by-code design: `getModifiedType`'s comment explicitly says the alias is reused only when the modified type is identical; otherwise the unaliased type is returned. The alias name denotes the *declared* type (with const); once the type is mutated, reusing the name would silently change its meaning, so the alias is dropped.

The issue: "Preserve alias?" — question mark. Reporter (a CIRCT maintainer) frames it as a discussion ("Arguably the type name shouldn't be preserved if mutating it (dropping const), but ... there seems to be a reasonable case for keeping the type alias but without the const bits"), explicitly "Low-priority ... but FYI". This is a feature request / design question, not a defect: no crash, no wrong hardware, no invalid IR, only a cosmetic loss of a typedef name in the output.

Per Part A: not a bug → NOT_A_BUG. The correct behavior is precisely the open design question the issue poses (preserve alias minus const bits vs. drop alias). Both are defensible; the current code chose one deliberately.

I'm confident in NOT_A_BUG. Write it up.

[Response]
I have all the evidence I need. Let me summarize the investigation:

**What the issue describes and what the code does:**

- Reproduced on the current checkout (`firtool` @ `5dc7f10`): with `type X = { a: const UInt<1> }`, after parsing the port type is `!firrtl.alias<X, bundle<a: const.uint<1>>>`; after DropConst it becomes plain `!firrtl.bundle<a: uint<1>>` and Verilog output has anonymous `struct packed {logic a;}` ports. Editing `const` out of the source yields `typedef ... X;` and ports `input X x`.
- Root cause: `BaseTypeAliasType::getModifiedType()` in `lib/Dialect/FIRRTL/FIRRTLTypes.cpp:2474` deliberately returns the **unaliased** type whenever a type modification changes the aliased type ("If a given `newInnerType` is identical to innerType, return `*this` because we can reuse the type alias. Otherwise return `newInnerType`"). DropConst calls `getAllConstDroppedType()`, so an alias whose aliased type contains `const` is intentionally shed rather than mutated in place.
- The resulting IR and hardware are semantically correct — the loss is purely the cosmetic typedef/alias name in the output. No crash, no invalid IR, no miscompile; the FIRRTL spec imposes no requirement to preserve type aliases through transforms, and the emitter itself doesn't emit FIRRTL type decls at all ("TODO: Emit type decl for type alias" in `FIREmitter.cpp`).

**Assessment:** This is a design question / enhancement request, not a defect. The issue title is literally "Preserve alias?" and the reporter lays out both defensible resolutions themselves ("Arguably the type name shouldn't be preserved if mutating it (dropping const), but ... there seems to be a reasonable case for keeping the type alias but without the const bits"), flags it "Low-priority ... FYI". The code's behavior (drop the alias when its type is mutated, rather than silently redefine the name to a different type) is a deliberate, commented design choice; output remains semantically identical.

DECISION: NOT_A_BUG
REASON: This is a design question/feature request about cosmetic name fidelity, not a defect: DropConst's alias-stripping via `BaseTypeAliasType::getModifiedType` (which deliberately sheds an alias whenever its aliased type is modified) is intentional and the emitted hardware is semantically identical — only the typedef name is lost. The issue itself poses the desired behavior as an open question with two defensible answers (keep the alias minus const vs. drop it, as today), so there is no unambiguous "correct behavior" to implement.

[Usage]
{"total": 19847, "input": 363, "output": 583, "reasoning": 405, "cache": {"write": 0, "read": 18496}, "cost_usd": 0.0026829481, "reason": "stop"}

[Result]
{"num_turns": 16, "input_tokens": 24496, "output_tokens": 3068, "reasoning_tokens": 7359, "cache_read": 154496, "cache_write": 0, "cost_usd": 0.026954844800000002}

