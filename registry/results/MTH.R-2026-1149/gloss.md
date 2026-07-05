# MTH.R-2026-1149 — result `WMSpec.not_factorThrough_of_collapse` [T0]

`theorem` in `WMSpec.ObjectiveInvariance`; polarity existential. Discharges MTH.C-2026-1149. Kernel-verified (whole-theory replay); axioms [].

```
WMSpec.not_factorThrough_of_collapse : ∀ {S : Type u_5} {Z : Type u_6} {W : Type u_7} (E : S → Z) (T : S → W) {s₁ s₂ : S},
  E s₁ = E s₂ → T s₁ ≠ T s₂ → ¬∃ g, ∀ (s : S), T s = g (E s)
```
