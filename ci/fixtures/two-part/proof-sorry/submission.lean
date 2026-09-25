/-!
# Mathesis deposit

@kind: result
@title: a proof part that is itself sorry
@module: Submission
@decls: Probe.hard
@pin: leanprover/lean4:v4.31.0

@gloss:
  Fixture for ci/test_two_part_fixtures.sh. The statement is fine; the
  proof part restates it and proves it by `sorry` again. Statement-identity
  holds, so the rejection must come from the axiom audit (sorryAx).
-/

/-! @statement -/

namespace Probe

theorem hard (n : Nat) : n + 0 = n := sorry

end Probe

/-! @proof -/

namespace Probe

theorem hard (n : Nat) : n + 0 = n := sorry

end Probe
