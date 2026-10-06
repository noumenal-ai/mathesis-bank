#!/usr/bin/env python3
"""Write the benchmark data and Lean files of the plan's section 8.

For each n in SIZES: bench/<n>.f32 holds n uniformly random finite binary32 words (fixed seed; a
word with exponent field 255 is drawn again), and four Lean files state one claim about them:

  Bench_<n>_S.lean       only `def S`: the elaboration time and .olean size of the data
  Bench_<n>_decide.lean  `def S` and the claim, by `decide`
  Bench_<n>_kernel.lean  `def S` and the claim, by `decide +kernel`
  Bench_<n>_rfl.lean     `def S` and the claim as `Dyadic.blt … = true`, by `rfl`

Bench_base.lean only imports the library, to separate out Lean's startup cost.

With --probe, it also writes the sizes beyond the plan, from their own seed, where the data is a
`noncomputable def` and the claim is closed by `decide +kernel`, the only form that reaches them:
probe<n>.f32 and Probe_<n>_kernel.lean. These are not committed.

    python3 bench/mkbench.py [--probe]
"""
import pathlib
import random
import struct
import sys

SEED = 20261007
SIZES = [10, 100, 1000, 10000]
PROBE_SEED = 20261008
PROBE_SIZES = [30000, 100000]
HERE = pathlib.Path(__file__).resolve().parent

PROBE = """import StetData

/-- {n} random finite binary32 values, decoded by the kernel. -/
noncomputable def S : List (Option Dyadic) := (f32bits% "probe{n}.f32").toList.map decode32

example : (S.filterMap id).sum < Dyadic.ofIntWithPrec 1 (-200) := by decide +kernel
"""

HEADER = """import StetData

/-- {n} random finite binary32 values, decoded by the kernel. -/
def S : List (Option Dyadic) := (f32bits% "{n}.f32").toList.map decode32
"""

# The claim: the values sum to less than 2^200 (the plan's `Dyadic.mk' 1 200`). It is true:
# every finite binary32 value is below 2^128 in magnitude.
CLAIMS = {
    "S": "",
    "decide": "\nexample : (S.filterMap id).sum < Dyadic.ofIntWithPrec 1 (-200) := by decide\n",
    "kernel": "\nexample : (S.filterMap id).sum < Dyadic.ofIntWithPrec 1 (-200) := by decide +kernel\n",
    "rfl": "\nexample : Dyadic.blt (S.filterMap id).sum (Dyadic.ofIntWithPrec 1 (-200)) = true := rfl\n",
}


def finite_words(rng: random.Random, n: int) -> list[int]:
    words: list[int] = []
    while len(words) < n:
        w = rng.getrandbits(32)
        if (w >> 23) & 0xFF != 0xFF:
            words.append(w)
    return words


def main() -> None:
    rng = random.Random(SEED)
    for n in SIZES:
        words = finite_words(rng, n)
        (HERE / f"{n}.f32").write_bytes(b"".join(struct.pack("<I", w) for w in words))
        for form, claim in CLAIMS.items():
            (HERE / f"Bench_{n}_{form}.lean").write_text(HEADER.format(n=n) + claim)
    (HERE / "Bench_base.lean").write_text("import StetData\n")
    if "--probe" in sys.argv[1:]:
        rng = random.Random(PROBE_SEED)
        for n in PROBE_SIZES:
            words = finite_words(rng, n)
            (HERE / f"probe{n}.f32").write_bytes(b"".join(struct.pack("<I", w) for w in words))
            (HERE / f"Probe_{n}_kernel.lean").write_text(PROBE.format(n=n))


if __name__ == "__main__":
    main()
