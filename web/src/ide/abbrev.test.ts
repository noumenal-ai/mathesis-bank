import table from "@leanprover/unicode-input/dist/abbreviations.json";
import { describe, expect, it } from "vitest";
import { expandOnType, replacementText } from "./abbrev";

/** Type `keys` one character at a time into an empty line, as the editor does. */
function type(keys: string): string {
  let line = "";
  let cursor = 0;
  for (const k of keys) {
    const before = line.slice(0, cursor);
    const e = expandOnType(before, k);
    if (e) {
      line = before.slice(0, e.from) + e.insert + line.slice(cursor);
      cursor = e.from + e.cursor;
    } else if (k !== "\t") {
      line = before + k + line.slice(cursor);
      cursor += 1;
    }
  }
  return line;
}

describe("Lean's unicode abbreviations", () => {
  it.each([
    ["to", "→"], ["forall", "∀"], ["exists", "∃"], ["and", "∧"], ["or", "∨"], ["not", "¬"],
    ["le", "≤"], ["ge", "≥"], ["ne", "≠"], ["N", "ℕ"], ["Z", "ℤ"], ["R", "ℝ"], ["Q", "ℚ"],
    ["lam", "λ"], ["fun", "λ"], ["alpha", "α"], ["beta", "β"], ["epsilon", "ε"], ["sub", "⊆"],
    ["iff", "↔"], ["in", "∈"], ["x", "×"], ["o", "∘"], ["-1", "⁻¹"], ["|-", "⊢"],
  ])("\\%s is %s", (abbrev, symbol) => {
    expect(replacementText(abbrev)).toBe(symbol);
  });

  it("completes a prefix to the shortest entry, and keeps an unknown tail", () => {
    expect(replacementText("alp")).toBe("α");
    expect(replacementText("alp7")).toBe("α7");
    expect(replacementText("")).toBeUndefined();
  });

  it("expands on a space and keeps the space", () => {
    expect(type("a \\to b")).toBe("a → b");
    expect(type("\\forall x, \\exists y, x \\le y")).toBe("∀ x, ∃ y, x ≤ y");
  });

  it("expands on any character that cannot extend the abbreviation", () => {
    expect(type("(\\N)")).toBe("(ℕ)");
    expect(type("\\a,")).toBe("α,");
  });

  it("expands on Tab without inserting it", () => {
    expect(type("\\R\t")).toBe("ℝ");
  });

  it("expands at once when nothing longer begins with the abbreviation", () => {
    expect(type("\\alpha")).toBe("α");
  });

  it("starts a second abbreviation right after the first", () => {
    expect(type("\\N\\to\\N ")).toBe("ℕ→ℕ ");
  });

  it("places the cursor inside a bracket pair", () => {
    expect(type("\\<>x")).toBe("⟨x⟩");
  });

  it("leaves a backslash inside a string alone", () => {
    expect(type('"a\\n" ')).toBe('"a\\n" ');
  });

  it("does nothing without a backslash", () => {
    expect(expandOnType("to", " ")).toBeNull();
  });

  it("carries no star glyph, which verify.yml's INV-2 lint refuses in docs/", () => {
    // Lean's table maps \bigstar to U+2605; vite.config.ts drops the entry before bundling.
    expect(Object.entries(table).filter(([, v]) => /[★⭐]/u.test(v))).toEqual([]);
    expect(replacementText("bigstar")).not.toContain("★");
  });
});
