# MTH.R-2026-1075 — result `TLT.NonIdentifiability.approx_lipschitz` [T0]

`theorem` in `WMSpec.NonIdentifiability.Apparatus`; polarity universal. Discharges MTH.C-2026-1075. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.approx_lipschitz : ∀ {S : Type u_1} {Z : Type u_2} [inst : PseudoMetricSpace Z] (E : S → Z) (T : S → ℝ) (L : NNReal) (ε «δ» : ℝ)
  {s₁ s₂ : S},
  dist (E s₁) (E s₂) ≤ ε →
    «δ» ≤ |T s₁ - T s₂| → ∀ (g : Z → ℝ), LipschitzWith L g → (∀ (s : S), T s = g (E s)) → «δ» ≤ ↑L * ε
```
