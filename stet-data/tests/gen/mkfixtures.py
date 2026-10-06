#!/usr/bin/env python3
"""Write the fixture files from the tables in the plan's section 6.

The words below were written down before any code ran and checked against hardware floats. They are
not regenerated from the implementation, which would make the checks circular.

    python3 tests/gen/mkfixtures.py
"""
import pathlib
import struct

FIXTURES = pathlib.Path(__file__).resolve().parent.parent / "fixtures"

# Table A, in file order: +0, -0, 1.0, 0.1f, -2.5, min subnormal, max subnormal, min normal,
# max finite, +inf, -inf, quiet NaN, signalling NaN.
EDGE = [
    0x00000000, 0x80000000, 0x3F800000, 0x3DCCCCCD, 0xC0200000, 0x00000001, 0x007FFFFF,
    0x00800000, 0x7F7FFFFF, 0x7F800000, 0xFF800000, 0x7FC00000, 0x7F800001,
]

# Table B: 0.5, 0.25, 1.0, -0.75.
SMALL = [0x3F000000, 0x3E800000, 0x3F800000, 0xBF400000]


def write_words(name: str, words: list[int]) -> None:
    data = b"".join(struct.pack("<I", w) for w in words)
    assert len(data) == 4 * len(words)
    (FIXTURES / name).write_bytes(data)


def main() -> None:
    FIXTURES.mkdir(parents=True, exist_ok=True)
    write_words("edge.f32", EDGE)    # 52 bytes
    write_words("small.f32", SMALL)  # 16 bytes
    # Five bytes, not a multiple of 4: f32bits% must refuse it.
    (FIXTURES / "five-bytes.f32").write_bytes(bytes(5))


if __name__ == "__main__":
    main()
