# MTH.R-2026-1039 — result `WMSpec.mixed_guard_exchange` [T0]

`theorem` in `WMSpec.MixedFamilies`; polarity universal. Discharges MTH.C-2026-1039. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.mixed_guard_exchange : ∀ {Θ : Type u_1} {Xd : Type u_2} {Yl : Type u_3} {ι : Type u_4} {k r : ℕ} {Lpred : Θ → Xd → List ι → ℕ}
  {Gd : Fin k → Xd → ℝ} {Gl : Fin r → Yl → ℝ} {lam : Fin k → ℝ} {mu : Fin r → ℝ} {g : Xd → Xd} {h : Yl → Yl}
  [Nonempty Yl],
  (∀ (θ : Θ) (x : Xd) (I₁ I₂ : List ι), Lpred θ x (I₁ ++ I₂) = Lpred θ x I₁ + Lpred θ x I₂) →
    WMSpec.ObjectiveInvariant (WMSpec.mixedObjective Lpred Gd Gl lam mu) (WMSpec.jointAction g h) →
      ∀ (θ₀ : Θ) (x₀ : Xd),
        ∃ c, (∀ (x : Xd), ∑ j, lam j * (Gd j (g x) - Gd j x) = c) ∧ ∀ (y : Yl), ∑ i, mu i * (Gl i (h y) - Gl i y) = -c
```
