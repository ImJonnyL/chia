firrtl.circuit "Test" {
  firrtl.module @Test() {
    %w1 = firrtl.wire sym @sym : !firrtl.uint<1>
    %view, %ref__io = firrtl.ref.send %w1 : !firrtl.uint<1>
    %0 = firrtl.ref.resolve %ref__io : !firrtl.ref<uint<1>>
  }
}
