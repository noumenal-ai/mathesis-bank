# Handoff — Mathesis IDE prototype

Working notes for the cloud session. **Delete this file and `mockups/` before opening any PR.**

## Standing rules from Dhruv
- Never add Co-Authored-By Claude, or any Claude attribution, to commits or PR bodies.
- Merge only what Dhruv approved. Right before a merge, run `gh pr checks <n>` and require every
  check to pass: the CodeQL summary can fail while every Analyze job passes.
- Discuss before large changes, and mock up before redesigns. The IDE decisions below are approved;
  post-merge ingestion (task 2D) is not, so propose it first.
- Site copy on social surfaces: no counts, and no wording about verification (it is the unstated
  baseline). People come first: the author's avatar and linked name. Times New Roman throughout.
- No GCP actions. The VM judge is parked: VM `dhruv-mathesis-lean-01` is stopped, and its code is on
  branch `judge-vm`.

## Task 1 — merge PR #14 once green (approved)
- https://github.com/noumenal-ai/mathesis-bank/pull/14 (branch `gate/kernel-builtins`).
- `verify.yml` was dispatched on the branch as run 36100289644. Every step through "Verify (strict
  re-derivation against frozen exports)" passed. "Re-derive the published bank from its frozen
  exports" was still running.
- When that run concludes `success` and `gh pr checks 14` is all pass, run `gh pr merge 14 --merge`.
  Then watch the push-triggered `verify.yml` on `main` (about 25 minutes, including the Pages deploy).
- If anything fails, don't merge. Report the failing step and the relevant log lines.
- Afterwards, rebase `ide/prototype` onto `main`.

## Task 2 — IDE prototype (approved decisions)
1. **Comparator format.** Every submission carries a statement part and a proof part.
2. **Live feedback.** A "Try it in Lean 4 Web" button opens https://live.lean-lang.org with the code.
3. **No server and no OAuth.** Submitting copies the file and opens GitHub's new-file page at
   `deposits/<slug>/submission.lean`. Prefill `value=` only while the URL stays under about 7 KB:
   GitHub returns 414 at 8 KB and above (measured).

Build each of the following as its own PR for Dhruv's review. Do not merge them.

**A. CI: Mathlib deposits (Phase 2b).**
- `deposit.yml` builds only `deploy/builder/Dockerfile` (Lean core), so no deposit can import
  Mathlib yet.
- Wire in `deploy/builder/Dockerfile.mathlib` (builder target) and `Dockerfile.exportrt` for deposits
  pinning `@mathlib: fabf563a7c95a166b8d7b6efca11c8b4dc9d911f`. `ci/gate_deposit.sh` takes the images
  from its environment (`MATHESIS_BUILDER_IMAGE` and the export image).
- Keep the `--network none` / read-only confinement.
- Cache the image (GHCR or the Actions cache) so a run doesn't refetch Mathlib.

**B. CI: two-part deposits.**
- Keep one file, so submitting is one paste. It has two sections:
  - **statement:** definitions plus theorem statements, where every theorem's proof is exactly `sorry`;
  - **proof:** the same theorem names, proved, with any extra lemmas.
- `parse_deposit.py` splits the sections. `gate_deposit.sh` then:
  1. builds the statement part and checks its form (no sorry outside theorem proofs, axiom-clean
     definitions);
  2. exports it as the reference R;
  3. builds the proof part;
  4. runs `mathesis-adjudicate --reference R candidate -- <decls>`.
- "Pose a claim" is a statement section alone.
- The existing `@discharges` mode stays for proving registry claims.
- Add tests in the style of `ci/test_deposit_format.sh`, plus a fixture run.

**C. The IDE page.**
- Lives in the Vite+TS client (`web/`), with a route and link from the site generator
  (`services/registry/crates/record`). Match `mockups/ide.html`:
  - three modes: New argument, Pose a claim, Prove a claim;
  - Statement and Proof tabs, with the statement locked in Prove mode;
  - title, gloss and byline.
- **Editor:** CodeMirror 6 with Lean highlighting and Lean's unicode abbreviations (`\to` → `→`).
- **Header format:** take it from the retired form, `git show 0b0e0d4:site/deposit.js` (`buildFile`):
  imports hoisted above the `/-! @kind/@title/@module/@decls/@pin/@mathlib/@discharges -/` header
  (see `ci/parse_deposit.py`).
- **Client-side checks:** no `prelude`, the same imports in both parts, and no
  `#eval`/`run_cmd`/`run_elab`.
- **Lean 4 Web link:** check the URL-fragment parameter name (`#codez=` with lz-string?) against the
  lean4web source.
- Build with `bank/tools/build-site.sh`. The prose lint and the catalogue labels/fields must pass.

**D. Post-merge ingestion (design first).**
- Nothing turns a merged deposit into a claim (MTH.C, frozen statement export) plus an argument
  (MTH.R) on the site.
- This touches accession numbering, the release export stores (`exports-v1`, `bank-exports-v1`) and
  the people registry. Propose a design to Dhruv before building it.

## Context
- **Pins:** Lean v4.31.0; Mathlib `fabf563a`. The gate pins lean4export `ca36c44` and Lean4Checker `b739819`.
- **No open claims exist.** All 212 registry claims are self-seeded (WMSpec, Eidometry) and already
  discharged. Their modules can't be imported by deposits until the definitions-only dictionary
  package exists.
- **Fork-PR workflows need maintainer approval** for every external contributor (a repo setting).
- **Pushes that touch `.github/workflows/` need a token with `workflow` scope.**
