# Judge — the Lean FRO comparator on a VM (parked)

A submission judge: [leanprover/comparator](https://github.com/leanprover/comparator), run on a VM
against a claim's locked statement. Each solution is built and exported inside landrun
(Landlock), which runs inside a systemd unit whose process may open no sockets but `AF_PACKET`
(no DNS, no systemd bus).

**Parked.** Submissions are verified in CI for now. This branch keeps the VM judge as it was
when the canary below passed, for when submissions get a live server.

## What is here

- `comparator/mathesis-v4.31.patch`: two commits on comparator `fd2e25de15` (the v4.31
  toolchain), apply with `git am`.
  - **Backported from upstream:**
    - Pass `--` to landrun, so lean4export's own `--` reaches it.
    - Walk projection types (#68).
    - Compare theorem targets by statement only (#64).
    - Check the quotient constants the replay erases (#71).
    - Compare the kernel built-ins `Char.ofNat`, `List`, `Nat`, `String`, `Char` and the parameter annotations.
  - **Our own additions:**
    - Look constants up in the kernel environment. `Environment.find?` misses replayed ones, which made the quotient check reject every honest proof.
    - Add `eagerReduce`, `Lean.reduceBool`, `Lean.reduceNat` and `Bool` to the built-ins; the v4.31 kernel names them.
    - Complete the `prelude` attack tests: upstream's pass only because lean4export aborts on a missing constant.
    - Make `runtests.lean` check each test's reason (`output_contains`), not just its exit code.
- `comparator/run-suite.sh`: builds the comparator and runs its test suite on the VM (16/16).
- `canary/`: one claim (Mathlib's analytic non-Borel set), six solutions, and the runner.
- `provision/`: `provision.sh` (root, once) sets up an unprivileged `judge` user;
  `provision-judge.sh` installs elan, landrun `811cfff51c`, the patched comparator, and the
  canary project with Mathlib `fabf563a` from Mathlib's cache.

## Provisioning

On a fresh Ubuntu 24.04 VM, with a kernel whose Landlock ABI is at least v4:

1. Copy `canary/template`, `canary/cases`, `canary/run-cases.sh`,
   `comparator/mathesis-v4.31.patch` and `provision/provision-judge.sh` to `/tmp/payload/`.
2. Run `provision/provision.sh` as root.
3. Run `canary/run-cases.sh` as `judge`. Results go to `~/canary/results/`.

Tools live in `/home/judge/tools/bin`, which must be on `PATH`: without it the comparator
cannot start landrun and every case fails early.

## Canary (2026-09-25, kernel 7.0 GCP, Landlock ABI v8)

| Solution | Verdict | Reason |
|---|---|---|
| `good` — the proof | admitted | |
| `weaker` — `True` under the claim's name | rejected | statement does not match |
| `axiom` — the statement from an axiom | rejected | illegal axiom `cheat` |
| `sorry` | rejected | illegal axiom `sorryAx` |
| `escape` — write outside the sandbox, reach the network | rejected | the write is denied, so the build fails |
| `escape2` — the proof, plus a systemd-bus and a DNS escape | admitted | both escapes fail; the proof stands |

`results-2026-09-25.txt` is the raw run.
