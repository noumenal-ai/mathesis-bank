/* tests/diff/oracle.c: the independent half of the differential test.
 *
 * For each input word w (hex, one per line on stdin), for every 32-bit word with --all, or for
 * every w with LO <= w < HI with --range LO HI:
 *   reinterpret w as a float f (memcpy); if !isfinite(f) print "none";
 *   else fr = frexpf(f, &ex);              f = fr * 2^ex, 0.5 <= |fr| < 1, exact
 *        m  = (int64_t) ldexpf(fr, 24);    exact: fr has at most 24 significant bits
 *        e  = ex - 24; normalise (strip trailing zero bits; m = 0 gives e = 0);
 *        print "m e".
 *
 * It shares no logic with decode32. It never extracts the sign, exponent or fraction field; it goes
 * through the C library's float semantics instead, so a mistake in how decode32 reads the fields
 * cannot be repeated here.
 *
 * Build: cc -O2 -ffp-contract=off -fno-fast-math oracle.c -lm
 */
#include <inttypes.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void emit(uint32_t w) {
  float f;
  memcpy(&f, &w, sizeof f);
  if (!isfinite(f)) {
    fputs("none\n", stdout);
    return;
  }
  int ex = 0;
  float fr = frexpf(f, &ex);
  int64_t m = (int64_t) ldexpf(fr, 24);
  int64_t e = (int64_t) ex - 24;
  if (m == 0) {
    e = 0;
  } else {
    while ((m & 1) == 0) {
      m /= 2;
      e += 1;
    }
  }
  printf("%" PRId64 " %" PRId64 "\n", m, e);
}

int main(int argc, char **argv) {
  if (argc == 2 && strcmp(argv[1], "--all") == 0) {
    uint32_t w = 0;
    do {
      emit(w);
    } while (++w != 0);
    return 0;
  }
  /* --range LO HI: every word w with LO <= w < HI, so a sweep can run in slices. */
  if (argc == 4 && strcmp(argv[1], "--range") == 0) {
    uint64_t lo = strtoull(argv[2], NULL, 0), hi = strtoull(argv[3], NULL, 0);
    if (lo > hi || hi > 0x100000000ull) {
      fprintf(stderr, "oracle: bad range %s %s\n", argv[2], argv[3]);
      return 2;
    }
    for (uint64_t w = lo; w < hi; w++) emit((uint32_t) w);
    return 0;
  }
  char line[64];
  while (fgets(line, sizeof line, stdin)) {
    unsigned long w;
    if (sscanf(line, "%lx", &w) != 1 || w > 0xFFFFFFFFul) {
      fprintf(stderr, "oracle: not a 32-bit hex word: %s", line);
      return 2;
    }
    emit((uint32_t) w);
  }
  return 0;
}
