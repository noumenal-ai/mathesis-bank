# MTH.R-2026-1085 — result `WMSpec.Flow.latentStep_iff_factorsThrough` [T0]

`theorem` in `WMSpec.Flow.FlowArchitecture`; polarity universal. Discharges MTH.C-2026-1085. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.Flow.latentStep_iff_factorsThrough : ∀ {T : Type u_1} {S : Type u_2} {Z : Type u_3} [inst : AddMonoid T] [inst_1 : AddAction T S] [Nonempty S] (E : S → Z)
  (t : T), WMSpec.Flow.LatentStep E t ↔ Function.FactorsThrough (fun s => E (t +ᵥ s)) E
```
