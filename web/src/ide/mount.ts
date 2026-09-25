// The IDE page: three modes, a statement and a proof, and a pull request.
//
// There is no server and no sign-in. Submitting copies the assembled file to
// the clipboard and opens GitHub's create-new-file page for
// `deposits/<slug>/submission.lean`; GitHub forks the bank to the author's
// account and opens the pull request from there. The page's shell and every
// label are the generator's (`ide_page` in crates/record/src/pages.rs).

import type { EditorState } from "@codemirror/state";
import type { EditorView } from "@codemirror/view";
import { clear, el, errorLine, label, qs, qsa, staticJson, value, withBase } from "../dom";
import { VALUES } from "../labels";
import { renderReason } from "../reasons.generated";
import { createView, paneState } from "./editor";
import { assemble, githubNewFileUrl, lean4webUrl, type Draft, type Mode, type Part, type Problem } from "./deposit";
import { glyph } from "./glyph";

interface ProfileRow {
  login: string;
  citation_name: string;
  avatar: string | null;
}

interface ClaimRow {
  accession: string;
  decl_name: string;
  pretty: string;
  author: string;
  author_login: string;
}

interface BankPage {
  rows: ClaimRow[];
  next_cursor: string | null;
}

const MODES: Mode[] = ["argue", "pose", "prove"];
const STORE = "mathesis.ide.v1";

/** Problems worth showing while the author types; the rest wait for a submit. */
const LIVE = new Set(["PRELUDE_DECLARED", "COMMAND_NOT_ACCEPTED", "IMPORT_NOT_LEADING", "IMPORT_INVALID"]);

const STARTER_STATEMENT = `import Mathlib

theorem two_add_two : (2 : ℕ) + 2 = 4 := by
  sorry
`;
const STARTER_PROOF = `import Mathlib

theorem two_add_two : (2 : ℕ) + 2 = 4 := by
  norm_num
`;

/** A claim's statement as a Lean part: its kernel statement under its own name,
 * proved by `sorry`. */
export function claimStatement(decl: string, pretty: string): string {
  const body = pretty.split("\n").join("\n    ");
  return `import Mathlib\n\ntheorem ${decl} :\n    ${body} := by\n  sorry\n`;
}

interface Saved {
  login?: string;
  title?: string;
  /** Superseded by `glosses`; read once so a gloss saved before it is not lost. */
  gloss?: string;
  glosses?: Partial<Record<Mode, string>>;
  parts?: Partial<Record<Mode, { statement?: string; proof?: string }>>;
}

function load(): Saved {
  try {
    const raw = window.localStorage.getItem(STORE);
    return raw ? (JSON.parse(raw) as Saved) : {};
  } catch {
    return {};
  }
}

function save(s: Saved): void {
  try {
    window.localStorage.setItem(STORE, JSON.stringify(s));
  } catch {
    // Private windows and blocked storage: the draft simply is not kept.
  }
}

async function loadClaims(): Promise<ClaimRow[]> {
  const out: ClaimRow[] = [];
  for (let i = 0; i < 500; i++) {
    const page = await staticJson<BankPage>(`/collection/claims-${String(i).padStart(4, "0")}.json`);
    if (!page.ok || !page.body) break;
    out.push(...page.body.rows);
    if (!page.body.next_cursor) break;
  }
  return out;
}

/** Copy without a permission prompt: the async API where the page has it, the
 * selection route where it does not. Both run inside the click. */
function copy(text: string): Promise<boolean> {
  if (navigator.clipboard?.writeText) {
    return navigator.clipboard.writeText(text).then(() => true, () => copyBySelection(text));
  }
  return Promise.resolve(copyBySelection(text));
}

function copyBySelection(text: string): boolean {
  const ta = el("textarea", { class: "mth-ide__file", readonly: "" });
  ta.value = text;
  document.body.append(ta);
  ta.select();
  let ok = false;
  try {
    ok = document.execCommand("copy");
  } catch {
    ok = false;
  }
  ta.remove();
  return ok;
}

export function mountIde(doc: Document): void {
  const root = qs<HTMLElement>(".mth-ide", doc);
  const host = qs<HTMLElement>("#ide-editor", doc);
  if (!root || !host) return;
  const loginInput = qs<HTMLInputElement>("#ide-login", doc);
  const titleInput = qs<HTMLInputElement>("#ide-title", doc);
  const glossInput = qs<HTMLTextAreaElement>("#ide-gloss", doc);
  const claimSelect = qs<HTMLSelectElement>("#ide-claim", doc);
  const claimCard = qs<HTMLElement>("#ide-claim-card", doc);
  const byline = qs<HTMLElement>("#ide-byline", doc);
  const problemsHost = qs<HTMLElement>("#ide-problems", doc);
  const sent = qs<HTMLElement>("#ide-sent", doc);
  const submit = qs<HTMLButtonElement>("#ide-submit", doc);
  const leanBtn = qs<HTMLButtonElement>("#ide-lean", doc);

  const saved = load();
  const params = new URLSearchParams(doc.location?.search ?? "");
  let profiles: ProfileRow[] = [];
  let claims: ClaimRow[] = [];
  let claim: ClaimRow | null = null;
  let mode: Mode = params.has("claim") ? "prove" : MODES.includes(params.get("mode") as Mode) ? (params.get("mode") as Mode) : "argue";
  let tab: Part = "statement";
  let attempted = false;

  if (loginInput) loginInput.value = saved.login ?? "";
  if (titleInput) titleInput.value = saved.title ?? "";
  // A gloss says what one deposit is, so each mode keeps its own: a claim posed after writing
  // up an argument must not go out under the argument's gloss.
  const glosses: Partial<Record<Mode, string>> = { ...saved.glosses };
  if (saved.glosses === undefined && saved.gloss) glosses[mode] = saved.gloss;
  if (glossInput) glossInput.value = glosses[mode] ?? "";

  // ---- the panes: one editor state per mode and part ----
  let timer: number | undefined;
  const changed = (): void => {
    window.clearTimeout(timer);
    timer = window.setTimeout(() => {
      persist();
      check();
    }, 250);
  };
  const panes = new Map<string, EditorState>();
  const key = (m: Mode, p: Part): string => `${m}:${p}`;
  const starter = (m: Mode, p: Part): string => {
    const kept = saved.parts?.[m]?.[p];
    if (kept !== undefined && m !== "prove") return kept;
    return p === "statement" ? STARTER_STATEMENT : STARTER_PROOF;
  };
  for (const m of ["argue", "pose"] as Mode[]) {
    for (const p of ["statement", "proof"] as Part[]) {
      panes.set(key(m, p), paneState({ doc: starter(m, p), onChange: changed }));
    }
  }
  const setProvePanes = (c: ClaimRow | null): void => {
    const st = c ? claimStatement(c.decl_name, c.pretty) : "";
    panes.set(key("prove", "statement"), paneState({ doc: st, locked: true }));
    panes.set(key("prove", "proof"), paneState({ doc: st, lockDecl: c?.decl_name ?? null, onChange: changed }));
  };
  setProvePanes(null);

  const view: EditorView = createView(host, panes.get(key(mode, tab)) as EditorState);
  const text = (m: Mode, p: Part): string =>
    (m === mode && p === tab ? view.state : (panes.get(key(m, p)) as EditorState)).doc.toString();

  const show = (m: Mode, p: Part): void => {
    panes.set(key(mode, tab), view.state);
    if (glossInput) glosses[mode] = glossInput.value;
    if (m !== mode && sent) {
      sent.hidden = true;
      clear(sent);
    }
    mode = m;
    if (glossInput) glossInput.value = glosses[mode] ?? "";
    tab = m === "pose" ? "statement" : p;
    view.setState(panes.get(key(mode, tab)) as EditorState);
    root.setAttribute("data-mode", mode);
    for (const b of qsa<HTMLButtonElement>(".mth-ide__mode", root)) {
      b.setAttribute("aria-pressed", String(b.getAttribute("data-mode") === mode));
    }
    for (const b of qsa<HTMLButtonElement>(".mth-ide__tab", root)) {
      b.setAttribute("aria-selected", String(b.getAttribute("data-tab") === tab));
    }
    check();
  };

  function persist(): void {
    const parts: Saved["parts"] = {};
    for (const m of ["argue", "pose"] as Mode[]) {
      parts[m] = { statement: text(m, "statement"), proof: text(m, "proof") };
    }
    save({
      login: loginInput?.value.trim() ?? "",
      title: titleInput?.value ?? "",
      glosses: { ...glosses, [mode]: glossInput?.value ?? "" },
      parts,
    });
  }

  function draft(): Draft {
    return {
      mode,
      title: titleInput?.value ?? "",
      gloss: glossInput?.value ?? "",
      statement: text(mode, "statement"),
      proof: text(mode, "proof"),
      claim: claim ? { accession: claim.accession, decl: claim.decl_name } : null,
      login: loginInput?.value.trim() ?? "",
    };
  }

  function goTo(p: Problem): void {
    if (p.part && (p.part !== tab || mode === "pose")) show(mode, p.part);
    if (p.line) {
      const n = Math.min(p.line, view.state.doc.lines);
      const at = view.state.doc.line(n).from;
      view.dispatch({ selection: { anchor: at }, scrollIntoView: true });
    }
    view.focus();
  }

  function renderProblems(list: Problem[]): void {
    if (!problemsHost) return;
    clear(problemsHost);
    for (const p of list) {
      const line = errorLine(renderReason(p.code, p.params));
      if (p.part || p.line) {
        line.classList.add("mth-ide__problem");
        line.tabIndex = 0;
        line.addEventListener("click", () => goTo(p));
        line.addEventListener("keydown", (e) => {
          if (e.key === "Enter") goTo(p);
        });
      }
      problemsHost.append(line);
    }
  }

  function check(): Problem[] {
    const all = assemble(draft()).problems;
    renderProblems(attempted ? all : all.filter((p) => LIVE.has(p.code)));
    return all;
  }

  // ---- the byline: the person first ----
  function renderByline(): void {
    if (!byline) return;
    clear(byline);
    const login = loginInput?.value.trim() ?? "";
    if (!/^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$/.test(login)) return;
    const known = profiles.find((p) => p.login.toLowerCase() === login.toLowerCase());
    const href = known ? withBase(`/u/${known.login}/`) : `https://github.com/${login}`;
    const a = el("a", { class: "mth-author", href });
    const face = el("img", {
      class: "mth-avatar mth-avatar--sm",
      width: "48",
      height: "48",
      src: known?.avatar ? withBase(known.avatar) : `https://github.com/${encodeURIComponent(login)}.png?size=96`,
    });
    face.setAttribute("alt", known?.citation_name ?? login);
    face.addEventListener("error", () => face.replaceWith(glyph(login, "mth-avatar mth-avatar--sm")), { once: true });
    a.append(face);
    const names = el("span", { class: "mth-author__names" });
    if (known) names.append(value("span", "profile.citation_name", known.citation_name, { class: "mth-author__name" }));
    names.append(value("span", "profile.login", known?.login ?? login,
      { class: known ? "mth-author__handle" : "mth-author__handle mth-author__name" }));
    a.append(names);
    byline.append(a);
  }

  // ---- the claim a Prove-mode proof is held to ----
  function renderClaim(): void {
    if (!claimCard) return;
    clear(claimCard);
    claimCard.hidden = claim === null;
    if (!claim) return;
    claimCard.append(value("div", "claim.decl_name", claim.decl_name, { class: "mth-ide__claim-decl" }));
    const by = el("div", { class: "mth-ide__claim-by" });
    by.append(label("span", "posedBy"));
    const who = profiles.find((p) => p.login === claim?.author_login);
    const a = el("a", { class: "mth-ide__person", href: withBase(`/u/${claim.author_login}/`) });
    if (who?.avatar) {
      const img = el("img", { class: "mth-avatar mth-avatar--xs", width: "24", height: "24", src: withBase(who.avatar) });
      img.setAttribute("alt", who.citation_name);
      a.append(img);
    } else {
      a.append(glyph(claim.author_login, "mth-glyph--xs"));
    }
    a.append(value("span", "profile.citation_name", claim.author));
    by.append(a);
    claimCard.append(by);
    claimCard.append(label("div", "statementLocked", { class: "mth-ide__lock" }));
  }

  function chooseClaim(accession: string): void {
    claim = claims.find((c) => c.accession === accession) ?? null;
    if (claimSelect) claimSelect.value = claim?.accession ?? "";
    const current = mode === "prove";
    if (current) panes.set(key(mode, tab), view.state);
    setProvePanes(claim);
    if (current) view.setState(panes.get(key(mode, tab)) as EditorState);
    renderClaim();
    check();
  }

  // ---- wiring ----
  for (const b of qsa<HTMLButtonElement>(".mth-ide__mode", root)) {
    b.addEventListener("click", () => show(b.getAttribute("data-mode") as Mode, tab));
  }
  for (const b of qsa<HTMLButtonElement>(".mth-ide__tab", root)) {
    b.addEventListener("click", () => show(mode, b.getAttribute("data-tab") as Part));
  }
  loginInput?.addEventListener("input", () => {
    renderByline();
    changed();
  });
  titleInput?.addEventListener("input", changed);
  glossInput?.addEventListener("input", changed);
  claimSelect?.addEventListener("change", () => chooseClaim(claimSelect.value));

  leanBtn?.addEventListener("click", () => {
    window.open(lean4webUrl(view.state.doc.toString()), "_blank", "noopener");
  });

  submit?.addEventListener("click", () => {
    attempted = true;
    if (sent) {
      sent.hidden = true;
      clear(sent);
    }
    const out = assemble(draft());
    renderProblems(out.problems);
    if (out.problems.length > 0) {
      problemsHost?.querySelector<HTMLElement>(".mth-error")?.focus();
      return;
    }
    persist();
    const link = githubNewFileUrl(out.slug, out.file);
    const copying = copy(out.file);
    window.open(link.url, "_blank", "noopener");
    void copying.then((ok) => {
      if (!sent) return;
      clear(sent);
      sent.hidden = false;
      if (ok) sent.append(value("span", "clipboard.state", VALUES.copied, { class: "mth-status mth-status--ok" }));
      if (!link.prefilled || !ok) sent.append(label("span", "pasteFromClipboard"));
      if (!ok) {
        const ta = el("textarea", { class: "mth-input mth-ide__file", readonly: "", rows: "12" });
        ta.value = out.file;
        sent.append(ta);
        ta.select();
      }
    });
  });

  // ---- data: people and claims ----
  void staticJson<ProfileRow[]>("/profiles.json").then((r) => {
    profiles = r.body ?? [];
    renderByline();
    renderClaim();
  });
  void loadClaims().then((rows) => {
    claims = rows;
    if (!claimSelect) return;
    clear(claimSelect);
    claimSelect.append(el("option", { value: "" }));
    for (const c of rows) {
      const o = value("option", "claim.decl_name", c.decl_name) as HTMLOptionElement;
      o.value = c.accession;
      claimSelect.append(o);
    }
    const wanted = params.get("claim");
    if (wanted) chooseClaim(wanted);
  });

  renderByline();
  show(mode, tab);
}
