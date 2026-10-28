// Minimal repro for https://github.com/llvm/circt/issues/7949
// ([DCToHW] Pass creates invalid ESI connections).
//
// A token forked where one fork output is packed into a module-output value
// and the other is packed into a value that is unpacked again downstream
// makes lower-dc-to-hw emit an `esi.wrap.vr` whose channel result has more
// than one consumer, failing verification with:
//   error: 'esi.wrap.vr' op channels must have at most one consumer
hw.module @ops(in %arg0 : !dc.value<i32>, in %clk : !seq.clock {dc.clock}, in %rst : i1 {dc.reset}, out out0 : !dc.value<i32>) {
  %token, %output = dc.unpack %arg0 : !dc.value<i32>
  %0:2 = dc.fork [2] %token
  %1 = dc.pack %0#0, %output : i32
  %2 = dc.pack %0#1, %output : i32
  %token_0, %output_1 = dc.unpack %2 : !dc.value<i32>
  dc.sink %token_0
  hw.output %1 : !dc.value<i32>
}
