# MTH.R-2026-1034 — result `WMSpec.Flow.FlowWorldModel.horizons_admissible` [T0]

`theorem` in `WMSpec.Flow.FlowArchitecture`; polarity universal. Discharges MTH.C-2026-1034. Kernel-verified (whole-theory replay); axioms [].

```
WMSpec.Flow.FlowWorldModel.horizons_admissible : ∀ {T : Type u_1} {S : Type u_2} {Z : Type u_3} [inst : AddMonoid T] [inst_1 : AddAction T S]
  (M : WMSpec.Flow.FlowWorldModel T S Z) {t : T}, t ∈ M.horizons → t ∈ WMSpec.Flow.admissibleHorizons M.encode
```
