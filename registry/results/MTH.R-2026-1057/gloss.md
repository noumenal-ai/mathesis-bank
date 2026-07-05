# MTH.R-2026-1057 — result `WMSpec.tvDistance_le_two_sin_half_fisherRao` [T0]

`theorem` in `WMSpec.FisherRaoFinite`; polarity universal. Discharges MTH.C-2026-1057. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.tvDistance_le_two_sin_half_fisherRao : ∀ {α : Type u_1} [inst : Fintype α] (p q : ProbabilityTheory.FintypePMF α),
  p.tvDistance q ≤ 2 * Real.sin (WMSpec.fisherRao p q / 2)
```
