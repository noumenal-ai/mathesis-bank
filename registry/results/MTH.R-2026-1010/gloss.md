# MTH.R-2026-1010 — result `WMSpec.le_bisimilarity` [T0]

`theorem` in `WMSpec.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1010. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.le_bisimilarity : ∀ {S : Type u_1} [inst : Fintype S] {V : Type u_2} {𝒯 : Set (S → V)} {P : S → ProbabilityTheory.FintypePMF S}
  {r : Setoid S}, r ∈ WMSpec.SpecCongruences 𝒯 P → r ≤ WMSpec.bisimilarity 𝒯 P
```
