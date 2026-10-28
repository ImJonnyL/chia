hw.module @top(in %arg0 : !dc.value<i32>, in %clk : !seq.clock {dc.clock}, in %rst : i1 {dc.reset}, out out0 : !dc.value<i32>) {
  %t, %v = dc.unpack %arg0 : !dc.value<i32>
  %c = hw.constant 0 : i32
  %p = dc.pack %t, %c : i32
  %t2, %v2 = dc.unpack %p : !dc.value<i32>
  %a = dc.pack %t2, %v2 : i32
  hw.output %a : !dc.value<i32>
}
