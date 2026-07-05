# MTH.R-2026-1045 — result `WMSpec.Flow.neg_mem_admissible` [T0]

`theorem` in `WMSpec.Flow.FlowArchitecture`; polarity universal. Discharges MTH.C-2026-1045. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.Flow.neg_mem_admissible : ∀ {T : Type u_1} {S : Type u_2} {Z : Type u_3} [inst : AddGroup T] [inst_1 : AddAction T S] [Finite S] (E : S → Z)
  {t : T}, t ∈ WMSpec.Flow.admissibleHorizons E → -t ∈ WMSpec.Flow.admissibleHorizons E
```
