# MTH.R-2026-1094 — result `WMSpec.bisim_zero_one_step_power` [T0]

`theorem` in `WMSpec.BisimMetric`; polarity universal. Discharges MTH.C-2026-1094. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.bisim_zero_one_step_power : ∀ {S : Type u_1} [inst : Fintype S] {V : Type u_2} (𝒯 : Set (S → V)) (P : S → ProbabilityTheory.FintypePMF S) {a b : S},
  (WMSpec.bisimilarity 𝒯 P) a b →
    ∀ (f : Quotient (WMSpec.bisimilarity 𝒯 P) → Bool),
      (WMSpec.quotientDynamics 𝒯 P ⟦a⟧).boolTestExpectation f = (WMSpec.quotientDynamics 𝒯 P ⟦b⟧).boolTestExpectation f
```
