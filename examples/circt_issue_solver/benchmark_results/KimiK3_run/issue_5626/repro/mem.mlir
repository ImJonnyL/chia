firrtl.circuit "Test" {
  firrtl.module @Test(in %clock: !firrtl.clock) {
    %m2 = firrtl.wire {annotations = [{class = "firrtl.transforms.DontTouchAnnotation"}]} : !firrtl.uint<1>
    %mem_r, %mem_w = firrtl.mem sym @m2 Undefined {depth = 4 : i64, name = "mem", portNames = ["r", "w"], readLatency = 0 : i32, writeLatency = 1 : i32} : !firrtl.bundle<addr: uint<2>, en: uint<1>, clk: clock, data flip: uint<8>>, !firrtl.bundle<addr: uint<2>, en: uint<1>, clk: clock, data: uint<8>, mask: uint<1>>
    %0 = firrtl.subfield %mem_r[clk] : !firrtl.bundle<addr: uint<2>, en: uint<1>, clk: clock, data flip: uint<8>>
    %1 = firrtl.subfield %mem_r[en] : !firrtl.bundle<addr: uint<2>, en: uint<1>, clk: clock, data flip: uint<8>>
    %2 = firrtl.subfield %mem_r[addr] : !firrtl.bundle<addr: uint<2>, en: uint<1>, clk: clock, data flip: uint<8>>
    firrtl.matchingconnect %0, %clock : !firrtl.clock
    %c1_ui1 = firrtl.constant 1 : !firrtl.uint<1>
    firrtl.matchingconnect %1, %c1_ui1 : !firrtl.uint<1>
    %c0_ui2 = firrtl.constant 0 : !firrtl.uint<2>
    firrtl.matchingconnect %2, %c0_ui2 : !firrtl.uint<2>
    %w_clk = firrtl.subfield %mem_w[clk] : !firrtl.bundle<addr: uint<2>, en: uint<1>, clk: clock, data: uint<8>, mask: uint<1>>
    %w_en = firrtl.subfield %mem_w[en] : !firrtl.bundle<addr: uint<2>, en: uint<1>, clk: clock, data: uint<8>, mask: uint<1>>
    %w_addr = firrtl.subfield %mem_w[addr] : !firrtl.bundle<addr: uint<2>, en: uint<1>, clk: clock, data: uint<8>, mask: uint<1>>
    %w_data = firrtl.subfield %mem_w[data] : !firrtl.bundle<addr: uint<2>, en: uint<1>, clk: clock, data: uint<8>, mask: uint<1>>
    %w_mask = firrtl.subfield %mem_w[mask] : !firrtl.bundle<addr: uint<2>, en: uint<1>, clk: clock, data: uint<8>, mask: uint<1>>
    firrtl.matchingconnect %w_clk, %clock : !firrtl.clock
    firrtl.matchingconnect %w_en, %c1_ui1 : !firrtl.uint<1>
    firrtl.matchingconnect %w_addr, %c0_ui2 : !firrtl.uint<2>
    %c0_ui8 = firrtl.constant 0 : !firrtl.uint<8>
    firrtl.matchingconnect %w_data, %c0_ui8 : !firrtl.uint<8>
    firrtl.matchingconnect %w_mask, %c1_ui1 : !firrtl.uint<1>
  }
}
