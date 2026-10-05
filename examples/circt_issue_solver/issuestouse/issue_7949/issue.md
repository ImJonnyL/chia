# Issue #7949: [DCToHW] Pass creates invalid ESI connections

- State: open
- Author: teqdruid
- Created: 2024-12-04T23:01:14Z
- Updated: 2024-12-09T19:41:09Z
- Labels: DC
- URL: https://github.com/llvm/circt/issues/7949

## Body

```
hw.module @AxiMMIO(in %data : !dc.value<i64>, in %read_address : !dc.value<i20>, in %write_address : !dc.value<i20>, in %write_data : !dc.value<i32>, in %clk : !seq.clock {dc.clock}, in %rst : i1 {dc.reset}, out cmd : !dc.value<!hw.struct<write: i1, offset: ui32, data: i64>>, out read_data : !dc.value<!hw.struct<data: i32, resp: i2>>) {
  %token, %output = dc.unpack %write_address : !dc.value<i20>
  %0:2 = dc.fork [2] %token 
  %1 = dc.pack %0#0, %output : i20
  %2 = dc.pack %0#1, %output : i20
  %token_0, %output_1 = dc.unpack %read_address : !dc.value<i20>
  %3:2 = dc.fork [2] %token_0 
  %4 = dc.pack %3#0, %output_1 : i20
  %5 = dc.pack %3#1, %output_1 : i20
  %c0_i2 = hw.constant 0 : i2
  %true = hw.constant true
  %c0_i64 = hw.constant 0 : i64
  %c0_i12 = hw.constant 0 : i12
  %false = hw.constant false
  %c-8_i20 = hw.constant -8 : i20
  %6 = dc.source
  %token_2, %output_3 = dc.unpack %5 : !dc.value<i20>
  %7 = dc.join %token_2, %6
  %8 = comb.and bin %output_3, %c-8_i20 : i20
  %9 = dc.source
  %10 = dc.source
  %11 = dc.join %10, %7
  %12 = comb.concat %c0_i12, %8 : i12, i20
  %13 = hwarith.cast %12 : (i32) -> ui32
  %14 = dc.source
  %15 = dc.join %9, %11, %14
  %16 = hw.struct_create (%false, %13, %c0_i64) : !hw.struct<write: i1, offset: ui32, data: i64>
  %token_4, %output_5 = dc.unpack %2 : !dc.value<i20>
  %17 = comb.extract %output_5 from 2 : (i20) -> i1
  %token_6, %output_7 = dc.unpack %write_data : !dc.value<i32>
  %18 = dc.join %token_4, %token_6
  %19 = dc.pack %18, %17 : i1
  %trueToken, %falseToken = dc.branch %19
  %20 = dc.join %trueToken, %falseToken
  %21 = comb.replicate %output_7 : (i32) -> i64
  %22 = dc.source
  %23 = dc.source
  %token_8, %output_9 = dc.unpack %1 : !dc.value<i20>
  %24 = dc.join %token_8, %23
  %25 = comb.and bin %output_9, %c-8_i20 : i20
  %26 = dc.source
  %27 = dc.join %26, %24
  %28 = comb.concat %c0_i12, %25 : i12, i20
  %29 = hwarith.cast %28 : (i32) -> ui32
  %30 = dc.join %22, %27, %20
  %31 = hw.struct_create (%true, %29, %21) : !hw.struct<write: i1, offset: ui32, data: i64>
  %32 = dc.merge %30, %15
  %token_10, %output_11 = dc.unpack %32 : !dc.value<i1>
  %33:2 = dc.fork [2] %token_10 
  %34 = dc.pack %33#0, %output_11 : i1
  %35 = dc.pack %33#1, %output_11 : i1
  %token_12, %output_13 = dc.unpack %35 : !dc.value<i1>
  %36 = arith.select %output_13, %31, %16 : !hw.struct<write: i1, offset: ui32, data: i64>
  %37 = dc.pack %token_12, %36 : !hw.struct<write: i1, offset: ui32, data: i64>
  %token_14, %output_15 = dc.unpack %34 : !dc.value<i1>
  %token_16, %output_17 = dc.unpack %data : !dc.value<i64>
  %38 = dc.join %token_14, %token_16
  %39 = dc.pack %38, %output_15 : i1
  %trueToken_18, %falseToken_19 = dc.branch %39
  dc.sink %trueToken_18
  %40:2 = dc.fork [2] %falseToken_19 
  %41 = comb.extract %output_17 from 0 : (i64) -> i32
  %42 = comb.extract %output_17 from 32 : (i64) -> i32
  %token_20, %output_21 = dc.unpack %4 : !dc.value<i20>
  %43 = comb.extract %output_21 from 2 : (i20) -> i1
  %44 = dc.join %token_20, %40#0, %40#1
  %45 = comb.mux bin %43, %42, %41 {sv.namehint = "mux_None_in0_in1"} : i32
  %46 = dc.source
  %47 = dc.join %44, %46
  %48 = hw.struct_create (%45, %c0_i2) : !hw.struct<data: i32, resp: i2>
  %49 = dc.pack %47, %48 : !hw.struct<data: i32, resp: i2>
  hw.output %37, %49 : !dc.value<!hw.struct<write: i1, offset: ui32, data: i64>>, !dc.value<!hw.struct<data: i32, resp: i2>>
}
```

This has already been through `--dc-materialize-forks-sinks`.

```
$ circt-opt dc.mlir --lower-dc-to-hw
chanOut: loc("dc.mlir":4:10)
dc.mlir:4:10: error: 'esi.wrap.vr' op only supports zero or one use
  %0:2 = dc.fork [2] %token
         ^
dc.mlir:4:10: note: see current operation: %5:2 = "esi.wrap.vr"(%4, %14) : (i0, i1) -> (!esi.channel<i0>, i1)
```

Sorry I haven't been able to simplify the example further.

## Comments (5)

### Comment by luisacicolini — 2024-12-05T18:04:21Z

Hello! I am running into the same issue, with a potentially simpler example that hopefully helps: 
- starting from the following example in handshake: 
```llvm
    handshake.func @ops(%arg0: i32, %arg1: i32, %arg2: i32, %arg3: i32, %clk: i32, %rst: i32) -> (i32, none) {
    %arg5 = merge %arg0, %arg1 : i32
    %arg23 = join %arg5 : i32
    return %arg5, %arg23: i32, none
}
```
- lowering to DC (`--lower-handshake-to-dc`): 
```llvm
  module {
  hw.module @ops(in %arg0 : !dc.value<i32>, in %arg1 : !dc.value<i32>, in %arg2 : !dc.value<i32>, in %arg3 : !dc.value<i32>, in %clk : !dc.value<i32>, in %rst : !dc.value<i32>, in %clk_0 : !seq.clock {dc.clock}, in %rst_0 : i1 {dc.reset}, out out0 : !dc.value<i32>, out out1 : !dc.token) {
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
```
- materializing forks and sinks (`--dc-materialize-forks-sinks`): 
```llvm
  module {
  hw.module @ops(in %arg0 : !dc.value<i32>, in %arg1 : !dc.value<i32>, in %arg2 : !dc.value<i32>, in %arg3 : !dc.value<i32>, in %clk : !dc.value<i32>, in %rst : !dc.value<i32>, in %clk_0 : !seq.clock {dc.clock}, in %rst_0 : i1 {dc.reset}, out out0 : !dc.value<i32>, out out1 : !dc.token) {
    %token, %output = dc.unpack %rst : !dc.value<i32>
    dc.sink %token
    %token_0, %output_1 = dc.unpack %clk : !dc.value<i32>
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
```
- attempting to lower to hw (`--lower-dc-to-hw`) yields the following error:
```chanOut: loc("../hs-dc-hw-examples/long-datapath-materialized-dc.mlir":14:29)
../hs-dc-hw-examples/long-datapath-materialized-dc.mlir:14:29: error: 'esi.wrap.vr' op only supports zero or one use
    %token_10, %output_11 = dc.unpack %0 : !dc.value<i1>
                            ^
../hs-dc-hw-examples/long-datapath-materialized-dc.mlir:14:29: note: see current operation: %37:2 = "esi.wrap.vr"(%36, %35#1) : (i0, i1) -> (!esi.channel<i0>, i1
```


### Comment by mortbopet — 2024-12-05T18:44:34Z

It's by no means a fix to this issue, since we should be able to successfully lower any valid DC program to HW, assuming it has materialized forks/sinks...

... _but_, i re-added some old disabled canonicalization patterns (that were previously folders) + a few new ones.
And, with those in tree, running canonicalization prior to `lower-dc-to-hw`, allows both @teqdruid and @luisacicolini's examples to lower successfully to HW.

PR is here: https://github.com/llvm/circt/pull/7952

### Comment by luisacicolini — 2024-12-05T18:50:44Z

thanks a lot!!

### Comment by teqdruid — 2024-12-09T18:43:23Z

@mortbopet Now I cannot run the canonicalizer in between materialize and lower:

```
$ circt-opt dc2.mlir --canonicalize --dc-materialize-forks-sinks --canonicalize --lower-dc-to-hw
dc2.mlir:59:35: error: 'dc.branch' op DCToHW: value %29:2 = "dc.branch"(%28) : (!dc.value<i1>) -> (!dc.token, !dc.token) is unused.
  %trueToken_18, %falseToken_19 = dc.branch %39

dc2.mlir:59:35: note: see current operation: %29:2 = "dc.branch"(%28) : (!dc.value<i1>) -> (!dc.token, !dc.token)
dc2.mlir:0:0: error: 'builtin.module' op DCToHW: failed to verify that all values are used exactly once. Remember to run the fork/sink materialization pass before HW lowering.
dc2.mlir:0:0: note: see current operation:
"builtin.module"() ({
  "hw.module"() <{module_type = !hw.modty<input data : !dc.value<i64>, input read_address : !dc.value<i20>, input write_address : !dc.value<i20>, input write_data : !dc.value<i32>, input clk : !seq.clock, input rst : i1, output cmd : !dc.value<!hw.struct<write: i1, offset: ui32, data: i64>>, output read_data : !dc.value<!hw.struct<data: i32, resp: i2>>>, parameters = [], per_port_attrs = [{}, {}, {}, {}, {dc.clock}, {dc.reset}, {}, {}], result_locs = [loc("dc2.mlir":1:213), loc("dc2.mlir":1:282)], sym_name = "AxiMMIO"}> ({
  ^bb0(%arg0: !dc.value<i64>, %arg1: !dc.value<i20>, %arg2: !dc.value<i20>, %arg3: !dc.value<i32>, %arg4: !seq.clock, %arg5: i1):
    %0 = "hw.constant"() <{value = -8 : i20}> : () -> i20
    %1 = "hw.constant"() <{value = false}> : () -> i1
    %2 = "hw.constant"() <{value = 0 : i12}> : () -> i12
    %3 = "hw.constant"() <{value = 0 : i64}> : () -> i64
    %4 = "hw.constant"() <{value = true}> : () -> i1
    %5 = "hw.constant"() <{value = 0 : i2}> : () -> i2
    %6:2 = "dc.unpack"(%arg2) : (!dc.value<i20>) -> (!dc.token, i20)
    %7:2 = "dc.fork"(%6#0) : (!dc.token) -> (!dc.token, !dc.token)
    %8:2 = "dc.unpack"(%arg1) : (!dc.value<i20>) -> (!dc.token, i20)
    %9:2 = "dc.fork"(%8#0) : (!dc.token) -> (!dc.token, !dc.token)
    %10 = "comb.and"(%8#1, %0) <{twoState}> : (i20, i20) -> i20
    %11 = "comb.concat"(%2, %10) : (i12, i20) -> i32
    %12 = "hwarith.cast"(%11) : (i32) -> ui32
    %13 = "hw.struct_create"(%1, %12, %3) : (i1, ui32, i64) -> !hw.struct<write: i1, offset: ui32, data: i64>
    %14:2 = "dc.unpack"(%arg3) : (!dc.value<i32>) -> (!dc.token, i32)
    %15 = "comb.replicate"(%14#1) : (i32) -> i64
    %16 = "comb.and"(%6#1, %0) <{twoState}> : (i20, i20) -> i20
    %17 = "comb.concat"(%2, %16) : (i12, i20) -> i32
    %18 = "hwarith.cast"(%17) : (i32) -> ui32
    %19 = "dc.join"(%7#0, %7#1, %14#0) : (!dc.token, !dc.token, !dc.token) -> !dc.token
    %20 = "hw.struct_create"(%4, %18, %15) : (i1, ui32, i64) -> !hw.struct<write: i1, offset: ui32, data: i64>
    %21 = "dc.merge"(%19, %9#1) : (!dc.token, !dc.token) -> !dc.value<i1>
    %22:2 = "dc.unpack"(%21) : (!dc.value<i1>) -> (!dc.token, i1)
    %23:2 = "dc.fork"(%22#0) : (!dc.token) -> (!dc.token, !dc.token)
    %24 = "arith.select"(%22#1, %20, %13) : (i1, !hw.struct<write: i1, offset: ui32, data: i64>, !hw.struct<write: i1, offset: ui32, data: i64>) -> !hw.struct<write: i1, offset: ui32, data: i64>
    %25 = "dc.pack"(%23#1, %24) : (!dc.token, !hw.struct<write: i1, offset: ui32, data: i64>) -> !dc.value<!hw.struct<write: i1, offset: ui32, data: i64>>
    %26:2 = "dc.unpack"(%arg0) : (!dc.value<i64>) -> (!dc.token, i64)
    %27 = "dc.join"(%23#0, %26#0) : (!dc.token, !dc.token) -> !dc.token
    %28 = "dc.pack"(%27, %22#1) : (!dc.token, i1) -> !dc.value<i1>
    %29:2 = "dc.branch"(%28) : (!dc.value<i1>) -> (!dc.token, !dc.token)
    %30:2 = "dc.fork"(%29#1) : (!dc.token) -> (!dc.token, !dc.token)
    %31 = "comb.extract"(%26#1) <{lowBit = 0 : i32}> : (i64) -> i32
    %32 = "comb.extract"(%26#1) <{lowBit = 32 : i32}> : (i64) -> i32
    %33 = "comb.extract"(%8#1) <{lowBit = 2 : i32}> : (i20) -> i1
    %34 = "dc.join"(%9#0, %30#0, %30#1) : (!dc.token, !dc.token, !dc.token) -> !dc.token
    %35 = "comb.mux"(%33, %32, %31) <{twoState}> {sv.namehint = "mux_None_in0_in1"} : (i1, i32, i32) -> i32
    %36 = "hw.struct_create"(%35, %5) : (i32, i2) -> !hw.struct<data: i32, resp: i2>
    %37 = "dc.pack"(%34, %36) : (!dc.token, !hw.struct<data: i32, resp: i2>) -> !dc.value<!hw.struct<data: i32, resp: i2>>
    "hw.output"(%25, %37) : (!dc.value<!hw.struct<write: i1, offset: ui32, data: i64>>, !dc.value<!hw.struct<data: i32, resp: i2>>) -> ()
  }) : () -> ()
}) : () -> ()
```

If I don't run the canonicalizer in between, it doesn't error out.

### Comment by teqdruid — 2024-12-09T19:41:08Z

OK. With that PR I think I figured out the hack:

```py
      "builtin.module(lower-handshake-to-dc)",
      "builtin.module(dc-materialize-forks-sinks)",
      "builtin.module(canonicalize)",
      "builtin.module(dc-materialize-forks-sinks)",
      "builtin.module(lower-dc-to-hw)",
```

That sequence seems to work.

