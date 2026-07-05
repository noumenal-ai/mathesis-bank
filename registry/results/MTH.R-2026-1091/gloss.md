# MTH.R-2026-1091 — result `WMSpec.quotientTarget_mk` [T0]

`theorem` in `WMSpec.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1091. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.quotientTarget_mk : ∀ {S : Type u_1} [inst : Fintype S] {V : Type u_2} (𝒯 : Set (S → V)) (P : S → ProbabilityTheory.FintypePMF S)
  {T : S → V} (hT : T ∈ 𝒯) (s : S), WMSpec.quotientTarget 𝒯 P hT ⟦s⟧ = T s
```
