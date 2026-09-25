// Lean 4 highlighting for CodeMirror 6.
//
// No maintained CodeMirror 6 package for Lean exists on npm, and a grammar is
// more than the editor needs: the kernel, not the highlighter, decides what a
// file means. This is a small stream tokenizer: nested block comments and
// docstrings, line comments, strings, numbers, keywords, capitalised names and
// attributes.

import { StreamLanguage, type StreamParser } from "@codemirror/language";

const KEYWORDS = new Set([
  "import", "prelude", "namespace", "section", "end", "open", "export", "universe", "variable",
  "theorem", "lemma", "def", "abbrev", "example", "instance", "structure", "class", "inductive",
  "axiom", "opaque", "where", "extends", "deriving", "mutual", "private", "protected",
  "noncomputable", "partial", "unsafe", "nonrec", "scoped", "local", "attribute", "set_option",
  "notation", "infix", "infixl", "infixr", "prefix", "postfix", "macro", "syntax", "macro_rules",
  "elab", "fun", "let", "have", "show", "from", "by", "at", "with", "match", "do", "if", "then",
  "else", "for", "in", "return", "calc", "suffices", "obtain", "rcases", "rintro", "intro",
  "intros", "exact", "apply", "refine", "rw", "rwa", "simp", "simp_all", "simpa", "dsimp",
  "constructor", "cases", "induction", "use", "exists", "unfold", "omega", "linarith",
  "nlinarith", "positivity", "norm_num", "ring", "field_simp", "aesop", "decide", "exact?",
  "trivial", "rfl", "contradiction", "exfalso", "by_contra", "push_neg", "specialize",
  "generalize", "subst", "ext", "funext", "congr", "gcongr", "filter_upwards", "tauto",
  "sorry", "admit", "Type", "Sort", "Prop",
]);
const SYMBOL_KEYWORDS = new Set(["∀", "∃", "λ", "Π", "Σ", "∃!"]);

interface State {
  /** Depth of nested `/- … -/`; 0 outside a comment. */
  comment: number;
}

const IDENT = /^[\p{L}_][\p{L}\p{N}_'!?₀-₉ₐ-ₜᵢ-ᵪ]*(?:\.[\p{L}_][\p{L}\p{N}_'!?₀-₉ₐ-ₜᵢ-ᵪ]*)*/u;

function inComment(stream: Parameters<StreamParser<State>["token"]>[0], state: State): string {
  while (!stream.eol()) {
    if (stream.match("/-")) state.comment++;
    else if (stream.match("-/")) {
      state.comment--;
      if (state.comment === 0) break;
    } else stream.next();
  }
  return "comment";
}

export const leanParser: StreamParser<State> = {
  name: "lean4",
  startState: () => ({ comment: 0 }),
  copyState: (s) => ({ comment: s.comment }),
  token(stream, state) {
    if (state.comment > 0) return inComment(stream, state);
    if (stream.eatSpace()) return null;
    if (stream.match("--")) {
      stream.skipToEnd();
      return "comment";
    }
    if (stream.match("/-")) {
      state.comment = 1;
      return inComment(stream, state);
    }
    if (stream.peek() === '"') {
      stream.next();
      let escaped = false;
      while (!stream.eol()) {
        const c = stream.next();
        if (c === '"' && !escaped) break;
        escaped = !escaped && c === "\\";
      }
      return "string";
    }
    if (stream.match(/^@\[[^\]]*\]/)) return "meta";
    if (stream.match(/^#[a-z_]+!?/)) return "meta";
    if (stream.match(/^(?:0x[0-9a-fA-F]+|\d+(?:\.\d+)?)/)) return "number";
    const word = stream.match(IDENT) as RegExpMatchArray | null;
    if (word) {
      const w = word[0];
      if (KEYWORDS.has(w) || SYMBOL_KEYWORDS.has(w)) return "keyword";
      const last = w.slice(w.lastIndexOf(".") + 1);
      return /^\p{Lu}/u.test(last) ? "typeName" : "variableName";
    }
    const c = stream.next() ?? "";
    if (SYMBOL_KEYWORDS.has(c)) return "keyword";
    return /[→←↔¬∧∨≤≥≠∈∉⊆⊂∪∩×∘=<>+\-*/^|:!]/.test(c) ? "operator" : null;
  },
  languageData: {
    commentTokens: { line: "--", block: { open: "/-", close: "-/" } },
  },
};

export const lean4 = StreamLanguage.define(leanParser);
