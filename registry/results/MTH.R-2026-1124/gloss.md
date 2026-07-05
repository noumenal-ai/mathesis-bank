# MTH.R-2026-1124 — result `WMSpec.bisim_mem` [T0]

`theorem` in `WMSpec.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1124. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.bisim_mem : ∀ {S : Type u_1} [inst : Fintype S] {V : Type u_2} (𝒯 : Set (S → V)) (P : S → ProbabilityTheory.FintypePMF S),
  WMSpec.bisimilarity 𝒯 P ∈ WMSpec.SpecCongruences 𝒯 P
```
