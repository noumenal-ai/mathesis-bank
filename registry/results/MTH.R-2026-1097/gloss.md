# MTH.R-2026-1097 — result `TLT.NonIdentifiability.no_lipschitz_reading_of_gap` [T0]

`theorem` in `WMSpec.NonIdentifiability.Apparatus`; polarity existential. Discharges MTH.C-2026-1097. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.no_lipschitz_reading_of_gap : ∀ {S : Type u_1} {Z : Type u_2} [inst : PseudoMetricSpace Z] (E : S → Z) (T : S → ℝ) (L : NNReal) (ε «δ» : ℝ)
  {s₁ s₂ : S},
  dist (E s₁) (E s₂) ≤ ε → «δ» ≤ |T s₁ - T s₂| → ↑L * ε < «δ» → ¬∃ g, LipschitzWith L g ∧ ∀ (s : S), T s = g (E s)
```
