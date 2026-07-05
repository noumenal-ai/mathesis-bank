# MTH.R-2026-1001 — result `WMSpec.fiber_saturated` [T0]

`theorem` in `WMSpec.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1001. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.fiber_saturated : ∀ {S : Type u_1} [inst : Fintype S] {V : Type u_2} (𝒯 : Set (S → V)) (P : S → ProbabilityTheory.FintypePMF S)
  (c : Quotient (WMSpec.bisimilarity 𝒯 P)), WMSpec.Saturated (WMSpec.bisimilarity 𝒯 P) {s | ⟦s⟧ = c}
```
