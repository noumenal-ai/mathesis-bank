// Lean's unicode input: `\to` becomes `→`, `\forall` `∀`, `\N` `ℕ`.
//
// The table is Lean's own, the `abbreviations.json` the VS Code extension
// ships in `@leanprover/unicode-input`, and the resolution follows its
// `AbbreviationProvider`: an abbreviation is completed to the shortest entry it
// is a prefix of, and a tail that extends no entry is kept as typed after the
// replaced prefix. It is replaced when a character arrives that cannot extend
// it (a space, a tab, any other character), or at once when it is complete
// and no longer entry begins with it.

import table from "@leanprover/unicode-input/dist/abbreviations.json";

const ABBREVIATIONS: Record<string, string> = table as Record<string, string>;
const CURSOR = "$CURSOR";

/** Every prefix of every abbreviation, the abbreviations themselves included. */
const PREFIXES = new Set<string>();
/** Every proper prefix: what a longer abbreviation still begins with. */
const PROPER = new Set<string>();
/** Abbreviations in the provider's order: shortest first, ties in table order. */
const BY_LENGTH = Object.keys(ABBREVIATIONS)
  .map((k, i) => ({ k, i }))
  .sort((a, b) => a.k.length - b.k.length || a.i - b.i)
  .map((e) => e.k);
for (const k of BY_LENGTH) {
  for (let n = 1; n <= k.length; n++) {
    PREFIXES.add(k.slice(0, n));
    if (n < k.length) PROPER.add(k.slice(0, n));
  }
}

const cache = new Map<string, string | undefined>();

/** The replacement for a typed abbreviation, without the leading backslash. */
export function replacementText(abbrev: string): string | undefined {
  if (abbrev === "") return undefined;
  if (cache.has(abbrev)) return cache.get(abbrev);
  let out: string | undefined;
  if (PREFIXES.has(abbrev)) {
    const k = BY_LENGTH.find((key) => key.startsWith(abbrev));
    out = k === undefined ? undefined : ABBREVIATIONS[k];
  } else {
    const head = replacementText(abbrev.slice(0, -1));
    out = head === undefined ? undefined : head + abbrev.slice(-1);
  }
  cache.set(abbrev, out);
  return out;
}

export interface Expansion {
  /** Offset into the text before the cursor where the backslash sits. */
  from: number;
  /** What replaces everything from `from` to the cursor, plus the typed character. */
  insert: string;
  /** Where the cursor lands, as an offset into `insert`. */
  cursor: number;
}

function finish(from: number, symbol: string, tail: string): Expansion {
  const at = symbol.indexOf(CURSOR);
  const text = symbol.replace(CURSOR, "");
  const insert = text + tail;
  return { from, insert, cursor: at === -1 ? insert.length : at };
}

/**
 * What typing `typed` does to the line before the cursor, `before`. Null means
 * "insert the character as usual": either no abbreviation is being typed, or
 * the character extends one that is not finished yet.
 *
 * `typed` is `"\t"` for the Tab key, which completes without inserting itself.
 */
export function expandOnType(before: string, typed: string): Expansion | null {
  const m = /\\([^\s\\]*)$/.exec(before);
  if (!m) return null;
  // A backslash inside a string literal is an escape, not an abbreviation.
  if (((before.slice(0, m.index).match(/"/g) ?? []).length & 1) === 1) return null;
  const abbrev = m[1] as string;
  const from = m.index;
  const extends_ = typed.length === 1 && !/\s/.test(typed) && PREFIXES.has(abbrev + typed);
  if (extends_) {
    const next = abbrev + typed;
    // Complete, and nothing longer begins with it: replace at once.
    if (ABBREVIATIONS[next] !== undefined && !PROPER.has(next)) {
      return finish(from, ABBREVIATIONS[next] as string, "");
    }
    return null;
  }
  const symbol = replacementText(abbrev);
  if (symbol === undefined) return null;
  return finish(from, symbol, typed === "\t" ? "" : typed);
}
