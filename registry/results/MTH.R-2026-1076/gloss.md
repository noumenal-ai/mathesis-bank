# MTH.R-2026-1076 — result `TLT.NonIdentifiability.map_quotient_eq_of_le` [T0]

`theorem` in `WMSpec.NonIdentifiability.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1076. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.map_quotient_eq_of_le : ∀ {S : Type u_1} {r r' : Setoid S},
  r ≤ r' →
    ∀ (P : S → PMF S) {s₁ s₂ : S},
      PMF.map (Quotient.mk r) (P s₁) = PMF.map (Quotient.mk r) (P s₂) →
        PMF.map (Quotient.mk r') (P s₁) = PMF.map (Quotient.mk r') (P s₂)
```
