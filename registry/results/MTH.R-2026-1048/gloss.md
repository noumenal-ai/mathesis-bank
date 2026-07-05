# MTH.R-2026-1048 — result `WMSpec.fisherRao_comm` [T0]

`theorem` in `WMSpec.BisimMetric`; polarity universal. Discharges MTH.C-2026-1048. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.fisherRao_comm : ∀ {α : Type u_1} [inst : Fintype α] (p q : ProbabilityTheory.FintypePMF α), WMSpec.fisherRao p q = WMSpec.fisherRao q p
```
