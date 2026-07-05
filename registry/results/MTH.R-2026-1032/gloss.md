# MTH.R-2026-1032 — result `WMSpec.finite_bool_ood_gap_of_tv` [T0]

`theorem` in `WMSpec.DraftWrappers`; polarity universal. Discharges MTH.C-2026-1032. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.finite_bool_ood_gap_of_tv : ∀ {α : Type u_1} [inst : Fintype α] (p q : ProbabilityTheory.FintypePMF α) (f : α → Bool) («δ» : ℝ),
  p.tvDistance q ≤ «δ» → |p.boolTestExpectation f - q.boolTestExpectation f| ≤ «δ»
```
