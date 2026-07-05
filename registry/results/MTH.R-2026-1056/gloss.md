# MTH.R-2026-1056 — result `TLT.NonIdentifiability.approx_lipschitz_ineq` [T0]

`theorem` in `WMSpec.NonIdentifiability.Apparatus`; polarity universal. Discharges MTH.C-2026-1056. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.approx_lipschitz_ineq : ∀ {S : Type u_1} {Z : Type u_2} [inst : PseudoMetricSpace Z] (E : S → Z) (T : S → ℝ) (L : NNReal) (g : Z → ℝ),
  LipschitzWith L g → (∀ (s : S), T s = g (E s)) → ∀ (s₁ s₂ : S), |T s₁ - T s₂| ≤ ↑L * dist (E s₁) (E s₂)
```
