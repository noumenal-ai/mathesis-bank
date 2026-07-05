# MTH.R-2026-1020 — result `TLT.NonIdentifiability.not_factorThrough_of_collapse_real` [T0]

`theorem` in `WMSpec.NonIdentifiability.Apparatus`; polarity existential. Discharges MTH.C-2026-1020. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.not_factorThrough_of_collapse_real : ∀ {S : Type u_1} {Z : Type u_2} (E : S → Z) (T : S → ℝ) {s₁ s₂ : S},
  E s₁ = E s₂ → T s₁ ≠ T s₂ → ¬∃ g, ∀ (s : S), T s = g (E s)
```
