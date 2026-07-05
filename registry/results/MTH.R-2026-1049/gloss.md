# MTH.R-2026-1049 — result `WMSpec.boolTestExpectation_mapPMF` [T0]

`theorem` in `WMSpec.MixedFamilies`; polarity universal. Discharges MTH.C-2026-1049. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.boolTestExpectation_mapPMF : ∀ {α : Type u_1} {β : Type u_2} [inst : Fintype α] [inst_1 : Fintype β] [inst_2 : DecidableEq β] (g : α → β)
  (p : ProbabilityTheory.FintypePMF α) (f : β → Bool),
  (WMSpec.mapPMF g p).boolTestExpectation f = p.boolTestExpectation fun a => f (g a)
```
