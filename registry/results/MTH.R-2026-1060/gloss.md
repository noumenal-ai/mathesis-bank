# MTH.R-2026-1060 — result `TLT.NonIdentifiability.latentKernel_unique_on_range` [T0]

`theorem` in `WMSpec.NonIdentifiability.KernelLumpability`; polarity universal. Discharges MTH.C-2026-1060. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.latentKernel_unique_on_range : ∀ {S : Type u_1} {Z : Type u_2} (E : S → Z) (P : S → PMF S) {Q₁ Q₂ : Z → PMF Z},
  (∀ (s : S), Q₁ (E s) = PMF.map E (P s)) → (∀ (s : S), Q₂ (E s) = PMF.map E (P s)) → ∀ z ∈ Set.range E, Q₁ z = Q₂ z
```
