firrtl.circuit "Foo" {
  firrtl.layer @Bar bind {
  }
  firrtl.module @Foo() {
    %c0_ui1 = firrtl.constant 0 : !firrtl.uint<1>
    firrtl.when %c0_ui1 : !firrtl.uint<1> {
      firrtl.layerblock @Bar {
        %0 = firrtl.int.ltl.implication %c0_ui1, %c0_ui1 : (!firrtl.uint<1>, !firrtl.uint<1>) -> !firrtl.uint<1>
        firrtl.int.verif.assert %0, %c0_ui1 : !firrtl.uint<1>, !firrtl.uint<1>
      }
      firrtl.layerblock @Bar {
        %1 = firrtl.int.ltl.implication %c0_ui1, %c0_ui1 : (!firrtl.uint<1>, !firrtl.uint<1>) -> !firrtl.uint<1>
        firrtl.int.verif.assert %1, %c0_ui1 : !firrtl.uint<1>, !firrtl.uint<1>
      }
    }
  }
}
