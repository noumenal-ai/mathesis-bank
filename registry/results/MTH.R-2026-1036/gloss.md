# MTH.R-2026-1036 — result `WMSpec.jepa_target_order_symmetry` [T0]

`theorem` in `WMSpec.DraftWrappers`; polarity universal. Discharges MTH.C-2026-1036. Kernel-verified (whole-theory replay); axioms ['propext'].

```
WMSpec.jepa_target_order_symmetry : ∀ {n : ℕ} {Context Target Pred : Type} (idxs : List (Fin n)) (context : Context) (target : Fin n → Target)
  (predict : Context → Fin n → Pred) (repLoss : Target → Pred → ℕ),
  NN.MLTheory.SelfSupervised.jepaLoss idxs.reverse context target predict repLoss =
    NN.MLTheory.SelfSupervised.jepaLoss idxs context target predict repLoss
```
