[Thinking]
Let me investigate the codebase.

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && grep -rn \"only supports zero or one use\" lib/ | head"}

[Tool Result]
(no output)

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && ls lib/Conversion/ 2>/dev/null; ls lib/Dialect/DC/ 2>/dev/null"}

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
CMakeLists.txt
DCDialect.cpp
DCOps.cpp
DCTypes.cpp
Transforms


[Usage]
{"total": 7569, "input": 7468, "output": 0, "reasoning": 101, "cache": {"write": 0, "read": 0}, "cost_usd": 0.0006634132, "reason": "tool-calls"}

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && grep -rn \"zero or one use\" lib/ include/ 2>/dev/null | head; ls lib/Dialect/DC/Transforms; ls lib/Conversion/DCToHW"}

[Tool Result]
CMakeLists.txt
DCMaterialization.cpp
DCPrintDot.cpp
CMakeLists.txt
DCToHW.cpp


[Usage]
{"total": 7913, "input": 293, "output": 68, "reasoning": 0, "cache": {"write": 0, "read": 7552}, "cost_usd": 0.0006360135, "reason": "tool-calls"}

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && grep -rn \"zero or one use\\|only supports\" lib/Dialect/DC/ lib/Conversion/DCToHW/ include/circt/Dialect/DC 2>/dev/null | head -20"}

[Tool Result]
(no output)

[Usage]
{"total": 8016, "input": 71, "output": 73, "reasoning": 0, "cache": {"write": 0, "read": 7872}, "cost_usd": 0.0006495437, "reason": "tool-calls"}

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && grep -rn \"wrap.vr\\|WrapVR\\|esi::.*wrap\" --include=*.cpp --include=*.td lib/ include/ | head -20"}

[Tool Result]
lib/Dialect/ESI/Passes/ESILowerToHW.cpp:226:                                         "Wrap consumer is not an unwrap.vr.");
lib/Dialect/ESI/Passes/ESILowerToHW.cpp:246:          unwrap, "unwrap.vr input must come from a wrap.vr.");
lib/Dialect/ESI/Passes/ESILowerToHW.cpp:275:          defOp, "Snoop input must be a wrap.vr operation");
lib/Dialect/ESI/Passes/ESILowerToHW.cpp:399:        "Snoop input must be a wrap.vr, wrap.fifo, or wrap.vo operation");
lib/Dialect/ESI/Passes/ESILowerToHW.cpp:429:/// Lower a `wrap.iface` to `wrap.vr` by extracting the wires then feeding the
lib/Dialect/ESI/Passes/ESILowerToHW.cpp:430:/// new `wrap.vr`.
lib/Dialect/ESI/Passes/ESILowerToHW.cpp:473:/// `unwrap.vr`.
lib/Dialect/ESI/ESIOps.cpp:194:circt::esi::ChannelType UnwrapValidReadyOp::channelType() {
lib/Dialect/ESI/ESIOps.cpp:226:circt::esi::ChannelType UnwrapFIFOOp::channelType() {
lib/Dialect/ESI/ESIOps.cpp:267:circt::esi::ChannelType UnwrapValidOnlyOp::channelType() {
lib/Dialect/ESI/ESIOps.cpp:341:circt::esi::ChannelType UnwrapSVInterfaceOp::channelType() {
lib/Conversion/HandshakeToHW/HandshakeToHW.cpp:490:    auto unwrapOp = esi::UnwrapValidReadyOp::create(b, loc, channel, ready);
lib/Conversion/DCToHW/DCToHW.cpp:249:    auto unwrapOp = esi::UnwrapValidReadyOp::create(b, loc, channel, ready);
include/circt/Dialect/ESI/ESIChannels.td:176:def WrapValidReadyOp : ESI_Op<"wrap.vr", [
include/circt/Dialect/ESI/ESIChannels.td:197:def UnwrapValidReadyOp : ESI_Op<"unwrap.vr", [


[Usage]
{"total": 8088, "input": 23, "output": 65, "reasoning": 0, "cache": {"write": 0, "read": 8000}, "cost_usd": 0.0006438077, "reason": "tool-calls"}

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && sed -n 150,230p include/circt/Dialect/ESI/ESIChannels.td && grep -rn \"wrap.vr\" lib/Dialect/ESI/*.cpp | grep -i \"verif\\|assert\" | head"}

[Tool Result]
    flow and debugging.
  }];

  let arguments = (ins ChannelType:$input);
  let results = (outs I1:$transaction, AnyType:$data);
  let hasVerifier = 1;
  let assemblyFormat = [{
    $input attr-dict `:` qualified(type($input))
  }];

  let extraClassDeclaration = [{
    /// Infer the return types of this operation.
    static LogicalResult inferReturnTypes(MLIRContext *context,
                                          std::optional<Location> loc,
                                          ValueRange operands,
                                          DictionaryAttr attrs,
                                          mlir::PropertyRef properties,
                                          mlir::RegionRange regions,
                                          SmallVectorImpl<Type> &results);
  }];
}

//===----------------------------------------------------------------------===//
// Wrap / unwrap channels to their signaling protocols.
//===----------------------------------------------------------------------===//

def WrapValidReadyOp : ESI_Op<"wrap.vr", [
    DeclareOpInterfaceMethods<ChannelOpInterface>
  ]> {
  let summary = "Wrap a value into an ESI port";
  let description = [{
    Wrapping a value into an ESI port type allows modules to send values down
    an ESI port. Wrap data with valid bit, result is the ESI channel and the
    ready signal from the other end of the channel.
  }];

  let arguments = (ins AnyType:$rawInput, I1:$valid);
  let results = (outs ChannelType:$chanOutput, I1:$ready);
  let hasCustomAssemblyFormat = 1;
  let hasCanonicalizeMethod = 1;
  let hasVerifier = 1;

  let builders = [
    OpBuilder<(ins "mlir::Value":$data, "mlir::Value":$valid)>
  ];
}

def UnwrapValidReadyOp : ESI_Op<"unwrap.vr", [
    DeclareOpInterfaceMethods<ChannelOpInterface>
  ]> {
  let summary = "Unwrap a value from an ESI port";
  let description = [{
    Unwrapping a value allows operations on the contained value. Unwrap the
    channel along with a ready signal tha
... [truncated]

[Usage]
{"total": 8683, "input": 537, "output": 82, "reasoning": 0, "cache": {"write": 0, "read": 8064}, "cost_usd": 0.0007079459, "reason": "tool-calls"}

[Thinking]
Where is the error "only supports zero or one use" emitted? Search DCToHW.cpp.

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && grep -rn \"zero or one use\\|exactly once\\|materialization\" lib/Conversion/DCToHW/DCToHW.cpp | head"}

[Tool Result]
106:/// A type converter is needed to perform the in-flight materialization of "raw"
863:    // Lowering to HW requires that every DC-typed value is used exactly once.
885:             "are used exactly once. Remember to run the "
886:             "fork/sink materialization pass before HW lowering.";


[Usage]
{"total": 9434, "input": 712, "output": 0, "reasoning": 82, "cache": {"write": 0, "read": 8640}, "cost_usd": 0.0007598648, "reason": "tool-calls"}

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && grep -rn \"zero or one\" include/circt/Dialect/ESI/ lib/Dialect/ESI/ | head"}

[Tool Result]
(no output)

[Usage]
{"total": 9563, "input": 99, "output": 56, "reasoning": 0, "cache": {"write": 0, "read": 9408}, "cost_usd": 0.0007335313, "reason": "tool-calls"}

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && grep -rn \"one use\" include/ lib/ | head"}

[Tool Result]
include/circt/Dialect/DC/DCPasses.td:18:    operations ensuring that all values have exactly one use.
include/circt/Dialect/HW/Passes.td:82:           "Inline modules that have only one use">,
include/circt/Dialect/Handshake/HandshakeUtils.h:32:/// values have exactly one use.
include/circt/Dialect/Handshake/HandshakePasses.td:42:    operations ensuring that all values have exactly one use.
include/circt/Dialect/Sim/SimTypes.td:44:    mutation performed by one user is not visible to other users.
include/circt/Support/InstanceGraph.h:132:  /// Return true if this module has exactly one use.
lib/Dialect/FIRRTL/Transforms/LowerDomains.cpp:548:        // The op has at least one use.  Replace it.  This changes the type, so
lib/Dialect/FIRRTL/FIRRTLFolds.cpp:2309:  // Only forward if there is more than one use
lib/Dialect/FIRRTL/FIRRTLReductions.cpp:1400:    // because destination has only one use.
lib/Dialect/FIRRTL/Export/FIREmitter.cpp:813:  // GenericIntrinsicOp is inlined if has exactly one use (only emit once)


[Usage]
{"total": 9612, "input": 34, "output": 42, "reasoning": 0, "cache": {"write": 0, "read": 9536}, "cost_usd": 0.000718207, "reason": "tool-calls"}

[Thinking]
The error message "'esi.wrap.vr' op only supports zero or one use" — where does that come from? Probably from the ESI wrap verifier in ESIOps.cpp or from ESILowerToHW. Search "supports".

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && grep -rn \"supports zero\" -r . 2>/dev/null | grep -v llvm | head"}

[Tool Result]
(no output)

[Usage]
{"total": 10004, "input": 305, "output": 0, "reasoning": 99, "cache": {"write": 0, "read": 9600}, "cost_usd": 0.0008213595, "reason": "tool-calls"}

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && grep -rln \"supports zero\" 2>/dev/null | head; grep -rn \"zero or one use\" /opt/circt-sdk 2>/dev/null | head -3"}

[Tool Result]
(no output)

[Usage]
{"total": 10080, "input": 27, "output": 69, "reasoning": 0, "cache": {"write": 0, "read": 9984}, "cost_usd": 0.0007863849, "reason": "tool-calls"}

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && git log --oneline -3; grep -rn \"one use\" lib/Conversion/DCToHW/DCToHW.cpp; sed -n 830,900p lib/Conversion/DCToHW/DCToHW.cpp"}

[Tool Result]
5dc7f10 [Synth] Move three-input op boilerplate to ODS (#10540)
    Type channelType = operands.getInput().getType();
    rewriter.replaceOpWithNewOp<esi::ChannelBufferOp>(
        op, channelType, clock, reset, operands.getInput(), op.getSizeAttr(),
        nullptr);
    return success();
  };
};

} // namespace

static bool isDCType(Type type) { return isa<TokenType, ValueType>(type); }

///  Returns true if the given `op` is considered as legal - i.e. it does not
///  contain any dc-typed values.
static bool isLegalOp(Operation *op) {
  if (auto funcOp = dyn_cast<HWModuleLike>(op))
    return llvm::none_of(funcOp.getPortTypes(), isDCType);

  bool operandsOK = llvm::none_of(op->getOperandTypes(), isDCType);
  bool resultsOK = llvm::none_of(op->getResultTypes(), isDCType);
  return operandsOK && resultsOK;
}

//===----------------------------------------------------------------------===//
// HW Top-module Related Functions
//===----------------------------------------------------------------------===//

namespace {
class DCToHWPass : public circt::impl::DCToHWBase<DCToHWPass> {
public:
  void runOnOperation() override {
    Operation *parent = getOperation();

    // Lowering to HW requires that every DC-typed value is used exactly once.
    // Check whether this precondition is met, and if not, exit.
    auto walkRes = parent->walk([&](Operation *op) {
      for (auto res : op->getResults()) {
        if (isa<dc::TokenType, dc::ValueType>(res.getType())) {
          if (res.use_empty()) {
            op->emitOpError() << "DCToHW: value " << res << " is unused.";
            return WalkResult::interrupt();
          }
          if (!res.hasOneUse()) {
            op->emitOpError()
                << "DCToHW: value " << res << " has multiple uses.";
            return WalkResult::interrupt();
          }
        }
      }
      return WalkResult::advance();
    });

    if (walkRes.wasInterrupted()) {
      parent->emitOpError()
          << "DCToHW: failed to veri
... [truncated]

[Usage]
{"total": 10165, "input": 39, "output": 78, "reasoning": 0, "cache": {"write": 0, "read": 10048}, "cost_usd": 0.0008042333, "reason": "tool-calls"}

[Thinking]
Now the actual error: "'esi.wrap.vr' op only supports zero or one use" — search in ESIOps.cpp verifier? Let me search git history for that string; maybe from WrapValidReadyOp::verify. Search "one use" in ESI.

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && grep -rn \"one use\\|use\\b\" lib/Dialect/ESI/ESIOps.cpp | head; grep -rn \"WrapValidReadyOp::\" -r lib include | head"}

[Tool Result]
lib/Dialect/ESI/ESIFolds.cpp:18:LogicalResult WrapValidReadyOp::canonicalize(WrapValidReadyOp op,
lib/Dialect/ESI/Passes/ESILowerPhysical.cpp:69:        WrapValidReadyOp::create(rewriter, loc, unwrap.getData(), valid);
lib/Dialect/ESI/Passes/ESILowerPhysical.cpp:83:    auto wrap = WrapValidReadyOp::create(rewriter, loc, unwrap.getRawOutput(),
lib/Dialect/ESI/Passes/ESILowerPhysical.cpp:222:    auto wrap = WrapValidReadyOp::create(
lib/Dialect/ESI/Passes/ESILowerPorts.cpp:169:    auto wrap = WrapValidReadyOp::create(b, data, valid);
lib/Dialect/ESI/Passes/ESILowerPorts.cpp:232:      WrapValidReadyOp::create(b, inst->getLoc(), newResults[dataPort.argNum],
lib/Dialect/ESI/Passes/ESILowerToHW.cpp:107:  auto wrap = WrapValidReadyOp::create(rewriter, loc, chPort,
lib/Dialect/ESI/Passes/ESILowerToHW.cpp:149:    auto wrap = WrapValidReadyOp::create(rewriter, loc, typedZero, valid);
lib/Dialect/ESI/Passes/ESILowerToHW.cpp:464:      WrapValidReadyOp::create(rewriter, loc, dataSignal, validSignal);
lib/Dialect/ESI/Passes/ESILowerToHW.cpp:669:  WrapValidReadyOp wrapRecv = WrapValidReadyOp::create(


[Usage]
{"total": 10881, "input": 644, "output": 0, "reasoning": 125, "cache": {"write": 0, "read": 10112}, "cost_usd": 0.0009167324, "reason": "tool-calls"}

[Thinking]
The error message "only supports zero or one use" — search entire tree for "only supports".

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && grep -rn \"only supports\" lib include | head"}

[Tool Result]
lib/Dialect/Seq/Transforms/LowerSeqHLMem.cpp:93:            writeOp, "only supports write ports with latency == 1");
lib/Dialect/FIRRTL/Transforms/LowerTypes.cpp:810:          // input into the opaque op. This only supports Bundles and Vectors.
lib/Dialect/HW/HWModuleOpInterface.cpp:68:/// FunctionOpInterface op. This only supports ops which use FunctionType to
lib/Dialect/Kanagawa/Transforms/KanagawaTunneling.cpp:151:                                    "tunneling only supports kanagawa.get_port";
lib/Dialect/ESI/Passes/ESILowerPhysical.cpp:171:        "currently only supports input channels with zero data delay");
lib/Dialect/ESI/Passes/ESILowerPhysical.cpp:199:        op, "only supports ValidReady, FIFO, and ValidOnly signaling");
lib/Dialect/ESI/Passes/ESILowerPhysical.cpp:250:        op, "only supports ValidReady, FIFO, and ValidOnly");
lib/Dialect/ESI/Passes/ESILowerToHW.cpp:137:        nullop, "NullOp lowering only supports hw types");
lib/Dialect/ESI/ESIOps.cpp:40:    return emitOpError("currently only supports channels with zero data delay");
lib/Dialect/ESI/ESIOps.cpp:51:    return emitOpError("only supports valid-ready signaling");


[Usage]
{"total": 11303, "input": 363, "output": 0, "reasoning": 60, "cache": {"write": 0, "read": 10880}, "cost_usd": 0.0008590057, "reason": "tool-calls"}

[Thinking]
The error message from the issue "esi.wrap.vr op only supports zero or one use" — likely from the ESI verifier (ESIOps.cpp WrapValidReadyOp::verify) checking chanOutput has zero or one use. Let me check.

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && sed -n 25,70p lib/Dialect/ESI/ESIOps.cpp"}

[Tool Result]
using namespace circt;
using namespace circt::esi;

//===----------------------------------------------------------------------===//
// ChannelBufferOp functions.
//===----------------------------------------------------------------------===//

circt::esi::ChannelType ChannelBufferOp::channelType() {
  return getOutput().getType();
}

LogicalResult ChannelBufferOp::verify() {
  if (getInput().getType().getInner() != getOutput().getType().getInner())
    return emitOpError("input and output data types must match");
  if (getOutput().getType().getDataDelay() != 0)
    return emitOpError("currently only supports channels with zero data delay");
  return success();
}

//===----------------------------------------------------------------------===//
// Snoop operation functions.
//===----------------------------------------------------------------------===//

LogicalResult SnoopValidReadyOp::verify() {
  ChannelType type = getInput().getType();
  if (type.getSignaling() != ChannelSignaling::ValidReady)
    return emitOpError("only supports valid-ready signaling");
  if (type.getInner() != getData().getType())
    return emitOpError("input and output types must match");
  return success();
}

LogicalResult SnoopValidReadyOp::inferReturnTypes(
    MLIRContext *context, std::optional<Location> loc, ValueRange operands,
    DictionaryAttr attrs, mlir::PropertyRef properties,
    mlir::RegionRange regions, SmallVectorImpl<Type> &results) {
  auto i1 = IntegerType::get(context, 1);
  results.push_back(i1);
  results.push_back(i1);
  results.push_back(cast<ChannelType>(operands[0].getType()).getInner());
  return success();
}

LogicalResult SnoopTransactionOp::verify() {
  ChannelType type = getInput().getType();
  if (type.getInner() != getData().getType())


[Usage]
{"total": 11721, "input": 358, "output": 0, "reasoning": 99, "cache": {"write": 0, "read": 11264}, "cost_usd": 0.0009397138, "reason": "tool-calls"}

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && grep -n \"WrapValidReadyOp\\|zero or one\\|use\\b\" lib/Dialect/ESI/ESIOps.cpp | head -30"}

[Tool Result]
107:ParseResult WrapValidReadyOp::parse(OpAsmParser &parser,
128:void WrapValidReadyOp::print(OpAsmPrinter &p) {
134:void WrapValidReadyOp::build(OpBuilder &b, OperationState &state, Value data,
140:LogicalResult WrapValidReadyOp::verify() {
184:circt::esi::ChannelType WrapValidReadyOp::channelType() {


[Usage]
{"total": 12148, "input": 374, "output": 62, "reasoning": 0, "cache": {"write": 0, "read": 11712}, "cost_usd": 0.0009198994, "reason": "tool-calls"}

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && sed -n 134,190p lib/Dialect/ESI/ESIOps.cpp"}

[Tool Result]
void WrapValidReadyOp::build(OpBuilder &b, OperationState &state, Value data,
                             Value valid) {
  build(b, state, ChannelType::get(state.getContext(), data.getType()),
        b.getI1Type(), data, valid);
}

LogicalResult WrapValidReadyOp::verify() {
  mlir::TypedValue<ChannelType> chanOut = getChanOutput();
  if (chanOut.getType().getSignaling() != ChannelSignaling::ValidReady)
    return emitOpError("only supports valid-ready signaling");
  if (failed(ChannelType::verifyChannel(chanOut)))
    return failure();
  return success();
}

ParseResult UnwrapValidReadyOp::parse(OpAsmParser &parser,
                                      OperationState &result) {
  llvm::SMLoc inputOperandsLoc = parser.getCurrentLocation();

  llvm::SmallVector<OpAsmParser::UnresolvedOperand, 2> opList;
  Type outputType;
  if (parser.parseOperandList(opList, 2, OpAsmParser::Delimiter::None) ||
      parser.parseOptionalAttrDict(result.attributes) || parser.parseColon() ||
      parser.parseType(outputType))
    return failure();

  auto inputType =
      ChannelType::get(parser.getBuilder().getContext(), outputType);

  auto boolType = parser.getBuilder().getI1Type();

  result.addTypes({inputType.getInner(), boolType});
  if (parser.resolveOperands(opList, {inputType, boolType}, inputOperandsLoc,
                             result.operands))
    return failure();
  return success();
}

void UnwrapValidReadyOp::print(OpAsmPrinter &p) {
  p << " " << getChanInput() << ", " << getReady();
  p.printOptionalAttrDict((*this)->getAttrs());
  p << " : " << getRawOutput().getType();
}

LogicalResult UnwrapValidReadyOp::verify() {
  if (getChanInput().getType().getSignaling() != ChannelSignaling::ValidReady)
    return emitOpError("only supports valid-ready signaling");
  return success();
}

circt::esi::ChannelType WrapValidReadyOp::channelType() {
  return cast<circt::esi::ChannelType>(getChanOutput().getType());
}

void UnwrapValidReadyOp::build(OpBuilder &b, Operation
... [truncated]

[Usage]
{"total": 12284, "input": 140, "output": 48, "reasoning": 0, "cache": {"write": 0, "read": 12096}, "cost_usd": 0.0009104004, "reason": "tool-calls"}

[Thinking]
The "only supports zero or one use" message isn't in the current tree — probably from ChannelType::verifyChannel? Check verifyChannel.

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && grep -rn \"verifyChannel\" lib/ include/ | head; grep -rn \"zero or one\\|one use\" lib/Dialect/ESI/*.cpp include/circt/Dialect/ESI/*.h 2>/dev/null"}

[Tool Result]
lib/Dialect/ESI/ESITypes.cpp:88:LogicalResult ChannelType::verifyChannel(mlir::TypedValue<ChannelType> chan) {
lib/Dialect/ESI/Passes/ESIVerifyConnections.cpp:47:        if (failed(ChannelType::verifyChannel(cv)))
lib/Dialect/ESI/ESIOps.cpp:144:  if (failed(ChannelType::verifyChannel(chanOut)))
include/circt/Dialect/ESI/ESIChannels.td:101:    static LogicalResult verifyChannel(mlir::TypedValue<ChannelType>);
lib/Dialect/ESI/ESIFolds.cpp:76:        op, "channel output doesn't have exactly one use");
lib/Dialect/ESI/ESIFolds.cpp:120:        op, "channel output doesn't have exactly one use");
lib/Dialect/ESI/ESIFolds.cpp:168:                                       "bundle has zero or more than one user");
lib/Dialect/ESI/ESIFolds.cpp:195:                                       "bundle has zero or more than one user");


[Usage]
{"total": 12908, "input": 576, "output": 0, "reasoning": 108, "cache": {"write": 0, "read": 12224}, "cost_usd": 0.001033696, "reason": "tool-calls"}

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && sed -n 80,120p lib/Dialect/ESI/ESITypes.cpp"}

[Tool Result]
  auto iter = consumers.begin();
  if (iter == consumers.end())
    return nullptr;
  OpOperand *result = &*iter;
  if (++iter != consumers.end())
    return nullptr;
  return result;
}
LogicalResult ChannelType::verifyChannel(mlir::TypedValue<ChannelType> chan) {
  auto consumers = getChannelConsumers(chan);
  if (consumers.empty() || ++consumers.begin() == consumers.end())
    return success();
  auto err = chan.getDefiningOp()->emitOpError(
      "channels must have at most one consumer");
  for (auto &consumer : consumers)
    err.attachNote(consumer.getOwner()->getLoc()) << "channel used here";
  return err;
}

std::optional<int64_t> WindowType::getBitWidth() const {
  return hw::getBitWidth(getLoweredType());
}

LogicalResult
WindowType::verify(llvm::function_ref<InFlightDiagnostic()> emitError,
                   StringAttr name, Type into,
                   ArrayRef<WindowFrameType> frames) {
  auto structInto = hw::type_dyn_cast<hw::StructType>(into);
  if (!structInto)
    return emitError() << "only windows into structs are currently supported";

  // Build a map from field name to type for quick lookup.
  SmallDenseMap<StringAttr, Type> fieldTypes;
  for (hw::StructType::FieldInfo field : structInto.getElements())
    fieldTypes[field.name] = field.type;

  // Track which fields have been consumed (for non-bulk-transfer uses).
  DenseSet<StringAttr> consumedFields;
  // Track which fields have been used as bulk transfer fields (header with
  // countWidth). These fields can be reused in data frames with numItems.
  DenseSet<StringAttr> bulkTransferFields;


[Usage]
{"total": 13186, "input": 274, "output": 48, "reasoning": 0, "cache": {"write": 0, "read": 12864}, "cost_usd": 0.0009726822, "reason": "tool-calls"}

[Thinking]
The exact error text in the issue ("op only supports zero or one use") doesn't exist verbatim in this tree — likely from firtool-1.148.0's... wait, this checkout IS firtool-1.148.0. Hmm, but maybe the message was from a later commit ("+ a few new ones"?). Actually the error might be from `WrapValidReadyOp::verify` at the time via `getChannelConsumers` logic, or from DCToHW? Let me search for "supports zero or one use" in git history.

Actually the key question is a decision, not exact reproduction. The issue is: lower-dc-to-hw fails on a valid, materialized DC program because a dc.fork [2] with both outputs packed... Let me look at how DCToHW lowers dc.pack/dc.unpack and why wrap.vr ends up with multiple uses.

In DCToHW, dc.unpack on a value → esi.unwrap.vr + fork... Let me look at lowerPack/lowerUnpack.

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && sed -n 200,330p lib/Conversion/DCToHW/DCToHW.cpp"}

[Tool Result]
  llvm::SmallVector<Value> getOutputReadys() {
    return extractValues<Value, OutputHandshake>(
        outputs, [](auto &hs) { return hs.ready; });
  }

  llvm::SmallVector<Value> getOutputChannels() {
    return extractValues<Value, OutputHandshake>(
        outputs, [](auto &hs) { return hs.channel; });
  }
  llvm::SmallVector<std::optional<Backedge>> getOutputDatas() {
    return extractValues<std::optional<Backedge>, OutputHandshake>(
        outputs, [](auto &hs) { return hs.data; });
  }
};

///  A class containing a bunch of syntactic sugar to reduce builder function
///  verbosity.
///  @todo: should be moved to support.
struct RTLBuilder {
  RTLBuilder(Location loc, OpBuilder &builder, Value clk = Value(),
             Value rst = Value())
      : b(builder), loc(loc), clk(clk), rst(rst) {}

  Value constant(const APInt &apv, StringRef name = {}) {
    // Cannot use zero-width APInt's in DenseMap's, see
    // https://github.com/llvm/llvm-project/issues/58013
    bool isZeroWidth = apv.getBitWidth() == 0;
    if (!isZeroWidth) {
      auto it = constants.find(apv);
      if (it != constants.end())
        return it->second;
    }

    auto cval = hw::ConstantOp::create(b, loc, apv);
    if (!isZeroWidth)
      constants[apv] = cval;
    return cval;
  }

  Value constant(unsigned width, int64_t value, StringRef name = {}) {
    return constant(
        APInt(width, value, /*isSigned=*/false, /*implicitTrunc=*/true));
  }
  std::pair<Value, Value> wrap(Value data, Value valid, StringRef name = {}) {
    auto wrapOp = esi::WrapValidReadyOp::create(b, loc, data, valid);
    return {wrapOp.getResult(0), wrapOp.getResult(1)};
  }
  std::pair<Value, Value> unwrap(Value channel, Value ready,
                                 StringRef name = {}) {
    auto unwrapOp = esi::UnwrapValidReadyOp::create(b, loc, channel, ready);
    return {unwrapOp.getResult(0), unwrapOp.getResult(1)};
  }

  ///  Various syntactic sugar functions.
  Value reg(StringRef name, Value in
... [truncated]

[Usage]
{"total": 13836, "input": 386, "output": 0, "reasoning": 266, "cache": {"write": 0, "read": 13184}, "cost_usd": 0.001307759, "reason": "tool-calls"}

[Thinking]
This is a triage task — I need to decide. Let me check the actual failing point. Let me try reproducing the second commenter's example read-only (running tools is fine — read-only edits only). Actually running circt-opt isn't editing. Let me check git log for PR #7952 and current state of fork lowering in DCToHW — how dc.fork is lowered and where wrap.vr multiple-use could arise.

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && grep -n \"ForkOp\\|lowerFork\\|fork\" lib/Conversion/DCToHW/DCToHW.cpp | head; git log --oneline --all --grep=7952 | head"}

[Tool Result]
512:class ForkConversionPattern : public OpConversionPattern<ForkOp> {
514:  using OpConversionPattern<ForkOp>::OpConversionPattern;
516:  matchAndRewrite(ForkOp op, OpAdaptor operands,
886:             "fork/sink materialization pass before HW lowering.";


[Usage]
{"total": 15219, "input": 1229, "output": 0, "reasoning": 166, "cache": {"write": 0, "read": 13824}, "cost_usd": 0.0012707807, "reason": "tool-calls"}

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && sed -n 330,530p lib/Conversion/DCToHW/DCToHW.cpp"}

[Tool Result]

  ///  OR-reduction of the bits in 'v'.
  Value reduceOr(Value v, StringRef name = {}) {
    return buildNamedOp([&]() { return bitOr(extractBits(v)); }, name);
  }

  ///  Extract bits v[hi:lo] (inclusive).
  Value extract(Value v, unsigned lo, unsigned hi, StringRef name = {}) {
    unsigned width = hi - lo + 1;
    return buildNamedOp(
        [&]() { return comb::ExtractOp::create(b, loc, v, lo, width); }, name);
  }

  ///  Truncates 'value' to its lower 'width' bits.
  Value truncate(Value value, unsigned width, StringRef name = {}) {
    return extract(value, 0, width - 1, name);
  }

  Value zext(Value value, unsigned outWidth, StringRef name = {}) {
    unsigned inWidth = value.getType().getIntOrFloatBitWidth();
    assert(inWidth <= outWidth && "zext: input width must be <= output width.");
    if (inWidth == outWidth)
      return value;
    auto c0 = constant(outWidth - inWidth, 0);
    return concat({c0, value}, name);
  }

  Value sext(Value value, unsigned outWidth, StringRef name = {}) {
    return comb::createOrFoldSExt(b, loc, value, b.getIntegerType(outWidth));
  }

  ///  Extracts a single bit v[bit].
  Value bit(Value v, unsigned index, StringRef name = {}) {
    return extract(v, index, index, name);
  }

  ///  Creates a hw.array of the given values.
  Value arrayCreate(ValueRange values, StringRef name = {}) {
    return buildNamedOp(
        [&]() { return hw::ArrayCreateOp::create(b, loc, values); }, name);
  }

  ///  Extract the 'index'th value from the input array.
  Value arrayGet(Value array, Value index, StringRef name = {}) {
    return buildNamedOp(
        [&]() { return hw::ArrayGetOp::create(b, loc, array, index); }, name);
  }

  ///  Muxes a range of values.
  ///  The select signal is expected to be a decimal value which selects
  ///  starting from the lowest index of value.
  Value mux(Value index, ValueRange values, StringRef name = {}) {
    if (values.size() == 2) {
      return buildNamedOp(
          [&]() {
          
... [truncated]

[Usage]
{"total": 15337, "input": 119, "output": 50, "reasoning": 0, "cache": {"write": 0, "read": 15168}, "cost_usd": 0.0011233933, "reason": "tool-calls"}

[Thinking]
The error in the issue is from wrap.vr verifier — where exactly does "only supports zero or one use" come from in this checkout? It doesn't exist. Let me check git log for that string's history:

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && git log --all --oneline -S \"zero or one use\" -- lib include | head"}

[Tool Result]
(no output)

[Usage]
{"total": 17235, "input": 1845, "output": 0, "reasoning": 94, "cache": {"write": 0, "read": 15296}, "cost_usd": 0.0013144599, "reason": "tool-calls"}

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && git log --all --oneline -S\"one use\" -- lib/Dialect/ESI lib/Conversion/DCToHW 2>/dev/null | head; git log --oneline --since=2024-11-01 --until=2025-01-15 -- lib/Conversion/DCToHW lib/Dialect/DC | head -30"}

[Tool Result]
5dc7f10 [Synth] Move three-input op boilerplate to ODS (#10540)


[Usage]
{"total": 17346, "input": 26, "output": 104, "reasoning": 0, "cache": {"write": 0, "read": 17216}, "cost_usd": 0.0013335998, "reason": "tool-calls"}

[Thinking]
Only one commit touching those dirs between Nov 2024 and Jan 2025? That's suspicious — maybe the repo is shallow or the log range... Actually "git log --since" should work. Only one commit? Odd. Let me check git log more broadly.

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && git log --oneline --since=2024-10-01 --until=2025-02-01 | head -40; git log --oneline | wc -l"}

[Tool Result]
1


[Usage]
{"total": 17493, "input": 28, "output": 0, "reasoning": 121, "cache": {"write": 0, "read": 17344}, "cost_usd": 0.0013663588, "reason": "tool-calls"}

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && git log --oneline -5; git log -1 --format=%ci; grep -n \"one use\\|hasOneUse\\|use_empty\" lib/Conversion/DCToHW/DCToHW.cpp | head"}

[Tool Result]
5dc7f10 [Synth] Move three-input op boilerplate to ODS (#10540)
2026-05-24 17:14:51 -0700
868:          if (res.use_empty()) {
872:          if (!res.hasOneUse()) {


[Usage]
{"total": 17575, "input": 27, "output": 76, "reasoning": 0, "cache": {"write": 0, "read": 17472}, "cost_usd": 0.0013121081, "reason": "tool-calls"}

[Thinking]
Shallow repo, single commit, dated 2026-05-24 (way after the issue). So this is current-ish CIRCT. The error text from the issue ("'esi.wrap.vr' op only supports zero or one use") doesn't exist in this tree — likely it was from a `WrapValidReadyOp::verify` check at the time (probably removed later). Let me search for a check that the chan output has ≤1 use anywhere in DCToHW/ESI... In ESIFolds.cpp line 76: "channel output doesn't have exactly one use" — that's a canonicalizer? Let me check what that is. Also check ESILowerToHW.cpp 429.

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && sed -n 60,90p lib/Dialect/ESI/ESIFolds.cpp && sed -n 100,160p lib/Dialect/ESI/Passes/ESILowerToHW.cpp"}

[Tool Result]
    auto falseConst =
        hw::ConstantOp::create(rewriter, op.getLoc(), rewriter.getI1Type(), 0);
    rewriter.replaceAllUsesWith(op.getRden(), falseConst);
    rewriter.eraseOp(op);
    return success();
  }

  // If the wrap has no users at all, just erase it.
  if (op->use_empty()) {
    rewriter.eraseOp(op);
    return success();
  }

  // Existing wrap-unwrap canonicalization logic
  if (!op.getChanOutput().hasOneUse())
    return rewriter.notifyMatchFailure(
        op, "channel output doesn't have exactly one use");
  auto unwrap = dyn_cast_or_null<UnwrapFIFOOp>(
      op.getChanOutput().getUses().begin()->getOwner());
  if (succeeded(UnwrapFIFOOp::mergeAndErase(unwrap, op, rewriter)))
    return success();
  return rewriter.notifyMatchFailure(
      op, "could not find corresponding unwrap for wrap");
}

//===----------------------------------------------------------------------===//
// ValidOnly wrap / unwrap canonicalization.
//===----------------------------------------------------------------------===//

LogicalResult UnwrapValidOnlyOp::mergeAndErase(UnwrapValidOnlyOp unwrap,
                                               WrapValidOnlyOp wrap,
  // stage.
  wrapReady.setValue(stageInstResults[0]);
  Value x, xValid;
  x = stageInstResults[1];
  xValid = stageInstResults[2];

  // Wrap up the output of the HW stage module.
  auto wrap = WrapValidReadyOp::create(rewriter, loc, chPort,
                                       rewriter.getI1Type(), x, xValid);
  // Set the stages x_ready backedge correctly.
  stageReady.setValue(wrap.getReady());

  rewriter.replaceOp(stage, wrap.getChanOutput());
  return success();
}

namespace {
struct NullSourceOpLowering : public OpConversionPattern<NullSourceOp> {
public:
  NullSourceOpLowering(MLIRContext *ctxt) : OpConversionPattern(ctxt) {}
  using OpConversionPattern::OpConversionPattern;

  LogicalResult
  matchAndRewrite(NullSourceOp nullop, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewrit
... [truncated]

[Usage]
{"total": 17862, "input": 104, "output": 0, "reasoning": 222, "cache": {"write": 0, "read": 17536}, "cost_usd": 0.0015263, "reason": "tool-calls"}

[Thinking]
Now, the actual root cause of the issue: DCToHW lowers `dc.unpack` (PackConversion?) by creating an esi.unwrap.vr whose channel result then feeds further unpacks... Actually the error is that a wrap.vr output channel ends up with multiple uses. In DCToHW, dc.pack ops each create wrap.vr; dc.unpack each creates unwrap.vr. The bug is that the DC program in the issue is valid and materialized, yet lowering produces IR violating ESI's one-use constraint on wrap.vr channels — i.e., a dc.pack's result... hmm.

Actually looking at the issue trace: `dc.unpack %write_address` creates a token used by fork [2], whose two outputs are packed twice → each pack result (a dc.value) is used once each. The DC-side check verifies exactly-one-use. But then DCToHW converts dc.pack→esi.wrap.vr + dc.unpack→unwrap.vr... The error mentions `%5:2 = "esi.wrap.vr"(%4, %14) : (i0, i1) -> (!esi.channel<i0>, i1)` — i0 (token) wrapped twice? The wrap is created by ForkConversionPattern or by ... The message "only supports zero or one use" — hmm, this checkout doesn't have it. It may have been in ESILowerToHW or in a `wrap.vr` verifier check added around that time. Search for "zero or" once more anywhere.

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /workspace/circt && grep -rn \"zero or one\" lib include | grep -v FIRRTL | head"}

[Tool Result]
lib/Dialect/HW/HWOpInterfaces.cpp:63:    // No "type" provided means must have zero or one inner symbols.


[Usage]
{"total": 19073, "input": 860, "output": 0, "reasoning": 357, "cache": {"write": 0, "read": 17856}, "cost_usd": 0.0017901924, "reason": "tool-calls"}

[Thinking]
The exact message doesn't exist in this checkout. The version pinned is firtool-1.148.0 (May 2026) — much later than the issue (Dec 2024). The error message may have been removed/changed in the intervening year, and the underlying problem may or may not have been fixed. Let me actually try reproducing the second commenter's example.

[Response]
Let me try reproducing the issue with the reporter's simpler example (read-only investigation).

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "mkdir -p /tmp/i7949 && cd /tmp/i7949 && cat > hs.mlir <<'EOF'\nmodule {\n  handshake.func @ops(%arg0: i32, %arg1: i32, %arg2: i32, %arg3: i32, %arg4: i32, %arg5: i32) -> (i32, none) {\n    %arg5_ = merge %arg0, %arg1 : i32\n    %arg23 = join %arg5_ : i32\n    return %arg5_, %arg23: i32, none\n  }\n}\nEOF\n/workspace/circt/build/bin/circt-opt hs.mlir --lower-handshake-to-dc > dc.mlir; cat dc.mlir"}

[Tool Result]
module {
  hw.module @ops(in %arg0 : !dc.value<i32>, in %arg1 : !dc.value<i32>, in %arg2 : !dc.value<i32>, in %arg3 : !dc.value<i32>, in %arg4 : !dc.value<i32>, in %arg5 : !dc.value<i32>, in %clk : !seq.clock {dc.clock}, in %rst : i1 {dc.reset}, out out0 : !dc.value<i32>, out out1 : !dc.token) {
    %token, %output = dc.unpack %arg0 : !dc.value<i32>
    %token_0, %output_1 = dc.unpack %arg1 : !dc.value<i32>
    %0 = dc.merge %token, %token_0
    %token_2, %output_3 = dc.unpack %0 : !dc.value<i1>
    %1 = arith.select %output_3, %output, %output_1 : i32
    %2 = dc.pack %token_2, %1 : i32
    %token_4, %output_5 = dc.unpack %2 : !dc.value<i32>
    %3 = dc.join %token_4
    hw.output %2, %3 : !dc.value<i32>, !dc.token
  }
}



[Usage]
{"total": 19389, "input": 34, "output": 24, "reasoning": 259, "cache": {"write": 0, "read": 19072}, "cost_usd": 0.0017126374, "reason": "tool-calls"}

[Tool Call: bash_7949_bash_7949_run_command]
Args: {"command": "cd /tmp/i7949 && /workspace/circt/build/bin/circt-opt dc.mlir --dc-materialize-forks-sinks > mat.mlir && cat mat.mlir && echo ==== && /workspace/circt/build/bin/circt-opt mat.mlir --lower-dc-to-hw 2>&1 | head -40"}

[Tool Result]
module {
  hw.module @ops(in %arg0 : !dc.value<i32>, in %arg1 : !dc.value<i32>, in %arg2 : !dc.value<i32>, in %arg3 : !dc.value<i32>, in %arg4 : !dc.value<i32>, in %arg5 : !dc.value<i32>, in %clk : !seq.clock {dc.clock}, in %rst : i1 {dc.reset}, out out0 : !dc.value<i32>, out out1 : !dc.token) {
    %token, %output = dc.unpack %arg5 : !dc.value<i32>
    dc.sink %token
    %token_0, %output_1 = dc.unpack %arg4 : !dc.value<i32>
    dc.sink %token_0
    %token_2, %output_3 = dc.unpack %arg3 : !dc.value<i32>
    dc.sink %token_2
    %token_4, %output_5 = dc.unpack %arg2 : !dc.value<i32>
    dc.sink %token_4
    %token_6, %output_7 = dc.unpack %arg0 : !dc.value<i32>
    %token_8, %output_9 = dc.unpack %arg1 : !dc.value<i32>
    %0 = dc.merge %token_6, %token_8
    %token_10, %output_11 = dc.unpack %0 : !dc.value<i1>
    %1 = arith.select %output_11, %output_7, %output_9 : i32
    %2 = dc.pack %token_10, %1 : i32
    %token_12, %output_13 = dc.unpack %2 : !dc.value<i32>
    %3:2 = dc.fork [2] %token_12 
    %4 = dc.pack %3#0, %output_13 : i32
    %5 = dc.pack %3#1, %output_13 : i32
    %token_14, %output_15 = dc.unpack %5 : !dc.value<i32>
    %6 = dc.join %token_14
    hw.output %4, %6 : !dc.value<i32>, !dc.token
  }
}

====
mat.mlir:14:29: error: 'esi.wrap.vr' op channels must have at most one consumer
    %token_10, %output_11 = dc.unpack %0 : !dc.value<i1>
                            ^
mat.mlir:14:29: note: see current operation: %37:2 = "esi.wrap.vr"(%36, %35#1) : (i0, i1) -> (!esi.channel<i0>, i1)
mat.mlir:18:12: note: channel used here
    %3:2 = dc.fork [2] %token_12 
           ^
mat.mlir:16:10: note: channel used here
    %2 = dc.pack %token_10, %1 : i32
         ^


[Usage]
{"total": 19773, "input": 351, "output": 94, "reasoning": 0, "cache": {"write": 0, "read": 19328}, "cost_usd": 0.0014878341, "reason": "tool-calls"}

[Thinking]
Reproduced. The bug still exists in this checkout (firtool-1.148.0). Same DC program (valid, materialized) fails in lower-dc-to-hw with "channels must have at most one consumer".

Root cause analysis: `dc.pack %token_10, %1 : i32` → lowering creates wrap.vr; also the token `%token_10` from `dc.unpack %0` — the token lowering: dc.unpack creates unwrap.vr; the token is a channel of i0. When the same token's channel output is consumed both by the pack (which uses it to... wait). Look: `%37:2 = esi.wrap.vr(%36, %35#1) : (i0, i1) -> (!esi.channel<i0>, i1)` — wrapping an i0 (token data) with valid, then the channel is used both by pack conversion AND fork conversion. So the same dc token gets wrapped into an ESI channel twice — once in the pack lowering and once elsewhere (fork?), or the wrap is shared and has two consumers.

So bug: DCToHW conversion of a valid, forks/sinks-materialized DC program emits ESI IR that violates the wrap.vr one-consumer verifier. The expected behavior: the pass should lower any valid materialized DC program to legal ESI/HW IR — mortbopet's comment confirms "we should be able to successfully lower any valid DC program to HW, assuming it has materialized forks/sinks". That's the intended behavior, clearly stated by the maintainer in the issue. So correct behavior is clear: handle it, not reject.

Is it CLEAR? The bug: valid input → pass crashes/errors during conversion with an ESI verifier failure (not a proper diagnostic). Expected: lower successfully to legal HW. The maintainer explicitly stated the intent. The bug is a concrete defect (conversion produces invalid IR). The fix — how wrap.vr channels should be shared/consumed — there could be design choices (e.g., insert esi.channel_buffer/fork to satisfy one-consumer), but the "correct behavior" at the pipeline level (this valid input must lower) is unambiguous. Per guidance: "A clearly-VALID input that crashes or miscompiles usually has one defensible answer — handle it correctly." Input here is valid DC (verifier passes; DC dialect has no rule against this shape after materialization). So DECISION: CLEAR.

Also note the workarounds (canonicalize loop) show the intended behavior is lowering to succeed, and PR #7952 partial. So proceed.

I should keep this as triage decision; but the instructions say "End your response with EXACTLY one of these footers". This is a decision task — I should report and end. The task is "BEFORE any attempt to reproduce or fix it. Decide whether this issue is something the pipeline should attempt at all." I already did read-only reproduction which is fine. End with the footer.

[Response]
I investigated the issue and reproduced it read-only in the current checkout (pinned at firtool-1.148.0, /workspace/circt).

## Findings

**PART A — Is this a bug? Yes.**

I reproduced the second commenter's example end-to-end with the source-tree `circt-opt`:

1. `handshake.func` → `--lower-handshake-to-dc` → valid DC.
2. `--dc-materialize-forks-sinks` → valid, fully materialized DC (every token/value has exactly one use or is sunk — the DCToHW precondition walk in `lib/Conversion/DCToHW/DCToHW.cpp:863-887` passes).
3. `--lower-dc-to-hw` then **fails**:

```
mat.mlir:14:29: error: 'esi.wrap.vr' op channels must have at most one consumer
    %token_10, %output_11 = dc.unpack %0 : !dc.value<i1>
mat.mlir:18:12: note: channel used here
    %3:2 = dc.fork [2] %token_12
mat.mlir:16:10: note: channel used here
    %2 = dc.pack %token_10, %1 : i32
```

This is the same failure as the issue (the `WrapValidReadyOp::verify` → `ChannelType::verifyChannel` check in `lib/Dialect/ESI/ESIOps.cpp:144` / `ESITypes.cpp:88` catches IR that `lower-dc-to-hw` itself just emitted). So the DCToHW conversion pattern emits ESI IR that violates the ESI one-consumer-per-channel invariant — the input DC program is valid and satisfies the pass's own stated precondition, yet the pass produces invalid IR. That is a genuine defect (a lowering that generates illegal IR), not a usage question or feature request.

**PART B — Are the bug and the correct behavior both clear? Yes.**

- The bug is concrete and reproducible: `DCToHW.cpp`'s conversion patterns (pack/unpack/fork lowering, e.g. `unwrapIO`/`ForkConversionPattern`) create `esi.wrap.vr` channels with more than one consumer for DC ops that share a token (pack + fork sharing the token channel), which the ESI verifier rejects.
- The correct behavior is unambiguous and grounded in the issue itself: the maintainer (mortbopet) states the design intent explicitly — *"we should be able to successfully lower any valid DC program to HW, assuming it has materialized forks/sinks."* Rejecting the input is not on the table (the input is valid DC); the pass must emit legal ESI/HW IR (e.g., by not double-wrapping/shared-consuming a token channel — buffer or restructure so each wrap channel has at most one consumer). PR #7952's canonicalizer workarounds were a stopgap, and the fact that a specific pass-ordering hack is needed to get valid IR out confirms the pass itself is expected to handle this input.

BUG: `--lower-dc-to-hw` emits `esi.wrap.vr` channel results with multiple consumers (shared token channels between pack and fork lowering), producing invalid ESI IR that the ESI verifier rejects for DC programs that are valid and have materialized forks/sinks.
EXPECTED: `lower-dc-to-hw` should successfully lower any valid DC program that has had forks/sinks materialized into legal HW/ESI IR where every wrapped channel has at most one consumer.
DECISION: CLEAR

[Usage]
{"total": 21825, "input": 725, "output": 729, "reasoning": 659, "cache": {"write": 0, "read": 19712}, "cost_usd": 0.0033520343, "reason": "stop"}

[Result]
{"num_turns": 30, "input_tokens": 18071, "output_tokens": 1768, "reasoning_tokens": 2818, "cache_read": 372864, "cache_write": 0, "cost_usd": 0.03337389250000001}

