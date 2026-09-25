/-!
# Mathesis deposit

@kind: claim
@title: a statement whose theorem is proved by something spelled sorry
@module: Submission
@decls: Probe.easy
@pin: leanprover/lean4:v4.31.0

@gloss:
  Fixture for ci/test_two_part_fixtures.sh. A notation makes the word
  `sorry` mean `trivial`, so `:= sorry` passes the parser's lexer (the
  notation's own spelling is inside a string, which the lexer blanks)
  while the theorem is actually PROVED. The export-level check must see
  that its value is not `sorryAx` and reject.
-/

/-! @statement -/

namespace Probe

local notation (priority := high) "sorry" => trivial

theorem easy : True := sorry

end Probe
