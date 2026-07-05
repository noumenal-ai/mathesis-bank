# MTH.R-2026-1145 — result `WMSpec.positionLatent_dynamics_iff_stroboscopic` [T0]

`theorem` in `WMSpec.NoLatentDynamics`; polarity universal. Discharges MTH.C-2026-1145. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.positionLatent_dynamics_iff_stroboscopic : ∀ (S : ClassicalMechanics.HarmonicOscillator) (t : Time),
  (∃ f,
      ∀ (IC : ClassicalMechanics.HarmonicOscillator.InitialConditions),
        f (WMSpec.positionEncoder IC) = WMSpec.positionEncoder (WMSpec.flow S t IC)) ↔
    Real.sin (S.ω * t.val) = 0
```
