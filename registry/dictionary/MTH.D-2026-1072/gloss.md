# MTH.D-2026-1072 — definition `WMSpec.mmdGuard_characterized`

`def` in `WMSpec.MixedFamilies`; obligated. Author-provided; Dictionary interrogation pending.

```
WMSpec.mmdGuard_characterized : {Xt : Type u_1} →
  [inst : MeasurableSpace Xt] →
    {H : Type u_2} →
      [inst_1 : NormedAddCommGroup H] →
        [inst_2 : InnerProductSpace ℝ H] →
          [inst_3 : CompleteSpace H] →
            [inst_4 : RKHS ℝ H Xt ℝ] →
              IsCharacteristic → MeasureTheory.Measure Xt → WMSpec.CharacterizedGuard (MeasureTheory.Measure Xt)
```
