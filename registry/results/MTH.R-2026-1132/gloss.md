# MTH.R-2026-1132 — result `WMSpec.miGuard_transport` [T0]

`theorem` in `WMSpec.GuardFamilies`; polarity existential. Discharges MTH.C-2026-1132. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.miGuard_transport : ∀ {α : Type u_4} {β : Type u_5} [inst : MeasurableSpace α] [inst_1 : MeasurableSpace β]
  (g : MeasureTheory.Measure (α × β) → MeasureTheory.Measure (α × β)),
  (∀ (P : MeasureTheory.Measure (α × β)),
      InformationTheory.mutualInformationReal (g P) = InformationTheory.mutualInformationReal P) →
    ∀ (P : MeasureTheory.Measure (α × β)) [MeasureTheory.IsProbabilityMeasure P]
      [MeasureTheory.IsProbabilityMeasure (g P)],
      P.AbsolutelyContinuous ((MeasureTheory.Measure.map Prod.fst P).prod (MeasureTheory.Measure.map Prod.snd P)) →
        InformationTheory.klDiv P ((MeasureTheory.Measure.map Prod.fst P).prod (MeasureTheory.Measure.map Prod.snd P)) ≠
            ⊤ →
          (g P).AbsolutelyContinuous
              ((MeasureTheory.Measure.map Prod.fst (g P)).prod (MeasureTheory.Measure.map Prod.snd (g P))) →
            InformationTheory.klDiv (g P)
                  ((MeasureTheory.Measure.map Prod.fst (g P)).prod (MeasureTheory.Measure.map Prod.snd (g P))) ≠
                ⊤ →
              (g P = (MeasureTheory.Measure.map Prod.fst (g P)).prod (MeasureTheory.Measure.map Prod.snd (g P)) ↔
                P = (MeasureTheory.Measure.map Prod.fst P).prod (MeasureTheory.Measure.map Prod.snd P))
```
