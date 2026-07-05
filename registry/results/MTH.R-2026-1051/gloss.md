# MTH.R-2026-1051 — result `WMSpec.quotientDynamics_mk` [T0]

`theorem` in `WMSpec.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1051. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.quotientDynamics_mk : ∀ {S : Type u_1} [inst : Fintype S] {V : Type u_2} (𝒯 : Set (S → V)) (P : S → ProbabilityTheory.FintypePMF S) (a : S),
  WMSpec.quotientDynamics 𝒯 P ⟦a⟧ = WMSpec.mapPMF (Quotient.mk (WMSpec.bisimilarity 𝒯 P)) (P a)
```
