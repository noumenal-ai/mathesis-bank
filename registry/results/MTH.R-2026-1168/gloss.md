# MTH.R-2026-1168 — result `WMSpec.StochasticWitness.bisimilarity_eq_kerWell` [T0]

`theorem` in `WMSpec.StochasticWitness`; polarity universal. Discharges MTH.C-2026-1168. Kernel-verified (stochastic-delta replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.StochasticWitness.bisimilarity_eq_kerWell : WMSpec.bisimilarity WMSpec.StochasticWitness.𝒯 WMSpec.StochasticWitness.diffusion =
    Setoid.ker WMSpec.StochasticWitness.wellEnergy
```
