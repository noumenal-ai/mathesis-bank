# MTH.R-2026-1053 — result `TLT.NonIdentifiability.pureKernel_map_quotientMk_of_conserved` [T0]

`theorem` in `WMSpec.NonIdentifiability.DerivedWorldModels`; polarity universal. Discharges MTH.C-2026-1053. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.pureKernel_map_quotientMk_of_conserved : ∀ {S : Type u_1} {ι : Type u_2} {W : ι → Type u_3} {T : (i : ι) → S → W i} {f : S → S},
  (∀ (i : ι) (s : S), T i (f s) = T i s) →
    ∀ (s : S),
      PMF.map (Quotient.mk (TLT.NonIdentifiability.bisimilarity T (TLT.NonIdentifiability.pureKernel f)))
          (TLT.NonIdentifiability.pureKernel f s) =
        PMF.pure ⟦s⟧
```
