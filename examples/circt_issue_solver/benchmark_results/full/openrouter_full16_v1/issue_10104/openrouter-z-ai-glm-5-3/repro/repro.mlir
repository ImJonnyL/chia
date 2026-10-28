firrtl.circuit "Foo" {
  firrtl.layer @Bar bind attributes {sym_visibility = "private"} {
  }
  firrtl.module @Foo() {
    %c0 = firrtl.constant 0 : !firrtl.uint<1>
    firrtl.when %c0 : !firrtl.uint<1> {
      firrtl.layerblock @Bar {
        %0 = firrtl.int.ltl.implication %c0, %c0 : (!firrtl.uint<1>, !firrtl.uint<1>) -> !firrtl.uint<1>
        firrtl.int.verif.assert %0, %c0 : !firrtl.uint<1>, !firrtl.uint<1>
      }
      firrtl.layerblock @Bar {
        %1 = firrtl.int.ltl.implication %c0, %c0 : (!firrtl.uint<1>, !firrtl.uint<1>) -> !firrtl.uint<1>
        firrtl.int.verif.assert %1, %c0 : !firrtl.uint<1>, !firrtl.uint<1>
      }
    }
  }
}
