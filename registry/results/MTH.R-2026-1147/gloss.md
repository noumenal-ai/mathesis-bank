# MTH.R-2026-1147 — result `WMSpec.fisherRao_mapPMF_le` [T0]

`theorem` in `WMSpec.BisimMetric`; polarity universal. Discharges MTH.C-2026-1147. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.fisherRao_mapPMF_le : ∀ {α : Type u_1} {β : Type u_2} [inst : Fintype α] [inst_1 : Fintype β] [inst_2 : DecidableEq β] (g : α → β)
  (p q : ProbabilityTheory.FintypePMF α),
  WMSpec.fisherRao (WMSpec.mapPMF g p) (WMSpec.mapPMF g q) ≤ WMSpec.fisherRao p q
```
