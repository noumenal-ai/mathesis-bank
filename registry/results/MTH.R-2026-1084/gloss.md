# MTH.R-2026-1084 — result `WMSpec.Flow.neg_mem_admissible_of_period` [T0]

`theorem` in `WMSpec.Flow.FlowArchitecture`; polarity universal. Discharges MTH.C-2026-1084. Kernel-verified (whole-theory replay); axioms ['propext'].

```
WMSpec.Flow.neg_mem_admissible_of_period : ∀ {T : Type u_1} {S : Type u_2} {Z : Type u_3} [inst : AddGroup T] [inst_1 : AddAction T S] (E : S → Z) {t : T},
  t ∈ WMSpec.Flow.admissibleHorizons E →
    (∃ k, 0 < k ∧ ∀ (x : S), k • t +ᵥ x = x) → -t ∈ WMSpec.Flow.admissibleHorizons E
```
