import { StringStream } from "@codemirror/language";
import { describe, expect, it } from "vitest";
import { lockedLines } from "./editor";
import { glyphPath } from "./glyph";
import { leanParser } from "./lean-mode";
import { claimStatement } from "./mount";

function tokens(src: string): [string, string | null][] {
  const state = leanParser.startState!(2);
  const out: [string, string | null][] = [];
  for (const line of src.split("\n")) {
    const s = new StringStream(line, 2, 2);
    while (!s.eol()) {
      const style = leanParser.token(s, state);
      if (s.current().trim() !== "") out.push([s.current(), style]);
      s.start = s.pos;
    }
  }
  return out;
}

describe("Lean highlighting", () => {
  it("tells keywords, names, comments and strings apart", () => {
    const t = tokens('theorem foo : ∀ n : Nat, n = n := by -- note\n  simp [h] "s"');
    expect(t).toContainEqual(["theorem", "keyword"]);
    expect(t).toContainEqual(["foo", "variableName"]);
    expect(t).toContainEqual(["∀", "keyword"]);
    expect(t).toContainEqual(["Nat", "typeName"]);
    expect(t).toContainEqual(["-- note", "comment"]);
    expect(t).toContainEqual(["simp", "keyword"]);
    expect(t).toContainEqual(['"s"', "string"]);
  });

  it("carries a nested block comment across lines", () => {
    const t = tokens("/- a /- b -/\nstill -/ def");
    expect(t).toEqual([["/- a /- b -/", "comment"], ["still -/", "comment"], ["def", "keyword"]]);
  });
});

describe("the lock a claim's statement carries", () => {
  it("marks the theorem from its head to the line that opens its proof", () => {
    const text = "import Mathlib\n\nlemma aux : True := trivial\n\ntheorem A.b :\n    1 = 1 := by\n  rfl\n";
    expect(lockedLines(text, "A.b")).toEqual([5, 6]);
    expect(lockedLines(text, "missing")).toBeNull();
  });

  it("writes a claim's statement as a part proved by sorry", () => {
    expect(claimStatement("A.b", "∀ n : ℕ,\n  n = n")).toBe(
      "import Mathlib\n\ntheorem A.b :\n    ∀ n : ℕ,\n      n = n := by\n  sorry\n",
    );
  });
});

describe("the glyph", () => {
  it("draws the same login the same way, whatever its case", () => {
    expect(glyphPath("Zetetic-Dhruv")).toEqual(glyphPath("zetetic-dhruv"));
    expect(glyphPath("a")).not.toEqual(glyphPath("b"));
    expect(glyphPath("x").tint).toBeGreaterThanOrEqual(0);
    expect(glyphPath("x").tint).toBeLessThan(4);
  });
});
