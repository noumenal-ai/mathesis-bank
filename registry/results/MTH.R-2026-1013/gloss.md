# MTH.R-2026-1013 — result `WMSpec.varQ_eq_zero_iff` [T0]

`theorem` in `WMSpec.GuardFamilies`; polarity universal. Discharges MTH.C-2026-1013. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.varQ_eq_zero_iff : ∀ {n : ℕ} (v : Fin n → ℚ), WMSpec.varQ v = 0 ↔ ∀ (i : Fin n), ↑n * v i = ∑ j, v j
```
