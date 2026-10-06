#!/usr/bin/env python3
"""A record of deposits alone has no owner, and never two.

    python3 ci/test_owner.py

The schema used to require exactly one `is_owner` profile as soon as there was any profile.
A deposited profile is never the owner (bankgen writes `is_owner: false`), so the first
deposit into the emptied record would have failed its own pull request's verify, and with it
every publication after. At most one owner now: the curator, when there is one. The renderer
never reads the flag.

Fails closed without `jsonschema`.
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
V = Draft202012Validator({**SCHEMA["$defs"]["profilesFile"], "$defs": SCHEMA["$defs"]})


def profile(login: str, owner: bool) -> dict:
    return {"id": "4571f84a-7314-5307-b61c-95010a1333a9", "login": login, "display_name": login,
            "citation_name": login, "github_user_id": 17, "github_type": "User", "kind": "person",
            "is_owner": owner, "created_at": "2026-10-06T00:00:00Z", "avatar": None}


def errors(doc) -> list[str]:
    return [e.message for e in V.iter_errors(doc)]


check("an_empty_record_has_no_profiles", not errors([]), "; ".join(errors([])))
e = errors([profile("ada", False)])
check("a_record_of_deposits_alone_has_no_owner", not e, "; ".join(e)[:120])
e = errors([profile("ada", True), profile("grace", False)])
check("one_owner_beside_deposits_is_valid", not e, "; ".join(e)[:120])
check("two_owners_are_refused", bool(errors([profile("ada", True), profile("grace", True)])),
      "two owners were accepted")
committed = json.loads((ROOT / "bank" / "profiles.json").read_text())
e = errors(committed)
check("the_committed_profiles_are_valid", not e, "; ".join(e)[:120])

print()
print(f"{len(PASSES)} passed, {len(FAILURES)} failed")
sys.exit(1 if FAILURES else 0)
