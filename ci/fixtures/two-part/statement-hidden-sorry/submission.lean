/-!
# Mathesis deposit

@kind: claim
@title: a statement whose definition hides a sorry from the source check
@module: Submission
@decls: Probe.threshold_pos
@pin: leanprover/lean4:v4.31.0

@gloss:
  Fixture for ci/test_two_part_fixtures.sh. `threshold` is defined by the
  `stop` tactic, which elaborates to `sorry` without the word appearing in
  the source, so the parser's lexer passes it. The export-level check must
  not: the adjudicator's audit of `threshold` over R reaches sorryAx.
  Posed (no proof section), so the statement check is the whole gate.
-/

/-! @statement -/

namespace Probe

def threshold : Nat := by stop exact 3

theorem threshold_pos : 0 < threshold := sorry

end Probe
