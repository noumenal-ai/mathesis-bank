# MTH.R-2026-1080 — result `WMSpec.hsicGuard_transport` [T0]

`theorem` in `WMSpec.GuardFamilies`; polarity universal. Discharges MTH.C-2026-1080. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.hsicGuard_transport : ∀ {Xt : Type u_1} [inst : MeasurableSpace Xt] {Yt : Type u_2} [inst_1 : MeasurableSpace Yt] {H : Type u_3}
  [inst_2 : NormedAddCommGroup H] [inst_3 : InnerProductSpace ℝ H] [inst_4 : CompleteSpace H]
  [inst_5 : RKHS ℝ H (Xt × Yt) ℝ],
  IsCharacteristic →
    ∀ (g : MeasureTheory.Measure (Xt × Yt) → MeasureTheory.Measure (Xt × Yt)),
      (∀ (P : MeasureTheory.Measure (Xt × Yt)), hsicDef (g P) = hsicDef P) →
        ∀ (P : MeasureTheory.Measure (Xt × Yt)),
          g P = (MeasureTheory.Measure.map Prod.fst (g P)).prod (MeasureTheory.Measure.map Prod.snd (g P)) ↔
            P = (MeasureTheory.Measure.map Prod.fst P).prod (MeasureTheory.Measure.map Prod.snd P)
```
