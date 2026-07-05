# MTH.R-2026-1119 — result `WMSpec.mixed_invariance_characterization` [T0]

`theorem` in `WMSpec.MixedFamilies`; polarity universal. Discharges MTH.C-2026-1119. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.mixed_invariance_characterization : ∀ {Θ : Type u_1} {Xd : Type u_2} {Yl : Type u_3} {ι : Type u_4} {k r : ℕ} {Lpred : Θ → Xd → List ι → ℕ}
  {Gd : Fin k → Xd → ℝ} {Gl : Fin r → Yl → ℝ} {lam : Fin k → ℝ} {mu : Fin r → ℝ} {g : Xd → Xd} {h : Yl → Yl}
  [Nonempty Yl],
  (∀ (θ : Θ) (x : Xd) (I₁ I₂ : List ι), Lpred θ x (I₁ ++ I₂) = Lpred θ x I₁ + Lpred θ x I₂) →
    (∀ (j : Fin k), 0 < lam j) →
      (∀ (i : Fin r), 0 < mu i) →
        (∀ (j : Fin k) (x : Xd), Gd j x ≤ Gd j (g x)) →
          (∀ (i : Fin r) (y : Yl), Gl i y ≤ Gl i (h y)) →
            ∀ (θ₀ : Θ) (x₀ : Xd),
              WMSpec.ObjectiveInvariant (WMSpec.mixedObjective Lpred Gd Gl lam mu) (WMSpec.jointAction g h) ↔
                WMSpec.ObjectiveInvariant Lpred g ∧
                  (∀ (j : Fin k) (x : Xd), Gd j (g x) = Gd j x) ∧ ∀ (i : Fin r) (y : Yl), Gl i (h y) = Gl i y
```
