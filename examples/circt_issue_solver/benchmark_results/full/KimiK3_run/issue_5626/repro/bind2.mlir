firrtl.circuit "Test" {
  firrtl.module @Sub() {}
  firrtl.module @Test() {
    %w1 = firrtl.wire sym @sym : !firrtl.uint<1>
    firrtl.instance sub {lowerToBind = true} @Sub()
  }
}
