// The IDE's CodeMirror 6 editor: Lean highlighting, Lean's unicode input, and
// the lock a claim's statement carries in Prove mode.

import { EditorState, RangeSetBuilder, type Extension } from "@codemirror/state";
import {
  Decoration,
  type DecorationSet,
  EditorView,
  ViewPlugin,
  type ViewUpdate,
  drawSelection,
  highlightActiveLine,
  highlightActiveLineGutter,
  keymap,
  lineNumbers,
} from "@codemirror/view";
import { defaultKeymap, history, historyKeymap, indentWithTab } from "@codemirror/commands";
import { HighlightStyle, bracketMatching, indentUnit, syntaxHighlighting } from "@codemirror/language";
import { tags as t } from "@lezer/highlight";
import { expandOnType } from "./abbrev";
import { lean4 } from "./lean-mode";

const leanHighlight = HighlightStyle.define([
  { tag: t.keyword, color: "var(--color-link)" },
  { tag: t.typeName, color: "var(--color-role-def-bd)" },
  { tag: t.comment, color: "var(--color-icon)", fontStyle: "italic" },
  { tag: t.string, color: "var(--color-warn-fg)" },
  { tag: t.number, color: "var(--color-warn-fg)" },
  { tag: t.meta, color: "var(--color-role-cite-bd)" },
]);

const theme = EditorView.theme({
  "&": {
    height: "100%",
    backgroundColor: "var(--color-surface)",
    color: "var(--color-text)",
    fontSize: "var(--text-code)",
  },
  "&.cm-focused": { outline: "none" },
  ".cm-scroller": { fontFamily: "var(--font-mono)", lineHeight: "1.6" },
  ".cm-content": { caretColor: "var(--color-text)", paddingBlock: "var(--spacing-3)" },
  ".cm-gutters": {
    backgroundColor: "var(--color-surface)",
    color: "var(--color-icon)",
    border: "none",
  },
  ".cm-activeLine": { backgroundColor: "var(--color-surface-2)" },
  ".cm-activeLineGutter": { backgroundColor: "var(--color-surface-2)" },
  "&.cm-focused .cm-selectionBackground, .cm-selectionBackground, ::selection": {
    backgroundColor: "var(--color-selection)",
  },
  ".cm-cursor": { borderLeftColor: "var(--color-text)" },
});

/** `\to` + space → `→ `: the abbreviation before the cursor is replaced when a
 * character arrives that cannot extend it. */
const unicodeInput = EditorView.inputHandler.of((view, from, to, text) => {
  if (text.length !== 1 || from !== to) return false;
  const line = view.state.doc.lineAt(from);
  const e = expandOnType(line.text.slice(0, from - line.from), text);
  if (!e) return false;
  const start = line.from + e.from;
  view.dispatch({
    changes: { from: start, to, insert: e.insert },
    selection: { anchor: start + e.cursor },
    userEvent: "input.type",
  });
  return true;
});

/** Tab completes a pending abbreviation without inserting itself. */
function completeOnTab(view: EditorView): boolean {
  const sel = view.state.selection.main;
  if (!sel.empty) return false;
  const line = view.state.doc.lineAt(sel.head);
  const e = expandOnType(line.text.slice(0, sel.head - line.from), "\t");
  if (!e) return false;
  const start = line.from + e.from;
  view.dispatch({
    changes: { from: start, to: sel.head, insert: e.insert },
    selection: { anchor: start + e.cursor },
    userEvent: "input.complete",
  });
  return true;
}

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * The claim's statement where it recurs in the proof: from the `theorem <decl>`
 * line through the line that opens its proof. It is marked, not frozen, so the
 * author sees what the proof must keep while writing around it.
 */
export function lockedLines(text: string, decl: string): [number, number] | null {
  const lines = text.split("\n");
  const bare = decl.split(".").pop() ?? decl;
  const head = new RegExp(`^(?:@\\[[^\\]]*\\]\\s*)?(?:protected\\s+)?(?:theorem|lemma)\\s+(?:_root_\\.)?(?:${escapeRegExp(decl)}|${escapeRegExp(bare)})(?=[\\s:({[]|$)`);
  const first = lines.findIndex((l) => head.test(l));
  if (first === -1) return null;
  for (let i = first; i < lines.length; i++) {
    if ((lines[i] as string).includes(":=")) return [first + 1, i + 1];
  }
  return [first + 1, first + 1];
}

function lockMarks(decl: string): Extension {
  const mark = Decoration.line({ class: "mth-ide__locked" });
  const build = (view: EditorView): DecorationSet => {
    const b = new RangeSetBuilder<Decoration>();
    const span = lockedLines(view.state.doc.toString(), decl);
    if (span) {
      for (let n = span[0]; n <= span[1]; n++) {
        const line = view.state.doc.line(n);
        b.add(line.from, line.from, mark);
      }
    }
    return b.finish();
  };
  return ViewPlugin.fromClass(
    class {
      decorations: DecorationSet;
      constructor(view: EditorView) {
        this.decorations = build(view);
      }
      update(u: ViewUpdate): void {
        if (u.docChanged) this.decorations = build(u.view);
      }
    },
    { decorations: (v) => v.decorations },
  );
}

export interface PaneOptions {
  doc: string;
  /** The whole pane is read-only: a claim's statement in Prove mode. */
  locked?: boolean;
  /** Mark this theorem's statement where it recurs. */
  lockDecl?: string | null;
  onChange?: () => void;
}

/** One pane's editor state. The view swaps states when the tab or mode changes,
 * so each part keeps its own undo history. */
export function paneState(o: PaneOptions): EditorState {
  const ext: Extension[] = [
    lineNumbers(),
    highlightActiveLineGutter(),
    highlightActiveLine(),
    drawSelection(),
    history(),
    bracketMatching(),
    indentUnit.of("  "),
    EditorState.tabSize.of(2),
    lean4,
    syntaxHighlighting(leanHighlight),
    theme,
    unicodeInput,
    keymap.of([{ key: "Tab", run: completeOnTab }, indentWithTab, ...defaultKeymap, ...historyKeymap]),
  ];
  if (o.locked) {
    ext.push(EditorState.readOnly.of(true), EditorView.editable.of(false),
      EditorView.editorAttributes.of({ class: "mth-ide__readonly" }));
  }
  if (o.lockDecl) ext.push(lockMarks(o.lockDecl));
  if (o.onChange) {
    const cb = o.onChange;
    ext.push(EditorView.updateListener.of((u) => {
      if (u.docChanged) cb();
    }));
  }
  return EditorState.create({ doc: o.doc, extensions: ext });
}

export function createView(parent: HTMLElement, state: EditorState): EditorView {
  return new EditorView({ state, parent });
}
