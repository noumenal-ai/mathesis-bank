#!/usr/bin/env python3
"""Write the differential test's input words: one file per case class, one 8-digit hex word a line.

  (a) every exponent field 0..255, x fraction fields {0, 1, 2, 0x400000, 0x7FFFFE, 0x7FFFFF},
      x both signs: 3072 words
  (b) every NaN boundary: exponent field 255 with fraction 1, 0x400000 or 0x7FFFFF, both signs: 6
  (c) 10^6 uniformly random 32-bit words, from the fixed seed below

    python3 tests/diff/cases.py OUTDIR      writes OUTDIR/a.hex, b.hex and c.hex
"""
import pathlib
import random
import sys

SEED = 20261007
RANDOM_WORDS = 1_000_000
FRACTIONS = [0, 1, 2, 0x400000, 0x7FFFFE, 0x7FFFFF]
NAN_FRACTIONS = [1, 0x400000, 0x7FFFFF]


def word(sign: int, exponent: int, fraction: int) -> int:
    return (sign << 31) | (exponent << 23) | fraction


def main() -> None:
    out = pathlib.Path(sys.argv[1])
    rng = random.Random(SEED)
    classes = {
        "a": [word(s, e, f) for s in (0, 1) for e in range(256) for f in FRACTIONS],
        "b": [word(s, 255, f) for s in (0, 1) for f in NAN_FRACTIONS],
        "c": [rng.getrandbits(32) for _ in range(RANDOM_WORDS)],
    }
    for name, words in classes.items():
        (out / f"{name}.hex").write_text("".join(f"{w:08x}\n" for w in words))


if __name__ == "__main__":
    main()
