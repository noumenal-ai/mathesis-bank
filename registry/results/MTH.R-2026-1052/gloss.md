# MTH.R-2026-1052 — result `WMSpec.positionEncoder_flow` [T0]

`theorem` in `WMSpec.NoLatentDynamics`; polarity universal. Discharges MTH.C-2026-1052. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.positionEncoder_flow : ∀ (S : ClassicalMechanics.HarmonicOscillator) (t : Time) (IC : ClassicalMechanics.HarmonicOscillator.InitialConditions),
  WMSpec.positionEncoder (WMSpec.flow S t IC) =
    ClassicalMechanics.HarmonicOscillator.InitialConditions.trajectory S IC t
```
