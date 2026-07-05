# MTH.R-2026-1131 — result `WMSpec.energyOfIC_eq` [T0]

`theorem` in `WMSpec.EnergyNonRecovery`; polarity universal. Discharges MTH.C-2026-1131. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.energyOfIC_eq : ∀ (S : ClassicalMechanics.HarmonicOscillator) (IC : ClassicalMechanics.HarmonicOscillator.InitialConditions),
  WMSpec.energyOfIC S IC = 1 / 2 * (S.m * ‖IC.v₀‖ ^ 2 + S.k * ‖IC.x₀‖ ^ 2)
```
