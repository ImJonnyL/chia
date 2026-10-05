# Issue #7388: [FIRRTL][LowerToHW] crash lowering enum code

- State: open
- Author: dtzSiFive
- Created: 2024-07-25T16:54:39Z
- Updated: 2024-07-25T16:54:39Z
- Labels: bug, FIRRTL
- URL: https://github.com/llvm/circt/issues/7388

## Body

Consider:
```
firrtl.circuit "MatchInline" {
  firrtl.module @MatchInline(in %i: !firrtl.enum<Some: uint<8>, None: uint<0>>, out %o: !firrtl.uint<8>) attributes {convention = #firrtl<convention scalarized>} {
    %c255_ui8 = firrtl.constant 255 : !firrtl.uint<8> {name = "c_out"}
    %c0_ui8 = firrtl.constant 0 : !firrtl.uint<8> {name = "c_in"}
    %c0_ui0 = firrtl.constant 0 : !firrtl.uint<0>
    %0 = firrtl.enumcreate Some(%c0_ui8) : (!firrtl.uint<8>) -> !firrtl.enum<Some: uint<8>, None: uint<0>>
    %1 = firrtl.enumcreate None(%c0_ui0) : (!firrtl.uint<0>) -> !firrtl.enum<Some: uint<8>, None: uint<0>>
    %2 = firrtl.istag %i Some : !firrtl.enum<Some: uint<8>, None: uint<0>>
    %c_out = firrtl.wire : !firrtl.uint<8>
    %3 = firrtl.mux(%2, %c_out, %c255_ui8) : (!firrtl.uint<1>, !firrtl.uint<8>, !firrtl.uint<8>) -> !firrtl.uint<8>
    firrtl.matchingconnect %o, %3 : !firrtl.uint<8>
  }
}
```

(obtained from valid FIRRTL, disabling `LowerSignatures` to workaround #7106))

This crashes when fed through `circt-opt --lower-firrtl-to-hw`:

```
PLEASE submit a bug report to https://github.com/llvm/circt and include the crash backtrace.
Stack dump:
0.	Program arguments: ./build/bin/firtool match-inline.fir
 #0 0x00005621d9f41e96 llvm::sys::PrintStackTrace(llvm::raw_ostream&, int) /home/will/src/sifive/circt/llvm/llvm/lib/Support/Unix/Signals.inc:723:13
 #1 0x00005621d9f3ff90 llvm::sys::RunSignalHandlers() /home/will/src/sifive/circt/llvm/llvm/lib/Support/Signals.cpp:106:18
 #2 0x00005621d9f4253b SignalHandler(int) /home/will/src/sifive/circt/llvm/llvm/lib/Support/Unix/Signals.inc:413:1
 #3 0x00007f500ee52f30 __restore_rt (/nix/store/k7zgvzp2r31zkg9xqgjim7mbknryv6bs-glibc-2.39-52/lib/libc.so.6+0x3ff30)
 #4 0x00005621da420ca0 void mlir::detail::IROperandBase::insertInto<mlir::IRObjectWithUseList<mlir::OpOperand>>(mlir::IRObjectWithUseList<mlir::OpOperand>*) /home/will/src/sifive/circt/llvm/mlir/include/mlir/IR/UseDefLists.h:99:24
 #5 0x00005621da420ca0 mlir::IROperand<mlir::OpOperand, mlir::Value>::insertIntoCurrent() /home/will/src/sifive/circt/llvm/mlir/include/mlir/IR/UseDefLists.h:186:30
 #6 0x00005621da420ca0 mlir::IROperand<mlir::OpOperand, mlir::Value>::IROperand(mlir::Operation*, mlir::Value) /home/will/src/sifive/circt/llvm/mlir/include/mlir/IR/UseDefLists.h:132:5
 #7 0x00005621da420ca0 mlir::OpOperand::OpOperand(mlir::Operation*, mlir::Value) /home/will/src/sifive/circt/llvm/mlir/include/mlir/IR/Value.h:284:38
 #8 0x00005621da420ca0 mlir::detail::OperandStorage::OperandStorage(mlir::Operation*, mlir::OpOperand*, mlir::ValueRange) /home/will/src/sifive/circt/llvm/mlir/lib/IR/OperationSupport.cpp:245:30
 #9 0x00005621da414ac8 mlir::Operation::create(mlir::Location, mlir::OperationName, mlir::TypeRange, mlir::ValueRange, mlir::DictionaryAttr, mlir::OpaqueProperties, mlir::BlockRange, unsigned int) /home/will/src/sifive/circt/llvm/mlir/lib/IR/Operation.cpp:122:3
#10 0x00005621da414465 mlir::Operation::create(mlir::Location, mlir::OperationName, mlir::TypeRange, mlir::ValueRange, mlir::NamedAttrList&&, mlir::OpaqueProperties, mlir::BlockRange, unsigned int) /home/will/src/sifive/circt/llvm/mlir/lib/IR/Operation.cpp:75:10
#11 0x00005621da414465 mlir::Operation::create(mlir::Location, mlir::OperationName, mlir::TypeRange, mlir::ValueRange, mlir::NamedAttrList&&, mlir::OpaqueProperties, mlir::BlockRange, mlir::RegionRange) /home/will/src/sifive/circt/llvm/mlir/lib/IR/Operation.cpp:58:7
#12 0x00005621da4142f7 llvm::SmallVectorTemplateCommon<mlir::NamedAttribute, void>::begin() /home/will/src/sifive/circt/llvm/llvm/include/llvm/ADT/SmallVector.h:280:45
#13 0x00005621da4142f7 llvm::SmallVectorTemplateCommon<mlir::NamedAttribute, void>::end() /home/will/src/sifive/circt/llvm/llvm/include/llvm/ADT/SmallVector.h:282:27
#14 0x00005621da4142f7 llvm::SmallVector<mlir::NamedAttribute, 4u>::~SmallVector() /home/will/src/sifive/circt/llvm/llvm/include/llvm/ADT/SmallVector.h:1215:46
#15 0x00005621da4142f7 mlir::NamedAttrList::~NamedAttrList() /home/will/src/sifive/circt/llvm/mlir/include/mlir/IR/OperationSupport.h:801:7
#16 0x00005621da4142f7 mlir::Operation::create(mlir::OperationState const&) /home/will/src/sifive/circt/llvm/mlir/lib/IR/Operation.cpp:36:7
#17 0x00005621da352ddc mlir::OpBuilder::create(mlir::OperationState const&) /home/will/src/sifive/circt/llvm/mlir/lib/IR/Builders.cpp:465:10
#18 0x00005621da473b1a llvm::ValueIsPresent<mlir::Operation*, void>::isPresent(mlir::Operation* const&) /home/will/src/sifive/circt/llvm/llvm/include/llvm/Support/Casting.h:622:55
#19 0x00005621da473b1a bool llvm::detail::isPresent<mlir::Operation*>(mlir::Operation* const&) /home/will/src/sifive/circt/llvm/llvm/include/llvm/Support/Casting.h:630:10
#20 0x00005621da473b1a decltype(auto) llvm::dyn_cast<circt::hw::UnionCreateOp, mlir::Operation>(mlir::Operation*) /home/will/src/sifive/circt/llvm/llvm/include/llvm/Support/Casting.h:662:3
#21 0x00005621da473b1a circt::hw::UnionCreateOp mlir::OpBuilder::create<circt::hw::UnionCreateOp, mlir::Type&, mlir::StringAttr&, mlir::Value&>(mlir::Location, mlir::Type&, mlir::StringAttr&, mlir::Value&) /home/will/src/sifive/circt/llvm/mlir/include/mlir/IR/Builders.h:513:19
#22 0x00005621da45485a circt::hw::UnionCreateOp mlir::ImplicitLocOpBuilder::create<circt::hw::UnionCreateOp, mlir::Type&, mlir::StringAttr&, mlir::Value&>(mlir::Type&, mlir::StringAttr&, mlir::Value&) /home/will/src/sifive/circt/llvm/mlir/include/mlir/IR/ImplicitLocOpBuilder.h:67:23
#23 0x00005621da45485a (anonymous namespace)::FIRRTLLowering::visitExpr(circt::firrtl::FEnumCreateOp) /home/will/src/sifive/circt/lib/Conversion/FIRRTLToHW/LowerToHW.cpp:2868:28
#24 0x00005621da45485a llvm::LogicalResult circt::firrtl::ExprVisitor<(anonymous namespace)::FIRRTLLowering, llvm::LogicalResult>::dispatchExprVisitor(mlir::Operation*)::'lambda'(auto)::operator()<circt::firrtl::FEnumCreateOp>(auto) const /home/will/src/sifive/circt/include/circt/Dialect/FIRRTL/FIRRTLVisitors.h:71:32
#25 0x00005621da45485a llvm::TypeSwitch<mlir::Operation*, llvm::LogicalResult>& llvm::TypeSwitch<mlir::Operation*, llvm::LogicalResult>::Case<circt::firrtl::FEnumCreateOp, circt::firrtl::ExprVisitor<(anonymous namespace)::FIRRTLLowering, llvm::LogicalResult>::dispatchExprVisitor(mlir::Operation*)::'lambda'(auto)&>(circt::firrtl::ExprVisitor<(anonymous namespace)::FIRRTLLowering, llvm::LogicalResult>::dispatchExprVisitor(mlir::Operation*)::'lambda'(auto)&) /home/will/src/sifive/circt/llvm/llvm/include/llvm/ADT/TypeSwitch.h:102:22
#26 0x00005621da45485a circt::firrtl::ExprVisitor<(anonymous namespace)::FIRRTLLowering, llvm::LogicalResult>::dispatchExprVisitor(mlir::Operation*) /home/will/src/sifive/circt/include/circt/Dialect/FIRRTL/FIRRTLVisitors.h:32:19
#27 0x00005621da4507e9 circt::firrtl::FIRRTLVisitor<(anonymous namespace)::FIRRTLLowering, llvm::LogicalResult>::dispatchVisitor(mlir::Operation*) /home/will/src/sifive/circt/include/circt/Dialect/FIRRTL/FIRRTLVisitors.h:404:18
#28 0x00005621da4507e9 (anonymous namespace)::FIRRTLLowering::run() /home/will/src/sifive/circt/lib/Conversion/FIRRTLToHW/LowerToHW.cpp:1802:27
#29 0x00005621da4507e9 (anonymous namespace)::FIRRTLModuleLowering::lowerModuleOperations(circt::hw::HWModuleOp, (anonymous namespace)::CircuitLoweringState&) /home/will/src/sifive/circt/lib/Conversion/FIRRTLToHW/LowerToHW.cpp:1785:48
#30 0x00005621da4507e9 _ZZN12_GLOBAL__N_120FIRRTLModuleLowering14runOnOperationEvENK3$_5clImEEDaT_ /home/will/src/sifive/circt/lib/Conversion/FIRRTLToHW/LowerToHW.cpp:731:16
#31 0x00005621da44b6fb llvm::LogicalResult::failed() const /home/will/src/sifive/circt/llvm/llvm/include/llvm/Support/LogicalResult.h:43:43
#32 0x00005621da44b6fb llvm::failed(llvm::LogicalResult) /home/will/src/sifive/circt/llvm/llvm/include/llvm/Support/LogicalResult.h:71:58
#33 0x00005621da44b6fb llvm::LogicalResult mlir::failableParallelForEach<llvm::detail::SafeIntIterator<unsigned long, false>, (anonymous namespace)::FIRRTLModuleLowering::runOnOperation()::$_5>(mlir::MLIRContext*, llvm::detail::SafeIntIterator<unsigned long, false>, llvm::detail::SafeIntIterator<unsigned long, false>, (anonymous namespace)::FIRRTLModuleLowering::runOnOperation()::$_5&&) /home/will/src/sifive/circt/llvm/mlir/include/mlir/IR/Threading.h:46:11
#34 0x00005621da44b6fb llvm::LogicalResult mlir::failableParallelForEach<llvm::iota_range<unsigned long>, (anonymous namespace)::FIRRTLModuleLowering::runOnOperation()::$_5>(mlir::MLIRContext*, llvm::iota_range<unsigned long>&&, (anonymous namespace)::FIRRTLModuleLowering::runOnOperation()::$_5&&) /home/will/src/sifive/circt/llvm/mlir/include/mlir/IR/Threading.h:92:10
#35 0x00005621da44b6fb llvm::LogicalResult mlir::failableParallelForEachN<(anonymous namespace)::FIRRTLModuleLowering::runOnOperation()::$_5>(mlir::MLIRContext*, unsigned long, unsigned long, (anonymous namespace)::FIRRTLModuleLowering::runOnOperation()::$_5&&) /home/will/src/sifive/circt/llvm/mlir/include/mlir/IR/Threading.h:107:10
#36 0x00005621da44b6fb (anonymous namespace)::FIRRTLModuleLowering::runOnOperation() /home/will/src/sifive/circt/lib/Conversion/FIRRTLToHW/LowerToHW.cpp:729:17
#37 0x00005621dab60b7f mlir::detail::OpToOpPassAdaptor::run(mlir::Pass*, mlir::Operation*, mlir::AnalysisManager, bool, unsigned int)::$_1::operator()() const /home/will/src/sifive/circt/llvm/mlir/lib/Pass/Pass.cpp:0:17
#38 0x00005621dab60b7f void llvm::function_ref<void ()>::callback_fn<mlir::detail::OpToOpPassAdaptor::run(mlir::Pass*, mlir::Operation*, mlir::AnalysisManager, bool, unsigned int)::$_1>(long) /home/will/src/sifive/circt/llvm/llvm/include/llvm/ADT/STLFunctionalExtras.h:45:12
#39 0x00005621dab60b7f llvm::function_ref<void ()>::operator()() const /home/will/src/sifive/circt/llvm/llvm/include/llvm/ADT/STLFunctionalExtras.h:68:12
#40 0x00005621dab60b7f void mlir::MLIRContext::executeAction<mlir::PassExecutionAction, mlir::Pass&>(llvm::function_ref<void ()>, llvm::ArrayRef<mlir::IRUnit>, mlir::Pass&) /home/will/src/sifive/circt/llvm/mlir/include/mlir/IR/MLIRContext.h:275:7
#41 0x00005621dab60b7f mlir::detail::OpToOpPassAdaptor::run(mlir::Pass*, mlir::Operation*, mlir::AnalysisManager, bool, unsigned int) /home/will/src/sifive/circt/llvm/mlir/lib/Pass/Pass.cpp:521:21
#42 0x00005621dab635a2 llvm::LogicalResult::failed() const /home/will/src/sifive/circt/llvm/llvm/include/llvm/Support/LogicalResult.h:43:43
#43 0x00005621dab635a2 llvm::failed(llvm::LogicalResult) /home/will/src/sifive/circt/llvm/llvm/include/llvm/Support/LogicalResult.h:71:58
#44 0x00005621dab635a2 mlir::detail::OpToOpPassAdaptor::runPipeline(mlir::OpPassManager&, mlir::Operation*, mlir::AnalysisManager, bool, unsigned int, mlir::PassInstrumentor*, mlir::PassInstrumentation::PipelineParentInfo const*) /home/will/src/sifive/circt/llvm/mlir/lib/Pass/Pass.cpp:593:9
#45 0x00005621dab635a2 mlir::PassManager::runPasses(mlir::Operation*, mlir::AnalysisManager) /home/will/src/sifive/circt/llvm/mlir/lib/Pass/Pass.cpp:904:10
#46 0x00005621dab635a2 mlir::PassManager::run(mlir::Operation*) /home/will/src/sifive/circt/llvm/mlir/lib/Pass/Pass.cpp:884:60
#47 0x00005621d9e915d7 llvm::LogicalResult::failed() const /home/will/src/sifive/circt/llvm/llvm/include/llvm/Support/LogicalResult.h:43:43
#48 0x00005621d9e915d7 llvm::failed(llvm::LogicalResult) /home/will/src/sifive/circt/llvm/llvm/include/llvm/Support/LogicalResult.h:71:58
#49 0x00005621d9e915d7 processBuffer(mlir::MLIRContext&, circt::firtool::FirtoolOptions&, mlir::TimingScope&, llvm::SourceMgr&, std::optional<std::unique_ptr<llvm::ToolOutputFile, std::default_delete<llvm::ToolOutputFile>>>&) /home/will/src/sifive/circt/tools/firtool/firtool.cpp:494:7
#50 0x00005621d9e90432 processInputSplit(mlir::MLIRContext&, circt::firtool::FirtoolOptions&, mlir::TimingScope&, std::unique_ptr<llvm::MemoryBuffer, std::default_delete<llvm::MemoryBuffer>>, std::optional<std::unique_ptr<llvm::ToolOutputFile, std::default_delete<llvm::ToolOutputFile>>>&) /home/will/src/sifive/circt/tools/firtool/firtool.cpp:566:12
#51 0x00005621d9e8ff04 processInput(mlir::MLIRContext&, circt::firtool::FirtoolOptions&, mlir::TimingScope&, std::unique_ptr<llvm::MemoryBuffer, std::default_delete<llvm::MemoryBuffer>>, std::optional<std::unique_ptr<llvm::ToolOutputFile, std::default_delete<llvm::ToolOutputFile>>>&) /home/will/src/sifive/circt/tools/firtool/firtool.cpp:582:12
#52 0x00005621d9e8ff04 executeFirtool(mlir::MLIRContext&, circt::firtool::FirtoolOptions&) /home/will/src/sifive/circt/tools/firtool/firtool.cpp:674:14
#53 0x00005621d9e8faf8 llvm::LogicalResult::failed() const /home/will/src/sifive/circt/llvm/llvm/include/llvm/Support/LogicalResult.h:43:43
#54 0x00005621d9e8faf8 llvm::failed(llvm::LogicalResult) /home/will/src/sifive/circt/llvm/llvm/include/llvm/Support/LogicalResult.h:71:58
#55 0x00005621d9e8faf8 main /home/will/src/sifive/circt/tools/firtool/firtool.cpp:769:8
#56 0x00007f500ee3d10e __libc_start_call_main (/nix/store/k7zgvzp2r31zkg9xqgjim7mbknryv6bs-glibc-2.39-52/lib/libc.so.6+0x2a10e)
#57 0x00007f500ee3d1c9 __libc_start_main@GLIBC_2.2.5 (/nix/store/k7zgvzp2r31zkg9xqgjim7mbknryv6bs-glibc-2.39-52/lib/libc.so.6+0x2a1c9)
#58 0x00005621d9e8f895 _start (./build/bin/firtool+0x80b895)
zsh: segmentation fault (core dumped)  ./build/bin/firtool match-inline.fir
```

I have not investigated beyond this, just reporting for now.
