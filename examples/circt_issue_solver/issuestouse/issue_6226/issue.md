# Issue #6226: Mixed ssaName and true name fails to parse correctly

- State: open
- Author: darthscsi
- Created: 2023-09-29T21:51:37Z
- Updated: 2026-03-06T03:04:00Z
- Labels: bug
- URL: https://github.com/llvm/circt/issues/6226

## Body

See Bar3 below.
circt-opt foo.mlir --mlir-print-op-generic

```
hw.module @Bar0(in %0: i1) {
}

hw.module @Bar1(in %a: i1) {
}

hw.module @Bar2(in %0 "space here" : i1) {
}

hw.module @Bar3(in %b "space here" : i1) {
}
```

## Comments (3)

### Comment by thomasnormal — 2026-03-03T18:13:10Z

Rechecked on current main (March 3, 2026 UTC) and could not reproduce this parse failure anymore.

I tested all issue variants:
```mlir
hw.module @Bar0(in %0: i1) {}
hw.module @Bar1(in %a: i1) {}
hw.module @Bar2(in %0 "space here" : i1) {}
hw.module @Bar3(in %b "space here" : i1) {}
```

Command:
- `build_test/bin/circt-opt /tmp/issue6226.mlir --mlir-print-op-generic`

Current behavior:
- Exit code 0; all forms parse/print successfully.

So this appears fixed/stale in current tree.


### Comment by thomasnormal — 2026-03-03T20:09:35Z

Follow-up: added dedicated in-tree regression coverage on `thomasnormal/circt` `main` in commit `51af860601`.

New test:
- `test/Dialect/HW/mixed-ssa-true-name-roundtrip.mlir`

What it guards:
- mixed SSA names and explicit quoted true names on `hw.module` ports parse/print/parse correctly
- includes the issue shapes:
  - `%0`
  - `%a`
  - `%0 "space here"`
  - `%b "space here"`

Validation:
- `build_test/bin/llvm-lit -sv -j1 test/Dialect/HW/mixed-ssa-true-name-roundtrip.mlir test/Dialect/HW/basic.mlir test/Dialect/HW/modules.mlir`
- result: `3 passed`


### Comment by seldridge — 2026-03-06T03:04:00Z

@thomasnormal, @thomasahle: Due to current CIRCT project policy, we are unable to accept patches from the `thomasnormal/circt` fork.

For others: please do not upstream any patches from the `thomasnormal/circt` fork. Additionally, recognize that any comments made by the @thomasnormal account appear to be from one or more AI agents.

For more information, please see this Discourse post: https://discourse.llvm.org/t/circt-project-policy-on-contributions-from-thomasnormal-circt-fork/90075

