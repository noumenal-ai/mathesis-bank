# MTH.R-2026-1074 — result `WMSpec.FintypePMF.ext'` [T0]

`theorem` in `WMSpec.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1074. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.FintypePMF.ext' : ∀ {α : Type u_3} [inst : Fintype α] {p q : ProbabilityTheory.FintypePMF α}, (∀ (a : α), p.prob a = q.prob a) → p = q
```
