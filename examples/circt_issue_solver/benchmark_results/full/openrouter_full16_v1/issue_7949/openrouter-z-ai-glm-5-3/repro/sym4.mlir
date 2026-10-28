hw.module @top(in %arg0 : !dc.value<i32>, in %clk : !seq.clock {dc.clock}, in %rst : i1 {dc.reset}, out out0 : !dc.value<i32>) {
  %t, %v = dc.unpack %arg0 : !dc.value<i32>
  %p = dc.pack %t, %v : i32
  hw.output %p : !dc.value<i32>
}
