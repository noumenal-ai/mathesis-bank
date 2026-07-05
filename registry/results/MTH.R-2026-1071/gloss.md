# MTH.R-2026-1071 — result `WMSpec.bhattacharyya_comm` [T0]

`theorem` in `WMSpec.BisimMetric`; polarity universal. Discharges MTH.C-2026-1071. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.bhattacharyya_comm : ∀ {α : Type u_1} [inst : Fintype α] (p q : ProbabilityTheory.FintypePMF α),
  WMSpec.bhattacharyya p q = WMSpec.bhattacharyya q p
```
