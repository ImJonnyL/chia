firrtl.circuit "Test" {
  firrtl.module @Sub() {}
  firrtl.module @Test() {
    %w1 = firrtl.wire sym @sym : !firrtl.uint<1>
    %s = firrtl.instance sub sym @sym @Sub()
  }
}
