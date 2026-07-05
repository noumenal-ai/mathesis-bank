# MTH.R-2026-1063 — result `WMSpec.energyOfIC_conserved` [T0]

`theorem` in `WMSpec.EnergyNonRecovery`; polarity universal. Discharges MTH.C-2026-1063. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.energyOfIC_conserved : ∀ (S : ClassicalMechanics.HarmonicOscillator) (IC : ClassicalMechanics.HarmonicOscillator.InitialConditions) (t : Time),
  S.energy (ClassicalMechanics.HarmonicOscillator.InitialConditions.trajectory S IC) t = WMSpec.energyOfIC S IC
```
