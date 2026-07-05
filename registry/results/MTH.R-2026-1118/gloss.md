# MTH.R-2026-1118 — result `WMSpec.bisimMetric_prices_tests` [T0]

`theorem` in `WMSpec.BisimMetric`; polarity universal. Discharges MTH.C-2026-1118. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.bisimMetric_prices_tests : ∀ {S : Type u_1} [inst : Fintype S] {V : Type u_2} (𝒯 : Set (S → V)) (P : S → ProbabilityTheory.FintypePMF S)
  (c c' : Quotient (WMSpec.bisimilarity 𝒯 P)) (f : Quotient (WMSpec.bisimilarity 𝒯 P) → Bool),
  |(WMSpec.quotientDynamics 𝒯 P c).boolTestExpectation f - (WMSpec.quotientDynamics 𝒯 P c').boolTestExpectation f| ≤
    Real.sin (WMSpec.bisimMetric 𝒯 P c c' / 2)
```
