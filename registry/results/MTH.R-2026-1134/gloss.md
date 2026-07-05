# MTH.R-2026-1134 — result `WMSpec.specEncoder_ker_le` [T0]

`theorem` in `WMSpec.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1134. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.specEncoder_ker_le : ∀ {S : Type u_1} [inst : Fintype S] {V : Type u_2} {𝒯 : Set (S → V)} {P : S → ProbabilityTheory.FintypePMF S}
  {Z : Type u_3} {E : S → Z}, WMSpec.SpecEncoder 𝒯 P E → Setoid.ker E ≤ WMSpec.bisimilarity 𝒯 P
```
