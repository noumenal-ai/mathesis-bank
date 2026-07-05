#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Mathesis — registry verification
#
# Runs the checks the site's "Verify" button reports. Runs identically in CI
# (GitHub Actions) and locally. Emits docs/verification.json.
#
# Checks:
#   1. schema   — every registry/{dictionary,claims,results}/*/manifest.json
#                 validates against schema/unit-manifest.v2.schema.json.
#   2. replay   — the recorded verdict for every Results accession is
#                 ADMITTED (read from the manifest's own verdict field, which
#                 is gate-emitted and never hand-edited — INV-3). This is the
#                 CI re-check of the founding whole-theory replay run.
#   3. axioms   — every Results accession's axiom_manifest is a subset of
#                 {propext, Classical.choice, Quot.sound}, or else declares
#                 the excess explicitly in trust_boundary_extensions.
#   4. crosslinks — every claim.discharged_by handle and every
#                 result.discharges handle resolves to a real accession in
#                 this registry snapshot. 0 broken links required.
#
# No LLM anywhere in this path (INV-4). Pure re-derivation from the registry.
# The registry re-derivation logic lives in ci/_verify_check.py (kept as its
# own file, not an inline heredoc, so quoting stays robust across bash 3.2
# on macOS and bash 4+/5 on GitHub Actions runners).
# ---------------------------------------------------------------------------
set -o pipefail

ROOT="${VERIFY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" || { echo "cannot cd to ROOT=$ROOT" >&2; exit 2; }

OUT="${1:-docs/verification.json}"
PY="${PYTHON:-python3}"

RESULT_JSON="$("$PY" ci/_verify_check.py)"
PY_STATUS=$?
if [ "$PY_STATUS" -ne 0 ]; then
  echo "verify.sh: python check failed" >&2
  echo "$RESULT_JSON" >&2
  exit 2
fi

get() { "$PY" -c "import json,sys; d=json.loads(sys.argv[1]); print(d[sys.argv[2]])" "$RESULT_JSON" "$1"; }
getc() { "$PY" -c "import json,sys; d=json.loads(sys.argv[1]); print(d['counts'][sys.argv[2]])" "$RESULT_JSON" "$1"; }

schema_total="$(get schema_total)"
schema_valid="$(get schema_valid)"
results_total="$(get results_total)"
admitted="$(get admitted)"
axiom_clean="$(get axiom_clean)"
broken_count="$(get broken_crosslinks_count)"

def_count="$(getc definitions)"
claims_count="$(getc claims)"
results_count="$(getc results)"
total_count="$(getc total_accessions)"

schema_status="pass"; [ "$schema_valid" -ne "$schema_total" ] && schema_status="fail"
replay_status="pass"; [ "$admitted" -ne "$results_total" ] && replay_status="fail"
axiom_status="pass"; [ "$axiom_clean" -ne "$results_total" ] && axiom_status="fail"
crosslink_status="pass"; [ "$broken_count" -ne 0 ] && crosslink_status="fail"

overall="pass"
for s in "$schema_status" "$replay_status" "$axiom_status" "$crosslink_status"; do
  [ "$s" = "fail" ] && overall="fail"
done

COMMIT="${GITHUB_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SRC="local"; [ -n "${GITHUB_ACTIONS:-}" ] && SRC="ci"
RUN_URL=""; [ -n "${GITHUB_SERVER_URL:-}" ] && RUN_URL="$GITHUB_SERVER_URL/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-}"

mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<JSON
{
  "schema": 1,
  "generatedBy": "$SRC",
  "repo": "${GITHUB_REPOSITORY:-}",
  "workflow": "verify.yml",
  "commit": "$COMMIT",
  "timestamp": "$NOW",
  "runUrl": "$RUN_URL",
  "status": "$overall",
  "checks": [
    { "id": "schema", "label": "Every manifest validates against schema v2", "status": "$schema_status", "detail": "$schema_valid / $schema_total manifests schema-valid" },
    { "id": "replay", "label": "Recorded whole-theory replay is ADMITTED", "status": "$replay_status", "detail": "$admitted / $results_total results carry verdict ADMITTED" },
    { "id": "axioms", "label": "Axiom closure", "status": "$axiom_status", "detail": "$axiom_clean / $results_total results depend only on propext, Classical.choice, Quot.sound" },
    { "id": "crosslinks", "label": "Claim <-> result cross-links resolve", "status": "$crosslink_status", "detail": "$broken_count broken cross-link(s)" }
  ],
  "counts": {
    "schema_valid": $schema_valid,
    "schema_total": $schema_total,
    "definitions": $def_count,
    "claims": $claims_count,
    "results": $results_count,
    "total_accessions": $total_count,
    "broken_crosslinks": $broken_count
  },
  "axiom_closure": ["propext", "Classical.choice", "Quot.sound"],
  "toolchain": "leanprover/lean4:v4.31.0"
}
JSON

echo "── verification summary ─────────────────────────"
echo "  schema     : $schema_valid / $schema_total valid"
echo "  replay     : $admitted / $results_total ADMITTED"
echo "  axioms     : $axiom_clean / $results_total clean"
echo "  crosslinks : $broken_count broken"
echo "  status     : $overall"
echo "  wrote      : $OUT"
[ "$overall" = pass ] && exit 0 || exit 1
