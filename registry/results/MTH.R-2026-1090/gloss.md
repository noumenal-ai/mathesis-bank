# MTH.R-2026-1090 — result `WMSpec.Flow.exists_period` [T0]

`theorem` in `WMSpec.Flow.FlowArchitecture`; polarity universal. Discharges MTH.C-2026-1090. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.Flow.exists_period : ∀ {T : Type u_1} {S : Type u_2} [inst : AddGroup T] [inst_1 : AddAction T S] [Finite S] (t : T),
  ∃ k, 0 < k ∧ ∀ (x : S), k • t +ᵥ x = x
```
