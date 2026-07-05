# MTH.R-2026-1087 — result `WMSpec.finite_fisherRao_risk_bound` [T0]

`theorem` in `WMSpec.FisherRaoFinite`; polarity universal. Discharges MTH.C-2026-1087. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.finite_fisherRao_risk_bound : ∀ {α : Type u_1} [inst : Fintype α] (p q : ProbabilityTheory.FintypePMF α) (f : α → Bool),
  |p.boolTestExpectation f - q.boolTestExpectation f| ≤ Real.sin (WMSpec.fisherRao p q / 2)
```
