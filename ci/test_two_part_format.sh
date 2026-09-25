#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------------
# The two-part deposit format: section markers, the statement's form, and cutting the parts.
#
#   bash ci/test_two_part_format.sh
#
# WHAT IS UNDER TEST
# ------------------
# `ci/parse_deposit.py` is the authority on the format (its header documents it). A two-part
# deposit is still ONE file, so that submitting stays one paste, split by two marker lines:
#
#     /-! @statement -/    definitions + theorem statements, every proof exactly `sorry`
#     /-! @proof -/        the same theorems, proved, plus any lemmas
#
# and a claim is POSED by a statement with no proof section. Everything here is the parser's
# half of that: which files are two-part, which are refused, and what the gate is handed to
# build. The gate's half — building, exporting R, adjudicating against it — needs a Lean
# toolchain and is exercised on real fixtures by ci/test_two_part_fixtures.sh.
#
# No Lean needed: this is the fail-closed surface, and every refusal below is one a depositor
# would otherwise discover minutes later as a build error that does not name the problem.
# ---------------------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="${PYTHON:-python3}"
PARSE="$ROOT/ci/parse_deposit.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

check() { # check <name> <cond-cmd...>
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then printf '  PASS  %s\n' "$name"; pass=$((pass+1))
  else printf '  FAIL  %s\n' "$name"; fail=$((fail+1)); fi
}
parses()  { "$PY" "$PARSE" "$1"; }
refused() { ! "$PY" "$PARSE" "$1"; }
# says <file> <text>: refused, and the refusal contains <text>. (`|| true` because pipefail would
# otherwise read the parser's nonzero exit — the very refusal being checked — as grep failing.)
says()    { ! "$PY" "$PARSE" "$1" >/dev/null 2>&1 && { "$PY" "$PARSE" "$1" 2>&1 || true; } | grep -q -- "$2"; }
field()   { "$PY" "$PARSE" "$1" 2>/dev/null | "$PY" -c 'import json,sys;print(json.dumps(json.load(sys.stdin).get(sys.argv[1])))' "$2"; }

echo "two-part deposit format"
echo

# A deposit is assembled from a header, then whatever follows. `hdr <kind> [extra @-lines]`.
hdr() {
  printf '/-!\n# Mathesis deposit\n\n@kind: %s\n@title: t\n@module: Submission\n@decls: Probe.t\n@pin: leanprover/lean4:v4.31.0\n%s\n@gloss:\n  g\n-/\n' "$1" "${2:-}"
}
STMT='/-! @statement -/

namespace Probe
def double (n : Nat) : Nat := n + n
theorem t (n : Nat) : double n = 2 * n := sorry
end Probe
'
PROOF='/-! @proof -/

namespace Probe
def double (n : Nat) : Nat := n + n
theorem t (n : Nat) : double n = 2 * n := by unfold double; omega
end Probe
'
mk() { # mk <file> <kind> <body> [extra @-lines]
  { hdr "$2" "${4:-}"; printf '\n%s' "$3"; } > "$TMP/$1"
}

# ---- 1. the well-formed shapes ---------------------------------------------------------------
mk two.lean  result "$STMT
$PROOF"
mk pose.lean claim  "$STMT"
{ printf 'import Init.Data.List.Basic\n\n'; cat "$TMP/two.lean"; } > "$TMP/two-imports.lean"

check "a two-part deposit parses"                     parses "$TMP/two.lean"
check "  and says so"                                 test "$(field "$TMP/two.lean" mode)" = '"two-part"'
check "  with the sections' line ranges"              test "$(field "$TMP/two.lean" parts)" = \
  '{"statement": {"start": 14, "end": 20}, "proof": {"start": 21, "end": 27}}'
check "a statement alone poses a claim"               test "$(field "$TMP/pose.lean" mode)" = '"pose"'
check "  and reports no proof section"                bash -c "'$PY' '$PARSE' '$TMP/pose.lean' | grep -q '\"proof\": null'"
check "two-part with hoisted imports parses"          parses "$TMP/two-imports.lean"

# Single-part is untouched: the new keys say so, and every old key is still there.
printf '%s\n\ntheorem t : True := trivial\n' "$(hdr result)" > "$TMP/single.lean"
check "a single-part deposit is mode single"          test "$(field "$TMP/single.lean" mode)" = '"single"'
check "  with no parts"                               test "$(field "$TMP/single.lean" parts)" = 'null'
check "  and every pre-existing key unchanged"        bash -c "'$PY' '$PARSE' '$TMP/single.lean' | '$PY' -c '
import json,sys
d=json.load(sys.stdin)
want={\"kind\":\"result\",\"title\":\"t\",\"module\":\"Submission\",\"decls\":[\"Probe.t\"],
      \"pin\":\"leanprover/lean4:v4.31.0\",\"mathlib\":None,\"discharges\":None,\"imports\":[],\"gloss\":\"g\"}
sys.exit(0 if all(d[k]==v for k,v in want.items()) else 1)'"

# ---- 2. markers: missing, duplicated, misordered, malformed ----------------------------------
mk proof-only.lean result "$PROOF"
mk dup-stmt.lean   result "$STMT
$STMT
$PROOF"
mk dup-proof.lean  result "$STMT
$PROOF
$PROOF"
mk misorder.lean   result "$PROOF
$STMT"
check "@proof without @statement is refused"          refused "$TMP/proof-only.lean"
check "  and the refusal says why"                    says "$TMP/proof-only.lean" 'without a preceding'
check "a duplicate @statement is refused"             says "$TMP/dup-stmt.lean" 'duplicate'
check "a duplicate @proof is refused"                 says "$TMP/dup-proof.lean" 'duplicate'
check "@proof before @statement is refused"           refused "$TMP/misorder.lean"

# A near-miss must not silently become body: that turns an intended two-part deposit into a
# single-part one, which then fails to build on a duplicate declaration and never names the typo.
for bad in '/-! @Statement -/' '/-! @statement' '/-! @statement -/ def x := 1' '/- @statement -/' '/-!@proof-/ --'; do
  mk near.lean result "$bad

theorem t : True := sorry
"
  check "malformed marker refused: $bad"              says "$TMP/near.lean" 'malformed section marker'
done
mk spaced.lean claim "  /-!   @statement   -/
namespace Probe
theorem t : True := sorry
end Probe
"
check "a marker with surrounding whitespace is fine"  parses "$TMP/spaced.lean"

# Every declaration belongs to a section; one between the header and @statement would belong to
# neither part, or to both — and a silently shared definition is what identity is there to test.
mk before.lean result "def shared := 1

$STMT
$PROOF"
check "content before @statement is refused"          says "$TMP/before.lean" 'between the header'
mk blank-before.lean claim "

$STMT"
check "  (blank lines there are fine)"                parses "$TMP/blank-before.lean"

mk empty-stmt.lean  result "/-! @statement -/

$PROOF"
mk empty-proof.lean result "$STMT
/-! @proof -/

"
check "an empty statement section is refused"         says "$TMP/empty-stmt.lean" 'section is empty'
check "an empty proof section is refused"             says "$TMP/empty-proof.lean" 'section is empty'

# ---- 3. what may accompany a statement --------------------------------------------------------
# A registry claim's statement is the registry's; a deposit discharging it supplies none.
mk disch.lean result "$STMT
$PROOF" '@discharges: MTH.C-2026-0001'
check "@discharges with a statement is refused"       says "$TMP/disch.lean" '@discharges and a'
mk pose-result.lean result "$STMT"
check "a posed claim must be @kind: claim"            says "$TMP/pose-result.lean" 'must be `@kind: claim`'

# ---- 4. the statement's form, at the source level ---------------------------------------------
# `stmt_case <name> <statement body>` builds a posed claim around the body.
stmt_case() { mk "$1" claim "/-! @statement -/
$2"; }
stmt_case ok-by.lean        'theorem Probe.t (n : Nat) : n = n := by sorry'
stmt_case ok-by-nl.lean     'theorem Probe.t (n : Nat) : n = n := by
  sorry'
stmt_case ok-comments.lean  '/-- A docstring may say sorry. -/
def d : Nat := 1 -- so may a comment: sorry
def s : String := "and a string: sorry"
def c : Char := '"'"'x'"'"'
/- a block /- nested -/ comment with sorry -/
@[simp] theorem Probe.t (h'"'"' : d = 1) : d = 1 := sorry'
stmt_case def-sorry.lean    'def d : Nat := sorry
theorem Probe.t : d = d := sorry'
stmt_case inst-sorry.lean   'instance : Inhabited Nat := sorry
theorem Probe.t : True := sorry'
stmt_case example.lean      'example : True := sorry
theorem Probe.t : True := sorry'
stmt_case exact-sorry.lean  'theorem Probe.t : True := by exact sorry'
stmt_case fun-sorry.lean    'theorem Probe.t : True → True := fun _ => sorry'
stmt_case admit.lean        'theorem Probe.t : True := by admit'
stmt_case sorryax.lean      'theorem Probe.t : True := sorryAx True false'
stmt_case two-sorry.lean    'theorem Probe.t (x : Nat := sorry) : True := sorry'
stmt_case proved.lean       'theorem Probe.t : True := trivial'
stmt_case where.lean        'theorem Probe.t : True := sorry
where aux : Nat := 1'
stmt_case decreasing.lean   'def f : Nat → Nat
  | 0 => 0
  | n+1 => f n
decreasing_by sorry
theorem Probe.t : True := sorry'
stmt_case unterminated.lean '/- never closed
theorem Probe.t : True := sorry'

check "\`:= by sorry\` is a statement"                parses "$TMP/ok-by.lean"
check "\`:= by\` then \`sorry\` on its own line too"  parses "$TMP/ok-by-nl.lean"
check "sorry in comments/strings/docstrings is not a sorry" parses "$TMP/ok-comments.lean"
check "a sorry definition is refused"                 says "$TMP/def-sorry.lean" 'not in a `theorem` or `lemma`'
check "  and the refusal names the file line"         says "$TMP/def-sorry.lean" 'line 15'
check "a sorry instance is refused"                   refused "$TMP/inst-sorry.lean"
check "a sorry example is refused"                    refused "$TMP/example.lean"
check "\`by exact sorry\` is refused"                 refused "$TMP/exact-sorry.lean"
check "\`fun _ => sorry\` is refused"                 refused "$TMP/fun-sorry.lean"
check "\`admit\` is refused"                          says "$TMP/admit.lean" 'not proved by exactly'
check "an explicit sorryAx is refused"                refused "$TMP/sorryax.lean"
check "a sorry in a default argument is refused"      refused "$TMP/two-sorry.lean"
check "a theorem with a real proof is refused"        says "$TMP/proved.lean" 'not proved by exactly'
check "a sorry followed by \`where\` is refused"      refused "$TMP/where.lean"
check "\`decreasing_by sorry\` is refused"            refused "$TMP/decreasing.lean"
check "an unterminated comment is refused"            says "$TMP/unterminated.lean" 'unterminated'
# The PROOF section has no source-level form: a sorry there is the axiom audit's to reject
# (sorryAx is not a permitted axiom), where it cannot be hidden behind a macro either.
mk proof-sorry.lean result "$STMT
/-! @proof -/
theorem Probe.t : True := sorry
"
check "a sorry in the proof section parses (the audit rejects it)" parses "$TMP/proof-sorry.lean"

# ---- 5. cutting the parts ---------------------------------------------------------------------
part() { "$PY" "$PARSE" --part "$1" "$2"; }
part statement "$TMP/two-imports.lean" > "$TMP/S.lean"
part proof     "$TMP/two-imports.lean" > "$TMP/P.lean"
N="$(awk 'END{print NR}' "$TMP/two-imports.lean")"
check "the statement part keeps every line number"    test "$(awk 'END{print NR}' "$TMP/S.lean")" = "$N"
check "the proof part keeps every line number"        test "$(awk 'END{print NR}' "$TMP/P.lean")" = "$N"
check "the statement part holds no proof"             bash -c "! grep -q 'omega\|@proof' '$TMP/S.lean'"
check "the proof part holds no statement"             bash -c "! grep -q ':= sorry\|@statement' '$TMP/P.lean'"
# Each surviving line is the file's own line, at its own number.
check "statement lines are the file's, in place"      bash -c "diff <(sed -n '16,22p' '$TMP/two-imports.lean') <(sed -n '16,22p' '$TMP/S.lean')"
check "proof lines are the file's, in place"          bash -c "diff <(sed -n '23,29p' '$TMP/two-imports.lean') <(sed -n '23,29p' '$TMP/P.lean')"

# Differing imports are impossible BY CONSTRUCTION: both parts are the same file above the first
# marker — imports and header, byte for byte — and an import anywhere below the header, in
# either section, is refused before any part is cut.
check "both parts share the file's prefix, byte for byte" bash -c \
  "cmp <(head -n 15 '$TMP/two-imports.lean') <(head -n 15 '$TMP/S.lean') && cmp <(head -n 15 '$TMP/two-imports.lean') <(head -n 15 '$TMP/P.lean')"
mk import-in-proof.lean result "$STMT
/-! @proof -/
import Init.Data.List.Basic
theorem Probe.t : True := trivial
"
check "an import inside a section is refused"         says "$TMP/import-in-proof.lean" 'import below the metadata header'
check "  so no part is ever cut from it"              bash -c "! '$PY' '$PARSE' --part proof '$TMP/import-in-proof.lean'"

check "--part on a single-part deposit is refused"    bash -c "! '$PY' '$PARSE' --part statement '$TMP/single.lean'"
check "--part proof on a posed claim is refused"      bash -c "! '$PY' '$PARSE' --part proof '$TMP/pose.lean'"
check "--part statement on a posed claim works"       bash -c "'$PY' '$PARSE' --part statement '$TMP/pose.lean' | grep -q ':= sorry'"
# A refused deposit yields no part at all, even though the cut itself would be well-defined.
check "--part is refused whenever the parse is"       bash -c "! '$PY' '$PARSE' --part statement '$TMP/def-sorry.lean'"

echo
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
