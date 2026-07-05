# MTH.R-2026-1151 — result `WMSpec.dyadicToRat_cast` [T1]

`theorem` in `WMSpec.ExecutableGuard`; polarity universal. Discharges MTH.C-2026-1151. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.dyadicToRat_cast : ∀ (d : TorchLean.Floats.IEEE754.IEEE32Exec.Dyadic),
  ↑(WMSpec.dyadicToRat d) = TorchLean.Floats.IEEE754.IEEE32Exec.dyadicToReal d
```
