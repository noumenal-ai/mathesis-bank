#!/usr/bin/env python3
"""A claim can carry the depositor's title and words.

    python3 ci/test_claim_words.py

The deposit form asks for a title and for the result "in words", and both now reach the
record: the words under the Lean on a feed card, the title in the Collection and search. They
are the author's assertions, like a relation, and nothing re-derives them; what this checks is
only that the schema carries them in the shape the generator writes, and refuses what it
should.

The ones that matter:

* `a_claim_without_either_is_still_valid`. Every record published before this, and every
  curated one, has neither, and must keep verifying.
* `a_title_over_one_line_is_refused` is not here on purpose: a line break is the gateway's to
  refuse at intake, where the depositor can be told. The schema's job is the bound.

Fails closed without `jsonschema`, as `bin/mathesis verify` does.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

PASSES: list[str] = []
FAILURES: list[str] = []


def check(name: str, ok: bool, detail: str = "") -> None:
    (PASSES if ok else FAILURES).append(name if ok else f"{name}: {detail}")
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + (f"  ({detail})" if detail and not ok else ""))


try:
    from jsonschema import Draft202012Validator
except ImportError:
    print("FAIL  python package `jsonschema` is not installed (pip install jsonschema)")
    sys.exit(1)

SCHEMA = json.loads((ROOT / "schema" / "bank-manifest.v2.schema.json").read_text())
VALIDATOR = Draft202012Validator({**SCHEMA["$defs"]["claimFile"], "$defs": SCHEMA["$defs"]})

CLAIM = {
    "accession": "MTH.C-2026-6999", "arguments_count": 1, "citation_name": "A. Author",
    "created_at": "2026-01-01T00:00:00Z", "decl_name": "sample", "login": "author",
    "dictionary_id": "00000000-0000-4000-8000-000000000000", "module": "Submission",
    "origin": "deposited", "pretty": "True", "profile_id": "00000000-0000-4000-8000-000000000001",
    "reference_sha256": "0" * 64, "statement_digest": "0" * 64,
}


def errors(**over) -> list[str]:
    return [e.message for e in VALIDATOR.iter_errors({**CLAIM, **over})]


e = errors()
check("a_claim_without_either_is_still_valid", not e, "; ".join(e))

e = errors(title="Twice a product is at most the sum of the squares",
           words="For real a and b, 2ab is at most a² + b².")
check("a_claim_with_a_title_and_words_is_valid", not e, "; ".join(e))

check("an_empty_title_is_refused", bool(errors(title="")), "an empty title was accepted")
check("an_empty_statement_in_words_is_refused", bool(errors(words="")), "empty words were accepted")
check("a_title_past_two_hundred_characters_is_refused", bool(errors(title="x" * 201)),
      "a 201-character title was accepted")
check("words_past_two_thousand_characters_are_refused", bool(errors(words="x" * 2001)),
      "2001 characters of words were accepted")
check("a_title_must_be_text", bool(errors(title=7)), "a number was accepted as a title")

committed = [json.loads(p.read_text()) for p in sorted((ROOT / "bank" / "claims").glob("*.json"))]
bad = [c.get("accession") for c in committed if list(VALIDATOR.iter_errors(c.get("claim", c)))]
check("every_committed_claim_is_valid", not bad, f"invalid: {bad[:3]}")

print()
print(f"{len(PASSES)} passed, {len(FAILURES)} failed")
sys.exit(1 if FAILURES else 0)
