# MTH.R-2026-1155 — result `WMSpec.toRat_cast` [T1]

`theorem` in `WMSpec.ExecutableGuard`; polarity universal. Discharges MTH.C-2026-1155. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.toRat_cast : ∀ {x : TorchLean.Floats.IEEE754.IEEE32Exec} {d : TorchLean.Floats.IEEE754.IEEE32Exec.Dyadic},
  x.toDyadic? = some d → ↑(WMSpec.toRat x) = x.toReal
```
