# MTH.R-2026-1108 — result `WMSpec.bhattacharyya_le_mapPMF` [T0]

`theorem` in `WMSpec.BisimMetric`; polarity universal. Discharges MTH.C-2026-1108. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.bhattacharyya_le_mapPMF : ∀ {α : Type u_1} {β : Type u_2} [inst : Fintype α] [inst_1 : Fintype β] [inst_2 : DecidableEq β] (g : α → β)
  (p q : ProbabilityTheory.FintypePMF α),
  WMSpec.bhattacharyya p q ≤ WMSpec.bhattacharyya (WMSpec.mapPMF g p) (WMSpec.mapPMF g q)
```
