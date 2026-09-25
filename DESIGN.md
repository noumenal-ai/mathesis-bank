# Mathesis v0 — Design Specification ("Kernel Record")

Companion to `SPEC.md`. `SPEC.md` is authoritative for routes, data, catalogue strings, lint rules and tests;
this document is authoritative for the stylesheet, the component set and the page compositions that realize them.
Where a section cites `SPEC §n`, that section governs and this document must not contradict it.

Nothing in this document introduces a visible string. Every string named here is either a frozen catalogue entry
(`web/src/labels.ts`, SPEC §8), a data value rendered inside `[data-value="true"][data-field]`, or a reason message
inside `[data-role="error"]`. Structural notes below are design documentation, not page content.

---

## 0. Direction, and what was grafted into it

**Direction: Kernel Record.** The interface is an instrument panel over a machine-checked record, not a publication
with a house style. Every pixel serves one of four jobs: locate a record, read a Lean statement, traverse an argument,
act on it. Visual language: neutral ground, hairline structure, one accent, typography tuned for Lean.

Five governing rules, each derived from a constraint in `SPEC.md` rather than from taste.

1. **One accent, four uses.** Accent appears only on links and the active nav underline, verified-record marks
   (DOI chips, the claim statement's left rail), focus rings, and the single primary action on a surface. Status uses
   three semantic ramps (`ok`/`warn`/`err`) that are never the accent. Everything else is neutral. "Which thing on this
   page is the verified object" is then answerable at a glance across four very different pages.
2. **Hairlines and ground, never elevation.** No shadow on content. Cards, tables and panels are 1px `ink-200` on
   white, separated by ground shifts. One shadow token exists, for the one thing that floats (the DAG minimap).
3. **Disclosure is native `<details>`; there are no modals, popovers, tooltips or toasts.** Forced, not preferred:
   Rule 1 bans explanatory tooltips, and the linted attribute set (SPEC §8 — `placeholder` banned; `title`/`aria-label`/
   `aria-description`/`alt` must be catalogue entries) makes icon-only and hover-revealed UI unbuildable. Native
   `<details>` gives keyboard semantics, `aria-expanded` for free and a no-JS `Expand`/`Collapse` path.
   Copy feedback is an inline `Copied` value swap (`clipboard.state`), never a toast.
4. **Lean statements render monochrome, and that is a decision.** `renderer_parity` (SPEC §13) requires the Rust
   `askama` render and the React render of the same record to produce identical normalized DOM. Two syntax tokenizers
   in two languages is the single most likely way to fail it, and highlighting buys nothing that font choice does not.
   Legibility comes from JuliaMono, 13px/1.55, `white-space: pre` with a permanently visible horizontal scrollbar,
   `scrollbar-gutter: stable`, and an accent left rail on the claim.
5. **Keyboard-first, undocumented.** No shortcuts overlay and no help affordance, because every string in one would be
   uncatalogued. Shortcuts exist and are unadvertised (§13 below). Density follows: 28px controls, 36px rows,
   24px section gaps, no decorative whitespace.

**Discarded explicitly.** `site/styles.css` (warm paper `#faf6ee`, Iowan Old Style serif, orange `#e0550f`, 17px body,
42rem measure, dark inverted `pre`) and the whole `site/` generator look. None of it survives; SPEC §10 deletes the files.

**Grafts from the other candidate directions, each with the reason it wins on its criterion.**

| # | Grafted from | What | Why it replaces the original |
|---|---|---|---|
| G1 | Instrument face | JuliaMono split by `unicode-range` (latin subset, then math/symbol subset) | First paint of a statement is not blocked by a ~1MB math block; the glyphs that matter still never fall back |
| G2 | Instrument face | Horizontal scrollbar on `.mth-lean` is always visible, never overlay-only | A horizontally truncated statement must never be silently truncated |
| G3 | Instrument face + Archival ledger | A full `@media print` stylesheet for landing pages (nav dropped, DAG forced to `List`, `Cite` last, `pre-wrap` with hanging indent) | A verified record should come off a printer as a datasheet; clipping loses content on paper |
| G4 | Instrument face | DAG sticky **depth ruler** (top) and **order gutter** (left), in addition to the minimap and inspector | Makes a 30–60 node graph navigable by position, not by hunting |
| G5 | Instrument face | **No arbitrary Tailwind values** (`[13px]`, `[#fff]`) in either renderer; every magnitude is a theme token | The winner's arbitrary values were the one place the two renderers could drift; this closes it and supports `renderer_parity` |
| G6 | Archival ledger | `.mth-dl--2up` two-pairs-per-row variant for the 7-row Verification block in the stream | Keeps the post card scannable without compounding a label (SPEC §8.5 forbids `Replay accepted` as one string) |
| G7 | Archival ledger | Chip family is semantic by border: solid = on-platform DOI, **dashed** = off-platform dictionary leaf, **dotted** = non-citable private helper | One consistent, colour-independent encoding of "where does this identifier live" |
| G8 | Archival ledger | Tables are named with `aria-labelledby` pointing at the existing catalogue heading — no `sr-only` caption | An assistive-only caption would be an uncatalogued string; reuse is lawful and needs no catalogue diff |
| G9 | Archival ledger + Instrument face | Determinate **9-tick state rail** replaces the indeterminate progress bar on `/submit` | The nine `verification.state` values are known; an indeterminate bar pretends less is known than is known |
| G10 | Instrument face | Ellipsis is only ever CSS `text-overflow`; no JS or `content:` ever inserts `…` | DOM text stays byte-equal to `values.json` (SPEC §8, R40) |

**Fixes to the winning direction's own defects.**

* **F1 — `<summary>` no longer follows content inside `<details>`.** The original relied on flex ordering inside
  `<details>`, which fights the details content slot. Replaced by the sibling-disclosure pattern of §7.11: the clamped
  statement is an ordinary element, the toggle is a sibling `<details>`, and the clamp is released by `:has()`.
  `<details>` is otherwise used in its plain form (summary first) wherever content is genuinely hidden.
* **F2 — clamp fade gradient removed.** Truncation is marked by a 1px dashed bottom rule, which survives print,
  costs no colour, and does not imply a colour ramp that means nothing.
* **F3 — skeleton rows removed.** Loading is a 2px indeterminate rule under the nav plus the existing count value;
  nothing renders fake content.
* **F4 — `backdrop-blur` on the nav removed.** Opaque `surface` + hairline. The nav is chrome, not glass.
* **F5 — status pulse removed** in favour of G9's determinate rail.
* **F6 — skip link.** Still absent, but the reason is recorded as a decision with its price, not left silent: see §15.

---

## 1. Build topology and the CSS contract

```
web/tailwind.css            source of truth (Tailwind v4, CSS-first config)
web/src/styles/components.css   the shared .mth-* component layer
      ↓ vite build (cssCodeSplit: false, one CSS entry)
web/dist-assets/record.css  the single unhashed stylesheet
web/dist-assets/app.js      the single unhashed SPA entry
web/dist-assets/fonts/*.woff2
      ↓ COPY into the webd image (SPEC §11.3)
served at /assets/*         recordgen writes no assets at all (SPEC §10, R32)
```

Rules that make this buildable and keep the two renderers identical:

1. **One stylesheet, two consumers.** `@source` globs cover `web/src/**` *and* `services/registry/crates/record/
   templates/**`, which is what `css_covers_templates` (SPEC §13) checks. A template-only change cannot ship without
   the `webd` image roll that carries its styles.
2. **No arbitrary values (G5).** Neither React nor `askama` may emit `class="w-[220px]"` or any `[...]` bracket
   utility. Every magnitude is a theme token or a `.mth-*` component rule. Enforced by a CI grep gate over both
   source trees (`rg -n '\[[^\]]*\]' --glob '*.tsx' --glob '*.html'` restricted to `class`/`className` attributes)
   and by a stylelint rule on `components.css`.
3. **The `.mth-*` layer is the renderer contract.** Both renderers emit the same class names for the same component;
   neither composes ad-hoc utility strings for a component that exists in the layer. `renderer_parity` compares tags,
   `data-*` and text; the shared class layer is what keeps them visually identical in practice.
4. **No inline `style` attributes anywhere.** CSP is `style-src 'self'` (SPEC §11). SVG geometry uses presentation
   attributes (`x`, `y`, `width`, `height`, `d`, `transform`), which CSP does not govern, so the DAG's deterministic
   layout needs no inline style. See §15 for the one CSP exception `/submit` requires.
5. **Fonts are self-hosted** under `/assets/fonts/` (`font-src 'self'`). No Google Fonts, no CDN, no external
   stylesheet, no `@import` of a remote sheet.
6. **No Tailwind plugins.** `@tailwindcss/typography` is deliberately not used: author prose is styled by hand against
   the 22 elements of `shared/html-allowlist.v1.json`, so the stylesheet cannot style an element the sanitizer strips
   or vice versa.

---

## 2. Typography

**Faces.** Text is set in the system's Times, falling back to self-hosted Tinos; code is self-hosted JuliaMono. Every
self-hosted face is woff2, subsetted, `font-display: swap`.

| Role | Family | Files | Why |
|---|---|---|---|
| Text | **Times New Roman**, then Times, then **Tinos** (self-hosted), Liberation Serif, Nimbus Roman, TeX Gyre Termes, `serif` (`--font-serif`) | `tinos-400-latin.woff2`, `tinos-700-latin.woff2` (SIL OFL 1.1, `TINOS-LICENSE.txt` beside them) | The record reads as a book of arguments, not a console. Tinos has Times New Roman's metrics, so a machine without Times sets the same line lengths; a machine with it never fetches Tinos |
| Code / Lean | **JuliaMono** | `julia-mono-400-latin.woff2`, `julia-mono-400-math.woff2`, `julia-mono-700-latin.woff2` | The only widely available mono with real coverage of Lean's operator/blackboard/script glyphs (`∀ ℕ ↔ ⊢ ≤ 𝓕 ⟨⟩ ↦ ⁻¹ ε`); no tofu, no mid-line metric change |

G1 split (two `@font-face` blocks per weight):

* latin/base `U+0000-024F, U+2010-2027, U+2030-205E`
* math/symbol `U+0370-03FF, U+2000-200F, U+2070-209F, U+20A0-20BF, U+2100-214F, U+2190-21FF, U+2200-22FF,
  U+2300-23FF, U+2460-24FF, U+25A0-25FF, U+27C0-27EF, U+2980-29FF, U+2A00-2AFF, U+1D400-1D7FF`

Bold JuliaMono ships latin only; no rendered statement uses bold (weight is never a semantic in a statement).

Base features on `body`: none; Times New Roman's figures are already tabular, so dates and hashes align.
Mono kills ligatures: `font-variant-ligatures: none; font-feature-settings: "calt" 0` — `->`, `<->`, `:=` must render
as the characters Lean emitted.

**UI scale** (Tailwind names redefined; about 1.2× the old sans scale, because Times's x-height is smaller).

| Token | px / line-height | Use |
|---|---|---|
| `text-2xs` | 13 / 20 | facet chips, DAG node kind, table micro-meta, gutter numbers |
| `text-xs` | 14 / 20 | control labels, `<dt>` terms, table headers |
| `text-sm` | 16 / 24 | **UI default**: body, table cells, buttons, inputs, values |
| `text-base` | 17 / 26 | `<dd>` values in the verification block, metric numbers |
| `text-lg` | 19 / 28 | `<h2>` (`Note`, `DOIs`, `Arguments`), landing-page decl |
| `text-xl` | 22 / 30 | profile login, section heads |
| `text-2xl` | 27 / 34 | `<h1>` (`About`, `Claims`, `Arguments`, `Posts`, `Sign in`, `Not found`) |
| `text-3xl` | 34 / 40 | reserved; unused in v0 |

**Mono scale** (separate, because Lean glyphs are tall).

| Token | px / line-height | Use |
|---|---|---|
| `text-code-xs` | 11 / 1.5 | DAG graph-node decl and one-line statement preview |
| `text-code-sm` | 12 / 1.5 | `pre[data-role=log]`, `pre[data-role=report]`, DAG list-node statements |
| `text-code` | 13 / **1.55** | `pre[data-role=lean-statement]`, Monaco, infoview |
| `text-code-lg` | 14 / 1.6 | claim statement on a landing page (region 1, unclamped) |
| `text-code-inline` | 0.85em | code inside a docstring: follows the prose it sits in |

Weights: 400 body, 500 labels/`<dt>`/table headers, 600 headings and the wordmark, 700 only inside `.record-prose`
`<strong>`. Letter-spacing: `0` for text, `+0.06em` on the uppercase terms, `+0.02em` on sha256 prefixes.

---

## 3. Colour

All values hex (exact contrast control). Ratios computed against the stated ground.

**Neutral — `ink`** (cool, paper-neutral):

| Token | Hex | Role | Contrast |
|---|---|---|---|
| `ink-0` | `#FFFFFF` | record surface, cards, table body | — |
| `ink-25` | `#FCFCFD` | page ground | — |
| `ink-50` | `#F7F8FA` | code/log ground, table header, inset panels, `#authored` ground | — |
| `ink-100` | `#EFF1F4` | hover ground, segmented track, protected editor lines, progress track | — |
| `ink-200` | `#E3E6EB` | **hairline** — card edges, table rules, dividers (decorative only) | — |
| `ink-300` | `#CDD2DA` | strong separator, DAG edges, `#authored` left rail, scrollbar thumb | — |
| `ink-400` | `#9BA3B0` | decorative marks, disabled text, DAG order gutter ticks | — |
| `ink-450` | `#737B88` | **control border** — inputs, selects, checkboxes, segmented control | 3.98:1 vs white ✓ (1.4.11) |
| `ink-500` | `#6B7482` | icons only — **banned for text** (4.47:1 on `ink-50` fails AA) | — |
| `ink-600` | `#4E5765` | **muted text** — `<dt>` terms, table headers, secondary values | 7.20:1 white / 6.77:1 `ink-50` ✓ |
| `ink-700` | `#39404C` | body text on tinted grounds | 9.6:1 ✓ |
| `ink-800` | `#262B34` | headings | 13.2:1 ✓ |
| `ink-900` | `#14171C` | **primary text**, Lean statements | 17.9:1 ✓ |

> Rule: `ink-200` is decorative structure. Anything a viewer must identify as a control uses `ink-450`.

**Accent** (the only accent):

| Token | Hex | Role | Contrast |
|---|---|---|---|
| `accent-50` | `#EEF3FD` | DOI chip ground, dictionary-leaf chip ground, selected row tint |
| `accent-100` | `#DCE7FB` | chip hover |
| `accent-200` | `#BCD0F6` | chip border |
| `accent-300` | `#8FB0EE` | focus row outline, DAG focus edge highlight |
| `accent-400` | `#5C89E2` | dark-theme borders |
| `accent-500` | `#3566D4` | **focus ring**, active nav underline, claim left rail, state-rail reached tick | 5.24:1 vs white ✓ |
| `accent-600` | `#2450BC` | **links**, primary-button ground | 7.08:1 vs white; white-on ✓ |
| `accent-700` | `#1B3E96` | chip text, link hover | 8.69:1 on `accent-50` ✓ |
| `accent-800` | `#172F72` | primary-button active | — |
| `accent-900` | `#13244F` | reserved | — |

**Semantic status** (never the accent; text / ground / border):

| Token | Text | Ground | Border | Contrast | Values it renders |
|---|---|---|---|---|---|
| `ok` | `#0F7A4A` | `#E6F4EC` | `#A9D9C0` | 4.75:1 ✓ | `accepted`, `pass`, `admitted`, `free`, `Ready`, `Copied` |
| `warn` | `#8A5A00` | `#FCF3E2` | `#EBD5A6` | 5.38:1 ✓ | `building`, `exporting`, `adjudicating`, `assembling`, `Elaborating` |
| `err` | `#B3261E` | `#FDECEA` | `#F2BDB8` | 5.72:1 ✓ | `rejected`, `failed`, `[data-role=error]`, `reason_code` |
| `neutral` | `#4E5765` | `#EFF1F4` | `#CDD2DA` | 6.77:1 ✓ | `received`, `queued`, `not-applicable`, `person`, `agent`, `initial`, `—` |

Colour is never the sole cue: every status chip carries its own value word (SPEC §8's value list), DOI chips carry a
border, in-prose links are underlined.

**Dark theme** — `prefers-color-scheme: dark` only. **No toggle control exists**: its label is uncatalogued.

```
bg #0D0F13 · surface #131720 · surface-2 #1A1F29 · code-bg #10141C
border #262C38 · border-strong #333B49 · border-control #5C6472 (3.23:1 ✓)
text #E8EBF0 (15.4:1 ✓) · muted #A7AEBB (8.5:1 ✓) · icon #7C8493
link/accent-500 #7BA3EE (7.65:1 ✓) · primary button bg #2E5AC4, white text (6.24:1 ✓)
ok #4ADE9B/#0E2A1E/#1D5238 · warn #E8B455/#2C2413/#54421C · err #FF9A90/#2C1512/#5A2521
```

---

## 4. Space, shape, structure, motion

* **Unit** 4px; spacing scale = Tailwind default.
* **Density:** `--h-control 28px`, `--h-control-lg 32px`, `--h-control-sm 24px`; `--h-row 36px`,
  `--h-row-tall 76px` (Collection claims rows, 3-line clamp); `--h-nav 48px`; `--h-tablehead 32px`.
* **Radii:** `xs 2px`, `sm 3px` (chips, inputs, buttons), `md 4px`, `lg 6px` (cards, panels), `xl 8px` (DAG viewport).
  **No pills, no `rounded-full`.** The avatar is a 4px-radius square, not a circle.
* **Borders:** 1px only. `--border-hair` (`ink-200`), `--border-control` (`ink-450`), `--border-strong` (`ink-300`).
* **Shadows:** exactly one, `--shadow-float`, used only by the DAG minimap. Content never casts a shadow.
* **Containers:** `--container-doc 760px` (About, Login, 404, 503), `--container-stream 1080px` (Posts, landing),
  `--container-shell 1600px` (Collection, Submit, Profile).
* **Gutters:** 16px `<640`, 24px `≥640`, 32px `≥1280`.
* **Breakpoints:** `sm 640 · md 768 · lg 1024 · xl 1280 · 2xl 1536 · 3xl 1760`.
* **Z-index:** `10` sticky table header / sticky mini-head · `20` sticky nav · `30` DAG minimap · no `40+`
  (there are no modals).
* **Motion:** `--ease-ui: cubic-bezier(.2,0,.2,1)`; `--dur-fast 100ms` (hover/focus), `--dur 150ms`
  (disclosure, chip state), `--dur-bar 1200ms` (the page-loading rule only). All wrapped in
  `@media (prefers-reduced-motion: reduce)`.
* **Focus** (never removed): `--ring: 0 0 0 2px var(--color-surface), 0 0 0 4px var(--color-accent-500)` on
  `:focus-visible`. Rows and DAG nodes use the row form instead — `inset 2px 0 0 accent-500`, `outline 1px accent-300`,
  ground `accent-50` — because a ring around a full-bleed row reads badly. Roving `tabindex` in: the posts stream,
  every table, the DAG node set, the DOIs table.

---

## 5. `web/tailwind.css` — the theme (source of truth)

```css
@import "tailwindcss";

/* css_covers_templates (SPEC §13): the stylesheet is built from BOTH renderers' sources */
@source "../src/**/*.{ts,tsx}";
@source "../../services/registry/crates/record/templates/**/*.html";

@theme {
  /* ---------- type ---------- */
  --font-serif: "Times New Roman", Times, Tinos, "Liberation Serif", "Nimbus Roman", "Nimbus Roman No9 L",
    "TeX Gyre Termes", serif;
  --font-mono: "JuliaMono", "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;

  --text-2xs: 0.8125rem;      --text-2xs--line-height: 1.25rem;
  --text-xs: 0.875rem;        --text-xs--line-height: 1.25rem;
  --text-sm: 1rem;            --text-sm--line-height: 1.5rem;
  --text-base: 1.0625rem;     --text-base--line-height: 1.625rem;
  --text-lg: 1.1875rem;       --text-lg--line-height: 1.75rem;
  --text-xl: 1.375rem;        --text-xl--line-height: 1.875rem;
  --text-2xl: 1.6875rem;      --text-2xl--line-height: 2.125rem;
  --text-3xl: 2.125rem;       --text-3xl--line-height: 2.5rem;

  --text-code-xs: 0.6875rem;  --text-code-xs--line-height: 1.5;
  --text-code-sm: 0.75rem;    --text-code-sm--line-height: 1.5;
  --text-code: 0.8125rem;     --text-code--line-height: 1.55;
  --text-code-lg: 0.875rem;   --text-code-lg--line-height: 1.6;

  /* ---------- neutral ---------- */
  --color-ink-0:  #FFFFFF;  --color-ink-25: #FCFCFD; --color-ink-50: #F7F8FA;
  --color-ink-100:#EFF1F4;  --color-ink-200:#E3E6EB; --color-ink-300:#CDD2DA;
  --color-ink-400:#9BA3B0;  --color-ink-450:#737B88; --color-ink-500:#6B7482;
  --color-ink-600:#4E5765;  --color-ink-700:#39404C; --color-ink-800:#262B34;
  --color-ink-900:#14171C;

  /* ---------- accent ---------- */
  --color-accent-50: #EEF3FD; --color-accent-100:#DCE7FB; --color-accent-200:#BCD0F6;
  --color-accent-300:#8FB0EE; --color-accent-400:#5C89E2; --color-accent-500:#3566D4;
  --color-accent-600:#2450BC; --color-accent-700:#1B3E96; --color-accent-800:#172F72;
  --color-accent-900:#13244F;

  /* ---------- status ---------- */
  --color-ok-fg:#0F7A4A;   --color-ok-bg:#E6F4EC;   --color-ok-bd:#A9D9C0;
  --color-warn-fg:#8A5A00; --color-warn-bg:#FCF3E2; --color-warn-bd:#EBD5A6;
  --color-err-fg:#B3261E;  --color-err-bg:#FDECEA;  --color-err-bd:#F2BDB8;

  /* ---------- semantic aliases (what components actually reference) ---------- */
  --color-bg: var(--color-ink-25);
  --color-surface: var(--color-ink-0);
  --color-surface-2: var(--color-ink-50);
  --color-code-bg: var(--color-ink-50);
  --color-text: var(--color-ink-900);
  --color-text-muted: var(--color-ink-600);
  --color-icon: var(--color-ink-500);
  --color-border: var(--color-ink-200);
  --color-border-strong: var(--color-ink-300);
  --color-border-control: var(--color-ink-450);
  --color-link: var(--color-accent-600);
  --color-selection: #C9DBFB;

  /* ---------- shape ---------- */
  --radius-xs: 2px; --radius-sm: 3px; --radius-md: 4px; --radius-lg: 6px; --radius-xl: 8px;
  --shadow-float: 0 1px 2px rgb(20 23 28 / .06), 0 8px 24px -10px rgb(20 23 28 / .20);
  --ease-ui: cubic-bezier(.2,0,.2,1);

  /* ---------- density ---------- */
  --spacing-control: 1.75rem;      /* 28 */
  --spacing-control-lg: 2rem;      /* 32 */
  --spacing-control-sm: 1.5rem;    /* 24 */
  --spacing-row: 2.25rem;          /* 36 */
  --spacing-row-tall: 4.75rem;     /* 76 */
  --spacing-nav: 3rem;             /* 48 */
  --spacing-tablehead: 2rem;       /* 32 */

  --container-doc: 760px;
  --container-stream: 1080px;
  --container-shell: 1600px;
  --breakpoint-3xl: 1760px;

  /* ---------- G5: every magnitude that used to be an arbitrary value ---------- */
  --field-w-xs: 88px;     /* Min */
  --field-w-sm: 140px;    /* From, To */
  --field-w-md: 180px;    /* Library, Author, DOI lookup */
  --field-w-lg: 220px;    /* Profile combobox */
  --field-w-xl: 360px;    /* Claim designation select */
  --field-w-search-min: 280px;

  --col-doi: 148px;  --col-decl: 220px;  --col-date: 128px;  --col-num: 88px;
  --col-axioms: 140px; --col-author: 140px; --col-kind: 104px; --col-lib: 160px;
  --col-statement-min: 320px;

  --h-log: 380px;  --h-report: 520px;
  --h-dag: min(720px, 70vh);
  --h-dag-stream: 420px;
  --h-editor: clamp(320px, 58vh, 720px);
  --h-note-editor: 240px;
  --w-minimap: 160px; --h-minimap: 96px;
  --w-login-card: 360px;

  --clamp-stream: 12;   /* lines */
  --clamp-table: 3;     /* lines */

  /* ---------- DAG geometry: fixed by SPEC §8.5, must not drift ---------- */
  --dag-col-pitch: 260px;   /* x = 24 + depth * 260 */
  --dag-row-pitch: 112px;   /* y = 24 + order * 112 */
  --dag-node-w: 220px;
  --dag-node-h: 88px;
  --dag-node-h-collapsed: 44px;
  --dag-origin: 24px;
  --dag-ruler-h: 24px;
  --dag-gutter-w: 40px;
}

@theme inline {
  --color-ring: var(--color-accent-500);
}

/* dark: media query only. No toggle exists (its label is uncatalogued). */
@media (prefers-color-scheme: dark) {
  :root {
    --color-bg:#0D0F13; --color-surface:#131720; --color-surface-2:#1A1F29;
    --color-code-bg:#10141C;
    --color-text:#E8EBF0; --color-text-muted:#A7AEBB; --color-icon:#7C8493;
    --color-border:#262C38; --color-border-strong:#333B49; --color-border-control:#5C6472;
    --color-link:#7BA3EE; --color-selection:#1F3A6B;
    --color-accent-50:#161F33; --color-accent-100:#1B2842; --color-accent-200:#24365A;
    --color-accent-500:#7BA3EE; --color-accent-600:#2E5AC4; --color-accent-700:#A9C4F4;
    --color-ok-fg:#4ADE9B;  --color-ok-bg:#0E2A1E;  --color-ok-bd:#1D5238;
    --color-warn-fg:#E8B455;--color-warn-bg:#2C2413;--color-warn-bd:#54421C;
    --color-err-fg:#FF9A90; --color-err-bg:#2C1512; --color-err-bd:#5A2521;
  }
}

@layer base {
  /* G1: JuliaMono split so a statement's first paint is not blocked by the math block */

  @font-face { font-family:"JuliaMono"; src:url("/assets/fonts/julia-mono-400-latin.woff2") format("woff2");
    font-weight:400; font-display:swap;
    unicode-range:U+0000-024F,U+2010-2027,U+2030-205E; }
  @font-face { font-family:"JuliaMono"; src:url("/assets/fonts/julia-mono-400-math.woff2") format("woff2");
    font-weight:400; font-display:swap;
    unicode-range:U+0370-03FF,U+2000-200F,U+2070-209F,U+20A0-20BF,U+2100-214F,U+2190-21FF,
                  U+2200-22FF,U+2300-23FF,U+2460-24FF,U+25A0-25FF,U+27C0-27EF,U+2980-29FF,
                  U+2A00-2AFF,U+1D400-1D7FF; }
  @font-face { font-family:"JuliaMono"; src:url("/assets/fonts/julia-mono-700-latin.woff2") format("woff2");
    font-weight:700; font-display:swap; unicode-range:U+0000-024F; }

  *,::before,::after { box-sizing:border-box; }
  html { -webkit-text-size-adjust:100%; }
  body {
    margin:0; background:var(--color-bg); color:var(--color-text);
    font-family:var(--font-serif); font-size:var(--text-sm); line-height:var(--text-sm--line-height);
    -webkit-font-smoothing:antialiased; text-rendering:optimizeLegibility;
  }
  ::selection { background:var(--color-selection); }
  a { color:var(--color-link); text-decoration:none; }
  a:hover { text-decoration:underline; text-underline-offset:2px; text-decoration-thickness:1px; }
  :focus-visible {
    outline:none;
    box-shadow:0 0 0 2px var(--color-surface),0 0 0 4px var(--color-ring);
    border-radius:var(--radius-sm);
  }
  h1,h2,h3 { margin:0; font-weight:600; color:var(--color-ink-800); }
  h1 { font-size:var(--text-2xl); line-height:var(--text-2xl--line-height); }
  h2 { font-size:var(--text-lg);  line-height:var(--text-lg--line-height); }
  h3 { font-size:var(--text-sm);  line-height:var(--text-sm--line-height); }
  table { border-collapse:separate; border-spacing:0; }
  svg { display:block; }                 /* every icon is decorative + aria-hidden */
  @media (prefers-reduced-motion:reduce) {
    *,::before,::after { animation-duration:1ms!important; animation-iteration-count:1!important;
                         transition-duration:1ms!important; scroll-behavior:auto!important; }
  }
}
```

### 5.1 `tailwind.config.ts` — mirror, for tooling and IntelliSense

```ts
import type { Config } from "tailwindcss";

const ink = { 0:"#FFFFFF",25:"#FCFCFD",50:"#F7F8FA",100:"#EFF1F4",200:"#E3E6EB",
  300:"#CDD2DA",400:"#9BA3B0",450:"#737B88",500:"#6B7482",600:"#4E5765",
  700:"#39404C",800:"#262B34",900:"#14171C" };
const accent = { 50:"#EEF3FD",100:"#DCE7FB",200:"#BCD0F6",300:"#8FB0EE",400:"#5C89E2",
  500:"#3566D4",600:"#2450BC",700:"#1B3E96",800:"#172F72",900:"#13244F" };

export default {
  content: ["./src/**/*.{ts,tsx}", "../services/registry/crates/record/templates/**/*.html"],
  theme: {
    extend: {
      colors: {
        ink, accent,
        ok:   { fg:"#0F7A4A", bg:"#E6F4EC", bd:"#A9D9C0" },
        warn: { fg:"#8A5A00", bg:"#FCF3E2", bd:"#EBD5A6" },
        err:  { fg:"#B3261E", bg:"#FDECEA", bd:"#F2BDB8" },
        bg:"var(--color-bg)", surface:"var(--color-surface)", "surface-2":"var(--color-surface-2)",
        "code-bg":"var(--color-code-bg)", text:"var(--color-text)",
        muted:"var(--color-text-muted)", icon:"var(--color-icon)",
        border:"var(--color-border)", "border-strong":"var(--color-border-strong)",
        "border-control":"var(--color-border-control)", link:"var(--color-link)",
      },
      fontFamily: {
        serif: ['Times New Roman','Times','Tinos','Liberation Serif','Nimbus Roman','Nimbus Roman No9 L','TeX Gyre Termes','serif'],
        mono: ['JuliaMono','JetBrains Mono','ui-monospace','SFMono-Regular','Menlo','Consolas','monospace'],
      },
      fontSize: {
        "2xs":["0.8125rem",{lineHeight:"1.25rem"}],
        xs:["0.875rem",{lineHeight:"1.25rem"}],
        sm:["1rem",{lineHeight:"1.5rem"}],
        base:["1.0625rem",{lineHeight:"1.625rem"}],
        lg:["1.1875rem",{lineHeight:"1.75rem"}],
        xl:["1.375rem",{lineHeight:"1.875rem"}],
        "2xl":["1.6875rem",{lineHeight:"2.125rem"}],
        "3xl":["2.125rem",{lineHeight:"2.5rem"}],
        "code-xs":["0.6875rem",{lineHeight:"1.5"}],
        "code-sm":["0.75rem",{lineHeight:"1.5"}],
        code:["0.8125rem",{lineHeight:"1.55"}],
        "code-lg":["0.875rem",{lineHeight:"1.6"}],
      },
      borderRadius: { xs:"2px", sm:"3px", md:"4px", lg:"6px", xl:"8px" },
      spacing: { control:"1.75rem","control-lg":"2rem","control-sm":"1.5rem",
                 row:"2.25rem","row-tall":"4.75rem", nav:"3rem", tablehead:"2rem" },
      maxWidth: { doc:"760px", stream:"1080px", shell:"1600px" },
      boxShadow: { float:"0 1px 2px rgb(20 23 28 / .06), 0 8px 24px -10px rgb(20 23 28 / .20)" },
      screens: { "3xl":"1760px" },
      transitionTimingFunction: { ui:"cubic-bezier(.2,0,.2,1)" },
      keyframes: { bar:{ "0%":{transform:"translateX(-100%)"}, "100%":{transform:"translateX(300%)"} } },
      animation: { bar:"bar 1200ms linear infinite" },
    },
  },
  plugins: [],
} satisfies Config;
```

---

## 6. String discipline (what may appear, and where)

Three kinds of visible string exist and no fourth (SPEC §8):

1. a catalogue entry from `labels.ts` / `crates/record/labels.json`;
2. a data value inside `[data-value="true"][data-field="<field>"]`, matching the page's sibling `values.json`
   byte for byte (generated tree) or the field's declared shape (DOM snapshots). A **docstring** is such a
   value: the author's own words from the verified source (`claim.doc`, `argument_node.doc`,
   `dictionary_constant.doc`, shape `docstring`), attributed to them, rendered from a closed Markdown subset
   (paragraphs, lists, code, strong, emphasis, http(s) links; everything else escaped) and, like a Lean
   statement, exempt from the four-word and vocabulary rules — they are not the platform's prose;
3. a reason message inside `<p data-role="error">`, rendered by `renderReason(code, params)`.

Design consequences, all load-bearing:

* **No `placeholder` attribute on any input, anywhere.** Every control carries a visible `<label>` or `<legend>`.
* **No icon-only interactive control** except the facet-chip remove button (`aria-label="Clear"`, a catalogue entry)
  and sortable table headers (the icon is nested inside a button whose text is the column label).
* **No tooltip, no `title` attribute** used for explanation.
* **G10: ellipsis is CSS only.** Truncation uses `text-overflow: ellipsis` (which does not alter `textContent`) or the
  clamp of §7.11. No JS, no `content:` rule, ever inserts `…` into a value.
* **No compound labels.** `<dt>Replay</dt><dd>accepted</dd>`, never `Replay accepted` (SPEC §8.5, R25).
* **The `<pre>` roles are exactly three** — `lean-statement`, `log`, `report`. A `<pre>` with any other or absent
  `data-role` is a lint violation (`unknown_role`), so the component layer defines exactly three `pre` components.
* **Exactly three elements carry a value inside an attribute:** the avatar's `alt`
  (`data-attr-value="alt" data-field="profile.citation_name"`), `[data-citation-text]` and `[data-citation-bibtex]`.

---

## 7. Component inventory

Declared in `web/src/styles/components.css` inside `@layer components` with `@apply` plus raw CSS where a property has
no utility. Every component lists its states; a state not listed does not exist.

### 7.1 `.mth-nav` — chrome

```
.mth-nav        h-nav, sticky top-0 z-20, bg-surface, border-b border-border. (No blur — F4.)
                Flex: wordmark | 4 links. Bytes identical on every page (SPEC §8).
.mth-wordmark   text-base 600 weight, tracking tight, ink-900,
                + 14px decorative square-in-square SVG mark (aria-hidden), gap-2 → "Mathesis" → /posts
.mth-nav-link   h-nav inline-flex items-center px-2.5 text-sm text-ink-600, hover:text-ink-900,
                2px transparent inset bottom border
.mth-nav-link[aria-current="page"]   text-ink-900 font-medium, border-b-2 border-accent-500
.mth-main       block; page container is .mth-doc | .mth-stream | .mth-shell; tabindex="-1"
```

States: default · hover · focus-visible (ring) · `aria-current="page"`.
No footer. No `Sign in` in the nav. No session-dependent bytes. No hamburger at any width: below 420px the four links
become a horizontally scrollable row (`overflow-x:auto; scrollbar-width:none`).

### 7.2 `.mth-btn` — buttons

| Class | Spec |
|---|---|
| `.mth-btn` | `h-control inline-flex items-center gap-1.5 px-2.5 rounded-sm text-sm font-medium border select-none`, `transition-[background,border-color] duration-100 ease-ui` |
| `.mth-btn--primary` | `bg-accent-600 border-accent-600 text-white`, hover `accent-700`, active `accent-800` — **one per surface** (`Submit`, `Open`, `Save`, `Go`, `Sign in`) |
| `.mth-btn--default` | `bg-surface border-border-control text-ink-800`, hover `ink-50`, active `ink-100` |
| `.mth-btn--quiet` | transparent, `text-ink-600`, hover `bg-ink-100 text-ink-900` (`Clear`, `Reset`, `Copy`, `Copy BibTeX`, `Cancel`, `Sign out`, `Expand all`, `Collapse all`) |
| `.mth-btn--lg` | `h-control-lg px-3` (`Submit`, `Open`, `Sign in`) |
| `.mth-btn--block` | `w-full justify-center` (`More`, `Reload`) |

States: default · hover · active · focus-visible · `[disabled]` / `[aria-disabled="true"]` (`opacity-45`,
`cursor-not-allowed`, **label text unchanged**, R46) · in-flight (`aria-disabled="true"` while a request is open;
no spinner, no label change). Minimum hit target 24×24 (WCAG 2.5.8). `.mth-btn--danger` does not exist: v0 has no
destructive action.

### 7.3 Form controls

```
.mth-field        flex flex-col gap-1 min-w-0
.mth-label        text-xs font-medium text-ink-600 leading-4     (always visible; placeholder is banned)
.mth-input        h-control w-full px-2 rounded-sm border border-border-control bg-surface
                  text-sm text-ink-900 tabular-nums
                  hover:border-ink-600  focus-visible:border-accent-500
.mth-input--mono  font-mono text-code, tracking sha              (DOI entry, Proves, decl fields)
.mth-input--w-xs|sm|md|lg|xl   inline-size: var(--field-w-*)     (G5: no arbitrary widths)
.mth-input--grow  flex:1; min-inline-size: var(--field-w-search-min)            (Search)
.mth-select       .mth-input + pr-6 + decorative chevron SVG (aria-hidden), appearance:none
.mth-textarea     font-mono text-code p-2.5 resize-y; min-block-size: var(--h-note-editor)   (Note editor)
.mth-segmented    inline-flex h-control p-0.5 rounded-sm bg-ink-100 border border-border-control
.mth-segmented__opt   h-control-sm px-2.5 rounded-xs text-xs font-medium text-ink-600
                      [aria-checked=true] → bg-surface, text-ink-900, 1px ring via box-shadow
                      [aria-disabled=true] → opacity-40, pointer-events-none, label unchanged
.mth-radio-row    inline-flex gap-4 items-center                 (Profile kind: person | agent)
```

`<fieldset>` + `<legend class="mth-label">` carries the catalogue label of every grouped control
(`Layout`, `Profile kind`, `Logs`).
States: default · hover · focus-visible · `aria-invalid="true"` (1px `err-bd` border, 2px `err-fg` left rule, the
reason message rendered below in `.mth-error`) · disabled · locked (the `Claim` select when `Proves` resolves:
`disabled`, value set to `claims.required_decl_name`, 2px `accent-500` left rule).

### 7.4 Values, terms, chips

```
.mth-term         text-xs font-medium text-ink-600 leading-4        every <dt>, every metric label
.mth-value        text-base text-ink-900 tabular-nums               every [data-value="true"]
.mth-value--mono  font-mono text-code text-ink-900
.mth-value--sha   font-mono text-code tracking-wide text-ink-700    (sha256-prefix, 12 hex)
.mth-value--em    text-ink-400                                      the single "—"
.mth-metric       inline-flex items-baseline gap-1.5  → <span.mth-term>Nodes</span><span.mth-value>12</span>
.mth-metric-row   flex flex-wrap items-baseline gap-x-5 gap-y-1
```

**Chip family (G7) — border style encodes where the identifier lives:**

```
.mth-doi          SOLID  border-accent-200, bg-accent-50, text-accent-700, font-mono text-xs,
                  h-5 px-1.5 rounded-sm; hover bg-accent-100, no underline      → on-platform DOI
.mth-doi--lg      h-6 text-sm px-2                                              (landing header, verdict)
.mth-chip-dict    DASHED border-accent-200, bg-accent-50, text-accent-700, font-mono text-2xs,
                  + 10px decorative external-link SVG (aria-hidden)             → off-platform dictionary leaf,
                  href = {pin.blueprint_url}#{dictionary_constant.blueprint_label}
.mth-chip-private DOTTED border-ink-300, text-ink-600, not a link               → data-citable="false" helper
.mth-chip-facet   SOLID border-border, bg-ink-100, text-ink-700, h-6 pl-2 pr-1,
                  + 24×24 remove button aria-label="Clear" with a 12px x-icon   → active Collection filter
.mth-status       h-5 px-1.5 rounded-sm text-xs font-medium border;
                  variants --ok --warn --err --neutral (the trios of §3)
```

States for `.mth-doi` / `.mth-chip-dict`: default · hover · focus-visible · visited (no distinct treatment).
`.mth-chip-facet`: default · hover · remove-button focus. `.mth-status` has no interaction states.

### 7.5 `.mth-state-rail` — determinate verification progress (G9)

```
.mth-dl          seven-row grid (see 7.8)
.mth-state-rail  inline-flex gap-0.5 items-center, aria-hidden="true"
.mth-state-rail__tick     w-3 h-0.5 rounded-xs bg-ink-100
.mth-state-rail__tick--on bg-accent-500                     reached states
.mth-state-rail__tick--err bg-err-fg                        the terminal tick when rejected|failed
```

Nine ticks, one per `verification.state` (`received queued building exporting adjudicating assembling admitted
rejected failed`), advancing discretely as the SSE stream reports each. It is decorative and `aria-hidden`; the
accessible content is always the adjacent `Status` term and its value. Replaces the indeterminate bar (F3/F5).

`.mth-progress` survives only as the page-loading rule: a 2px full-width track under the nav,
`.mth-progress__bar` a 1/3-width `accent-500` segment with `animation: bar`, shown while an SPA navigation or a
`More` request is open, carrying no text and never standing in for content.

### 7.6 `.mth-card` — post card and panels

```
.mth-card          bg-surface border border-border rounded-lg      (NO shadow)
.mth-card__region  border-t border-border first:border-t-0 px-4 py-3.5   (the five post regions)
.mth-panel         bg-surface-2 border border-border rounded-lg p-3.5
.mth-panel--authored  + 3px ink-300 left rail                   (#authored only)
.mth-login-card    bg-surface border border-border rounded-lg p-8; inline-size: var(--w-login-card)
.mth-rule          h-px bg-border
.mth-section-head  flex items-baseline justify-between gap-3 mb-2.5
```

States: default · `[data-focused]` (roving focus in the stream: `inset 2px 0 0 accent-500`, `outline 1px accent-300`).

### 7.7 `.mth-avatar`, editor chrome

```
.mth-avatar   rounded-md border border-border object-cover bg-ink-100
              --lg 64px (profile) · --sm 48px (a post's author) · --xs 24px (an author in a table)
              alt carries data-attr-value="alt" data-field="profile.citation_name"
              src = /avatars/{login}.{ext}, the record's own copy — no request leaves the site
.mth-person   inline-flex gap-2: a photo (or glyph) and a name, one link — to /u/{login}/ for a
              member, to https://github.com/{login} for a cited person who is not one
.mth-glyph    the abstract avatar of a person the record holds no photo of: a 5×5 grid mirrored
              left to right, from an FNV-1a hash of the GitHub login, in one of four tints
              (--0 accent-500, --1 accent-800, --2 ink-600, --3 accent-300); aria-hidden, since
              the name always stands beside it · --sm 20px · --xs 24px
.mth-editor          border border-border rounded-lg overflow-hidden bg-surface
.mth-editor__head    h-control-lg px-2.5 flex items-center justify-between border-b border-border bg-ink-50
.mth-editor__mount   height: var(--h-editor)
.mth-infoview        border-l border-border bg-surface overflow-auto font-mono text-code p-2.5
.mth-mono-protected  Monaco line decoration: bg ink-100, 2px ink-400 gutter mark   (lines 1, 2, last)
.mth-diag-error      Monaco: 2px wavy err-fg underline
.mth-diag-advisory   Monaco: 1px dotted ink-450 underline + ink-400 gutter dot     (never blocks Submit)
```

The Monaco theme `mathesis-light` / `mathesis-dark` is derived from the same tokens: ground `surface`, gutter
`surface-2`, line numbers `ink-400`, cursor `accent-600`, selection `selection`, current line `ink-50`, font
JuliaMono at `text-code`, ligatures off, minimap off, `renderWhitespace: "none"`. Token colours are monochrome
(`ink-900` identifiers, `ink-800` 500-weight keywords, `ink-600` italic comments) so the buffer and the published
statement read as the same object; only diagnostics carry colour.

### 7.8 `.mth-dl` — the term/value grid (Verification and every other pair block)

```
.mth-dl          grid grid-cols-[minmax(120px,160px)_minmax(0,1fr)] gap-x-4 gap-y-1.5 items-baseline
.mth-dl > dt     .mth-term, pt-px
.mth-dl > dd     m-0 .mth-value, min-w-0 break-words
.mth-dl--2up     ≥1024: grid-cols-[term 1fr term 1fr]            (G6 — unused since verification left the stream)
@media (max-width:640px) { .mth-dl, .mth-dl--2up { grid-cols-1 } ; dd { mb-2 } }
```

The Verification block is always seven `<dt>/<dd>` pairs, on an argument's own page only. `--2up` changes only how the same seven
pairs wrap; it never merges a term into its value.

### 7.9 `.mth-table`

```
.mth-table             w-full text-sm; aria-labelledby → the section's catalogue <h1>/<h2> (G8)
.mth-table thead th    h-tablehead sticky top-nav z-10 bg-ink-50 border-y border-border
                       px-2.5 text-left text-xs font-medium text-ink-600 whitespace-nowrap
.mth-table tbody td    h-row px-2.5 border-b border-border align-middle
.mth-table tbody tr:hover          bg-ink-50
.mth-table tbody tr[data-focused]  bg-accent-50 + 2px inset accent-500 left rail + 1px accent-300 outline
.mth-table--tall tbody td          h-row-tall py-2 align-top        (Collection claims, 3-line statement)
.mth-th-sort           full-cell button, gap-1, + 10px decorative caret; <th aria-sort="…">
.mth-td-mono           font-mono text-code text-ink-800; truncation via text-overflow only (G10)
.mth-table-scroll      overflow-x-auto; first column (DOI) position:sticky left-0 bg-surface,
                       right hairline via box-shadow 1px 0 0 var(--color-border)
```

No table carries a count, and no page shows one: a count is commentary on the record, not part of it.

States: default · hover · roving `[data-focused]` · sorted (`aria-sort` + caret) · **empty** (empty `<tbody>`,
no count, no sentence, no illustration) · **loading** (the §7.5 page rule; rows are simply absent) · **error**
(`.mth-error` directly above the table, `<tbody>` cleared).
No zebra striping — hairline row rules only. A link that fills a whole cell is not underlined (the column header
supplies the affordance); links inside running text are underlined.

Below `md` a table may render `.mth-table--stacked`: each row becomes a `<dl>` block, hairline-separated, reusing the
same column labels as `<dt>` so no new string appears.

### 7.10 `.mth-disclosure` — the only reveal primitive

```
.mth-disclosure            border border-border rounded-md bg-surface
.mth-disclosure > summary  list-none cursor-pointer h-control inline-flex items-center gap-1.5 px-2
                           text-xs font-medium text-ink-600 hover:text-ink-900 rounded-sm
                           + 12px decorative chevron, rotate-90 when [open]
summary::-webkit-details-marker { display:none }
details[open] .mth-lbl-expand       { display:none }   /* label swap, catalogue strings only, no JS */
details:not([open]) .mth-lbl-collapse { display:none }
```

Used with content (summary first, standard semantics) for: `Uses`, `Used by`, `Report`, `Cite`.
Used as a sibling toggle (§7.11) for statement clamping.
`Expand all` / `Collapse all` is one `open` attribute write per `<details>` in the card. Without JS each toggle still
works individually. No modal, popover, tooltip or toast exists in v0.

### 7.11 `.mth-lean` — the primary content, and the clamp mechanism (F1, F2, G2)

```css
.mth-lean {                         /* <pre data-role="lean-statement" data-value data-field="…"> */
  @apply font-mono text-code text-ink-900 bg-code-bg border border-border rounded-md
         px-3 py-2.5 overflow-x-auto;
  white-space: pre;                 /* never rewrapped, never character-substituted */
  tab-size: 2;
  scrollbar-gutter: stable;         /* no layout shift when a long line appears */
  font-variant-ligatures: none;
  overscroll-behavior-x: contain;
  scrollbar-width: thin;            /* G2: the x-scrollbar is permanently visible, */
}                                   /*     so truncation is never silent            */
.mth-lean::-webkit-scrollbar        { height: 8px; }
.mth-lean::-webkit-scrollbar-thumb  { background: var(--color-ink-300); border-radius: var(--radius-md); }
.mth-lean::-webkit-scrollbar-track  { background: var(--color-ink-100); }

.mth-lean--claim { @apply border-l-2 border-l-accent-500 rounded-l-none pl-3; }
.mth-lean--lg    { @apply text-code-lg; }        /* landing page, unclamped */
.mth-lean--node  { @apply text-code-sm px-2 py-1.5 bg-surface; }

/* Clamp: the wrapper clips vertically, the <pre> still scrolls horizontally. */
.mth-lean-clamp        { @apply relative overflow-hidden; }
.mth-lean-clamp--12    { max-block-size: calc(var(--clamp-stream) * 1.55 * var(--text-code) + 1.25rem); }
.mth-lean-clamp--3     { max-block-size: calc(var(--clamp-table)  * 1.55 * var(--text-code) + 0.75rem); }
.mth-lean-clamp[data-clamped="true"] { border-bottom: 1px dashed var(--color-border-strong); }  /* F2 */

/* F1: the toggle is a SIBLING <details>, so <summary> is never reordered inside a details slot. */
.mth-lean-clamp:has(+ .mth-lean-toggle[open]) { max-block-size: none; border-bottom: 0; }

@supports not selector(:has(*)) {   /* degradation shows MORE, never less */
  .mth-lean-clamp { max-block-size: none; border-bottom: 0; }
  .mth-lean-toggle { display: none; }
}
```

Markup contract:

```html
<div class="mth-lean-clamp mth-lean-clamp--12" id="stmt-MTH.R-2026-5007" data-clamped="true">
  <pre class="mth-lean mth-lean--claim" data-role="lean-statement"
       data-value="true" data-field="claim.pretty">…</pre>
</div>
<details class="mth-lean-toggle mth-disclosure">
  <summary aria-controls="stmt-MTH.R-2026-5007">
    <span class="mth-lbl-expand">Expand</span><span class="mth-lbl-collapse">Collapse</span>
  </summary>
</details>
```

States: clamped (default in the stream and in the Collection `Statement` column) · expanded ·
unclamped-by-construction (landing pages; the wrapper and toggle are not emitted at all) · horizontally scrolled.
Monochrome by decision (§0 rule 4). Ids are deterministic (accession, or accession + node index) so the generated tree
stays byte-stable.

**Print (G3):** `@media print { .mth-lean { white-space: pre-wrap; text-indent: -2ch; padding-left: 2ch;
font-size: 9pt; border-color:#000; } }` — a deliberate print-only deviation, since clipping loses content on paper.
DOM text is unaffected.

### 7.12 `.mth-pre-log`, `.mth-pre-report`

```
.mth-pre-log     <pre data-role="log">    font-mono text-code-sm text-ink-800 bg-code-bg
                 border border-border rounded-md p-2.5 overflow-auto; max-block-size: var(--h-log)
                 white-space:pre; scrollbar-gutter:stable; overflow-anchor:none
.mth-pre-report  <pre data-role="report"> same shape; max-block-size: var(--h-report); word-break:break-all
```

Verbatim compiler output and verbatim adjudicator JSON: no highlighting, no line numbers, no paraphrase.
States: empty (element absent, not an empty box) · streaming (auto-scrolled to bottom only while the state is
non-terminal) · terminal.

### 7.13 `.mth-dag`

```
.mth-dag-viewport   relative border border-border rounded-xl bg-surface overflow-auto
                    height: var(--h-dag)         (stream: var(--h-dag-stream))
                    scrollbar-gutter: stable
.mth-dag-ruler      G4: sticky top-0, height: var(--dag-ruler-h), opaque bg-surface, border-b border-border,
                    one tick per depth column at --dag-col-pitch, each carrying
                    <span .mth-term>Depth</span> once + the depth index as a data value
.mth-dag-gutter     G4: sticky left-0, width: var(--dag-gutter-w), border-r border-border,
                    one tick per order row at --dag-row-pitch, order index as a data value, text-2xs ink-400
.mth-dag-svg        block; extent = (24 + maxDepth*260 + 220 + 24) × (24 + maxOrder*112 + 88 + 24)
                    NEVER downscaled — text below ~11px is unreadable; the viewport scrolls instead.
                    Geometry via presentation attributes only (no inline style — §1 rule 4)
.mth-dag-node       220×88 group (44 collapsed): bg-surface, 1px border-strong, rounded-md
   line 1  {argument_node.decl_name}  font-mono text-code-xs; namespace prefix ink-400 + leaf ink-900 500
           (concatenated textContent === the value, so the byte-for-byte check passes)
   line 2  «Declaration kind» + value → .mth-status--neutral h-4 text-2xs
   line 3  statement preview, font-mono text-code-xs text-ink-600, one line, overflow hidden
.mth-dag-node--root           border-l-2 border-l-accent-500, header ground accent-50
.mth-dag-node[data-citable="false"]   dotted border ink-300, text ink-600, no DOI chip (G7)
.mth-dag-node[data-focused]   outline 2px accent-500, outline-offset 1px
.mth-dag-edge       stroke ink-300; stroke-width 1; fill none; cubic bezier C(x1+90,y1 x2-90,y2);
                    6px arrowhead marker
.mth-dag-edge--hot  stroke accent-500; stroke-width 1.5      (incident to the focused node)
.mth-dag-minimap    absolute bottom-2 right-2, width/height: var(--w-minimap)/var(--h-minimap), bg-surface
                    border border-border rounded-md shadow-float z-30 aria-hidden="true"
                    (rendered when nodes > 40)
.mth-dag-inspector  .mth-panel beside/below the viewport; renders exactly the List row's fields for the
                    focused node — no new field, no new string
.mth-dag-list       <ol> topological; each <li> = .mth-panel with decl · Declaration kind ·
                    the step's docstring (not the thesis's: it opens the post) ·
                    .mth-lean--node (clamp-3 in the stream) · Uses / Used by <details> · leaf chips
                    (a chip with no blueprint anchor links to its leaf's item); after the steps, one item
                    per hypothesis of the thesis and one per definition or cited result, each with its
                    role chip, docstring, statement and — for a cited result — its author (.mth-person)
```

**Roles.** The graph draws every part of the argument, not only its steps:

| Role | Vertex | Placed | Colour (`--color-role-*`) |
|---|---|---|---|
| «Thesis» | the root | depth 0 | thesis: accent ground, accent border, 1.5px |
| «Step» | every other theorem the argument proves | its depth | neutral |
| «Hypothesis» | each Prop-typed binder of the thesis (`argument_hypothesis.*`) | depth 1, edge from the thesis | amber |
| «Definition» | a definition a step uses | one column right of the deepest step using it | teal |
| «Cited result» | a result by another author a step uses | one column right of the deepest step using it | violet |

A legend (`.mth-dag__legend`, `.mth-role`) names the roles the argument has; the list's items carry the same
colours as a 3px rail. A hypothesis box shows its type cut to 26 characters (`argument_hypothesis.label`, shape
`lean-term`) over its binder name; the list carries the full type.

Layout is deterministic (SPEC §8.5: `x = 24 + depth·260`, `y = 24 + order·112`, one down and one up barycenter pass,
ties by vertex id byte order) and the geometry lives in `--dag-*` tokens so CSS and generator cannot drift.

States: `Graph` · `List` · per-node collapsed/expanded · `Expand all` / `Collapse all` · node focused
(inspector updates, incident edges hot) · **oversized** (`nodes > 400 || edges > 4000`: the `Graph` option renders
`aria-disabled="true"` with its label unchanged and `List` is active) · **no-JS** (`List`, server-rendered, the
authoritative form). With scripts, `Graph` is the default wherever it is offered — in the stream, on a landing page
and at every width, a narrow screen scrolling the graph in its viewport; `List` clamps node statements to 3 lines in the
stream.
Keyboard: `←`/`→` by depth, `↑`/`↓` by order, `Enter` moves focus to the inspector, `Esc` returns to the viewport.

### 7.14 `.mth-cite`, `.mth-copy`

```
.mth-cite          .mth-disclosure; summary = «Cite»
.mth-cite__body    p-3 flex flex-col gap-2.5 bg-surface-2 border-t border-border
.mth-cite__text    text-sm text-ink-800 leading-5 select-all
                   data-attr-value="data-citation-text" data-field="citation.text"
.mth-cite__bibtex  hidden; data-attr-value="data-citation-bibtex" data-field="citation.bibtex"
.mth-cite__actions flex gap-2  → «Copy» · «Copy BibTeX»
.mth-copy          .mth-btn--quiet containing <span class="mth-lbl">Copy</span> and
                   <span data-value="true" data-field="clipboard.state" hidden>Copied</span>;
                   on success the visibility swaps for 2000ms, Copied styled text-ok-fg,
                   wrapper aria-live="polite"
```

States: idle · copied (2s) · clipboard unavailable (the value never swaps; nothing else changes, no error string).
The citation is baked at generation time (SPEC §8.6) — there is no client mount that could populate it.

### 7.15 `.mth-error`, `.mth-degraded`

```
.mth-error     <p data-role="error"> text-sm text-err-fg bg-err-bg border border-err-bd
               rounded-md px-3 py-2 m-0
.mth-degraded  flex flex-col items-start gap-2  → .mth-error + «Reload» (.mth-btn--default)
```

`.mth-degraded` is the **only** failure surface in the UI and renders identically in the SPA
(`renderReason("REGISTRY_UNAVAILABLE", {})`) and in the generated `503.html`, which renders the same reason text at
generation time and needs no client (SPEC §8.9, R44).

### 7.16 `.record-prose` — author prose

Scoped to `[data-region="author"]` and `#about-body` only, and hand-written against the 22 allowlisted elements of
`shared/html-allowlist.v1.json` (`p br hr strong em del code pre blockquote ul ol li h2 h3 h4 h5 h6 table thead tbody
tr th td a sup sub`). Measure `68ch`; `text-base/1.6`; `p+p` margin `0.75rem`; `h3` 14px/600 with `1.25rem` top
margin; inline `code` `font-mono`, `font-size: .92em`, on `ink-100`; `pre` takes the `.mth-pre-log` shape;
`blockquote` 2px `ink-300` left rule + `ink-600`; `a` underlined; `table` reuses `.mth-table` at `text-xs`.
`h1` is unstyled because the sanitizer strips it; `h2` is stripped in the `note` profile and allowed in `about`.

---

## 8. Icons

Eight decorative inline SVGs at 14px (12px in `2xs` contexts, 10px on DAG chips), 1.5px stroke, `currentColor`,
`aria-hidden="true" focusable="false"`: `chevron-down`, `chevron-right`, `caret-sort`, `check`, `x`, `external`,
`copy`, `arrow-right`, plus a 16px decorative wordmark glyph and the GitHub mark on `/login`.
No icon-only interactive control exists except the facet-chip remove (`aria-label="Clear"`, a catalogue entry) and the
sort carets nested inside header buttons whose text is the column label. Any other icon-only button would need an
uncatalogued `aria-label` and is therefore unbuildable.

---

## 9. Accessibility contract

* **Contrast:** every text/ground pair in §3 is ≥4.5:1; `ink-450` control borders are 3.98:1 (1.4.11); the
  `accent-500` focus ring is 5.24:1 on white and 3.6:1 on `ink-50`. `ink-500` is banned for text.
* **Focus:** `:focus-visible` is never suppressed; roving `tabindex` in the stream, every table and the DAG node set;
  `Esc` returns focus to the container.
* **Target size:** every control ≥24×24 (2.5.8); default control height 28px.
* **Landmarks:** one `<nav>` (unlabelled — an `aria-label` would be uncatalogued), `<main tabindex="-1">`.
  **No skip link** (see §15 for the decision and its price); the 4-item nav keeps the pre-`main` tab cost at five.
* **Table naming (G8):** `aria-labelledby` points at the section's existing catalogue heading (`DOIs`, `Arguments`,
  `Claims`). No `sr-only` caption, which would be an uncatalogued string.
* **Live regions:** `aria-live="polite"` on the Submit `Status` value, the Collection `Rows` value and the `Copied`
  swap. (`aria-live` is outside the linter's five-attribute scope.)
* **State attributes:** `aria-current="page"` (nav, Collection bank tabs), `aria-sort`, `aria-expanded` (native
  `<details>`), `aria-disabled="true"` (oversized-DAG `Graph` option, in-flight actions), `aria-checked`,
  `aria-invalid`, `aria-controls` (clamp toggle). All outside the linted attribute set.
* **Colour is never the sole cue:** status chips carry their value word; DOI/dict/private chips differ by border
  style as well as colour (G7); in-prose links are underlined.
* **Reduced motion** disables the page rule's animation and all transitions.
* **No-JS:** every generated page renders its record fully without scripts — claim statement, every DAG node decl,
  the author, the ⋯ menu, and on a record page the DOI and all verification rows (`no_javascript_required`, SPEC §13). Disclosure, clamping and
  the login link all work without JS; only `Expand all`/`Collapse all`, the DAG `Graph` layout, search, paging and
  the IDE require it.

---

## 10. Print (G3)

```css
@media print {
  .mth-nav, .mth-toolbar, .mth-dag-minimap, .mth-dag-viewport,
  .mth-btn, .mth-lean-toggle, #owner-tools, .mth-chip-facet { display: none; }
  :root { --color-bg:#fff; --color-surface:#fff; --color-surface-2:#fff; --color-code-bg:#fff;
          --color-text:#000; --color-text-muted:#000;
          --color-border:#000; --color-border-strong:#000; --color-link:#000; }
  .mth-dag-list { display: block; }                 /* List is the print form of the DAG */
  .mth-card, .mth-panel, .mth-lean { break-inside: avoid; border-color:#000; }
  .mth-cite { break-before: page; display: block; }  /* the citation prints last */
  .mth-cite__bibtex { display: block; }
  a[href]::after { content: ""; }                    /* the DOI is already rendered; no URL expansion */
  @page { margin: 18mm; }
}
```

A landing page printed on paper is a datasheet: the record, the DAG as an ordered list, the seven verification rows,
attribution, the DOI and the citation.

---

## 11. Responsive matrix

| Surface | `<640` | `640–1023` | `≥1024` | `≥1760` |
|---|---|---|---|---|
| Nav | 4 links, horizontally scrollable, 16px gutter | inline | inline | inline |
| Posts | 1 col, card padding 12px, claim clamp 12 | 1 col | 1 col, `max-w-stream` | `max-w-stream` |
| Post DAG | `Graph` default, scrolled in its viewport | `Graph` default | `Graph` default wherever offered; `List` is the no-JS form | same |
| Verification `<dl>` (record pages only) | 1 col | 2 col | 2 col | 2 col |
| Collection | table scrolls-x with sticky `DOI`; filters stack 1-col | filters 2-col | filters inline row | `max-w-shell`, `Statement` widens |
| Profile DOIs | scrolls-x (or `--stacked`) | scrolls-x | full | full |
| Submit | editor 45vh over infoview 30vh, stacked | stacked | split 60/40 | split 62/38, `max-w-shell` |
| Landing | 1 col; `#authored` rail 2px | 1 col | `max-w-stream` | `max-w-stream` |
| About / Login / 404 / 503 | `max-w-doc` | `max-w-doc` | `max-w-doc` | `max-w-doc` |

Statements keep `white-space: pre` and horizontal scroll at every width; they are never reflowed to fit a phone.

---

## 12. Page compositions

**Reading key.** `«Label»` = a frozen catalogue entry. `{field}` = a data value rendered inside
`[data-value="true"][data-field="field"]`. `‹reason›` = `renderReason(code, params)` inside `<p data-role="error">`.
Structural notes are documentation, not page content. Every composition contains zero invented copy.

Shared chrome on **every** page, generated and SPA alike, byte-identical, no conditional string:

```
<nav class="mth-nav">
  «Mathesis»                                → /posts       (wordmark + 16px decorative mark)
  «Posts» «Collection» «About»              → / /collection/claims /about
                                             Posts is the landing page.
  «Profile»                                 → /u/{owner.login}/   (at the right, apart from the row)
                                             Until sign-in exists, «Profile» opens the profile the record
                                             is published under (the owner); with sign-in it opens the
                                             signed-in user's own. «Write» (→ /ide/) is not in the nav: it
                                             is a button on that profile, and the IDE counts as Profile.
</nav>                                        aria-current="page" on the active item
<main class="mth-main" tabindex="-1"> … </main>
```

No footer. No `Sign in` in the nav. No session-dependent bytes anywhere in the nav.

### 12.1 POSTS — `/posts`

```
<main class="mth-stream">                                    max-w-stream, py-6, gap-6

  TOOLBAR  .mth-toolbar   h-control-lg, flex items-end gap-3, border-b border-border pb-3
    ├ .mth-field  «Profile»  <select class="mth-select mth-input--w-lg">
    │                          option[0] «All», then {profile.citation_name} per option
    │                          (source: generated profiles.json; state round-trips through ?profile=)
    └ «Clear»     .mth-btn--quiet

  STREAM  <ol> gap-6, roving tabindex, j/k move focus, Enter → /a/{argument.accession}
    └ POST CARD  .mth-card  ×20, newest first — the five regions below, in order

  «More»  .mth-btn--default .mth-btn--block   h-control-lg mt-2   (cursor paging; absent at end)
</main>
```

#### The post card — the author, the claim, the argument (shared by `/`, `/u/{login}` and `/a/{MTH.R-…}`)

A post opens with its author, as a social feed does:

```
AUTHOR  <header class="mth-post__author">   bottom hairline
  <a class="mth-author" href="/u/{login}/">
    <img class="mth-avatar mth-avatar--sm">  48px; alt is the value profile.citation_name;
                                             src is the record's own copy, /avatars/{login}.{ext};
                                             absent avatar → no <img>
    {profile.citation_name}  600 weight      {profile.login}  muted, "@" by CSS
  </a>
  ml-auto: {profile.kind} .mth-status--neutral · {argument.created_at} tabular-nums, muted
  ⋯  <details class="mth-more">              the post's one way to its records; opens without JS,
       <summary aria-label="«DOIs»">          the client closes it on an outside click or Escape
       .mth-more__menu  {Claim} {claim.accession} → /a/{claim.accession}
                        {Argument} {argument.accession} → /a/{argument.accession}
                                             (the two kind words are accession.kind values)
  «Cites» .mth-person per cited person:      full-width row, only when the argument cites premises
          .mth-glyph + {argument.cites} → https://github.com/{people.github}
                                             written by other authors
</header>
```

The post closes on `.mth-post__footer`: one link, «Discuss» ↗ → `{forum_base}/p/{argument.accession}/`, the post's
page on the forum (a separate site, `noumenal-ai/mathesis-forum`). Mathesis takes only verified arguments; talk about
them happens there, never on the record.

Verification is the baseline every post meets, so a post never states it: no verification block, no DOI,
no accession chip. The ⋯ menu leads to the claim's and the argument's pages (§12.4), where the DOI, the
citation and a small verification section live. Two regions follow the header:

```
REGION 1  .mth-card__region — Claim
  words .mth-docstring--thesis  {claim.doc}      the author's docstring, text-lg; a second paragraph
                                                 (lineage, departures) text-sm muted; absent → nothing
  meta  .mth-metric  «Decl» {claim.decl_name}    .mth-value--mono, CSS-truncated (G10)
        «Copy»  .mth-copy   → {clipboard.state} = Copied for 2s
  body  stream:  .mth-lean-clamp--12 wrapper + <pre .mth-lean--claim data-field="claim.pretty">
                 + sibling .mth-lean-toggle  («Expand»/«Collapse»)        [§7.11]
        landing: no wrapper, no toggle, .mth-lean--lg

REGION 2  .mth-card__region — Argument DAG
  head  flex flex-wrap items-center gap-x-5 gap-y-2        no counts of nodes, edges or depth
      <fieldset class="mth-segmented"><legend class="mth-label">«Layout»</legend>
        «Graph»   aria-checked; aria-disabled="true" when nodes>400 || edges>4000 || vw<1024
        «List»
      </fieldset>
      «Expand all» · «Collapse all»   .mth-btn--quiet
  body  LIST (server-rendered, the no-JS form, default in the stream)
        <ol class="mth-dag-list">  topological order
          <li class="mth-panel" data-citable="{true|false}" id="n-{accession}-{order}">
            row1  {argument_node.decl_name} .mth-value--mono
                  «Declaration kind» {argument_node.kind} .mth-status--neutral
                  <a class="mth-doi"> only when data-citable="true"
            row2  <pre class="mth-lean mth-lean--node" data-role="lean-statement"
                       data-value="true" data-field="argument_node.pretty">   (clamp-3 in the stream)
            row3  .mth-chip-dict per dictionary leaf →
                     href = {pin.blueprint_url}#{dictionary_constant.blueprint_label}
                  .mth-chip-private for a non-citable helper
            row4  <details class="mth-disclosure"><summary>«Uses»</summary> anchor list</details>
                  <details class="mth-disclosure"><summary>«Used by»</summary> anchor list</details>
          </li>
        </ol>
        GRAPH (≥1024, eligible only)
        <div class="mth-dag-viewport">
          <div class="mth-dag-ruler">   depth ticks, one per 260px            (G4)
          <div class="mth-dag-gutter">  order ticks, one per 112px            (G4)
          <svg class="mth-dag-svg"> edges then nodes, geometry by attributes </svg>
          <div class="mth-dag-minimap" aria-hidden="true">   when nodes > 40
        </div>
        <aside class="mth-dag-inspector mth-panel">  the focused node's List fields, nothing new

```

The verification block and the DOI with its citation moved to the record pages (§12.4); the attribution
region was replaced by the author header.

**States.** Loading (SPA paging) → the 2px page rule under the nav; no skeleton text (F3).
Empty stream → empty `<ol>`; no count, no empty-state sentence, no illustration.
Degraded → `.mth-degraded` inside the region that made the request, and nowhere else.

### 12.2 PROFILE — `/u/{login}` (generated; public until sign-in exists, then login-gated)

```
<main class="mth-shell">    py-6, flex flex-col gap-6

  IDENTITY  .mth-panel  grid grid-cols-[auto_1fr] gap-4 items-start
    ├ <img class="mth-avatar" alt=…>    omitted entirely when the profile has no cached avatar;
    │                                    the grid collapses to one column, no reserved gap
    └ col
        {profile.login}    text-xl font-semibold text-ink-900
        .mth-metric-row
          «Profile kind» {profile.kind}  .mth-status--neutral    ← CURRENT kind only, never a history
          «Joined»       {profile.created_at}
                                  no tallies of claims, arguments or posts

  OWNER TOOLS  <section id="owner-tools" hidden>   SPA-rendered, own profile only, exactly 3 controls
    .mth-panel bg-surface-2  flex flex-wrap items-end gap-4
      ├ «Submit»  .mth-btn--primary → /submit
      ├ <fieldset class="mth-radio-row">     present only while {profile.kind} is null
      │    <legend class="mth-label">«Profile kind»</legend>
      │    ( ) «person»  ( ) «agent»         ← the two option texts are catalogue VALUES
      │    «Save» .mth-btn--default
      └ «Sign out» .mth-btn--quiet  ml-auto  → POST /api/v1/logout

  DOIS  <section>
    .mth-section-head  <h2 id="dois-h">«DOIs»</h2>
    <div class="mth-table-scroll"><table class="mth-table" aria-labelledby="dois-h">   (G8)
      th: «DOI» --col-doi sticky · «Decl» 1fr/min --col-decl · «Accession kind» --col-kind
          «Date» --col-date
      default «Date» desc (newest first), ties by accession
      td: .mth-doi | .mth-td-mono truncated | «Claim»/«Argument» .mth-status--neutral
          | tabular date
      no verification column: a profile is a social surface
      row → /a/{accession}; roving tabindex, j/k/Enter
    </table></div>

  POSTS  <ol> of .mth-card, identical to §12.1's stream (this profile's posts only)
</main>
```

**States.** Unauthenticated → `302 /login?redirect_to=%2Fu%2F{login}` (nothing renders).
Gateway unreachable → the generated `503.html` with HTTP 503.
`kind` null → the `Profile kind` fieldset is present and `Submit` still renders; the `409 profile_kind_unset` surfaces
on `/submit` as `‹PROFILE_KIND_UNSET›`.
`/profile` renders nothing (pure 302). `/p/{profile_id}` is a 302 to the current `/u/{login}`.

### 12.3 SUBMIT — `/submit` (gated; generated shell + SPA mount). Four regions, in DOM order.

```
<main class="mth-shell">  py-5, flex flex-col gap-4

REGION 1  Editor
  <section class="mth-editor">
    <header class="mth-editor__head">
      «Status» <span data-value="true" data-field="ide.status" aria-live="polite">
                 {Elaborating|Ready}</span>   → .mth-status--warn | --ok
    </header>
    ≥1024: grid-cols-[62%_38%] · <1024: stacked (editor 45vh, infoview 30vh)
      ├ .mth-editor__mount      Monaco; lines 1, 2 and the last are .mth-mono-protected (read-only)
      │                         diagnostics .mth-diag-error · advisory lint .mth-diag-advisory
      └ .mth-infoview           the Lean infoview over the allowlisted widget RPC channel (SPEC §7)
  </section>

REGION 2  Designation                     .mth-toolbar  flex flex-wrap items-end gap-3
  ├ .mth-field «Claim»  <select class="mth-select mth-input--mono mth-input--w-xl">
  │                       built from textDocument/documentSymbol, theorems only;
  │                       [disabled] + locked to {claims.required_decl_name} when «Proves» resolves
  ├ .mth-field «Proves» <input class="mth-input mth-input--mono mth-input--w-md">   (MTH.C accession)
  └ «Submit» .mth-btn--primary .mth-btn--lg  ml-auto    ← never disabled by the advisory lint

REGION 3  Status                          appears after 201
  .mth-panel  flex flex-col gap-2.5
    row  «Status» <span data-value="true" data-field="verification.state" aria-live="polite">{state}</span>
           .mth-status: received|queued → --neutral
                        building|exporting|adjudicating|assembling → --warn
                        admitted → --ok · rejected|failed → --err
         .mth-state-rail  nine ticks, aria-hidden, advancing with the SSE stream            (G9)
    row  <fieldset class="mth-segmented"><legend class="mth-label">«Logs»</legend>
           «Build» «Export» «Adjudicate» </fieldset>
    <pre class="mth-pre-log" data-role="log">{logs.step}</pre>     verbatim compiler output

REGION 4  Verdict                         terminal SSE event — exactly two shapes
  A. admitted   .mth-panel border-ok-bd
       «Claim»    <a class="mth-doi mth-doi--lg">{claim.accession}</a>
       «Argument» <a class="mth-doi mth-doi--lg">{argument.accession}</a>
       «Open» .mth-btn--primary → {post_url}
  B. rejected | failed   .mth-panel border-err-bd
       «Reason» <span data-value="true" data-field="verification.reason_code">{reason_code}</span>
                  .mth-status--err .font-mono
       ‹renderReason(code, params)›                       <p data-role="error">
       <details class="mth-disclosure"><summary>«Report»</summary>
         <pre class="mth-pre-report" data-role="report">{report_json}</pre></details>
       For build/export stages the compiler message is region 3's <pre>; nothing paraphrases it.
</main>
```

All nine `Status` states, both verdict shapes and every `renderReason` template are DOM-snapshotted for
`prose-lint --dom` (SPEC §8.7, §13).

### 12.4 LANDING PAGE — `/a/{accession}`

```
<main class="mth-stream">
  STICKY MINI-HEAD  h-control-lg sticky top-nav z-10 bg-bg border-b border-border
                    flex items-center gap-2       (controls only; appears on scroll)
     <span class="mth-doi">{accession}</span>  ·  ml-auto «Cite» «Copy BibTeX»

  <article class="landing" data-accession="{accession}" data-owner-profile-id="{…}">

    <section data-region="verified" id="record" class="mth-landing__record">   generated · immutable
      • argument accession → the post card (author with ⋯, claim unclamped, DAG with Graph default)
      • claim accession → a card:
          AUTHOR    the author header, no ⋯ · the date is {claim.created_at}
          REGION 1  «Decl» {claim.decl_name} · .mth-lean--claim .mth-lean--lg · «Copy»
          REGION 2  <h2>«Arguments»</h2> + .mth-table
                    th: «DOI» «Author» «Date» — the author as .mth-person (24px photo, → /u/{login}/)
                    OMITTED ENTIRELY when there are no arguments — which is how an open seed claim renders
      then, below the card and outside it, <div class="mth-record">:
          «DOI» {accession} · «Cite» «Copy» «Copy BibTeX»    (baked)
          <section class="mth-verification">   small: 2xs uppercase title, 2xs rows, muted, top hairline
            argument: the seven pairs — «Replay» «Axioms» «Statement identity» «Substrate»
                      «Dictionary pin» «Frozen export» «Verified»
            claim:    «Library» {claim.module} · «Statement digest» {statement_digest_12}
                      · «First verified» {claim.created_at}
          </section>
    </section>

    <section data-region="author" id="authored"
             data-note-endpoint="/api/v1/notes/{accession}"
             class="mth-panel mth-panel--authored mt-8">   (bg-surface-2, 3px ink-300 left rail)
      ships EMPTY; hydrated at runtime from GET /api/v1/notes/{acc}
        <h2>«Note»</h2>
        <div class="record-prose">{note.body_html}</div>
        .mth-metric  «Updated» {note.updated_at}
        owner only:  «Edit» → .mth-textarea + «Save» .mth-btn--primary + «Cancel» .mth-btn--quiet
    </section>
  </article>
</main>
```

**The separation of the two regions is load-bearing.** `#record` is white-ground, hairline-bordered, accent-marked;
`#authored` is `surface-2` with a 3px `ink-300` left rail and a 32px gap. A `MutationObserver` on
`[data-region="verified"]` must record zero mutations through the full interaction pass (SPEC §8.6), so no editor,
citation mount or hydration may touch it.

**`#authored` states.** (1) revision 0 / `204` → heading, `«Updated»` + timestamp, owner controls, empty body.
(2) viewing → sanitized body. (3) editing → body replaced by `.mth-textarea`, `«Save»` + `«Cancel»`, `«Edit»` hidden.
(4) saving → both buttons `aria-disabled`. (5) conflict (`412`) → `.mth-error` with the reason above the textarea,
`«Save»` re-enabled. (6) not owner → body and `«Updated»` only. (7) API unavailable → **no note content at all**:
the region holds exactly `.mth-degraded` (`‹REGISTRY_UNAVAILABLE›` + `«Reload»`) and nothing else.

### 12.5 COLLECTION — `/collection/claims` · `/collection/arguments`

Two documents, not a filter (SPEC §8.3). Same skeleton, different `<h1>`, columns and control set.

```
<main class="mth-shell">  py-6, flex flex-col gap-4

  HEAD  flex items-baseline gap-4
    <h1 id="bank-h">«Claims»</h1>            (or «Arguments» on the other document)
    TABS  .mth-segmented rendered as two <a> links — the bank is a path, not a radio
      «Claims» → /collection/claims    «Arguments» → /collection/arguments
      aria-current="page" on the active one

  FILTER BAR  .mth-panel  grid gap-3
              <640: grid-cols-1 · 640–1023: grid-cols-2 · ≥1024: flex flex-wrap items-end
    .mth-field «Search»          <input class="mth-input mth-input--grow">   ("/" focuses)
                                 (.mth-input--grow: flex-1; min-inline-size: var(--field-w-search-min))
    .mth-field «DOI»             <input class="mth-input mth-input--mono mth-input--w-md">
               «Go»              .mth-btn--primary h-control  → /a/{acc}
    .mth-field «Library»         <select class="mth-select mth-input--w-md">  option[0] «All»
    .mth-field «Author»          <select class="mth-select mth-input--w-md">  option[0] «All»
    .mth-field «Axiom manifest»  <select class="mth-select mth-input--w-sm">  «All» · «free» · names
    .mth-field «From»            <input type="date" class="mth-input mth-input--w-sm">
    .mth-field «To»              <input type="date" class="mth-input mth-input--w-sm">
    .mth-field «Sort»            <select class="mth-select mth-input--w-sm">  «Newest» · «Oldest»
    «Clear» .mth-btn--quiet   «Reset» .mth-btn--quiet
    No placeholder attribute on any input; every control is visibly labelled.

  FACETS  flex flex-wrap gap-2   .mth-chip-facet per active filter
          {facet.value} + 24×24 remove button, aria-label=«Clear»

  TABLE   .mth-table-scroll > table.mth-table[.mth-table--tall] aria-labelledby="bank-h"     (G8)
    CLAIMS columns
      «DOI» --col-doi sticky        → .mth-doi
      «Statement» 1fr/min --col-statement-min
                                    → .mth-lean-clamp--3 + <pre .mth-lean data-field="claim.pretty">
                                      + sibling .mth-lean-toggle («Expand»/«Collapse»)
      «Decl» --col-decl             → .mth-td-mono, CSS-truncated
      «Library» --col-lib           → .mth-value
      «Axioms» --col-axioms         → names | «free» | «—»
      «First verified» --col-date   → tabular date
    ARGUMENTS columns
      «DOI» sticky · «Claim» (.mth-doi) · «Decl» · «Author» · «Axioms» · «Verified»
    Sticky thead below the nav; hairline rules; no zebra; row focus = accent left rail + accent-50.
    Empty result → empty <tbody>. No count, no empty-state sentence, no illustration.

  «More»  .mth-btn--default .mth-btn--block    (value-based cursor paging)
</main>
```

**States.** `422 invalid_filter` → `<p data-role="error">` with the API `message` directly above the table, `<tbody>`
cleared, and the offending `.mth-field` marked `aria-invalid="true"`.
A registry outage does **not** affect this page (search is served from Tantivy via `mathesisd`, never through the
gateway — SPEC §8, §11.4). Loading → the 2px page rule; rows are absent, never faked.

### 12.6 ABOUT — `/about` (an empty shell, and it ships empty)

The generated `<main>` has **exactly three element children**, in order, and nothing else, ever (SPEC §8.4):

```html
<main class="mth-doc">          max-w-doc, py-10, flex flex-col gap-6

  <h1>About</h1>

  <div id="dictionary-slot" class="mth-panel flex items-center justify-between gap-4">
    <a id="dictionary-link" class="mth-btn mth-btn--default mth-btn--lg"
       href="{pin.blueprint_url}">Dictionary
       <svg external 12px aria-hidden="true" focusable="false"></svg></a>
    <span data-value="true" data-field="dictionary.label"
          class="mth-value--mono text-ink-600">{dictionary.label}</span>
  </div>

  <div id="about-body" class="record-prose"><!-- verbatim bytes of about/body.html --></div>
</main>
```

`about/body.html` ships zero-length, so `#about-body` has zero child nodes in the shipped build and the page is mostly
white space. **That is the correct artifact.** `.record-prose` is pre-styled so the owner's future commit renders
correctly with no CSS change. The pin label is a `<span>` inside `#dictionary-slot` — a sibling of the link, not a
fourth child of `<main>` — so both halves of `about_shell` hold at once.

### 12.7 The three remaining generated routes

```
/login      <main class="mth-doc py-16 flex flex-col items-center gap-5">
              centred card .mth-login-card (width: var(--w-login-card)), border border-border,
              rounded-lg, bg-surface, p-8
              <h1>«Sign in»</h1>
              <a id="sign-in" class="mth-btn mth-btn--primary mth-btn--lg"
                 href="/auth/github/start?redirect_to=%REDIRECT_TO%">
                <svg GitHub mark 16px aria-hidden="true"> «Sign in»</a>
            </main>
            Exactly two things in <main>. No form, no JS dependency, no third element.

/404.html   <main class="mth-doc py-16"><h1>«Not found»</h1></main>
            The only visible strings are «Not found» and the nav.

/503.html   <main class="mth-doc py-16">
              <div class="mth-degraded">
                <p data-role="error">‹REGISTRY_UNAVAILABLE›</p>   ← rendered at GENERATION time
                <a class="mth-btn mth-btn--default" href="{current path}">«Reload»</a>
              </div>
            </main>
            Served with HTTP 503 for /u/{login}, /profile and /submit. Needs no client.
```

---

## 13. Keyboard map (implemented, deliberately undocumented in-product)

| Keys | Scope | Action |
|---|---|---|
| `g p` `g c` `g u` `g a` | global | Posts · Collection · Profile · About |
| `/` | Collection | focus `«Search»`; `Esc` blurs |
| `j` `k` | stream, tables, DOIs table | move roving focus |
| `Enter` | focused row / card / DAG node | open its landing page / inspector |
| `e` | focused `<details>` | toggle |
| `E` `C` | post card | `«Expand all»` / `«Collapse all»` |
| `←` `→` `↑` `↓` | DAG graph viewport | move by depth / order, scroll into view |
| `c` | post card | activate `«Copy»` (claim statement) |
| `Esc` | anywhere | close the focused disclosure, return focus to its container |

There is no shortcuts overlay, no help affordance, no tooltip and no `?` key: every string such a surface would need
is outside the frozen catalogue. The keyboard layer is a capability, not a feature with copy.

---

## 14. Cross-page invariants the implementation must preserve

1. Nav bytes are identical on every generated page, including `about/index.html`, `login/index.html`, `404.html` and
   `503.html`.
2. `Sign in` appears only on `/login`; `Sign out` only inside `#owner-tools`.
3. Every visible string is a catalogue entry, a `[data-value][data-field]` value, or a `[data-role="error"]` message.
   No fourth kind exists.
4. `placeholder` appears on no input anywhere; every control carries a visible `<label>` or `<legend>`.
5. The only `<pre>` roles are `lean-statement`, `log`, `report`; every other `pre`/`code` is linted normally.
6. Exactly three elements carry a value in an attribute: the avatar `alt`, `[data-citation-text]`,
   `[data-citation-bibtex]`.
7. `[data-region="verified"]` contains no login, no avatar, no `Profile kind`, no mutable timestamp — only
   `citation_name` and `/p/{profile_id}`.
8. The dictionary is reachable from exactly two places: the About link slot and the DAG's `.mth-chip-dict` leaves.
9. No modal, popover, tooltip, toast, empty-state illustration, skeleton text, hero, footer or theme toggle exists on
   any surface.
10. No inline `style` attribute and no `[...]` arbitrary Tailwind value is emitted by either renderer (§1 rules 2, 4).
11. The DAG's geometry constants exist once, in `--dag-*`; the generator and the stylesheet both read them.
12. Ellipsis, where it appears, is CSS `text-overflow` or the `.mth-lean-clamp`; no code inserts `…` into a value.

---

## 15. Decisions that carry a price, recorded rather than hidden

1. **No skip link.** Its visible text has no catalogue entry, and adding one is a reviewer-visible catalogue diff
   (SPEC §8). Mitigation as shipped: a 4-item nav, one wordmark link, `<main tabindex="-1">` and landmark navigation,
   so the pre-`main` tab cost is five. If the owner wants one, the price is exactly one catalogue entry plus its
   placement — no other part of this design changes.
2. **No theme toggle.** Same reason; dark theme follows `prefers-color-scheme` only.
3. **CSP and Monaco.** The platform ships no inline styles, so `style-src 'self'` holds everywhere — except that
   Monaco injects `<style>` elements at runtime for themes and decorations. `/submit` is therefore served with
   `style-src 'self' 'unsafe-inline'` **on that route only**; every other route keeps `style-src 'self'`. This is a
   real relaxation on one gated, authenticated page, and it is named here rather than discovered at deploy time.
   The alternative (a per-response nonce threaded into Monaco's style injection) is not assumed to work until it is
   demonstrated against the pinned `monaco-editor` version.
4. **`:has()` for the clamp toggle** (§7.11). Baseline in current Chrome, Safari and Firefox; the
   `@supports not selector(:has(*))` fallback renders statements unclamped, which shows more content, never less.
5. **Monochrome Lean statements.** Deliberate (§0 rule 4). If highlighting is ever wanted, it must be produced by one
   tokenizer shared by both renderers, or `renderer_parity` is the test that will fail.
