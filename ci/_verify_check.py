#!/usr/bin/env python3
"""
Helper for ci/verify.sh: re-derives the verification facts straight from the
registry (schema validity, recorded replay verdicts, axiom closure, and
claim<->result cross-links), and prints one JSON object to stdout.

Kept as its own file (rather than an inline bash heredoc) so quoting is not
fragile across bash 3.2 (macOS) and bash 4+/5 (GitHub Actions runners).
No LLM anywhere in this path (INV-4): this is a byte-faithful re-check of the
registry's own recorded fields, never a re-derivation of a verdict.
"""
import json
import os
import sys
import glob

try:
    import jsonschema
except ImportError:
    print(json.dumps({"error": "jsonschema not installed"}))
    sys.exit(2)


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
    admitted = sum(1 for m in results.values() if (m.get("verdict") or {}).get("result") == "ADMITTED")
    not_admitted = [h for h, m in results.items() if (m.get("verdict") or {}).get("result") != "ADMITTED"]

    # --- axioms: whitelist check on results ---
    whitelist = {"propext", "Classical.choice", "Quot.sound"}
    axiom_clean = 0
    axiom_dirty = []
    for h, m in results.items():
        ax = set(m.get("axiom_manifest") or [])
        tbe = set(m.get("trust_boundary_extensions") or [])
        excess = ax - whitelist
        if not excess or excess <= tbe:
            axiom_clean += 1
        else:
            axiom_dirty.append(h)

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

    out = {
        "schema_total": schema_total,
        "schema_valid": schema_valid,
        "schema_fail_detail": schema_fail_detail[:20],
        "results_total": len(results),
        "admitted": admitted,
        "not_admitted": not_admitted[:20],
        "axiom_clean": axiom_clean,
        "axiom_dirty": axiom_dirty[:20],
        "broken_crosslinks": broken[:20],
        "broken_crosslinks_count": len(broken),
        "counts": {
            "definitions": len(definitions),
            "claims": len(claims),
            "results": len(results),
            "total_accessions": len(all_handles),
        },
    }
    print(json.dumps(out))


if __name__ == "__main__":
    main()
