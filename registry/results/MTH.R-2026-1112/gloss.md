# MTH.R-2026-1112 — result `TLT.NonIdentifiability.JEPA.jepa_target_not_factorsThrough` [T0]

`theorem` in `WMSpec.NonIdentifiability.JepaBoundary`; polarity existential. Discharges MTH.C-2026-1112. Kernel-verified (whole-theory replay); axioms [].

```
TLT.NonIdentifiability.JEPA.jepa_target_not_factorsThrough : ∀ {Input Context Target : Type} (E : Input → Context) (T : Input → Target) {i₁ i₂ : Input},
  E i₁ = E i₂ → T i₁ ≠ T i₂ → ¬Function.FactorsThrough T E
```
