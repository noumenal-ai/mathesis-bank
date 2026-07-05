# MTH.R-2026-1006 — result `WMSpec.oscillator_latentStep_iff` [T0]

`theorem` in `WMSpec.Flow.OscillatorBinding`; polarity universal. Discharges MTH.C-2026-1006. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.oscillator_latentStep_iff : ∀ (S : ClassicalMechanics.HarmonicOscillator) (t : Time),
  WMSpec.LatentStepAt (WMSpec.flow S t) WMSpec.positionEncoder ↔ Real.sin (S.ω * t.val) = 0
```
