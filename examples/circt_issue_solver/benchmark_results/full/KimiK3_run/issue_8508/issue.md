# Issue #8508: [FIRRTL] InjectDUTHierarchy Creates Names that Conflict with ExtModule Defnames

- State: open
- Author: seldridge
- Created: 2025-05-22T17:45:32Z
- Updated: 2025-05-22T17:45:39Z
- Labels: bug, FIRRTL
- URL: https://github.com/llvm/circt/issues/8508

## Body

Consider the following circuit:

``` firrtl
FIRRTL version 5.1.0
circuit Foo: %[[
  {
    "class": "sifive.enterprise.firrtl.MarkDUTAnnotation",
    "target": "~|Bar"
  },
  {
    "class": "sifive.enterprise.firrtl.InjectDUTHierarchyAnnotation",
    "name": "logic"
  }
]]

  extmodule Bar:
    output a: UInt<1>

    defname = Bar

  public module Foo:
    output a: UInt<1>

    inst bar of Bar
    connect a, bar.a
```

When compiled (without assertions) this will create an illegal circuit:

``` console
$ firtool Foo.fir
Foo.fir:13:3: error: 'firrtl.extmodule' op attribute 'defname' with value "Bar" conflicts with the name of another module in the circuit
  extmodule Bar:
  ^
Foo.fir:13:3: note: see current operation: 
"firrtl.extmodule"() <{annotations = [], convention = #firrtl<convention scalarized>, defname = "Bar", layers = [], parameters = [], portAnnotations = [[]], portDirections = array<i1: true>, portLocations = [loc("Foo.fir":14:12)], portNames = ["a"], portSymbols = [], portTypes = [!firrtl.uint<1>], sym_name = "logic"}> ({
}) : () -> ()
Foo.fir:13:3: note: previous module declared here
```

The problem is that the created wrapper module name conflicts with the defname of the external module. (I realize that this circuit is weird as the DUT is a blackbox.)

When compiled with assertions on, this will trip an assertion:

``` console
Assertion failed: (isa<To>(Val) && "cast<Ty>() argument of incompatible type!"), function cast, file Casting.h, line 566.
PLEASE submit a bug report to https://github.com/llvm/circt and include the crash backtrace.
Stack dump:
0.	Program arguments: firtool /Users/schuylereldridge/repos/github.com/seldridge/firrtl-snippets/inject-dut-hierarchy-extmodule.fir -verbose-pass-executions
Stack dump without symbol names (ensure you have llvm-symbolizer in your PATH or set the environment var `LLVM_SYMBOLIZER_PATH` to point to it):
0  firtool                  0x000000010476353c llvm::sys::PrintStackTrace(llvm::raw_ostream&, int) + 56
1  firtool                  0x00000001047619bc llvm::sys::RunSignalHandlers() + 112
2  firtool                  0x0000000104763ba4 SignalHandler(int, __siginfo*, void*) + 312
3  libsystem_platform.dylib 0x000000019150c624 _sigtramp + 56
4  libsystem_pthread.dylib  0x00000001914d288c pthread_kill + 296
5  libsystem_c.dylib        0x00000001913dbc60 abort + 124
6  libsystem_c.dylib        0x00000001913daeec err + 0
7  firtool                  0x000000010522d014 circt::ExportVerilog::isExpressionEmittedInline(mlir::Operation*, circt::LoweringOptions const&) (.cold.4) + 0
8  firtool                  0x00000001048a2c94 (anonymous namespace)::InjectDUTHierarchy::runOnOperation() + 5980
9  firtool                  0x00000001051d8784 mlir::detail::OpToOpPassAdaptor::run(mlir::Pass*, mlir::Operation*, mlir::AnalysisManager, bool, unsigned int) + 588
10 firtool                  0x00000001051d8f8c mlir::detail::OpToOpPassAdaptor::runPipeline(mlir::OpPassManager&, mlir::Operation*, mlir::AnalysisManager, bool, unsigned int, mlir::PassInstrumentor*, mlir::PassInstrumentation::PipelineParentInfo const*) + 312
11 firtool                  0x00000001051d9ee0 mlir::detail::OpToOpPassAdaptor::runOnOperationAsyncImpl(bool) + 1652
12 firtool                  0x00000001051d8ae4 mlir::detail::OpToOpPassAdaptor::run(mlir::Pass*, mlir::Operation*, mlir::AnalysisManager, bool, unsigned int) + 1452
13 firtool                  0x00000001051dacdc mlir::PassManager::run(mlir::Operation*) + 1112
14 firtool                  0x00000001046998b0 processBuffer(mlir::MLIRContext&, circt::firtool::FirtoolOptions&, mlir::TimingScope&, llvm::SourceMgr&, std::__1::optional<std::__1::unique_ptr<llvm::ToolOutputFile, std::__1::default_delete<llvm::ToolOutputFile>>>&) + 3388
15 firtool                  0x0000000104698aa8 processInputSplit(mlir::MLIRContext&, circt::firtool::FirtoolOptions&, mlir::TimingScope&, std::__1::unique_ptr<llvm::MemoryBuffer, std::__1::default_delete<llvm::MemoryBuffer>>, std::__1::optional<std::__1::unique_ptr<llvm::ToolOutputFile, std::__1::default_delete<llvm::ToolOutputFile>>>&) + 380
16 firtool                  0x00000001046944a0 executeFirtool(mlir::MLIRContext&, circt::firtool::FirtoolOptions&) + 936
17 firtool                  0x000000010469209c main + 336
18 dyld                     0x0000000191132b98 start + 6076
zsh: abort      firtool  -verbose-pass-executions
```
