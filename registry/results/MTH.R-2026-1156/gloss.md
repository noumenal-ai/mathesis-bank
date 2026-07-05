# MTH.R-2026-1156 — result `WMSpec.flow_zero` [T0]

`theorem` in `WMSpec.NoLatentDynamics`; polarity universal. Discharges MTH.C-2026-1156. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.flow_zero : ∀ (S : ClassicalMechanics.HarmonicOscillator) (IC : ClassicalMechanics.HarmonicOscillator.InitialConditions),
  WMSpec.flow S 0 IC = IC
```
