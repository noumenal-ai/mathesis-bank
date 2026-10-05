#!/usr/bin/env python3
"""Who a profile can be: someone with a GitHub account, and someone without one.

    python3 ci/test_profiles.py

Stet accounts are made with GitHub or with Google. A depositor who signed in with Google and
never connected GitHub has no GitHub id and no GitHub account type, and the profile says so with
two nulls rather than inventing values or leaving the fields out. Everything the record credits
them with is in the profile and the claim: the handle, the citation name, the accession.

The ones that matter:

* `a_profile_without_github_is_valid`, and its partner
  `github_type_is_null_exactly_when_the_id_is`. Half a GitHub identity is a mistake, not a
  third kind of account.
* `a_record_of_deposits_alone_has_no_owner`. A deposited profile is never the owner, so a bank
  whose only profiles came from deposits has none. The schema used to require exactly one owner
  as soon as there was any profile, which turned the first deposit into an empty bank into a
  failing pull request.
* `two_owners_are_refused`. The owner is the curator; two would make the flag mean nothing.

Fails closed without `jsonschema`, as `bin/mathesis verify` does: this file is the schema check.
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


def errors(ref: str, doc) -> list[str]:
    v = Draft202012Validator({"$defs": SCHEMA["$defs"], "$ref": f"#/$defs/{ref}"})
    return [e.message for e in v.iter_errors(doc)]


def profile(**over) -> dict:
    p = {
        "id": "4571f84a-7314-5307-b61c-95010a1333a9",
        "login": "ada",
        "display_name": "Ada Lovelace",
        "citation_name": "Ada Lovelace",
        "github_user_id": 17,
        "github_type": "User",
        "kind": "person",
        "is_owner": False,
        "created_at": "2026-10-05T00:00:00Z",
        "avatar": None,
    }
    p.update(over)
    return p


GITHUB = profile()
GOOGLE = profile(id="0c6a8a5e-3f0e-5d3a-9a49-1b1c2d3e4f50", login="grace",
                 display_name="Grace Hopper", citation_name="Grace Hopper",
                 github_user_id=None, github_type=None)

# ---- one profile ------------------------------------------------------------------------------

e = errors("profile", GITHUB)
check("a_profile_with_github_is_valid", not e, "; ".join(e))

e = errors("profile", GOOGLE)
check("a_profile_without_github_is_valid", not e, "; ".join(e))

e = errors("profile", profile(github_type=None))
check("github_type_is_null_exactly_when_the_id_is", bool(e), "an id with no type was accepted")

e = errors("profile", profile(github_user_id=None))
check("a_type_without_an_id_is_refused", bool(e), "a type with no id was accepted")

e = errors("profile", {k: v for k, v in GOOGLE.items() if k != "github_user_id"})
check("the_github_fields_are_stated_not_omitted", bool(e), "a profile with the id left out was accepted")

e = errors("profile", profile(github_type="Bot"))
check("an_unknown_account_type_is_refused", bool(e), "github_type 'Bot' was accepted")

# ---- the file ---------------------------------------------------------------------------------

e = errors("profilesFile", [])
check("an_empty_record_has_no_profiles", not e, "; ".join(e))

e = errors("profilesFile", [GITHUB, GOOGLE])
check("a_record_of_deposits_alone_has_no_owner", not e, "; ".join(e))

e = errors("profilesFile", [profile(is_owner=True), GOOGLE])
check("one_owner_beside_deposits_is_valid", not e, "; ".join(e))

e = errors("profilesFile", [profile(is_owner=True), dict(GOOGLE, is_owner=True)])
check("two_owners_are_refused", bool(e), "two owners were accepted")

# ---- what is committed ------------------------------------------------------------------------

committed = json.loads((ROOT / "bank" / "profiles.json").read_text())
e = errors("profilesFile", committed)
check("the_committed_profiles_are_valid", not e, "; ".join(e[:3]))

print()
print(f"{len(PASSES)} passed, {len(FAILURES)} failed")
sys.exit(1 if FAILURES else 0)
