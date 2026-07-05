# MTH.R-2026-1067 — result `WMSpec.bisim_classification_factors` [T0]

`theorem` in `WMSpec.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1067. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.bisim_classification_factors : ∀ {S : Type u_1} [inst : Fintype S] {V : Type u_2} [Nonempty S] {𝒯 : Set (S → V)}
  {P : S → ProbabilityTheory.FintypePMF S} {Z : Type u_3} {E : S → Z},
  WMSpec.SpecEncoder 𝒯 P E → ∃ φ, ∀ (s : S), ⟦s⟧ = φ (E s)
```
