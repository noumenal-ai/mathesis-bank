# MTH.R-2026-1077 — result `WMSpec.jepa_unselected_target_structure_invisible` [T0]

`theorem` in `WMSpec.DraftWrappers`; polarity universal. Discharges MTH.C-2026-1077. Kernel-verified (whole-theory replay); axioms ['propext'].

```
WMSpec.jepa_unselected_target_structure_invisible : ∀ {n : ℕ} {Context Target Pred : Type} (idxs : List (Fin n)) (context : Context) (target₁ target₂ : Fin n → Target)
  (predict : Context → Fin n → Pred) (repLoss : Target → Pred → ℕ),
  (∀ i ∈ idxs, target₁ i = target₂ i) →
    NN.MLTheory.SelfSupervised.jepaLoss idxs context target₁ predict repLoss =
      NN.MLTheory.SelfSupervised.jepaLoss idxs context target₂ predict repLoss
```
