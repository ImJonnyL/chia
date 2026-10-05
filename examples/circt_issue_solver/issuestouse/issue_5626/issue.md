# Issue #5626: [FIRRTL][LowerToHW] HW::ModuleNamespace does not work with FIRRTL operations

- State: open
- Author: youngar
- Created: 2023-07-18T20:42:15Z
- Updated: 2023-08-08T18:08:09Z
- Labels: FIRRTL
- URL: https://github.com/llvm/circt/issues/5626

## Body

```mlir
firrtl.circuit "Test" {
  firrtl.module @Test() {
    %w1 = firrtl.wire sym @__Test__w2 : !firrtl.uint<1>
    %w2 = firrtl.wire {annotations = [{class = "firrtl.transforms.DontTouchAnnotation"}]} : !firrtl.uint<1>
  }
}
```

Running: `./bin/circt-opt -pass-pipeline="builtin.module(lower-firrtl-to-hw)" ./test.mlir` gives:

```mlir
module {
  hw.module @Test() {
    %z_i1 = sv.constantZ : i1
    %w1 = hw.wire %z_i1 sym @__Test__w2  : i1
    %w2 = hw.wire %z_i1 sym @__Test__w2  : i1
    hw.output
  }
}
```
The problem is that both `w1` and `w2` now have the same `inner_sym` `@__Test__w2`.

Part of the problem is that we are using the `hw::ModuleNamespace` to create symbols, but this namespace is not properly populated on FIRRTL ops.   This partly comes down to the fact that FIRRTL uses `InnerSymAttr` for `inner_sym`s, and HW uses `StringAttrs`.

Also, there are some places in `LowerToHW` where we fail to use the `moduleNamespace` at all when picking an inner symbol name.

## Comments (2)

### Comment by dtzSiFive — 2023-08-08T17:49:20Z

On 1.50.0 or so, I'm seeing this output instead:

```mlir
module {
  hw.module @Test() {
    %z_i1 = sv.constantZ : i1
    %w1 = hw.wire %z_i1 sym @__Test__w2  : i1
    %w2 = hw.wire %z_i1 sym @__Test__w2_0  : i1
    hw.output
  }
```

Think this was fixed by https://github.com/llvm/circt/pull/5703 ?

### Comment by dtzSiFive — 2023-08-08T18:08:09Z

The reported example works now (and the title issue), but:

> Also, there are some places in LowerToHW where we fail to use the moduleNamespace at all when picking an inner symbol name.

Is still outstanding. 
