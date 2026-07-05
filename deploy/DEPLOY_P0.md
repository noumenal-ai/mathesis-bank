# Deploying P0 — strict re-derivation into the live CI

**What P0 does.** The deployed "Verify" check stops re-reading the manifest's own
recorded fields and instead RE-DERIVES every Result from its frozen `.export` through the Lean
kernel gate (`mathesis-adjudicate`), failing closed if the gate or a blob is missing. This closes
the C1 `sorry`-through-CI kill (findings F2/F5/F6).

**Status.** Implemented + validated locally (below). **Option A CHOSEN + PRE-STAGED** on branch
`deploy/p0-strict-rederivation`: `backend-gate/` is vendored (source-only; sanity-built clean) and
committed. What remains is two credentialed actions (blob upload + push) — see below.

---

## The one decision: how the gate SOURCE reaches the public CI

The re-derivation exe must be built (or fetched) on the public `mathesis-bank` runner, but the gate
source currently lives in the *private* `noumenal-ai/mathesis` backend.

| Option | What CI does | Trade-off |
|---|---|---|
| **A — vendor gate source (recommended)** | `verify.yml` builds `mathesis-adjudicate` from `backend-gate/` (Lean-core, ~2-3 min, cached) | Publishes the ~8 gate files (Comparator-derived, Apache-2.0). Anyone can audit the verifier. Most transparent — matches the bank's thesis. |
| B — prebuilt binary | CI downloads a 171 MB binary from a Release asset | No source published, but the verifier is an opaque blob nobody can rebuild-and-compare. Undercuts "anyone can re-derive." |
| C — private checkout | CI checks out the private backend via a deploy key | Source stays private; needs a secret; verifier unauditable to the public. |

**Recommendation: A.** The verifier of a public evidence bank should be public. `verify.yml` as written
assumes A. If you prefer B/C, swap the "Build re-derivation gate" step (notes in `verify.yml`).

---

## Deploy steps (option A — remaining actions only)

**1. Vendor the gate source. — DONE.** `backend-gate/` is vendored (source-only, `.lake` gitignored)
and committed on `deploy/p0-strict-rederivation`. It sanity-built clean (16 jobs, no Mathlib). To
re-stage from scratch: `bash deploy/stage-gate-source.sh`.

**2. Upload the frozen export blobs** (credentialed — run as the account with release rights on
mathesis-bank). One command:
```
MATHESIS_BACKEND="<PRIV>" bash deploy/upload-blobs.sh
```
(`<PRIV>` = the Mathesis-v4.31 root, default already set. Creates Release `exports-v1` if absent and
uploads both sha256-named blobs. GitHub Release assets allow 2 GB/asset; 321 MB + 74 MB fit. The
blobs are public + auditable by design.)

**3. Push the branch + merge to main.** Everything (including `.github/workflows/verify.yml`) is in
one commit on `deploy/p0-strict-rederivation`. Push it as **`dhruvgupta-zetesis`** (the
workflow-scoped collaborator on mathesis-bank — it can push `.github/workflows/`; a non-workflow
token silently rejects that path, the known org gotcha), then open + merge the PR to `main`:
```
git push -u origin deploy/p0-strict-rederivation      # as dhruvgupta-zetesis
gh pr create -R noumenal-ai/mathesis-bank -B main -H deploy/p0-strict-rederivation \
  --title "P0: strict re-derivation CI (F6 fix)" --body "Build gate + fetch blobs + strict verify."
```
(Web-editor fallback for the workflow file if the account isn't handy: paste `.github/workflows/verify.yml`.)
Merging to `main` triggers the run. Do step 2 (blobs) BEFORE merging, or the first run fails closed
(correctly) on missing blobs.

**4. Confirm.** The merge (or Actions → verify → "Run workflow") kicks a run. A green run means:
the gate built, blobs fetched + sha256-verified, and all 171 Results independently re-derived. The
run's `verification.json` (and the site's Verify chip) will show `rederivation: pass`. If a blob or
the gate is missing, the run fails RED (fail-closed) — that is the intended behavior, not a bug.

**Rollback.** `git revert` the deploy commit. (The pre-P0 verify is the exploitable re-check path, so
prefer fixing forward over reverting.)

---

## Local validation already done (so CI is not the first run)
- From-clean build of `mathesis-adjudicate`: 16 jobs, no Mathlib, exit 0 → **build-in-Actions is light + feasible.**
- Exe runs **standalone** (static binary; no `lake env`/toolchain at runtime) → CI needs only the binary + blob.
- Fresh-runner sim: blobs absent → `fetch_exports.sh` (local store) → **both blobs sha256-verified** → strict verify → `ok:true`, `rederive_status:ran`, **171/171 re-derived, 0 mismatch**.
- Fail-closed proven: strict + exe absent → `ok:false`; strict + blobs absent → `ok:false`. No silent green.
