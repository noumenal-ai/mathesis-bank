/-!
# Mathesis deposit

@kind: result
@title: a proof that proves a different statement under the same name
@module: Submission
@decls: Probe.all_small
@pin: leanprover/lean4:v4.31.0

@gloss:
  Fixture for ci/test_two_part_fixtures.sh. The statement claims every
  natural number is below 10 — false. The proof part keeps the name and
  weakens the statement to one number, which it can prove. Statement-
  identity must catch the changed type and reject.
-/

/-! @statement -/

namespace Probe

theorem all_small : ∀ n : Nat, n < 10 := sorry

end Probe

/-! @proof -/

namespace Probe

theorem all_small : ∀ n : Nat, n = 3 → n < 10 := by
  intro n h; subst h; decide

end Probe
