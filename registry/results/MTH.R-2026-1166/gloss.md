# MTH.R-2026-1166 — result `WMSpec.boolTest_gap_le_half_tvDistance` [T0]

`theorem` in `WMSpec.FisherRaoFinite`; polarity universal. Discharges MTH.C-2026-1166. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.boolTest_gap_le_half_tvDistance : ∀ {α : Type u_1} [inst : Fintype α] (p q : ProbabilityTheory.FintypePMF α) (f : α → Bool),
  |p.boolTestExpectation f - q.boolTestExpectation f| ≤ p.tvDistance q / 2
```
