# MTH.R-2026-1099 — result `WMSpec.toRat_of_toDyadic` [T1]

`theorem` in `WMSpec.ExecutableGuard`; polarity universal. Discharges MTH.C-2026-1099. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.toRat_of_toDyadic : ∀ {x : TorchLean.Floats.IEEE754.IEEE32Exec} {d : TorchLean.Floats.IEEE754.IEEE32Exec.Dyadic},
  x.toDyadic? = some d → WMSpec.toRat x = WMSpec.dyadicToRat d
```
