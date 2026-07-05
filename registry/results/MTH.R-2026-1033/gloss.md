# MTH.R-2026-1033 — result `WMSpec.mixedPushforward_invariance_characterization` [T0]

`theorem` in `WMSpec.MixedFamilies`; polarity universal. Discharges MTH.C-2026-1033. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.mixedPushforward_invariance_characterization : ∀ {Θ : Type u_1} {Xd : Type u_2} {ι : Type u_3} {k r : ℕ} [inst : Fintype Xd] [inst_1 : DecidableEq Xd] [Nonempty Xd]
  {Lpred : Θ → Xd → List ι → ℕ} {Gd : Fin k → Xd → ℝ} {Gl : Fin r → ProbabilityTheory.FintypePMF Xd → ℝ}
  {lam : Fin k → ℝ} {mu : Fin r → ℝ} {g : Xd → Xd},
  (∀ (θ : Θ) (x : Xd) (I₁ I₂ : List ι), Lpred θ x (I₁ ++ I₂) = Lpred θ x I₁ + Lpred θ x I₂) →
    (∀ (j : Fin k), 0 < lam j) →
      (∀ (i : Fin r), 0 < mu i) →
        (∀ (j : Fin k) (x : Xd), Gd j x ≤ Gd j (g x)) →
          (∀ (i : Fin r) (P : ProbabilityTheory.FintypePMF Xd), Gl i P ≤ Gl i (WMSpec.mapPMF g P)) →
            ∀ (θ₀ : Θ) (x₀ : Xd),
              WMSpec.ObjectiveInvariant (WMSpec.mixedObjective Lpred Gd Gl lam mu)
                  (WMSpec.jointAction g (WMSpec.mapPMF g)) ↔
                WMSpec.ObjectiveInvariant Lpred g ∧
                  (∀ (j : Fin k) (x : Xd), Gd j (g x) = Gd j x) ∧
                    ∀ (i : Fin r) (P : ProbabilityTheory.FintypePMF Xd), Gl i (WMSpec.mapPMF g P) = Gl i P
```
