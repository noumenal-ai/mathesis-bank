# Mathesis

Mathesis is an evidence bank for machine-checked machine-learning theory, published by
Noumenal Research. It is modeled on GenBank or the Protein Data Bank, not a journal: it holds
verified units (accessions) and lets commentary, applications, and later overlay journals build
on top, instead of gating publication behind a single editorial judgment.

There are three banks:

- **Dictionary** (`MTH.D-YYYY-NNNN`): definitions used across the claims and results.
- **Claims** (`MTH.C-YYYY-NNNN`): statements of record, frozen before any proof is attempted.
- **Results** (`MTH.R-YYYY-NNNN`): kernel-checked demonstrations that discharge claims.

A verified unit is called a **demonstration**. Every accession is immutable once written;
corrections mint a new accession and record the supersession link rather than editing history.

This repository is the **static read site** (Tier A of the Mathesis architecture): it renders
the already-populated registry. It does not run a backend, hold auth, or accept deposits. A later,
separate phase adds git-native deposit intake (pull requests to the registry, gated in CI).

## Layout

```
site/       source of truth: the generator (generate.py) + styles.css + app.js + verify.js
docs/       BUILT Pages root (generated, do not hand-edit): index.html, styles.css, app.js,
            data/*.json, data/a/<handle>.json, a/<handle>.html, verification.json
ci/         verify.sh (+ its helper _verify_check.py) and verify.yml (GitHub Actions)
registry/   snapshot of the 430 accession dirs: manifest.json + gloss.md + pin.json only
            (the large frozen-export audit artifacts are not stored in this repo)
schema/     unit-manifest.v2.schema.json, the schema every manifest validates against
```

## Building the site

```
pip install jsonschema
python3 site/generate.py     # reads registry/, validates every manifest, writes docs/
ci/verify.sh docs/verification.json   # re-derives the Verify button's facts from the registry
```

`generate.py` is deterministic and idempotent: running it twice on an unchanged registry produces
byte-identical output. It validates every manifest against `schema/unit-manifest.v2.schema.json`
and fails loudly (non-zero exit) on the first invalid manifest or on any hit against the language
firewall (see below). It never computes or edits a gate-emitted field (`tier`, `axiom_manifest`,
`verdict`); those are rendered verbatim from the manifest.

`ci/verify.sh` re-derives, straight from the registry snapshot (no LLM anywhere in this path):
that every manifest is schema-valid, that every Result's own recorded verdict is `ADMITTED`, that
every Result's axiom closure is a subset of `{propext, Classical.choice, Quot.sound}` (or declares
the excess explicitly), and that every claim&#8596;result cross-link resolves. It writes
`docs/verification.json`, which the site's Verify button reads.

Because `generate.py` rebuilds `docs/` from a clean slate each run, it preserves an existing
non-placeholder `verification.json` across the wipe, so the build order between `generate.py` and
`verify.sh` does not matter.

## Language firewall

None of a fixed list of internal-programme terms may appear anywhere in the built `docs/` output.
`generate.py` greps its own output for this list and fails the build on any hit; `ci/verify.yml`
runs an independent second check. The one documented exception: the bare character `γ` is allowed
strictly inside `<pre>`/`<code>` spans, because two accessions in the registry (`MTH.R/C-2026-1041`)
legitimately use `γ` as an ordinary Lean bound type-variable name in their pretty-printed statement,
unrelated content that only collides on the bare character; byte-faithful rendering means the
generator must not rewrite a manifest's own statement text to dodge the collision. See
`_GREEK_GAMMA` in `site/generate.py` for the exact, narrow scope of that carve-out.

## GitHub Pages setup

Pages serves from `main` / `docs/`. Enable it in the repo's Settings &rarr; Pages once the repo
exists on GitHub.

**Note:** pushing files under `.github/workflows/` requires a token with the `workflow`
scope. If your push account lacks it, add `.github/workflows/verify.yml` (copied from
`ci/verify.yml`) through GitHub's web editor instead.

## What this site is not

It is not a journal and does not run peer review. It does not rank accessions, compute a single
quality score, or show citation counts; where scale and depth of checking both matter, it shows
two separate counts (T0, T2) rather than one combined number. See `docs/charter.html` (source:
the `render_charter` function in `site/generate.py`) for the full charter, including the trust
base and what "kernel-checked; interrogation pending" means for a Dictionary definition.
