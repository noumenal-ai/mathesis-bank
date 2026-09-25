import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import LZString from "lz-string";
import { describe, expect, it } from "vitest";
import {
  MATHLIB_REV,
  PIN,
  PREFILL_LIMIT,
  assemble,
  blankComments,
  buildFile,
  checkPart,
  githubNewFileUrl,
  lean4webUrl,
  slugify,
  splitLeadingImports,
  theoremNames,
  type Draft,
} from "./deposit";
import { PROOF_MARKER, STATEMENT_MARKER, serializeParts } from "./sections";
import { REPO_DIR } from "../sources";

const STATEMENT = `import Mathlib

namespace Demo

theorem two_add_two : (2 : ℕ) + 2 = 4 := by
  sorry

end Demo
`;
const PROOF = `import Mathlib

namespace Demo

lemma helper : (2 : ℕ) + 2 = 4 := by norm_num

theorem two_add_two : (2 : ℕ) + 2 = 4 := helper

end Demo
`;

function draft(over: Partial<Draft> = {}): Draft {
  return { mode: "argue", title: "Two and two", gloss: "Four.", statement: STATEMENT, proof: PROOF, ...over };
}

/** ci/parse_deposit.py over a file, when a Python is on the path. */
function parse(file: string): { status: number; json: Record<string, unknown> | null; err: string } | null {
  const py = spawnSync("python3", ["--version"]);
  if (py.status !== 0) return null;
  const dir = mkdtempSync(join(tmpdir(), "ide-deposit-"));
  const path = join(dir, "submission.lean");
  writeFileSync(path, file);
  const r = spawnSync("python3", [join(REPO_DIR, "ci", "parse_deposit.py"), path], { encoding: "utf8" });
  return {
    status: r.status ?? -1,
    json: r.status === 0 ? (JSON.parse(r.stdout) as Record<string, unknown>) : null,
    err: r.stderr,
  };
}

describe("the header", () => {
  it("hoists imports above the header, as buildFile did", () => {
    const file = buildFile(
      { kind: "result", title: "T", module: "Submission", decls: ["a", "b"], imports: ["Mathlib"], gloss: "g", mathlib: MATHLIB_REV },
      "BODY",
    );
    expect(file).toBe(
      [
        "import Mathlib",
        "",
        "/-!",
        "# Mathesis deposit",
        "",
        "@kind: result",
        "@title: T",
        "@module: Submission",
        "@decls: a, b",
        `@pin: ${PIN}`,
        `@mathlib: ${MATHLIB_REV}`,
        "",
        "@gloss:",
        "  g",
        "-/",
        "",
        "BODY",
        "",
      ].join("\n"),
    );
  });

  it("writes no import block and no @mathlib for a core-only file", () => {
    const file = buildFile({ kind: "claim", title: "T", module: "", decls: ["x"], imports: [], gloss: "" }, "B");
    expect(file.startsWith("/-!\n")).toBe(true);
    expect(file).not.toContain("@mathlib");
    expect(file).toContain("@module: Submission");
  });

  it("defuses a title or gloss that would close the header or forge a field", () => {
    const file = buildFile(
      { kind: "result", title: "a -/ b\nc", module: "S", decls: ["x"], imports: [], gloss: "line -/\n@kind: claim" },
      "B",
    );
    const header = file.slice(0, file.indexOf("-/\n"));
    expect(header).toContain("@title: a - / b c");
    expect(header).toContain("  line - /");
    expect(header).toContain("  @ kind: claim");
  });

  it("splits a leading run of imports the way the parser does", () => {
    expect(splitLeadingImports("import A\n\nimport B C -- note\ntheorem x : True := trivial")).toEqual({
      imports: ["A", "B", "C"],
      body: "theorem x : True := trivial",
    });
    const noImports = "-- c\nimport A\n";
    expect(splitLeadingImports(noImports)).toEqual({ imports: [], body: noImports });
  });

  it("derives a slug the path can carry", () => {
    expect(slugify("An analytic set of reals that is not Borel!")).toBe("an-analytic-set-of-reals-that-is-not-borel");
    expect(slugify("  ")).toBe("deposit");
    expect(slugify("x".repeat(80)).length).toBe(48);
  });
});

describe("the two sections", () => {
  it("writes the statement then the proof, each under its marker", () => {
    expect(serializeParts({ statement: "\n\nS\n", proof: "P\n\n" })).toBe(
      `${STATEMENT_MARKER}\nS\n\n${PROOF_MARKER}\nP`,
    );
  });

  it("writes the statement alone for a posed claim", () => {
    expect(serializeParts({ statement: "S", proof: null })).toBe(`${STATEMENT_MARKER}\nS`);
  });

  it("assembles one file with both parts and the imports once", () => {
    const out = assemble(draft());
    expect(out.problems).toEqual([]);
    expect(out.path).toBe("deposits/two-and-two/submission.lean");
    expect(out.file.match(/^import Mathlib$/gm)).toHaveLength(1);
    expect(out.file).toContain("@decls: Demo.two_add_two\n");
    expect(out.file).toContain("@kind: result\n");
    expect(out.file.indexOf(STATEMENT_MARKER)).toBeLessThan(out.file.indexOf(PROOF_MARKER));
  });

  it("assembles a posed claim as a claim with no proof section", () => {
    const out = assemble(draft({ mode: "pose", proof: "" }));
    expect(out.problems).toEqual([]);
    expect(out.file).toContain("@kind: claim\n");
    expect(out.file).not.toContain(PROOF_MARKER);
  });

  it("titles a Prove-mode deposit by its claim and names the claim", () => {
    const out = assemble(
      draft({ mode: "prove", title: "", login: "Zetetic-Dhruv", claim: { accession: "MTH.C-2026-6001", decl: "Demo.two_add_two" } }),
    );
    expect(out.problems).toEqual([]);
    expect(out.file).toContain("@title: Demo.two_add_two\n");
    expect(out.file).toContain("@proves: MTH.C-2026-6001\n");
    expect(out.slug).toBe("demo-two-add-two-zetetic-dhruv");
  });
});

describe("the parser accepts what the IDE assembles", () => {
  it("round-trips an argument through ci/parse_deposit.py", (ctx) => {
    const out = assemble(draft({ gloss: "Four.\nIn two lines." }));
    const r = parse(out.file);
    if (r === null) ctx.skip();
    expect(r?.err).toBe("");
    expect(r?.json).toMatchObject({
      kind: "result",
      title: "Two and two",
      module: "Submission",
      decls: ["Demo.two_add_two"],
      pin: PIN,
      mathlib: MATHLIB_REV,
      discharges: null,
      imports: ["Mathlib"],
      gloss: "Four.\nIn two lines.",
    });
  });

  it("round-trips a posed claim with no imports", (ctx) => {
    const st = "theorem t : True := by\n  sorry\n";
    const r = parse(assemble(draft({ mode: "pose", statement: st, proof: "" })).file);
    if (r === null) ctx.skip();
    expect(r?.json).toMatchObject({ kind: "claim", decls: ["t"], mathlib: null, imports: [] });
  });

  it("round-trips a Prove-mode deposit, whose extra @proves line the parser ignores", (ctx) => {
    const r = parse(
      assemble(draft({ mode: "prove", claim: { accession: "MTH.C-2026-6001", decl: "Demo.two_add_two" } })).file,
    );
    if (r === null) ctx.skip();
    expect(r?.json).toMatchObject({ kind: "result", title: "Demo.two_add_two", discharges: null });
  });
});

describe("the client checks", () => {
  const codes = (d: Draft): string[] => assemble(d).problems.map((p) => p.code);

  it("refuses prelude, with its line", () => {
    const p = checkPart("proof", "-- note\nprelude\nimport Init\n");
    expect(p).toContainEqual(expect.objectContaining({ code: "PRELUDE_DECLARED", line: 2, part: "proof" }));
  });

  it("refuses the commands that run code while the file builds", () => {
    const src = "#eval 1\nrun_cmd pure ()\nrun_elab pure ()\n#exit\ninitialize foo : IO.Ref Nat ← IO.mkRef 0\n" +
      "theorem x : True := by run_tac pure ()\n";
    const found = checkPart("statement", src).filter((p) => p.code === "COMMAND_NOT_ACCEPTED");
    expect(found.map((p) => p.params.command)).toEqual(["#eval", "run_cmd", "run_elab", "#exit", "initialize", "run_tac"]);
    expect(found.map((p) => p.line)).toEqual([1, 2, 3, 4, 5, 6]);
  });

  it("does not mistake a comment, a string or a longer name for a command", () => {
    const src = '-- #eval 1\n/- run_cmd /- nested -/ #exit -/\ndef s := "#eval"\ntheorem initialize_ok : True := trivial\n' +
      "example : Foo.initialize = 1 := rfl\n";
    expect(checkPart("statement", src)).toEqual([]);
  });

  it("asks for one import list in both parts", () => {
    expect(codes(draft({ proof: PROOF.replace("import Mathlib", "import Mathlib.Tactic") }))).toContain("IMPORTS_DIFFER");
    expect(codes(draft())).not.toContain("IMPORTS_DIFFER");
    // A posed claim has no proof part to compare.
    expect(codes(draft({ mode: "pose", proof: "import Other" }))).not.toContain("IMPORTS_DIFFER");
  });

  it("finds an import below other source", () => {
    const p = checkPart("statement", "import A\ntheorem t : True := trivial\nimport B\n");
    expect(p).toContainEqual(expect.objectContaining({ code: "IMPORT_NOT_LEADING", line: 3 }));
  });

  it("names a statement theorem the proof leaves out, and a gap left in the proof", () => {
    const c = codes(draft({ proof: "import Mathlib\n\ntheorem other : True := by\n  sorry\n" }));
    expect(c).toContain("PROOF_DECL_MISSING");
    expect(c).toContain("PROOF_LEAVES_GAP");
  });

  it("reports the gap at the author's own line", () => {
    const p = assemble(draft({ proof: "import Mathlib\n\nnamespace Demo\ntheorem two_add_two : 2 = 2 := by\n  sorry\nend Demo\n" }))
      .problems.find((x) => x.code === "PROOF_LEAVES_GAP");
    expect(p?.line).toBe(5);
  });

  it("asks for a title, a theorem, and in Prove mode a claim", () => {
    expect(codes(draft({ title: " " }))).toContain("TITLE_MISSING");
    expect(codes(draft({ statement: "import Mathlib\n" }))).toContain("STATEMENT_DECLARES_NOTHING");
    expect(codes(draft({ mode: "prove", claim: null }))).toContain("CLAIM_NOT_CHOSEN");
  });

  it("reads theorem names through namespaces, sections and _root_", () => {
    const src = "namespace A\nsection\ntheorem x : True := trivial\nend\nnamespace B\n@[simp] lemma y : True := trivial\nend B\n" +
      "theorem _root_.z : True := trivial\nend A\n/- theorem hidden : True -/\n";
    expect(theoremNames(src)).toEqual(["A.x", "A.B.y", "z"]);
  });

  it("blanks comments and strings but keeps the lines", () => {
    const src = 'a -- b\n/- c\n-/ "d"\n';
    const out = blankComments(src);
    expect(out.split("\n")).toHaveLength(src.split("\n").length);
    expect(out.trim()).toBe("a");
  });
});

describe("GitHub's new-file page", () => {
  it("prefills the file while the URL stays under the limit", () => {
    const link = githubNewFileUrl("two-and-two", "import Mathlib\n");
    expect(link.prefilled).toBe(true);
    expect(link.url).toBe(
      "https://github.com/noumenal-ai/mathesis-bank/new/main?filename=deposits/two-and-two/submission.lean" +
        "&value=import%20Mathlib%0A",
    );
  });

  it("opens it empty once the URL would reach the limit", () => {
    const base = "https://github.com/noumenal-ai/mathesis-bank/new/main?filename=deposits/s/submission.lean";
    const room = PREFILL_LIMIT - (base.length + "&value=".length);
    expect(githubNewFileUrl("s", "a".repeat(room - 1)).prefilled).toBe(true);
    const over = githubNewFileUrl("s", "a".repeat(room));
    expect(over).toEqual({ url: base, prefilled: false });
    // Unicode is counted as it travels: percent-encoded.
    expect(githubNewFileUrl("s", "→".repeat(Math.ceil(room / 9) + 1)).prefilled).toBe(false);
  });

  it("keeps the limit below GitHub's 8 KB", () => {
    expect(PREFILL_LIMIT).toBeLessThan(8192);
  });
});

describe("Lean 4 Web", () => {
  it("carries the code as lz-string base64 under #codez=, as lean4web reads it", () => {
    const code = "import Mathlib\n\ntheorem t : ∀ n : ℕ, n = n := fun _ => rfl\n";
    const url = lean4webUrl(code);
    expect(url.startsWith("https://live.lean-lang.org/#codez=")).toBe(true);
    const arg = url.slice(url.indexOf("#") + 1);
    // lean4web's parseArgs: split on & and =, then decodeURIComponent.
    const [key, val] = arg.split("=");
    expect(key).toBe("codez");
    expect(arg.split("=")).toHaveLength(2);
    expect(LZString.decompressFromBase64(decodeURIComponent(val as string))).toBe(code);
  });

  it("escapes what fixedEncodeURIComponent escapes", () => {
    const url = lean4webUrl("(".repeat(50));
    expect(url).not.toMatch(/[()]/);
    expect(url.slice(url.indexOf("=") + 1)).not.toMatch(/[+/=]/);
  });
});
