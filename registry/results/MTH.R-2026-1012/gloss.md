# MTH.R-2026-1012 — result `WMSpec.sin_half_fisherRao` [T0]

`theorem` in `WMSpec.FisherRaoFinite`; polarity universal. Discharges MTH.C-2026-1012. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.sin_half_fisherRao : ∀ {α : Type u_1} [inst : Fintype α] (p q : ProbabilityTheory.FintypePMF α),
  Real.sin (WMSpec.fisherRao p q / 2) = √(1 - WMSpec.bhattacharyya p q ^ 2)
```
