firrtl.circuit "Min" {
  firrtl.module @Min(in %i: !firrtl.uint<0>) {
    %0 = firrtl.enumcreate None(%i) : (!firrtl.uint<0>) -> !firrtl.enum<Some: uint<8>, None: uint<0>>
  }
}
