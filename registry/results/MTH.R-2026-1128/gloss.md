# MTH.R-2026-1128 — result `WMSpec.spreadGuard_eq_iff` [T1]

`theorem` in `WMSpec.ExecutableGuard`; polarity universal. Discharges MTH.C-2026-1128. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.spreadGuard_eq_iff : ∀ (x y : Unit × (Fin 2 → TorchLean.Floats.IEEE754.IEEE32Exec)),
  WMSpec.spreadGuard x = WMSpec.spreadGuard y ↔ WMSpec.spreadQ x = WMSpec.spreadQ y
```
