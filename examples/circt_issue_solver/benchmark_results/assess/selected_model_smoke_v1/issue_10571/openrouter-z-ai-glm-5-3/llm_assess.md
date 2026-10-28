[Thinking]
Investigate the AggregateToComb pass for unions. Quick grep.

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && ls lib/Conversion/ && grep -n \"union\" lib/Conversion/AggregateToComb/*.cpp | head -50"}

[Tool Result]
AffineToLoopSchedule
ArcToLLVM
CFToHandshake
CMakeLists.txt
CalyxNative
CalyxToFSM
CalyxToHW
CombToArith
CombToDatapath
CombToLLVM
CombToSMT
CombToSynth
ConvertToArcs
ConvertToLLVM
CoreToFSM
DCToHW
DatapathToComb
DatapathToSMT
ExportAIGER
ExportVerilog
FIRRTLToHW
FSMToCore
FSMToSMT
FSMToSV
HWArithToHW
HWToBTOR2
HWToLLVM
HWToSMT
HWToSV
HWToSystemC
HandshakeToDC
HandshakeToHW
ImportAIGER
ImportLiberty
ImportVerilog
LTLToCore
LoopScheduleToCalyx
MooreToCore
PipelineToHW
SCFToCalyx
SMTToZ3LLVM
SeqToSV
SimToSV
SynthToComb
Utils
VerifToSMT
VerifToSV

STDERR:
grep: lib/Conversion/AggregateToComb/*.cpp: No such file or directory


[Usage]
{"total": 3000, "input": 2935, "output": 0, "reasoning": 65, "cache": {"write": 0, "read": 0}, "cost_usd": 0.0002961565, "reason": "tool-calls"}

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && grep -rln \"aggregate-to-comb\\|AggregateToComb\" lib include tools | head"}

[Tool Result]
lib/Dialect/HW/Transforms/HWAggregateToComb.cpp
lib/Dialect/HW/Transforms/CMakeLists.txt
lib/Dialect/Synth/Analysis/LongestPathAnalysis.cpp
lib/Dialect/Synth/Transforms/SynthesisPipeline.cpp
lib/Conversion/CombToSynth/CombToSynth.cpp
include/circt/Dialect/HW/Passes.td
include/circt/Dialect/Synth/Analysis/LongestPathAnalysis.h


[Usage]
{"total": 3317, "input": 326, "output": 47, "reasoning": 0, "cache": {"write": 0, "read": 2944}, "cost_usd": 0.000291429, "reason": "tool-calls"}

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && grep -n \"union\\|UnionType\\|StructType\" lib/Dialect/HW/Transforms/HWAggregateToComb.cpp | head -40 && wc -l lib/Dialect/HW/Transforms/HWAggregateToComb.cpp"}

[Tool Result]
197:    auto structType = cast<hw::StructType>(op.getInput().getType());
249:    addConversion([](hw::StructType t) -> Type {
311 lib/Dialect/HW/Transforms/HWAggregateToComb.cpp


[Usage]
{"total": 3499, "input": 158, "output": 77, "reasoning": 0, "cache": {"write": 0, "read": 3264}, "cost_usd": 0.0003437338, "reason": "tool-calls"}

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && sed -n 150,300p lib/Dialect/HW/Transforms/HWAggregateToComb.cpp"}

[Tool Result]
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
    auto arrayGetOp =
        hw::ArrayGetOp::create(rewriter, loc, array2D, adaptor.getIndex());

    rewriter.replaceOp(op, arrayGetOp);
    return success();
  }
};

struct HWStructCreateOpConversion : OpConversionPattern<hw::StructCreateOp> {
  using OpConversionPattern<hw::StructCreateOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(hw::StructCreateOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    // Lower struct_create to comb.concat. The first field occupies the MSBs, so
    // we concatenate fields in order (comb.concat places first operand at MSB).
    rewriter.replaceOpWithNewOp<comb::ConcatOp>(op, adaptor.getInput());
    return success();
  }
};

struct HWStructExtractOpConversion : OpConversionPattern<hw::StructExtractOp> {
  using OpConversionPattern<hw::StructExtractOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(hw::StructExtractOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto structType = cast<hw::StructType>(op.getInput().getType());
    auto fieldIndex = op.getFieldIndex();
    auto elements = structType.getElements();

    int64_t totalBitWidth = hw::getBitWidth(str
... [truncated]

[Usage]
{"total": 3606, "input": 101, "output": 49, "reasoning": 0, "cache": {"write": 0, "read": 3456}, "cost_usd": 0.0003137783, "reason": "tool-calls"}

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && sed -n 300,311p lib/Dialect/HW/Transforms/HWAggregateToComb.cpp && sed -n 180,200p lib/Dialect/HW/Transforms/HWAggregateToComb.cpp && grep -rn \"union_create\\|union_extract\\|UnionType\" include/circt/Dialect/HW/HWOps.td | head"}

[Tool Result]
  target.addDynamicallyLegalOp<comb::MuxOp>(
      [](comb::MuxOp op) { return hw::type_isa<IntegerType>(op.getType()); });
  target.addLegalDialect<hw::HWDialect, comb::CombDialect>();

  RewritePatternSet patterns(&getContext());
  AggregateTypeConverter typeConverter;
  populateHWAggregateToCombOpConversionPatterns(patterns, typeConverter);

  if (failed(mlir::applyPartialConversion(getOperation(), target,
                                          std::move(patterns))))
    return signalPassFailure();
}

  LogicalResult
  matchAndRewrite(hw::StructCreateOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    // Lower struct_create to comb.concat. The first field occupies the MSBs, so
    // we concatenate fields in order (comb.concat places first operand at MSB).
    rewriter.replaceOpWithNewOp<comb::ConcatOp>(op, adaptor.getInput());
    return success();
  }
};

struct HWStructExtractOpConversion : OpConversionPattern<hw::StructExtractOp> {
  using OpConversionPattern<hw::StructExtractOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(hw::StructExtractOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto structType = cast<hw::StructType>(op.getInput().getType());
    auto fieldIndex = op.getFieldIndex();
    auto elements = structType.getElements();



[Usage]
{"total": 5098, "input": 1410, "output": 104, "reasoning": 0, "cache": {"write": 0, "read": 3584}, "cost_usd": 0.0004910966, "reason": "tool-calls"}

[Thinking]
Confirmed root cause: type converter only converts ArrayType and StructType to integers; UnionType isn't converted, so mux on unions stays illegal (dynamically legal check requires IntegerType). Union create/extract ops exist? Check whether hw dialect has union_create/union_extract ops.

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && grep -n \"Union\" include/circt/Dialect/HW/HWOps.td | head -20 && grep -rn \"union_create\\|union_extract\" lib/Dialect/HW/Transforms/HWAggregateToComb.cpp; grep -n \"union\" include/circt/Dialect/HW/HWAggregateToComb* 2>/dev/null"}

[Tool Result]

[exit code: 2]

[Usage]
{"total": 5573, "input": 358, "output": 0, "reasoning": 159, "cache": {"write": 0, "read": 5056}, "cost_usd": 0.0005959826, "reason": "tool-calls"}

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && grep -rn \"UnionType\" include/circt/Dialect/HW/*.td include/circt/Dialect/HW/HWDialect.h 2>/dev/null | head; grep -rln \"union_create\\|UnionCreate\" include/circt lib/Dialect/HW lib/Dialect/SVT 2>/dev/null | head"}

[Tool Result]
include/circt/Dialect/HW/HWAggregates.td:356:  let results = (outs UnionType:$result);
include/circt/Dialect/HW/HWAggregates.td:370:      UnionType type = getType();
include/circt/Dialect/HW/HWAggregates.td:397:  let arguments = (ins UnionType:$input, I32Attr:$fieldIndex);
include/circt/Dialect/HW/HWAggregates.td:411:      UnionType type = getInput().getType();
include/circt/Dialect/HW/HWTypes.td:62:// A handle to refer to circt::hw::UnionType in ODS.
include/circt/Dialect/HW/HWTypes.td:63:def UnionType : DialectType<HWDialect,
include/circt/Dialect/HW/HWTypes.td:64:    CPred<"::circt::hw::type_isa<circt::hw::UnionType>($_self)">,
include/circt/Dialect/HW/HWTypes.td:65:          "a UnionType", "::circt::hw::TypeAliasOr<::circt::hw::UnionType>">;
include/circt/Dialect/HW/HWTypesImpl.td:199:// An untagged union. Declares the hw::UnionType in C++.
include/circt/Dialect/HW/HWTypesImpl.td:200:def UnionTypeImpl : HWType<"Union", [
include/circt/Dialect/Moore/MooreOps.td
include/circt/Dialect/HW/HWAggregates.td
include/circt/Dialect/HW/HWVisitors.h
lib/Dialect/HW/HWOps.cpp
lib/Dialect/HW/HWDialect.cpp


[Usage]
{"total": 5682, "input": 17, "output": 97, "reasoning": 0, "cache": {"write": 0, "read": 5568}, "cost_usd": 0.0005206235, "reason": "tool-calls"}

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && sed -n 340,420p include/circt/Dialect/HW/HWAggregates.td"}

[Tool Result]
// Union operations
//===----------------------------------------------------------------------===//

def UnionCreateOp : HWOp<"union_create", [Pure]> {
  let summary = "Create a union with the specified value.";
  let description = [{
    Create a union with the value 'input', which can then be accessed via the
    specified field.

    ```
      %x = hw.constant 0 : i3
      %z = hw.union_create "bar", %x : !hw.union<bar: i3, baz: i8>
    ```
  }];

  let arguments = (ins I32Attr:$fieldIndex, HWNonInOutType:$input);
  let results = (outs UnionType:$result);
  let hasCustomAssemblyFormat = 1;
  let hasVerifier = 1;

  let builders = [
    OpBuilder<(ins "Type":$unionType, "StringAttr":$fieldName, "Value":$input)>,
    OpBuilder<(ins "Type":$unionType, "StringRef":$fieldName, "Value":$input), [{
      build($_builder, $_state, unionType, $_builder.getStringAttr(fieldName), input);
    }]>
  ];

  let extraClassDeclaration = [{
    /// Return the name attribute of the accessed field.
    StringAttr getFieldNameAttr() {
      UnionType type = getType();
      return type.getElements()[getFieldIndex()].name;
    }

    /// Return the name of the accessed field.
    StringRef getFieldName() {
      return getFieldNameAttr().getValue();
    }
  }];
}

def UnionExtractOp : HWOp<"union_extract", [Pure, 
    DeclareOpInterfaceMethods<InferTypeOpInterface, ["inferReturnTypes"]>,
  ]> {
  let summary = "Get a union member.";
  let description = [{
    Get the value of a union, interpreting it as the type of the specified
    member field.  Extracting a value belonging to a different field than the
    union was initially created will result in undefined behavior.

    ```
      %u = ...
      %v = hw.union_extract %u["foo"] : !hw.union<foo: i3, bar: i16>
      // %v is of type 'i3'
    ```
  }];

  let arguments = (ins UnionType:$input, I32Attr:$fieldIndex);
  let results = (outs HWNonInOutType:$result);
  let hasCustomAssemblyFormat = 1;

  let builders = [
    OpBuilder<(in
... [truncated]

[Usage]
{"total": 6125, "input": 443, "output": 50, "reasoning": 0, "cache": {"write": 0, "read": 5632}, "cost_usd": 0.0004890105, "reason": "tool-calls"}

[Thinking]
The pass has conversions for struct create/extract but not union_create/union_extract, and the type converter doesn't convert UnionType. So mux on unions fails to legalize. This is a genuine defect? Is it a "missing feature"? The pass explicitly converts aggregate types; unions are aggregate types; comb.mux on union is well-formed IR (verifier allows it?). The pass errors out with "failed to legalize" — a valid input causes a hard failure. But maintainers' comment says "It's not simply implemented 👍 Please feel free to implement" — an unimplemented feature that results in a pass failure on valid IR.

Is this a BUG or a feature request? The pass crashes/errs on valid IR. Typically classified as a bug (unimplemented feature causing legalization failure on valid input). Correct behavior: extend the pass to handle UnionType — bitcast + mux on integer, or convert union ops. But is the correct behavior clear? The pass lowers aggregates to integers; unions have a bit width (union of field widths, max). The natural fix: add UnionType conversion in type converter (like StructType → IntegerType of bitwidth) and conversions for union_create/union_extract. But union_extract semantics: extracting a field from union is a bitcast/truncation — union bit layout? UnionType width = max field width. union_create zero-extends (or bitcasts) input to union width; union_extract extracts low bits. Actually comment by uenoku: "insert bitcast hw.union, and construct union_extract/create based on the bit layout" — suggests intended fix is different (bitcast unions, keep union ops?). Hmm, that suggests design choice ambiguity.

But wait — the key question for Part A: is it a bug? The input is valid IR (comb.mux of unions). The pass errors "explicitly marked illegal" — the pass was simply never taught unions. Maintainer says "not simply implemented" — i.e., a missing feature. Missing feature that causes hard failure on valid input... The prompt says bug is "a crash, assertion, miscompile..." vs "a feature request or enhancement". An unimplemented case in a pass that then errors is typically considered a bug in automated triage contexts (valid input → error). But maintainers explicitly framed it as "not simply implemented — feel free to implement" = feature request. Hmm.

The more decisive issue: PART B. Correct behavior: unions are bit-ambiguous — UnionType bit width? Check hw::getBitWidth for UnionType.

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && grep -n \"UnionType\" lib/Dialect/HW/HWTypes.cpp | head -20 && grep -rn \"UnionType\" lib/Dialect/HW/HWAggregates.cpp | head"}

[Tool Result]
95:  if (auto t = dyn_cast<UnionType>(type))
433:Type UnionType::parse(AsmParser &p) {
458:            parameters.push_back(UnionType::FieldInfo{
470:void UnionType::print(AsmPrinter &odsPrinter) const {
473:      getElements(), odsPrinter, [&](const UnionType::FieldInfo &field) {
481:LogicalResult UnionType::verify(function_ref<InFlightDiagnostic()> emitError,
482:                                ArrayRef<UnionType::FieldInfo> elements) {
495:std::optional<uint32_t> UnionType::getFieldIndex(mlir::StringAttr fieldName) {
496:  ArrayRef<hw::UnionType::FieldInfo> elems = getElements();
503:std::optional<uint32_t> UnionType::getFieldIndex(mlir::StringRef fieldName) {
507:UnionType::FieldInfo UnionType::getFieldInfo(::mlir::StringRef fieldName) {
513:Type UnionType::getFieldType(mlir::StringRef fieldName) {
517:std::optional<int64_t> UnionType::getBitWidth() const {

STDERR:
grep: lib/Dialect/HW/HWAggregates.cpp: No such file or directory


[Usage]
{"total": 7353, "input": 688, "output": 0, "reasoning": 585, "cache": {"write": 0, "read": 6080}, "cost_usd": 0.0012860032, "reason": "tool-calls"}

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && sed -n 515,525p lib/Dialect/HW/HWTypes.cpp && git log --oneline -3 -- lib/Dialect/HW/Transforms/HWAggregateToComb.cpp"}

[Tool Result]
}

std::optional<int64_t> UnionType::getBitWidth() const {
  int64_t maxSize = 0;
  for (auto field : getElements()) {
    int64_t fieldSize = hw::getBitWidth(field.type);
    if (fieldSize < 0)
      return std::nullopt;
    fieldSize += field.offset;
    if (fieldSize > maxSize)
      maxSize = fieldSize;
5dc7f10 [Synth] Move three-input op boilerplate to ODS (#10540)


[Usage]
{"total": 7690, "input": 325, "output": 69, "reasoning": 0, "cache": {"write": 0, "read": 7296}, "cost_usd": 0.0006220119, "reason": "tool-calls"}

[Thinking]
So union width is defined. The pass just doesn't handle UnionType. Is this a bug or feature request? The pass, applied to valid IR containing unions, fails with a legalization error. The pass is intended to lower all hw aggregate types (docs?). Check pass doc in Passes.td.

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && grep -B2 -A15 \"HWAggregateToComb\" include/circt/Dialect/HW/Passes.td"}

[Tool Result]
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


[Usage]
{"total": 7919, "input": 125, "output": 0, "reasoning": 114, "cache": {"write": 0, "read": 7680}, "cost_usd": 0.0006974895, "reason": "tool-calls"}

[Thinking]
Analysis: The pass is meant to lower aggregate operations. Unions are aggregates in HW dialect, and `comb.mux` over union types is legal IR (op verifier allows any type? comb.mux requires same types, works). The pass marks mux illegal unless integer type, then fails to legalize union-typed mux because the type converter lacks a UnionType conversion and union_create/union_extract conversions. So valid IR → pass failure.

Part A: Is this a bug or feature request? The maintainers said "not simply implemented" — i.e., an unimplemented feature. However, the practical effect: valid input errors out. Per typical triage of this pipeline: unimplemented case that produces a hard error on valid IR is a defect (missing functionality = bug in coverage). But the pipeline distinguishes "feature request or enhancement" from bug. Here the issue is literally asking "is this a bug or should I do something different" and maintainer says implement it — it's a missing-feature request in a pass.

The stronger gate is Part B: correct behavior clear? The maintainer's hint "insert bitcast hw.union, and construct union_extract/create based on the bit layout" — actually that reads as: bitcast the union to an integer? "insert bitcast hw.union" — ambiguous. Options for fix:
1. Add UnionType → IntegerType conversion in type converter + union_create/union_extract conversions (extend, mirroring struct handling). Then mux on union legalizes via type converter automatically.
2. Keep unions as-is (bitcast union to int via hw.bitcast) and make mux legal on unions.

Union bit layout: fields have offsets (union of widths, offset?). Let me check field offset — union fields have `offset`. Struct extract uses MSB-first; union_extract semantics differ (fields overlap). union_create zero-extends? Check union_create verifier/custom format... In FIRRTL lowerings, union_create bitcasts/truncates the input into union width. The lowering to comb would be: union_create → zext/bitcast input to union-width integer; union_extract → extract low bits of field width (truncation), which is well-defined (fields at offset 0?). Check offset assignment.

[Tool Call: bash_10571_bash_10571_run_command]
Args: {"command": "cd /workspace/circt && sed -n 433,500p lib/Dialect/HW/HWTypes.cpp"}

[Tool Result]
Type UnionType::parse(AsmParser &p) {
  llvm::SmallVector<FieldInfo, 4> parameters;
  llvm::StringSet<> nameSet;
  bool hasDuplicateName = false;
  if (p.parseCommaSeparatedList(
          mlir::AsmParser::Delimiter::LessGreater, [&]() -> ParseResult {
            StringRef name;
            Type type;

            auto fieldLoc = p.getCurrentLocation();
            if (p.parseKeyword(&name) || p.parseColon() || p.parseType(type))
              return failure();

            if (!nameSet.insert(name).second) {
              p.emitError(fieldLoc, "duplicate field name \'" + name +
                                        "\' in hw.union type");
              // Continue parsing to print all duplicates, but make sure to
              // error eventually
              hasDuplicateName = true;
            }

            size_t offset = 0;
            if (succeeded(p.parseOptionalKeyword("offset")))
              if (p.parseInteger(offset))
                return failure();
            parameters.push_back(UnionType::FieldInfo{
                StringAttr::get(p.getContext(), name), type, offset});
            return success();
          }))
    return Type();

  if (hasDuplicateName)
    return Type();

  return get(p.getContext(), parameters);
}

void UnionType::print(AsmPrinter &odsPrinter) const {
  odsPrinter << '<';
  llvm::interleaveComma(
      getElements(), odsPrinter, [&](const UnionType::FieldInfo &field) {
        odsPrinter << field.name.getValue() << ": " << field.type;
        if (field.offset)
          odsPrinter << " offset " << field.offset;
      });
  odsPrinter << ">";
}

LogicalResult UnionType::verify(function_ref<InFlightDiagnostic()> emitError,
                                ArrayRef<UnionType::FieldInfo> elements) {
  llvm::SmallDenseSet<StringAttr> fieldNameSet;
  LogicalResult result = success();
  fieldNameSet.reserve(elements.size());
  for (const auto &elt : elements)
    if (!fieldNameSet.insert(elt.name).second) {
      result = failure(
... [truncated]

[Usage]
{"total": 8584, "input": 214, "output": 0, "reasoning": 498, "cache": {"write": 0, "read": 7872}, "cost_usd": 0.0012545394, "reason": "tool-calls"}

[Thinking]
So union fields can have offsets. A comb lowering would need to handle offsets — union_create: place input bits at offset, union_extract: extract at offset. That's implementable but the design choice of how the pass should handle it (extend the type converter like structs vs. bitcast approach) is somewhat open, and importantly the maintainers explicitly labeled this as "not simply implemented" — a feature request / unimplemented enhancement, not a defect in existing behavior. The pass works as designed for its implemented scope (arrays, structs); unions were never claimed to be supported (there's even a "TODO: Add ArraySliceOp and struct operations as well").

Also the input's validity: comb.mux on union types — is that even accepted/used in practice? It parses fine. But the pass fails, which is a hard error on IR the pass wasn't designed for.

Per the prompt's Part A: "It is NOT a bug if it is a feature request or enhancement." The maintainer's own comment confirms it's an unimplemented feature ("It's not simply implemented. Please feel free to implement."). So DECISION: NOT_A_BUG.

I could also mention Part B ambiguity anyway but footer requires one. Go with NOT_A_BUG.

[Response]
## Analysis

I investigated the `--aggregate-to-comb` pass (`lib/Dialect/HW/Transforms/HWAggregateToComb.cpp`) and the HW union infrastructure:

**What the pass supports today:**
- The type converter (`AggregateTypeConverter`) only converts `hw::ArrayType` and `hw::StructType` to integer types (lines ~249–255).
- Conversion patterns exist for `array_get/create/concat/inject`, `aggregate_constant`, `struct_create`, and `struct_extract` — but **no** patterns for `hw::UnionType`, `hw::UnionCreateOp`, or `hw::UnionExtractOp`.
- `comb::MuxOp` is only dynamically legal when its result is an `IntegerType` (`target.addDynamicallyLegalOp<comb::MuxOp>(...)`), so a mux over `!hw.union<...>` is marked illegal and then fails to legalize — exactly the error in the issue.
- The pass file itself carries a `// TODO: Add ArraySliceOp and struct operatons as well.` — unions were never in its implemented scope.

**What the issue actually is:**
The reporter's IR is well-formed and parses fine, and the pass hard-fails on it. But this is not a defect in behavior the pass claims to implement: the pass summary/docs say it lowers *aggregate operations to comb operations*, and it simply was never taught about unions. The maintainer (uenoku) confirmed this directly in the issue: *"It's not simply implemented 👍 Please feel free to implement"* — and sketched a design (bitcast `hw.union`, construct `union_extract`/`union_create` from the bit layout). That is the maintainer explicitly classifying this as an unimplemented feature / enhancement request with an invitation to contribute, not a miscompile or wrong output in existing supported functionality. Union field offsets (which `UnionType` supports via `offset N`) also mean the "correct" comb-level lowering has real design freedom (extend the type converter mirror-of-structs vs. the bitcast approach suggested in the comment), reinforcing that this is new functionality to design, not a broken invariant to restore.

Supporting evidence that structs/arrays work as intended confirms the existing pass behaves correctly for everything it was built for; only the union case is missing.

DECISION: NOT_A_BUG
REASON: This is an unimplemented feature / enhancement request, not a defect in existing behavior — the maintainer's own comment on the issue ("It's not simply implemented. Please feel free to implement") confirms the pass never claimed to support `hw.union` types. The pass works correctly for its documented scope (arrays, structs); adding union support (type-converter entry plus `union_create`/`union_extract` conversions) is new functionality to be designed, not a fix to incorrect behavior.

[Usage]
{"total": 9988, "input": 563, "output": 663, "reasoning": 186, "cache": {"write": 0, "read": 8576}, "cost_usd": 0.0018188401, "reason": "stop"}

[Result]
{"num_turns": 13, "input_tokens": 7663, "output_tokens": 1156, "reasoning_tokens": 1607, "cache_read": 67008, "cache_write": 0, "cost_usd": 0.009020694899999999}

