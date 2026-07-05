# MTH.R-2026-1008 — result `WMSpec.Flow.mem_admissibleHorizons` [T0]

`theorem` in `WMSpec.Flow.FlowArchitecture`; polarity universal. Discharges MTH.C-2026-1008. Kernel-verified (whole-theory replay); axioms [].

```
WMSpec.Flow.mem_admissibleHorizons : ∀ {T : Type u_1} {S : Type u_2} {Z : Type u_3} [inst : AddMonoid T] [inst_1 : AddAction T S] {E : S → Z} {t : T},
  t ∈ WMSpec.Flow.admissibleHorizons E ↔ Function.FactorsThrough (fun s => E (t +ᵥ s)) E
```
