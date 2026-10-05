# Issue #7531: [Moore] Input triggers assertion in canonicalizer infra

- State: open
- Author: maerhart
- Created: 2024-08-19T20:24:31Z
- Updated: 2026-03-06T03:03:48Z
- Labels: bug, Moore
- URL: https://github.com/llvm/circt/issues/7531

## Body

`circt-opt -canonicalize` triggers an assertion on the following input. Maybe an upstream bug?

`Assertion failed: (mayBeGraphRegion(*op->getParentRegion()) && "expected that op has no uses"), function operator(), file PatternMatch.cpp, line 182.`

```
module {
  moore.module private @snitch_regfile(in %clk_i : !moore.l1, in %raddr_i : !moore.array<2 x l5>, out rdata_o : !moore.array<2 x l32>, in %waddr_i : !moore.array<1 x l5>, in %wdata_i : !moore.array<1 x l32>, in %we_i : !moore.l1) {
    %0 = moore.constant 1 : i32
    %1 = moore.constant 0 : i32
    %rdata_o = moore.variable : <array<2 x l32>>
    moore.procedure always_ff {
      cf.br ^bb1(%1 : !moore.i32)
    ^bb1(%3: !moore.i32):  // 2 preds: ^bb0, ^bb6
      moore.return
    ^bb2:  // no predecessors
      cf.br ^bb4
    ^bb3:  // no predecessors
      cf.br ^bb4
    ^bb4:  // 2 preds: ^bb2, ^bb3
      %4 = moore.add %4, %0 : i32
      cf.br ^bb6
    ^bb5:  // no predecessors
      cf.br ^bb6
    ^bb6:  // 2 preds: ^bb4, ^bb5
      %5 = moore.add %3, %0 : i32
      cf.br ^bb1(%5 : !moore.i32)
    }
    %2 = moore.read %rdata_o : <array<2 x l32>>
    moore.output %2 : !moore.array<2 x l32>
  }
}
```

## Comments (11)

### Comment by mingzheTerapines — 2024-08-28T01:36:35Z

@hailongSun2000 let's have a look.

### Comment by terapines-osc-circt — 2024-08-28T05:59:06Z

Hey, @maerhart. After I modify the code snippet from
```
 ^bb4:  // 2 preds: ^bb2, ^bb3
      %4 = moore.add %4, %0 : i32
      cf.br ^bb6
```
to
```
 ^bb4:  // 2 preds: ^bb2, ^bb3
      %4 = moore.add %3, %0 : i32
      cf.br ^bb6
```
It can work.

### Comment by terapines-osc-circt — 2024-08-28T06:02:02Z

For the Snitch RISC-V Core, does it will generate `%4 = moore.add %4, %0` :thinking:?

### Comment by maerhart — 2024-08-28T12:14:07Z

Not directly, I used `circt-reduce` to get a smaller test case that still shows the same issue.
It's interesting that there's a combinational cycle inside a procedure.

There are a few things that we might want to investigate:
* Why is the comb cycle in the procedure not already rejected by the verifier after parsing (with a proper error message)?
* Is this comb cycle also present in the non-reduced version of snitch? If yes, can this only occur in unreachable blocks? If no, is there a pass in the pipeline that has a bug?
* Check which pass leaves these basic blocks without predecessors in the IR and make sure it doesn't anymore.

### Comment by terapines-osc-circt — 2024-08-29T03:14:42Z

Your example is so special :monocle_face:!
As long as `cf.br` can jump the block containing the comb cycle, MLIR throws a proper error message for the comb cycle. For example:
```
hw.module private @Top(){
  %0 = hw.constant 1 : i32
  llhd.process {
    ^bb1:
      cf.br ^bb2
    ^bb2:
      %1 = comb.add %1, %0 : i32
      llhd.halt
  }
  hw.output
}
```
```
test08.mlir:7:12: error: operand #0 does not dominate this use
      %1 = comb.add %1, %0 : i32
           ^
test08.mlir:7:12: note: see current operation: %1 = "comb.add"(%1, %0) : (i32, i32) -> i32
test08.mlir:7:12: note: operand defined here (op in the same block)
```
I use the `circt-verilog` tool to run the relevant modules(`snitch_regfile`) in different `.sv` files. No error is thrown.
I failed to use `circt-reduce`, but I noticed the `--include=<string>` and `--test=<string>` options. Please teach me how to use it(Thanks in advance :smiley:!), and then I can reproduce this error.


### Comment by terapines-osc-circt — 2024-08-29T06:13:41Z

If I understand correctly, due to `cf` being SSACFG, and the comb cycle like `%4 = moore.add %4, %0`, the `%4` is used(user/use) by itself, so MLIR detects this IR & block which has no predecessors, then the following error is thrown.
![image](https://github.com/user-attachments/assets/92465ebd-cdde-4054-8e8e-4023a71822e8)
How should we suppress this stack dump and substitute it with an error message :thinking:? Or avoid SSACFG containing the comb cycle? WDYT?

### Comment by maerhart — 2024-08-30T12:46:18Z

I think the first thing we should do is find the pass in the circt-verilog pipeline that leaves behind these blocks with no predecessors and make sure that it removes them. They are causing issues at several places, so fixing it at the root is probably the easiest solution for now.

### Comment by thomasnormal — 2026-03-03T12:57:18Z

Rechecked this on current `main`; I could not reproduce the canonicalizer assertion anymore.

I added an in-tree no-crash regression to lock this behavior:
- commit: `c6ec2927cf`
- test: `test/Dialect/Moore/canonicalize-unreachable-self-cycle-no-crash.mlir`

The test uses the issue repro shape (unreachable blocks + self-referential `moore.add`) and verifies `-canonicalize` completes and removes the problematic procedure/add operations.

Validation:
- `build_test/bin/llvm-lit -sv -j1 test/Dialect/Moore/canonicalize-unreachable-self-cycle-no-crash.mlir test/Dialect/Moore/canonicalizers.mlir`


### Comment by thomasnormal — 2026-03-03T18:32:12Z

Rechecked with the issue reproducer on current workspace build:

- `build_test/bin/circt-opt /tmp/issue7531.mlir -canonicalize`

This no longer reproduces the assertion in my environment; the command exits successfully.


### Comment by thomasnormal — 2026-03-03T19:58:36Z

Follow-up: the no-crash regression for this issue shape is now on `thomasnormal/circt` `main` in commit `365c974101`.

Added test:
- `test/Dialect/Moore/canonicalize-unreachable-self-cycle-no-crash.mlir`

Validation:
- `build_test/bin/llvm-lit -sv -j1 test/Dialect/Moore/canonicalize-unreachable-self-cycle-no-crash.mlir test/Dialect/Moore/canonicalizers.mlir` (PASS)


### Comment by seldridge — 2026-03-06T03:03:48Z

@thomasnormal, @thomasahle: Due to current CIRCT project policy, we are unable to accept patches from the `thomasnormal/circt` fork.

For others: please do not upstream any patches from the `thomasnormal/circt` fork. Additionally, recognize that any comments made by the @thomasnormal account appear to be from one or more AI agents.

For more information, please see this Discourse post: https://discourse.llvm.org/t/circt-project-policy-on-contributions-from-thomasnormal-circt-fork/90075

