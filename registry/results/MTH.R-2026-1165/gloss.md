# MTH.R-2026-1165 — result `TLT.NonIdentifiability.not_factorThrough_of_collapse_bool` [T0]

`theorem` in `WMSpec.NonIdentifiability.Apparatus`; polarity existential. Discharges MTH.C-2026-1165. Kernel-verified (whole-theory replay); axioms [].

```
TLT.NonIdentifiability.not_factorThrough_of_collapse_bool : ∀ {S : Type u_1} {Z : Type u_2} (E : S → Z) (T : S → Bool) {s₁ s₂ : S},
  E s₁ = E s₂ → T s₁ ≠ T s₂ → ¬∃ g, ∀ (s : S), T s = g (E s)
```
