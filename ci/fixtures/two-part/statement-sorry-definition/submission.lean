/-!
# Mathesis deposit

@kind: result
@title: a statement whose definition is sorry
@module: Submission
@decls: Probe.threshold_pos
@pin: leanprover/lean4:v4.31.0

@gloss:
  Fixture for ci/test_two_part_fixtures.sh. `threshold` is `sorry`, so the
  claim is about nothing in particular. The parser refuses it at the source
  level, before anything is built.
-/

/-! @statement -/

namespace Probe

def threshold : Nat := sorry

theorem threshold_pos : 0 < threshold := sorry

end Probe

/-! @proof -/

namespace Probe

def threshold : Nat := sorry

theorem threshold_pos : 0 < threshold := sorry

end Probe
