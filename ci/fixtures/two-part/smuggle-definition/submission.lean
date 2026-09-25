/-!
# Mathesis deposit

@kind: result
@title: a proof that re-states a definition differently
@module: Submission
@decls: Probe.bound_big
@pin: leanprover/lean4:v4.31.0

@gloss:
  Fixture for ci/test_two_part_fixtures.sh. The statement claims `bound`,
  defined as 10, exceeds 100 — false. The proof part re-states `bound` as
  1000 and proves the claim about ITS `bound`, which is kernel-valid and
  axiom-clean on its own. Statement-identity must catch the divergent
  definition and reject.
-/

/-! @statement -/

namespace Probe

def bound : Nat := 10

theorem bound_big : 100 < bound := sorry

end Probe

/-! @proof -/

namespace Probe

def bound : Nat := 1000

theorem bound_big : 100 < bound := by decide

end Probe
