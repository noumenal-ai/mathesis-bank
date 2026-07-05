# MTH.R-2026-1120 — result `WMSpec.no_positionLatent_dynamics_of_nonstroboscopic` [T0]

`theorem` in `WMSpec.NoLatentDynamics`; polarity existential. Discharges MTH.C-2026-1120. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.no_positionLatent_dynamics_of_nonstroboscopic : ∀ (S : ClassicalMechanics.HarmonicOscillator) (t : Time),
  Real.sin (S.ω * t.val) ≠ 0 →
    ¬∃ f,
        ∀ (IC : ClassicalMechanics.HarmonicOscillator.InitialConditions),
          f (WMSpec.positionEncoder IC) = WMSpec.positionEncoder (WMSpec.flow S t IC)
```
