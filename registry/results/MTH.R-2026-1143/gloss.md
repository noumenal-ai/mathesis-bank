# MTH.R-2026-1143 — result `WMSpec.forcing_theorem` [T0]

`theorem` in `WMSpec.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1143. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.forcing_theorem : ∀ {S : Type u_1} [inst : Fintype S] {V : Type u_2} (𝒯 : Set (S → V)) (P : S → ProbabilityTheory.FintypePMF S),
  WMSpec.bisimilarity 𝒯 P ∈ WMSpec.SpecCongruences 𝒯 P ∧
    (∀ r ∈ WMSpec.SpecCongruences 𝒯 P, r ≤ WMSpec.bisimilarity 𝒯 P) ∧
      ∀ {Z : Type u_3} (E : S → Z), WMSpec.SpecEncoder 𝒯 P E → Setoid.ker E ≤ WMSpec.bisimilarity 𝒯 P
```
