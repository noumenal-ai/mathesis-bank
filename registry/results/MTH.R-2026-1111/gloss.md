# MTH.R-2026-1111 — result `WMSpec.bisimMetric_comm` [T0]

`theorem` in `WMSpec.BisimMetric`; polarity universal. Discharges MTH.C-2026-1111. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.bisimMetric_comm : ∀ {S : Type u_1} [inst : Fintype S] {V : Type u_2} (𝒯 : Set (S → V)) (P : S → ProbabilityTheory.FintypePMF S)
  (c c' : Quotient (WMSpec.bisimilarity 𝒯 P)), WMSpec.bisimMetric 𝒯 P c c' = WMSpec.bisimMetric 𝒯 P c' c
```
