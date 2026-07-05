# MTH.D-2026-1039 — definition `WMSpec.instDecidableEqQuotientBisimilarity`

`def` in `WMSpec.ForcingTheorem`; obligated. Author-provided; Dictionary interrogation pending.

```
WMSpec.instDecidableEqQuotientBisimilarity : {S : Type u_1} →
  [inst : Fintype S] →
    {V : Type u_2} →
      (𝒯 : Set (S → V)) → (P : S → ProbabilityTheory.FintypePMF S) → DecidableEq (Quotient (WMSpec.bisimilarity 𝒯 P))
```
