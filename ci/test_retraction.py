#!/usr/bin/env python3
"""Withdrawing a record without deleting it.

    python3 ci/test_retraction.py

There was no way to withdraw anything. `bankgen` contains no removal path at all — the only
`remove_*` call in it is a test tidying its own temp directory — so the bank was additive-only
and a record published in error had to stay, unmarked.

Deleting one is not the answer. A claim whose argument file is gone fails the crosslinks leg,
the README lists exactly that as a way to break the verifier deliberately, and an accession
scheme whose whole point is that a citation resolves should not answer one with a 404.

So a retraction marks. The record still re-derives — the kernel accepted that replay and nothing
about the mathematics changed — and what is withdrawn is the recommendation.

The two that matter:

* `a_partial_retraction_is_refused`. A record marked withdrawn with no reason tells a reader
  that something is wrong and not what, which is worse than leaving it alone.
* `a_withdrawn_record_is_reported_and_does_not_fail`. Failing would make one retraction cascade
  into a corpus that will not verify, which is a reason not to retract anything — the wrong
  incentive. Staying silent would let `verify` end in "no failures" over a corpus containing
  records that do not stand.
"""

from __future__ import annotations

import importlib.util
import io
import json
import sys
from contextlib import redirect_stdout
from importlib.machinery import SourceFileLoader
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
_loader = SourceFileLoader("mathesis_cli", str(ROOT / "bin" / "mathesis"))
_spec = importlib.util.spec_from_loader("mathesis_cli", _loader)
cli = importlib.util.module_from_spec(_spec)
_loader.exec_module(cli)

PASSES: list[str] = []
FAILURES: list[str] = []


def check(name: str, ok: bool, detail: str = "") -> None:
    (PASSES if ok else FAILURES).append(name if ok else f"{name}: {detail}")
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + (f"  ({detail})" if detail else ""))


WHO = "4571f84a-7314-5307-b61c-95010a1333a9"
WHEN = "2026-09-28T00:00:00Z"
WHY = "The statement is true and reads as something stronger than it is."


def claim(**over) -> dict:
    c = {"accession": "MTH.C-2026-6501", "statement_digest": "a" * 64}
    c.update(over)
    return c


# ---- the schema -------------------------------------------------------------------------------

try:
    from jsonschema import Draft202012Validator

    schema = json.loads((ROOT / "schema" / "bank-manifest.v2.schema.json").read_text())
    shape = schema["$defs"]["claimFile"]
    # A committed claim when there is one, and a synthetic one when the record is empty: what is
    # being tested is the schema's rule for the three fields, which needs a claim of the right
    # shape, not a particular record.
    on_disk = sorted((ROOT / "bank" / "claims").glob("*.json"))
    real = json.loads(on_disk[0].read_text()) if on_disk else {
        "accession": "MTH.C-2026-6999", "arguments_count": 1, "citation_name": "A. Author",
        "created_at": "2026-01-01T00:00:00Z", "decl_name": "sample", "login": "author",
        "dictionary_id": "00000000-0000-4000-8000-000000000000", "module": "Submission",
        "origin": "deposited", "pretty": "True", "profile_id": "00000000-0000-4000-8000-000000000001",
        "reference_sha256": "0" * 64, "statement_digest": "0" * 64,
    }
    real = real.get("claim", real)
    v = Draft202012Validator({**shape, "$defs": schema["$defs"]})

    full = {**real, "retracted_at": WHEN, "retracted_by": WHO, "retraction_reason": WHY}
    errs = list(v.iter_errors(full))
    check("a_retracted_claim_validates", not errs, "; ".join(e.message for e in errs)[:110])

    # Each of the three on its own must be refused: they are one assertion in three fields.
    for lone in ("retracted_at", "retracted_by", "retraction_reason"):
        partial = {**real, lone: {"retracted_at": WHEN, "retracted_by": WHO,
                                  "retraction_reason": WHY}[lone]}
        refused = bool(list(v.iter_errors(partial)))
        check(f"a_partial_retraction_is_refused ({lone})", refused,
              "" if refused else "accepted a retraction missing its siblings")

    check("an_empty_reason_is_refused",
          bool(list(v.iter_errors({**full, "retraction_reason": ""}))))

    # The corpus as committed. Adding the first retraction should be a visible diff, not a
    # thing that quietly becomes true.
    committed = [json.loads(p.read_text()) for p in sorted((ROOT / "bank" / "claims").glob("*.json"))]
    committed = [c.get("claim", c) for c in committed]
    marked = [c["accession"] for c in committed if c.get("retracted_at")]
    check("no_record_is_withdrawn_today", not marked, f"withdrawn: {marked}")
except ImportError:
    print("\n  not exercised: the schema half, for want of `jsonschema`")


# ---- the leg ----------------------------------------------------------------------------------

def run_leg(claims: list[dict], args: list[dict]) -> str:
    saved_c, saved_a = cli.claims, cli.argument_files
    cli.claims = lambda: claims
    cli.argument_files = lambda: args
    try:
        buf = io.StringIO()
        with redirect_stdout(buf):
            cli.leg_standing()
        return buf.getvalue()
    finally:
        cli.claims, cli.argument_files = saved_c, saved_a


out = run_leg([claim(), claim(accession="MTH.C-2026-6002", statement_digest="b" * 64)], [])
check("a_corpus_in_good_standing_says_nothing", out.strip() == "", repr(out)[:60])

withdrawn = claim(retracted_at=WHEN, retracted_by=WHO, retraction_reason=WHY)
out = run_leg([withdrawn], [])
check("a_withdrawn_record_is_reported_and_does_not_fail",
      "MTH.C-2026-6501" in out and WHY in out, repr(out)[:80])

# An argument whose step carries a withdrawn claim's statement digest leans on it. Same
# derivation leg_dependencies makes, applied to standing rather than to identity.
dependent = {
    "argument": {"accession": "MTH.R-2026-6009", "claim_accession": "MTH.C-2026-6009"},
    "nodes": [{"is_root": True, "type_sha256": "c" * 64, "decl_name": "root"},
              {"is_root": False, "type_sha256": "a" * 64, "decl_name": "step"}],
}
out = run_leg([withdrawn], [dependent])
check("an_argument_leaning_on_a_withdrawn_record_is_named",
      "MTH.R-2026-6009" in out and "withdrawn" in out, repr(out)[:90])

# The root is the argument's own claim, not a dependency on someone else's.
own_root = {
    "argument": {"accession": "MTH.R-2026-6501", "claim_accession": "MTH.C-2026-6501"},
    "nodes": [{"is_root": True, "type_sha256": "a" * 64, "decl_name": "root"}],
}
out = run_leg([withdrawn], [own_root])
check("a_records_own_root_is_not_a_dependency_on_itself",
      "MTH.R-2026-6501 has a step" not in out, repr(out)[:80])

print()
print(f"{len(PASSES)} passed, {len(FAILURES)} failed")
sys.exit(1 if FAILURES else 0)
