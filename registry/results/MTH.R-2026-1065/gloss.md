# MTH.R-2026-1065 — result `WMSpec.unselectedRewrite_invariantAt` [T0]

`theorem` in `WMSpec.MaskIndexedInvariance`; polarity universal. Discharges MTH.C-2026-1065. Kernel-verified (whole-theory replay); axioms ['propext'].

```
WMSpec.unselectedRewrite_invariantAt : ∀ {n : ℕ} {Context Target Pred : Type} [inst : DecidableEq (Fin n)] (I : List (Fin n)) (r : Fin n → Target → Target),
  WMSpec.ObjectiveInvariantAt (WMSpec.jepaFamily n Context Target Pred) I fun x =>
    (x.1, fun i => if i ∈ I then x.2 i else r i (x.2 i))
```
