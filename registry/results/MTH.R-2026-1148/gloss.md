# MTH.R-2026-1148 — result `WMSpec.blind_tests_zero_power` [T0]

`theorem` in `WMSpec.MixedFamilies`; polarity existential. Discharges MTH.C-2026-1148. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.blind_tests_zero_power : ∀ {α : Type u_1} [inst : Fintype α] {Θ : Type u_3} {M : Type u_4} {V : Type u_5} [inst_1 : DecidableEq α]
  {L : Θ → α → M → V} {b : α → α},
  WMSpec.ObjectiveInvariant L b →
    ∀ (r : V → Bool) (θ : Θ) (m : M) (p : ProbabilityTheory.FintypePMF α),
      ((WMSpec.mapPMF b p).boolTestExpectation fun a => r (L θ a m)) = p.boolTestExpectation fun a => r (L θ a m)
```
