#!/usr/bin/env python3
"""Does a record publish the statement the kernel actually checked?

    python3 ci/test_statement_binding.py

`bin/mathesis verify`'s re-derivation leg replays every frozen export and compares the result to
the manifest: the verdict, the kernel's acceptance, the target's presence, the triviality flag
and the axioms. Every one of those is about the TERM. None of them was about the WORDS.

So a record could publish any rendering it liked and pass. `statement_digest` was the sha256 of
`pretty`, and `pretty` is produced by pretty-printing in an environment that imports the
author's own module, where their `notation` and `@[app_unexpander]` declarations are live while
their own theorem is printed:

    theorem rh : Disguised := trivial
    notation "RiemannHypothesis" => Disguised

renders as `RiemannHypothesis`. The axiom audit passes, the kernel accepts the replay, the
triviality flag is clear, and the record says something it did not prove.

The adjudicator renders from the exact `Expr` the kernel replayed, in an empty environment where
no delaborator has been registered — notation lives in syntax extensions, which a kernel export
does not contain. That string is a function of the term alone, so the gate produces it again
here, over the published blob, on a stranger's machine.

These assertions are about `statement_mismatch`, which is where that decision is made. The leg
around it is a dict lookup and a call. No Lean toolchain and no network.
"""

from __future__ import annotations

import hashlib
import importlib.util
from importlib.machinery import SourceFileLoader
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# `bin/mathesis` has no .py suffix, so importlib infers no loader from the path and
# spec_from_file_location returns None. Naming the loader is the whole fix; the alternative —
# renaming the verifier — would change the command every reader of the README types.
_loader = SourceFileLoader("mathesis_cli", str(ROOT / "bin" / "mathesis"))
_spec = importlib.util.spec_from_loader("mathesis_cli", _loader)
cli = importlib.util.module_from_spec(_spec)
_loader.exec_module(cli)

PASSES: list[str] = []
FAILURES: list[str] = []


def check(name: str, ok: bool, detail: str = "") -> None:
    (PASSES if ok else FAILURES).append(name if ok else f"{name}: {detail}")
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + (f"  ({detail})" if detail else ""))


HONEST = "∀ (n : Nat), Nat.le n n"
DISGUISED = "RiemannHypothesis"


def digest(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def claim(**over) -> dict:
    c = {"accession": "MTH.C-2026-6500", "statement_digest": digest(HONEST),
         "statement_source": "kernel"}
    c.update(over)
    return c


def target(**over) -> dict:
    t = {"decl": "rh", "axioms_reached": [], "statement": HONEST}
    t.update(over)
    return t


# ---- the binding holds -----------------------------------------------------------------------

check("a_record_whose_digest_matches_the_kernel_passes",
      cli.statement_mismatch(claim(), target()) is None)

# ---- the binding is broken --------------------------------------------------------------------

# The attack, end to end: the record publishes the author's flattering rendering while the term
# the kernel replayed says something else.
bad = cli.statement_mismatch(claim(statement_digest=digest(DISGUISED)), target())
check("a_record_publishing_a_rendering_the_kernel_did_not_produce_is_caught",
      bad is not None and "publishes" in bad, repr(bad))

# A record that claims the guarantee while the gate rendered nothing is making an unsupported
# claim about itself — an older gate, or a record that was not produced the way it says.
for missing in (None, "", "   "):
    got = cli.statement_mismatch(claim(), target(statement=missing))
    check(f"claiming_the_binding_with_no_gate_statement_is_refused ({missing!r})",
          got is not None and "rendered no statement" in got, repr(got))

# ---- records that do not claim the binding -----------------------------------------------------

# The 32 curated records. Their graphs and verdicts no longer exist on disk, so they cannot be
# regenerated to acquire the binding; failing them here would report an honest corpus as broken.
# What they get is a record that does not claim the guarantee, which is the truthful outcome.
c = claim(statement_digest=digest(DISGUISED))
del c["statement_source"]
check("a_record_that_does_not_claim_the_binding_is_not_held_to_it",
      cli.statement_mismatch(c, target()) is None)

check("a_missing_claim_is_not_an_assertion_about_statements",
      cli.statement_mismatch(None, target()) is None)


# ---- and the corpus on disk --------------------------------------------------------------------

# The schema permits the field; these assert what the committed records actually say, so that
# adding one with the binding is a visible change rather than a silent one.
claims = [json.loads(p.read_text()) for p in sorted((ROOT / "bank" / "claims").glob("*.json"))]
claims = [c.get("claim", c) for c in claims]
bound = [c["accession"] for c in claims if c.get("statement_source") == "kernel"]
check("every_committed_claim_declares_what_its_digest_is_of",
      all(c.get("statement_source") in (None, "kernel") for c in claims),
      f"{len(bound)} of {len(claims)} carry the binding")

# ---- the schema edit itself --------------------------------------------------------------------

# The corpus validating proves the field is OPTIONAL. It does not prove the field is ACCEPTED,
# because no committed claim carries one — `additionalProperties: false` would reject it and the
# corpus would still pass. So this validates a claim that does carry it, and one that carries a
# value outside the enum, against the real schema.
try:
    from jsonschema import Draft202012Validator

    schema = json.loads((ROOT / "schema" / "bank-manifest.v2.schema.json").read_text())
    shape = schema["$defs"]["claimFile"]
    # A committed claim when there is one, and a synthetic one when the record is empty: the
    # question is whether the schema accepts the field, which needs a claim of the right shape,
    # not a particular record.
    committed = sorted((ROOT / "bank" / "claims").glob("*.json"))
    real = json.loads(committed[0].read_text()) if committed else {
        "accession": "MTH.C-2026-6999", "arguments_count": 1, "citation_name": "A. Author",
        "created_at": "2026-01-01T00:00:00Z", "decl_name": "sample", "login": "author",
        "dictionary_id": "00000000-0000-4000-8000-000000000000", "module": "Submission",
        "origin": "deposited", "pretty": "True", "profile_id": "00000000-0000-4000-8000-000000000001",
        "reference_sha256": "0" * 64, "statement_digest": "0" * 64,
    }
    real = real.get("claim", real)

    v = Draft202012Validator({**shape, "$defs": schema["$defs"]})
    ok = list(v.iter_errors({**real, "statement_source": "kernel"}))
    check("the_schema_accepts_a_claim_carrying_the_binding", not ok,
          "; ".join(e.message for e in ok)[:120])

    bad = list(v.iter_errors({**real, "statement_source": "author"}))
    check("the_schema_refuses_a_value_outside_the_enum", bool(bad),
          "anything was accepted" if not bad else "")
except ImportError:
    # Not a silent pass: the schema half simply did not run, and says so in the words
    # run_tests.sh and this repository's CI both read.
    print("\n  not exercised: the schema half, for want of `jsonschema`")

print()
print(f"{len(PASSES)} passed, {len(FAILURES)} failed")
sys.exit(1 if FAILURES else 0)
