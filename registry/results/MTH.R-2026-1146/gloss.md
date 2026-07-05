# MTH.R-2026-1146 — result `TLT.NonIdentifiability.isConforming_ker_targets_of_conserved` [T0]

`theorem` in `WMSpec.NonIdentifiability.DerivedWorldModels`; polarity universal. Discharges MTH.C-2026-1146. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.isConforming_ker_targets_of_conserved : ∀ {S : Type u_1} {ι : Type u_2} {W : ι → Type u_3} {T : (i : ι) → S → W i} {f : S → S},
  (∀ (i : ι) (s : S), T i (f s) = T i s) →
    TLT.NonIdentifiability.IsConforming T (TLT.NonIdentifiability.pureKernel f) (Setoid.ker fun s i => T i s)
```
