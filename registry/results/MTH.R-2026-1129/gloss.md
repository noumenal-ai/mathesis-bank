# MTH.R-2026-1129 — result `TLT.NonIdentifiability.not_factorThrough_of_collapse` [T0]

`theorem` in `WMSpec.NonIdentifiability.Apparatus`; polarity existential. Discharges MTH.C-2026-1129. Kernel-verified (whole-theory replay); axioms [].

```
TLT.NonIdentifiability.not_factorThrough_of_collapse : ∀ {S : Type u_1} {Z : Type u_2} {W : Type u_3} (E : S → Z) (T : S → W) {s₁ s₂ : S},
  E s₁ = E s₂ → T s₁ ≠ T s₂ → ¬∃ g, ∀ (s : S), T s = g (E s)
```
