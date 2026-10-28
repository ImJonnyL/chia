# Issue #2266: [FIRTOOL] -verilog flag should not include firrtl_black_box_resource_files.f

- State: open
- Author: lsteveol
- Created: 2021-12-01T14:12:03Z
- Updated: 2024-02-12T16:26:41Z
- URL: https://github.com/llvm/circt/issues/2266

## Body

As discussed in https://github.com/llvm/circt/issues/2254 , `firtool -verilog` will append the contents of the `firrtl_black_box_resource_files.f` file into the output verilog file. This results in non-compliant verilog. Since these BlackBox modules are included in the output verilog the `firrtl_black_box_resource_files.f` doesn't appear to be useful anyways.

`-split-verilog` does not have this issue.


Below is an example

```verilog
//previous valid verilog
endmodule
    	// /home/lsteveol/projects/wlink_test/wav-wlink-hw/output-chirrtl/Wlink.fir:33116:13

// ----- 8< ----- FILE "firrtl_black_box_resource_files.f" ----- 8< -----

./wav_latch_model.sv
./wlink_WavFIFOMem.v
./wlink_WavFIFOPtrLogic.v
./wlink_WavReplayFIFOPtrLogic.v
./wlink_wlink_axi_arFC_a2l_93x8.v
./wlink_wlink_axi_arFC_l2a_93x8.v
./wlink_wlink_axi_awFC_a2l_93x8.v
./wlink_wlink_axi_awFC_l2a_93x8.v
./wlink_wlink_axi_bFC_a2l_6x8.v
./wlink_wlink_axi_bFC_l2a_6x8.v
./wlink_wlink_axi_rFC_a2l_39x32.v
./wlink_wlink_axi_rFC_l2a_39x32.v
./wlink_wlink_axi_wFC_a2l_37x32.v
./wlink_wlink_axi_wFC_l2a_37x32.v	// /home/lsteveol/projects/wlink_test/wav-wlink-hw/output-chirrtl/Wlink.fir:2:1

EOF
```

## Comments (2)

### Comment by sashimi-yzh — 2023-06-24T08:55:04Z

This problem still exists in firtool 1.44.0.

### Comment by darthscsi — 2024-02-12T16:26:40Z

`-verilog` is only suitable for writing test-cases in the compile, it will not in general produce valid verilog.  I intend to hide the option at some point in the future.
