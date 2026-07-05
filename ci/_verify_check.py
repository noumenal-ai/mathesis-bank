#!/usr/bin/env python3
"""
Helper for ci/verify.sh: re-derives the verification facts for the registry
and prints one JSON object to stdout.

Post-F6 hardening
------------------
The prior version of this file was a byte-faithful re-check of the
manifest's OWN recorded fields (schema validity + recorded verdict.result +
a whitelist check on the recorded axiom_manifest) and never re-derived
anything from the frozen export. Finding F6 proved that is exploitable: a
`sorry` proof of a false statement, or any hand-edited manifest, passes
GREEN as long as its own recorded fields say so, and the axiom check had a
second escape hatch (`excess <= trust_boundary_extensions`) that let a
result self-declare its way past the whitelist.

This version:
  1. Makes the axiom check STRICT. The whitelist is fixed:
     {propext, Classical.choice, Quot.sound}. A result is axiom_clean IFF
     its recorded axiom_manifest, as a set, is a SUBSET of the whitelist.
     There is no excess-vs-trust_boundary_extensions escape any more. Any
     result whose trust_boundary_extensions is non-empty is routed to
     needs_human_review and is NEVER counted clean, independent of what its
     axiom_manifest says.
  2. Re-derives axiom-closure and replay from the frozen export itself, not
     from the manifest's recorded fields, by invoking an independent Lean
     re-derivation executable (mathesis-adjudicate) against the immutable
     .export blob and comparing its fresh verdict to the recorded one.
     Results sharing one export blob are batched into a single exe
     invocation (the corpus's two blobs are 321MB/74MB; one process per
     blob, not one per declaration).

No LLM anywhere in this path (INV-4). Kept as its own file (rather than an
inline bash heredoc) so quoting is not fragile across bash 3.2 (macOS) and
bash 4+/5 (GitHub Actions runners).
"""
import hashlib
import json
import os
import subprocess
import sys
import glob

try:
    import jsonschema
except ImportError:
    print(json.dumps({"error": "jsonschema not installed"}))
    sys.exit(2)


# Fixed whitelist. Not configurable at the call site — widening this is a
# code change, not a data change, by design.
AXIOM_WHITELIST = {"propext", "Classical.choice", "Quot.sound"}

# Large artifacts (the .export blobs and the built re-derivation exe) live
# OUTSIDE this repo — blobs in object storage (fetched by ci/fetch_exports.sh),
# the exe built on the CI runner. Their locations are env-configurable so the
# same script runs unchanged in CI and on a dev box:
#   MATHESIS_EXPORTS_DIR  — dir holding <sha>.export blobs
#   MATHESIS_ADJUDICATE   — path to the mathesis-adjudicate binary
# with the local dev tree as the last-resort fallback.
_LOCAL_ROOT = os.environ.get(
    "MATHESIS_V431_ROOT",
    "/Users/polaris/Documents/Epistemology and Zetesis/Noumenal/Mathesis-v4.31",
)


def _first_existing(*cands):
    for c in cands:
        if c and os.path.exists(c):
            return c
    return cands[-1]


EXPORTS_DIR = os.environ.get("MATHESIS_EXPORTS_DIR") or _first_existing(
    os.path.join(os.getcwd(), "registry", "_shared", "exports"),
    os.path.join(_LOCAL_ROOT, "registry", "_shared", "exports"),
)
DEFAULT_ADJUDICATE_BIN = _first_existing(
    os.path.join(_LOCAL_ROOT, "backend", "lean", ".lake", "build", "bin", "mathesis-adjudicate"),
)


def sha256_of_file(path, chunk_size=8 * 1024 * 1024):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def run_rederivation(results):
    """
    Re-derive axiom-closure/replay for every result with a frozen_export by
    invoking the independent Lean adjudication exe directly against the
    immutable .export blob — never trusting the manifest's own recorded
    axiom_manifest/verdict fields.

    Returns (rederive_status, rederive_mismatch, verified_handles) where
    verified_handles is the set of result handles that were actually run
    through re-derivation and passed (used to gate axiom_clean/admitted
    downstream, if the caller chooses to require it).
    """
    mismatch = []
    verified = set()

    adjudicate_bin = os.environ.get("MATHESIS_ADJUDICATE") or DEFAULT_ADJUDICATE_BIN

    with_export = {h: m for h, m in results.items() if m.get("frozen_export")}

    if not with_export:
        return "no-exports-declared", mismatch, verified

    if not os.path.isfile(adjudicate_bin) or not os.access(adjudicate_bin, os.X_OK):
        # The production re-derivation exe is not built yet. Degrade
        # honestly: nothing is counted as re-derivation-verified, and the
        # output says so explicitly rather than silently reporting green.
        return "skipped-exe-absent", mismatch, verified

    # Group by export sha256 — many results share one blob; call the exe
    # once per blob with every associated decl, not once per decl.
    by_sha = {}
    for h, m in with_export.items():
        fe = m["frozen_export"]
        by_sha.setdefault(fe["sha256"], []).append(h)

    for sha, handles in by_sha.items():
        export_path = os.path.join(EXPORTS_DIR, f"{sha}.export")

        # --- integrity: file sha256 == recorded sha256 == filename sha ---
        # (filename-vs-recorded is checked per-handle below since more than
        # one manifest can point at the same sha; here we just need the one
        # file to exist and hash-match before we trust it for ANY of them.)
        if not os.path.isfile(export_path):
            for h in handles:
                mismatch.append({"handle": h, "reason": f"export blob missing on disk: {export_path}"})
            continue

        actual_sha = sha256_of_file(export_path)
        if actual_sha != sha:
            for h in handles:
                mismatch.append({
                    "handle": h,
                    "reason": f"export blob sha256 mismatch: file={actual_sha} recorded/filename={sha}",
                })
            continue

        # Per-handle integrity: recorded sha256 must equal the sha used as
        # the filename/group key, and decl_names must be present.
        decls = []
        decl_owner = {}
        group_ok_handles = []
        for h in handles:
            m = results[h]
            fe = m["frozen_export"]
            if fe.get("sha256") != sha:
                mismatch.append({"handle": h, "reason": "frozen_export.sha256 does not match its own group key"})
                continue
            names = (m.get("statement") or {}).get("decl_names") or []
            if not names:
                mismatch.append({"handle": h, "reason": "no statement.decl_names to re-derive"})
                continue
            for n in names:
                decl_owner.setdefault(n, []).append(h)
                decls.append(n)
            group_ok_handles.append(h)

        if not decls:
            continue

        # --- invoke the Lean re-derivation exe once for this blob ---
        # NOTE on exit code: the real exe exits nonzero (1) whenever its
        # whole-invocation verdict is REJECTED (i.e. ANY target in the batch
        # fails), but it still emits a complete, valid JSON report on
        # stdout in that case — a batch containing one bad decl must not
        # cause us to discard the (possibly many) genuinely-clean targets
        # in the same batch. So: parse stdout regardless of returncode, and
        # only treat a nonzero exit as fatal-for-everyone-in-the-batch if
        # stdout does NOT parse as JSON at all (a real crash/panic).
        # The exe is a self-contained static binary — it runs standalone with
        # no `lake env` / toolchain / cwd dependency (verified). Invoke it
        # directly so CI needs only the binary + the blob, not the backend tree.
        cmd = [adjudicate_bin, export_path, "--"] + decls
        try:
            proc = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=1800,
            )
        except Exception as e:
            for h in group_ok_handles:
                mismatch.append({"handle": h, "reason": f"exe invocation failed: {e}"})
            continue

        try:
            fresh = json.loads(proc.stdout)
        except Exception as e:
            for h in group_ok_handles:
                mismatch.append({
                    "handle": h,
                    "reason": (
                        f"adjudicate exe exited {proc.returncode} with unparseable stdout "
                        f"({e}); stderr: {proc.stderr.strip()[:500]}"
                    ),
                })
            continue

        # Real shape (verified against the built mathesis-adjudicate exe):
        #   {"export": str, "constants": int, "permitted": [str, ...],
        #    "replay": {"accepted": bool, "detail": str},
        #    "targets": [{"decl": str, "axiom_audit": "pass"|"fail",
        #                 "axioms_reached": [str, ...],
        #                 "illegal_axiom": str|null}, ...],
        #    "verdict": "ADMITTED"|"REJECTED"}
        # `replay.accepted` and `verdict` are WHOLE-INVOCATION fields (one
        # bad target anywhere in the batch flips the top-level verdict to
        # REJECTED) — per-target correctness is judged from that target's
        # own axiom_audit/illegal_axiom/axioms_reached, not from the
        # top-level verdict, so one bad theorem sharing a blob with many
        # good ones doesn't spuriously fail the good ones. The top-level
        # replay.accepted IS a whole-batch gate, though: if the kernel
        # rejected the export's replay outright, nothing decoded from that
        # batch can be trusted, whatever individual axiom_audits claim.
        whole_replay_accepted = bool((fresh.get("replay") or {}).get("accepted"))
        targets_by_decl = {}
        for t in (fresh.get("targets") or []):
            if isinstance(t, dict) and t.get("decl"):
                targets_by_decl[t["decl"]] = t

        for decl_name, owners in decl_owner.items():
            target = targets_by_decl.get(decl_name)
            for h in owners:
                if h not in group_ok_handles:
                    continue
                m = results[h]
                if target is None:
                    mismatch.append({"handle": h, "reason": f"adjudicate output missing target {decl_name}"})
                    continue

                reasons = []
                if not whole_replay_accepted:
                    reasons.append("whole-export replay not accepted by the Lean kernel")
                if target.get("axiom_audit") != "pass":
                    reasons.append(f"axiom_audit={target.get('axiom_audit')!r} (want 'pass')")
                if target.get("illegal_axiom"):
                    reasons.append(f"illegal axiom reached: {target['illegal_axiom']!r}")

                fresh_axioms = set(target.get("axioms_reached") or [])
                recorded_axioms = set(m.get("axiom_manifest") or [])
                undisclosed = (fresh_axioms - AXIOM_WHITELIST) - recorded_axioms
                if undisclosed:
                    reasons.append(f"fresh axioms undisclosed by recorded axiom_manifest: {sorted(undisclosed)}")

                recorded_verdict = (m.get("verdict") or {}).get("result")
                if recorded_verdict == "ADMITTED" and target.get("axiom_audit") == "fail":
                    reasons.append("recorded verdict=ADMITTED but fresh per-target re-derivation rejects this decl")

                if reasons:
                    mismatch.append({"handle": h, "reason": "; ".join(reasons)})
                else:
                    verified.add(h)

    return "ran", mismatch, verified


def main():
    root = os.getcwd()
    schema_path = os.path.join(root, "schema", "unit-manifest.v2.schema.json")
    schema = json.load(open(schema_path))
    validator = jsonschema.Draft202012Validator(schema)

    banks = {"dictionary": "MTH.D", "claims": "MTH.C", "results": "MTH.R"}

    all_handles = {}
    schema_valid = 0
    schema_total = 0
    schema_fail_detail = []

    for bank_key in banks:
        for path in sorted(glob.glob(os.path.join(root, "registry", bank_key, "*", "manifest.json"))):
            schema_total += 1
            handle = os.path.basename(os.path.dirname(path))
            try:
                m = json.load(open(path))
            except Exception as e:
                schema_fail_detail.append(f"{handle}: unreadable ({e})")
                continue
            errs = sorted(validator.iter_errors(m), key=lambda e: e.path)
            if errs:
                schema_fail_detail.append(f"{handle}: {errs[0].message}")
                continue
            schema_valid += 1
            all_handles[handle] = m

    results = {h: m for h, m in all_handles.items() if m["deposit_class"] == "demonstration"}
    claims = {h: m for h, m in all_handles.items() if m["deposit_class"] == "claim"}
    definitions = {h: m for h, m in all_handles.items() if m["deposit_class"] == "definition"}

    # --- replay: every result's own recorded verdict is ADMITTED ---
    # (Still reported — it is the CI re-check of the founding whole-theory
    # replay run's own recorded outcome — but no longer the whole story:
    # rederive_mismatch below is what actually catches a falsified verdict.)
    admitted = sum(1 for m in results.values() if (m.get("verdict") or {}).get("result") == "ADMITTED")
    not_admitted = [h for h, m in results.items() if (m.get("verdict") or {}).get("result") != "ADMITTED"]

    # --- axioms: STRICT whitelist check, no trust_boundary_extensions escape ---
    axiom_clean = 0
    axiom_dirty = []
    needs_human_review = []
    for h, m in results.items():
        tbe = m.get("trust_boundary_extensions") or []
        if tbe:
            # A non-empty trust_boundary_extensions can NEVER make a
            # deposit clean; it routes to human review instead, full stop.
            needs_human_review.append({"handle": h, "trust_boundary_extensions": sorted(tbe)})
            continue
        ax = set(m.get("axiom_manifest") or [])
        excess = ax - AXIOM_WHITELIST
        if not excess:
            axiom_clean += 1
        else:
            axiom_dirty.append({"handle": h, "excess_axioms": sorted(excess)})

    # --- crosslinks: claim <-> result handles resolve ---
    broken = []
    for h, m in claims.items():
        for r in (m.get("discharged_by") or []):
            if r not in all_handles:
                broken.append(f"{h} -> {r}")
        for dep in (m.get("dependency_closure") or []):
            if dep["handle"] not in all_handles:
                broken.append(f"{h} -> {dep['handle']} (dependency)")
    for h, m in results.items():
        d = m.get("discharges")
        if d and d not in all_handles:
            broken.append(f"{h} -> {d}")
        for dep in (m.get("dependency_closure") or []):
            if dep["handle"] not in all_handles:
                broken.append(f"{h} -> {dep['handle']} (dependency)")

    # --- re-derivation: the core fix. Never trust the recorded fields; go
    # back to the frozen export and re-run an independent Lean adjudication. ---
    rederive_status, rederive_mismatch, rederive_verified = run_rederivation(results)

    axiom_dirty_handles = [d["handle"] for d in axiom_dirty]
    ok = (
        schema_valid == schema_total
        and len(broken) == 0
        and len(axiom_dirty_handles) == 0
        and len(needs_human_review) == 0
        and len(rederive_mismatch) == 0
    )

    # STRICT mode (set MATHESIS_STRICT=1 in CI): re-derivation is not optional.
    # Without this, an absent exe or missing blob yields rederive_status=
    # "skipped-exe-absent" with an empty mismatch list — which would pass GREEN
    # WITHOUT ever re-deriving, silently reintroducing the F6 hole on the
    # deployed runner. Strict mode fails closed: every Result must have been
    # actually re-derived from its frozen export.
    strict = os.environ.get("MATHESIS_STRICT", "").strip().lower() not in ("", "0", "false", "no")
    strict_failures = []
    if strict:
        if rederive_status != "ran":
            strict_failures.append(f"re-derivation did not run (status={rederive_status})")
        if len(rederive_verified) != len(results):
            strict_failures.append(
                f"only {len(rederive_verified)}/{len(results)} Results were re-derived from their frozen export"
            )
        if strict_failures:
            ok = False

    out = {
        "schema_total": schema_total,
        "schema_valid": schema_valid,
        "schema_fail_detail": schema_fail_detail[:20],
        "results_total": len(results),
        "admitted": admitted,
        "not_admitted": not_admitted[:20],
        "axiom_clean": axiom_clean,
        "axiom_dirty": axiom_dirty_handles[:20],
        "axiom_dirty_detail": axiom_dirty[:20],
        "needs_human_review": needs_human_review[:50],
        "broken_crosslinks": broken[:20],
        "broken_crosslinks_count": len(broken),
        "rederive_status": rederive_status,
        "rederive_verified_count": len(rederive_verified),
        "rederive_mismatch": rederive_mismatch[:50],
        "strict": strict,
        "strict_failures": strict_failures,
        "exports_dir": EXPORTS_DIR,
        "counts": {
            "definitions": len(definitions),
            "claims": len(claims),
            "results": len(results),
            "total_accessions": len(all_handles),
        },
        "ok": ok,
    }
    print(json.dumps(out))
    # verify.sh treats ANY nonzero exit from this script as "python check
    # failed" (infrastructure error) and skips writing docs/verification.json
    # entirely (see verify.sh's PY_STATUS handling). Pass/fail on the checks
    # themselves is communicated through the JSON fields (including "ok")
    # and left to verify.sh's own bash logic to act on, exactly as before —
    # this process exits 0 whenever it successfully produced a verdict,
    # however unflattering that verdict is.


if __name__ == "__main__":
    main()
