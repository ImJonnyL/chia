module {
  hw.module @top(in %arg0 : !dc.value<i32>, in %clk : !seq.clock {dc.clock}, in %rst : i1 {dc.reset}, out out0 : !dc.value<i32>) {
    %token, %output = dc.unpack %arg0 : !dc.value<i32>
    %0:2 = dc.fork [2] %token 
    %1 = dc.pack %0#1, %output : i32
    dc.sink %0#0
    hw.output %1 : !dc.value<i32>
  }
}

