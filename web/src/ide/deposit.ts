// The deposit file the IDE assembles, and the checks it runs before anything
// leaves the browser.
//
// Everything here is a pure function of the draft, so the header grammar, the
// checks and the two outbound URLs are tested without a DOM. The format is the
// retired deposit form's `buildFile` (`git show 0b0e0d4:site/deposit.js`), and
// `ci/parse_deposit.py` is the authority over it: a file it rejects is a file
// this module must never produce.

import LZString from "lz-string";
import { serializeParts } from "./sections";

export const REPO = "noumenal-ai/mathesis-bank";
/** `ci/parse_deposit.py`'s PIN_REQUIRED, exactly. */
export const PIN = "leanprover/lean4:v4.31.0";
/** The one Mathlib revision the bank builds deposits against. */
export const MATHLIB_REV = "fabf563a7c95a166b8d7b6efca11c8b4dc9d911f";

/** GitHub answers 414 once the new-file URL reaches 8 KB (measured); a URL
 * longer than this opens the page empty and the file goes by clipboard. */
export const PREFILL_LIMIT = 7000;

export type Mode = "argue" | "pose" | "prove";
export type Kind = "result" | "claim" | "definition";
export type Part = "statement" | "proof";

export interface HeaderFields {
  kind: Kind;
  title: string;
  module: string;
  decls: string[];
  imports: string[];
  gloss: string;
  mathlib?: string | null;
  discharges?: string | null;
  /** The accession of the site claim a Prove-mode deposit proves. Informational:
   * the parser ignores an unknown @-line, and the statement section is what the
   * proof is held to. */
  proves?: string | null;
}

// ------------------------------------------------------------------ imports

const IMPORT_LINE = /^\s*import\s+(.*?)\s*(?:--.*)?$/;
const MODULE_NAME = /^[A-Za-z_][A-Za-z0-9_']*(?:\.[A-Za-z_][A-Za-z0-9_']*)*$/;

export interface SplitImports {
  imports: string[];
  body: string;
}

/**
 * The leading run of `import` lines and the rest, as `split_leading_imports`
 * in ci/parse_deposit.py reads it: blank lines may sit between imports, and the
 * first other line ends the run. `import A B` is Lean's multi-module form and is
 * split into one module per line, which is the only form the parser accepts.
 */
export function splitLeadingImports(source: string): SplitImports {
  const lines = source.split("\n");
  const imports: string[] = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i] as string;
    if (line.trim() === "") {
      i++;
      continue;
    }
    const m = IMPORT_LINE.exec(line);
    if (!m || (m[1] as string) === "") break;
    for (const mod of (m[1] as string).split(/\s+/)) if (!imports.includes(mod)) imports.push(mod);
    i++;
  }
  if (imports.length === 0) return { imports: [], body: source };
  return { imports, body: lines.slice(i).join("\n") };
}

export function importsMathlib(imports: string[]): boolean {
  return imports.some((m) => m === "Mathlib" || m.startsWith("Mathlib."));
}

// ------------------------------------------------------------------- header

/** A single-line value that cannot close the header or forge a field. */
function scalar(v: string): string {
  return v.replace(/\s+/g, " ").replace(/-\//g, "- /").trim();
}

/**
 * The deposit file: imports hoisted above the `/-! … -/` header, then the body.
 *
 * `/-!` is a module docstring, which is declaration-level syntax, and Lean
 * requires every import to precede all declarations, so the imports go first.
 * The field order and the two-space gloss indent are `buildFile`'s.
 */
export function buildFile(h: HeaderFields, body: string): string {
  const lines: string[] = [];
  if (h.imports.length) {
    for (const m of h.imports) lines.push(`import ${m}`);
    lines.push("");
  }
  lines.push(
    "/-!",
    "# Mathesis deposit",
    "",
    `@kind: ${h.kind}`,
    `@title: ${scalar(h.title)}`,
    `@module: ${scalar(h.module) || "Submission"}`,
    `@decls: ${h.decls.join(", ")}`,
    `@pin: ${PIN}`,
  );
  if (h.mathlib) lines.push(`@mathlib: ${h.mathlib}`);
  if (h.discharges) lines.push(`@discharges: ${h.discharges}`);
  if (h.proves) lines.push(`@proves: ${h.proves}`);
  lines.push("", "@gloss:");
  for (const g of h.gloss.replace(/\s+$/, "").split("\n")) {
    // A gloss line reading `@name:` would be parsed as a field, and `-/` would
    // close the header early; both are defused without changing the words.
    lines.push(`  ${g.replace(/-\//g, "- /").replace(/^(\s*)@(?=[A-Za-z_])/, "$1@ ")}`);
  }
  lines.push("-/", "", body, "");
  return lines.join("\n");
}

export function slugify(s: string): string {
  return (
    s
      .toLowerCase()
      .normalize("NFKD")
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 48)
      .replace(/-+$/, "") || "deposit"
  );
}

export function depositPath(slug: string): string {
  return `deposits/${slug}/submission.lean`;
}

// ------------------------------------------------------------ lean scanning

/** The source with comments and string literals blanked to spaces, newlines
 * kept, so a regex over it reports the author's own line numbers. Block
 * comments nest, as Lean's do. */
export function blankComments(src: string): string {
  let out = "";
  let i = 0;
  let depth = 0;
  const blank = (s: string): string => s.replace(/[^\n]/g, " ");
  while (i < src.length) {
    const two = src.slice(i, i + 2);
    if (depth > 0) {
      if (two === "/-") {
        depth++;
        out += "  ";
        i += 2;
      } else if (two === "-/") {
        depth--;
        out += "  ";
        i += 2;
      } else {
        out += blank(src[i] as string);
        i++;
      }
      continue;
    }
    if (two === "/-") {
      depth = 1;
      out += "  ";
      i += 2;
    } else if (two === "--") {
      const end = src.indexOf("\n", i);
      const stop = end === -1 ? src.length : end;
      out += blank(src.slice(i, stop));
      i = stop;
    } else if (src[i] === '"') {
      let j = i + 1;
      while (j < src.length && src[j] !== '"') j += src[j] === "\\" ? 2 : 1;
      out += blank(src.slice(i, j + 1));
      i = j + 1;
    } else {
      out += src[i];
      i++;
    }
  }
  return out;
}

const MODIFIERS = /^(?:@\[[^\]]*\]\s*|private\s+|protected\s+|noncomputable\s+|nonrec\s+|scoped\s+|local\s+)*/;
const THEOREM_HEAD = /^(?:theorem|lemma)\s+([^\s:({[⦃⟨|]+)/;

/** The fully qualified theorem names a part declares, in order. */
export function theoremNames(source: string): string[] {
  const out: string[] = [];
  const scopes: (string | null)[] = [];
  for (const raw of blankComments(source).split("\n")) {
    const line = raw.trimStart();
    const ns = /^namespace\s+(\S+)/.exec(line);
    if (ns) {
      scopes.push(ns[1] as string);
      continue;
    }
    if (/^(?:noncomputable\s+)?section\b/.test(line)) {
      scopes.push(null);
      continue;
    }
    if (/^end\b/.test(line)) {
      scopes.pop();
      continue;
    }
    if (raw !== line) continue; // a declaration head starts in column one
    const rest = line.slice((MODIFIERS.exec(line)?.[0] ?? "").length);
    const m = THEOREM_HEAD.exec(rest);
    if (!m) continue;
    const name = m[1] as string;
    const full = name.startsWith("_root_.")
      ? name.slice("_root_.".length)
      : [...scopes.filter((s): s is string => s !== null), name].join(".");
    if (!out.includes(full)) out.push(full);
  }
  return out;
}

// ------------------------------------------------------------------- checks

export interface Problem {
  code: string;
  params: Record<string, string>;
  part?: Part;
  line?: number;
}

/** Commands that run code while the file builds. */
const RUNS_CODE = /(^|[^\w#!.])(#eval!?|#exit|run_cmd|run_elab|run_meta|run_tac|builtin_initialize|initialize)(?![\w!])/g;

function lineOf(text: string, index: number): number {
  return text.slice(0, index).split("\n").length;
}

/** The checks one part carries on its own. */
export function checkPart(part: Part, source: string): Problem[] {
  const out: Problem[] = [];
  const code = blankComments(source);
  const prelude = /^[ \t]*prelude\b/m.exec(code);
  if (prelude) {
    out.push({ code: "PRELUDE_DECLARED", part, line: lineOf(code, prelude.index),
      params: { part, line: String(lineOf(code, prelude.index)) } });
  }
  for (const m of code.matchAll(RUNS_CODE)) {
    const at = (m.index ?? 0) + (m[1] as string).length;
    const line = lineOf(code, at);
    out.push({ code: "COMMAND_NOT_ACCEPTED", part, line,
      params: { part, command: m[2] as string, line: String(line) } });
  }
  // An import below the leading run is a file that cannot build, and the
  // deposit parser refuses it before any build is spent.
  // The run is read from the raw source, as the parser reads it: a comment
  // above the imports ends the run there too.
  const { imports, body } = splitLeadingImports(source);
  const offset = source.length - body.length;
  const late = /^[ \t]*import\b/m.exec(blankComments(body));
  if (late) {
    const line = lineOf(source, offset + late.index);
    out.push({ code: "IMPORT_NOT_LEADING", part, line, params: { part, line: String(line) } });
  }
  for (const mod of imports) {
    if (!MODULE_NAME.test(mod)) {
      out.push({ code: "IMPORT_INVALID", part, params: { module: mod } });
    }
  }
  return out;
}

export interface Draft {
  mode: Mode;
  title: string;
  gloss: string;
  statement: string;
  proof: string;
  /** Prove mode: the claim being proved. */
  claim?: { accession: string; decl: string } | null;
  /** The byline's GitHub login, when given. */
  login?: string;
}

export interface Assembled {
  file: string;
  slug: string;
  path: string;
  problems: Problem[];
}

function sameList(a: string[], b: string[]): boolean {
  const x = [...a].sort();
  const y = [...b].sort();
  return x.length === y.length && x.every((v, i) => v === y[i]);
}

/** The deposit file for a draft, and every problem the client can see in it. */
export function assemble(d: Draft): Assembled {
  const problems: Problem[] = [];
  const withProof = d.mode !== "pose";
  const title = d.mode === "prove" ? (d.claim?.decl ?? "") : d.title.trim();
  if (title === "") {
    problems.push(d.mode === "prove"
      ? { code: "CLAIM_NOT_CHOSEN", params: {} }
      : { code: "TITLE_MISSING", params: {} });
  }

  problems.push(...checkPart("statement", d.statement));
  if (withProof) problems.push(...checkPart("proof", d.proof));

  const st = splitLeadingImports(d.statement);
  const pf = splitLeadingImports(d.proof);
  if (withProof && !sameList(st.imports, pf.imports)) {
    const show = (l: string[]): string => (l.length ? l.join(", ") : "—");
    problems.push({ code: "IMPORTS_DIFFER", params: { statement: show(st.imports), proof: show(pf.imports) } });
  }

  const decls = theoremNames(st.body);
  if (decls.length === 0) problems.push({ code: "STATEMENT_DECLARES_NOTHING", part: "statement", params: {} });
  if (withProof) {
    const proved = theoremNames(pf.body);
    for (const decl of decls) {
      if (!proved.includes(decl)) problems.push({ code: "PROOF_DECL_MISSING", part: "proof", params: { decl } });
    }
    const code = blankComments(pf.body);
    const offset = d.proof.length - pf.body.length;
    const lineBase = lineOf(d.proof, offset) - 1;
    for (const m of code.matchAll(/(?<![\w.])(sorry|admit)(?![\w'])/g)) {
      const line = lineBase + lineOf(code, m.index ?? 0);
      problems.push({ code: "PROOF_LEAVES_GAP", part: "proof", line,
        params: { tactic: m[1] as string, line: String(line) } });
    }
  }

  const kind: Kind = d.mode === "pose" ? "claim" : "result";
  const slugSource = d.mode === "prove" && d.login ? `${title} ${d.login}` : title;
  const slug = slugify(slugSource);
  const file = buildFile(
    {
      kind,
      title,
      module: "Submission",
      decls,
      imports: st.imports,
      gloss: d.gloss,
      mathlib: importsMathlib(st.imports) ? MATHLIB_REV : null,
      proves: d.mode === "prove" ? (d.claim?.accession ?? null) : null,
    },
    serializeParts({ statement: st.body, proof: withProof ? pf.body : null }),
  );
  return { file, slug, path: depositPath(slug), problems };
}

// -------------------------------------------------------------- the two URLs

export interface NewFileLink {
  url: string;
  /** Whether the file rides in the URL; when not, it goes by clipboard. */
  prefilled: boolean;
}

/** GitHub's create-new-file page for the deposit, prefilled while it fits. */
export function githubNewFileUrl(slug: string, content: string, limit = PREFILL_LIMIT): NewFileLink {
  const base = `https://github.com/${REPO}/new/main?filename=${depositPath(slug)}`;
  const full = `${base}&value=${encodeURIComponent(content)}`;
  return full.length < limit ? { url: full, prefilled: true } : { url: base, prefilled: false };
}

/**
 * Lean 4 Web with `code` in its editor.
 *
 * Checked against leanprover-community/lean4web at 27e9590, the file
 * `client/src/editor/code-atoms.ts`: the hash argument `codez` is read with
 * `LZString.decompressFromBase64`, and written as
 * `LZString.compressToBase64(code).replace(/=*$/, '')` because a trailing `=`
 * breaks its `key=value` split (`client/src/store/url-converters.ts`,
 * `parseArgs`). `formatArgs` escapes the value with `fixedEncodeURIComponent`
 * (`client/src/utils/UrlParsing.tsx`): `encodeURIComponent` plus `(` and `)`.
 * The plain form is `#code=`; `codez` keeps the link short.
 */
export function lean4webUrl(code: string): string {
  const z = LZString.compressToBase64(code).replace(/=*$/, "");
  const escaped = encodeURIComponent(z).replace(/[()]/g, (c) => `%${c.charCodeAt(0).toString(16)}`);
  return `https://live.lean-lang.org/#codez=${escaped}`;
}
