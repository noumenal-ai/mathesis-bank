#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# Mathesis — parse a form-raised deposit's metadata header.
#
# A deposit is a SINGLE file `deposits/<slug>/submission.lean` whose FIRST
# block is a Lean doc-comment `/-! ... -/` carrying an @-header (see
# site/deposit.js `buildFile`). Because the header is a valid Lean doc
# comment, the file BUILDS directly at the pinned toolchain — the gate builds
# the very same file the human sees.
#
# This script parses that header, plus the section markers of a two-part
# deposit (below), and prints one JSON object:
#   {kind, title, module, decls:[...], pin, mathlib|null, discharges|null,
#    imports:[...], gloss, mode, parts}
#
# ── TWO-PART DEPOSITS: a statement and its proof, in one file ─────────────────
# A deposit may split its body into a STATEMENT section and a PROOF section so
# that the claim a reader sees is frozen separately from the argument for it.
# Each section opens with a marker that is itself a Lean module doc comment,
# alone on its line:
#
#     import Mathlib.Logic.Basic            -- shared by both parts, hoisted
#
#     /-!
#     # Mathesis deposit
#     @kind: result
#     @title: ...
#     @decls: double_eq
#     @pin: leanprover/lean4:v4.31.0
#     -/
#
#     /-! @statement -/
#     def double (n : Nat) : Nat := n + n
#     theorem double_eq (n : Nat) : double n = 2 * n := sorry
#
#     /-! @proof -/
#     def double (n : Nat) : Nat := n + n
#     theorem double_eq (n : Nat) : double n = 2 * n := by
#       unfold double; omega
#
# WHY MARKERS THAT ARE DOC COMMENTS: each part, cut out of the file, is still
# ordinary Lean — the marker is a comment to the compiler — and the cut needs
# nothing more than a line comparison, so there is no Lean parsing in the split
# and nothing to disagree about between this script, the IDE, and the gate.
#
# WHY THE PROOF RE-STATES THE DEFINITIONS: the two parts are built as two
# separate modules, and the proof cannot import the statement, because the
# statement already declares `double_eq` (as `sorry`) and Lean will not let the
# proof declare it again. So the proof part is a complete file of its own. That
# costs a copy — which the IDE makes for the depositor — and buys the soundness
# argument: the gate never trusts that the copy is faithful. It exports the
# statement as a reference R and has the adjudicator check, constant by
# constant, that every target's type and every definition that type reaches are
# IDENTICAL in R and in the proof's export. A proof part that edits a definition
# or a statement is a different environment, and is rejected as a smuggle.
#
# The parts are emitted by `--part statement|proof` (see `emit_part`): the
# whole file with the OTHER section's lines blanked. Blanking rather than
# cutting keeps every line where the depositor wrote it, so a build error in
# either part points at the line in submission.lean they can actually see; and
# because both parts are the same file up to the first marker, they share the
# hoisted imports and the header BY CONSTRUCTION — "the two parts import
# different things" is not a state this format can express.
#
# Modes (the `mode` key):
#   single    — no markers. Everything is exactly as it was before sections
#               existed; `parts` is null.
#   two-part  — `@statement` then `@proof`: the gate builds and checks the
#               statement, exports it as R, builds the proof, and adjudicates
#               the proof against R.
#   pose      — `@statement` alone: a claim posed without a proof. The gate
#               builds, checks and exports the statement and stops there.
# `parts` gives each section's 1-based inclusive line range, marker line first:
#   {"statement": {"start": s, "end": e}, "proof": {"start": s, "end": e}|null}
#
# The statement section has a FORM, checked here at the source level: every
# `theorem`/`lemma` in it is proved by exactly `:= sorry` or `:= by sorry`, and
# every `sorry` in it is such a proof and nothing else — never a definition, an
# instance, an example, or part of a larger term. This is the cheap first line;
# the gate checks the same property again on the statement's export, where a
# notation or a tactic cannot disguise a sorry or a proof (ci/statement_form.py;
# ci/fixtures/two-part/statement-{hidden,fake}-sorry are the two directions).
#
# Why `@discharges` and `@statement` never go together, and why a posed claim is
# `@kind: claim`: see the checks themselves in `main`.
#
# It FAILS CLOSED (nonzero exit, error on stderr) when:
#   * the file has no leading /-! ... -/ block (leading `import` lines may precede it),
#   * an `import` appears BELOW the header, where Lean cannot accept it,
#   * an import names something that is not a dotted Lean module name,
#   * a required field is missing (@kind, @title, @decls, @pin),
#   * @kind is not one of result|definition|claim,
#   * @pin is not exactly leanprover/lean4:v4.31.0,
#   * @decls is empty after splitting, or any decl is not a plausible name,
#   * @discharges is present but is not a claims handle MTH.C-YYYY-NNNN,
#   * a section marker is malformed, duplicated, out of order, or `@proof`
#     appears without `@statement`,
#   * anything but blank lines sits between the header and `@statement`,
#   * a section declared by its marker is empty,
#   * `@discharges` and `@statement` are both present,
#   * a posed claim (`@statement` without `@proof`) is not `@kind: claim`,
#   * the statement section has a `sorry` that is not a whole theorem proof.
# A malformed deposit therefore never yields a parse the gate could act on.
# ---------------------------------------------------------------------------
import json
import re
import sys

PIN_REQUIRED = "leanprover/lean4:v4.31.0"
VALID_KINDS = ("result", "definition", "claim")

# The @-fields the header may carry. Everything the gate keys on is here; an
# unknown @-line is ignored (forward-compatible) rather than fatal.
SCALAR_FIELDS = ("kind", "title", "module", "decls", "pin", "discharges", "mathlib")

# A @decls entry is passed to the kernel gate as an argv item AND echoed into
# the PR-comment markdown. Lean declaration names use ASCII letters/digits and
# `_ . ' ! ?`, plus a wide range of non-ASCII (greek, subscripts, unicode
# letters). We ALLOW exactly those and reject everything else — in particular
# whitespace/controls, path separators, and shell/markdown metacharacters —
# so a hostile decl cannot break out of the gate's argv or the report markdown.
DECL_ASCII_OK = set(
    "0123456789"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "abcdefghijklmnopqrstuvwxyz"
    "_.'!?"
)


def decl_char_ok(c):
    # Non-ASCII (>= 0x80) is allowed: Lean identifiers may contain unicode
    # letters/subscripts. ASCII must be in the identifier allow-set.
    return ord(c) >= 0x80 or c in DECL_ASCII_OK


# An `import` line, and the module-name grammar it may name.
#
# WHY IMPORTS LIVE ABOVE THE HEADER
# ---------------------------------
# `/-! ... -/` is a Lean *module docstring*, which is declaration-level syntax, and Lean requires
# every `import` to precede all declarations. So a file shaped "header first, then source" can
# never import anything:
#
#     /-! @kind: result ... -/
#     import Mathlib.Logic.Basic     -> error: invalid 'import' command, it must be used in
#                                       the beginning of the file
#
# That made the entire banked corpus's vocabulary unreachable to a form-raised deposit: Mathlib
# is what the 512 accessions are built on, and no deposit could import it. The deposit form and
# `backend/deposits.py:build_submission` therefore HOIST a leading run of `import` lines above
# the header, and this parser accepts that shape. A deposit with no imports is assembled exactly
# as before, byte for byte.
IMPORT_RE = re.compile(r"^\s*import\s+(\S+)\s*$")

# Conservative: dotted ASCII identifiers, which covers Init/Std/Lean and every `Mathlib.*`.
# Lean permits more (guillemet-quoted and unicode module names), and this deliberately does not:
# the module name is interpolated verbatim into the file the gate builds, so a name that cannot
# be a module is a malformed deposit rather than something to pass through and find out later.
MODULE_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_']*(?:\.[A-Za-z_][A-Za-z0-9_']*)*\Z")


def split_leading_imports(text):
    """(module names, the rest of the file).

    Only a LEADING run of `import` lines counts, blank lines allowed between them. The first line
    that is neither blank nor an import ends the run — normally the `/-!` that opens the header.
    """
    lines = text.splitlines(keepends=True)
    imports = []
    i = 0
    while i < len(lines):
        if not lines[i].strip():
            i += 1
            continue
        m = IMPORT_RE.match(lines[i])
        if m is None:
            break
        imports.append(m.group(1))
        i += 1
    if not imports:
        # Return the text untouched when there is nothing to hoist, so the no-import path is
        # provably identical to the pre-existing one.
        return [], text
    return imports, "".join(lines[i:])


def die(msg):
    sys.stderr.write("parse_deposit: " + msg + "\n")
    sys.exit(1)


# ── section markers ─────────────────────────────────────────────────────────────
# A marker is the whole of its line, surrounding whitespace aside. Anything that merely LOOKS
# like one — `/-! @Statement -/`, `/-! @proof`, a marker with text after it — is refused rather
# than read as body: a near-miss that silently became body would turn an intended two-part
# deposit into a single-part one, which builds both sections as ONE file and fails for a reason
# (a duplicate declaration) that says nothing about the marker the depositor mistyped.
MARKER_RE = re.compile(r"^\s*/-!\s*@(statement|proof)\s*-/\s*$")
NEAR_MARKER_RE = re.compile(r"/-!?\s*@\s*(statement|proof)\b", re.IGNORECASE)


def find_sections(text, header_close):
    """Locate the section markers below the header. Returns (mode, parts), or dies.

    `header_close` is the index in `text` of the `-/` closing the header. Lines are split on
    "\\n" alone, because that is how Lean counts them and these line numbers are handed to the
    gate to cut the file with; `str.splitlines` also breaks on U+2028 and friends, which may
    legally sit inside a Lean string literal.
    """
    lines = text.split("\n")
    close_line = text.count("\n", 0, header_close)
    markers = []  # (name, 0-based line index)
    for idx in range(close_line + 1, len(lines)):
        ln = lines[idx]
        m = MARKER_RE.match(ln)
        if m:
            markers.append((m.group(1), idx))
        elif NEAR_MARKER_RE.search(ln):
            die("malformed section marker on line %d: %r\n"
                "  A marker is exactly `/-! @statement -/` or `/-! @proof -/`, alone on its line."
                % (idx + 1, ln.strip()[:80]))
    # The line the header closes on can hold a marker too only in a file nobody would write;
    # it is refused below as "content before @statement" if it carries anything at all.
    if not markers:
        return "single", None

    names = [n for n, _ in markers]
    for n in ("statement", "proof"):
        if names.count(n) > 1:
            die("duplicate `/-! @%s -/` marker (lines %s)"
                % (n, ", ".join(str(i + 1) for nm, i in markers if nm == n)))
    if names[0] != "statement":
        die("`/-! @proof -/` without a preceding `/-! @statement -/`\n"
            "  A proof is checked against the statement it proves, so the statement comes first.")

    stmt_line = markers[0][1]
    # Everything between the header and `@statement` would belong to neither part, or — worse —
    # to both, and a definition that is silently shared is exactly what statement-identity is
    # there to catch rather than to be spared. Refuse it: the header, then the sections.
    tail = text[header_close + 2:].split("\n", 1)[0]
    between = [tail] + lines[close_line + 1:stmt_line]
    if any(s.strip() for s in between):
        die("content between the header and `/-! @statement -/`\n"
            "  In a two-part deposit every declaration belongs to a section; put it after the "
            "marker.")

    proof_line = markers[1][1] if len(markers) > 1 else None
    stmt_end = (proof_line - 1) if proof_line is not None else len(lines) - 1
    if not any(s.strip() for s in lines[stmt_line + 1:stmt_end + 1]):
        die("the `@statement` section is empty")
    parts = {"statement": {"start": stmt_line + 1, "end": stmt_end + 1}, "proof": None}
    if proof_line is not None:
        if not any(s.strip() for s in lines[proof_line + 1:]):
            die("the `@proof` section is empty\n"
                "  To pose a claim without a proof, leave out the `/-! @proof -/` marker entirely.")
        parts["proof"] = {"start": proof_line + 1, "end": len(lines)}
    return ("two-part" if proof_line is not None else "pose"), parts


def emit_part(text, parts, which):
    """The file as the `which` part: every line of the OTHER section replaced by an empty line.

    Imports and header are the file's own, untouched, so both parts share them by construction;
    and every surviving line keeps its line number, so a build error in either part names a line
    of submission.lean the depositor can find.
    """
    lines = text.split("\n")
    other = parts["proof" if which == "statement" else "statement"]
    if other is not None:
        for i in range(other["start"] - 1, other["end"]):
            lines[i] = ""
    return "\n".join(lines)


# ── the statement's form, at the source level ──────────────────────────────────
# The rule: every `sorry` in the statement is the ENTIRE proof of a `theorem`/`lemma`. A sorry
# anywhere else is a hole in the claim itself — a definition that is `sorry` makes the statement
# about nothing in particular, and `sorryAx` would then be a premise the proof gets for free.
#
# This is deliberately the CHEAP check. It lexes rather than parses: comments and string
# literals are blanked (so a `sorry` in a docstring is not a sorry), the rest is split into
# tokens, and each sorry-like token must sit at the very end of a theorem's declaration as
# `:= sorry` or `:= by sorry`. It cannot see through a notation or macro that expands to sorry,
# and does not try: the authority is ci/statement_form.py, which reads the statement's EXPORT —
# what the kernel will actually hold — and checks the same property there. What this buys is a
# message, before any build, that names the line.
SORRY_TOKENS = ("sorry", "admit", "sorryAx")

# Tokens that begin a new command. A sorry is attributed to the nearest one before it, and a
# declaration's tail runs to the next one (or to a modifier of the next declaration). Over-
# splitting can only make a legitimate `:= sorry` look like something else and be refused;
# it cannot make an illegitimate sorry look legitimate, because acceptance needs a `theorem`
# or `lemma` keyword and the exact tail, with nothing sorry-like anywhere else in between.
COMMAND_TOKENS = frozenset("""
    theorem lemma def abbrev instance structure class inductive coinductive example axiom axioms
    opaque irreducible_def mutual namespace section end open export variable universe universes
    set_option attribute notation infix infixl infixr prefix postfix macro macro_rules syntax
    elab elab_rules declare_syntax_cat deriving initialize builtin_initialize alias omit include
    run_cmd run_elab run_meta #eval #check #print #reduce #exit #guard #synth #lint
""".split())
MODIFIER_TOKENS = frozenset("""
    @[ private protected noncomputable partial unsafe nonrec scoped local
""".split())

TOKEN_RE = re.compile(
    r"@\[|:=|#[A-Za-z_]+|«[^»]*»"
    r"|[A-Za-z_À-\U0010ffff][A-Za-z0-9_'!?.À-\U0010ffff]*"
    r"|\S")


def _ident_char(c):
    return c.isalnum() or c in "_'!?." or ord(c) >= 0xc0


def mask_comments_and_strings(src):
    """`src` with every comment and string/char literal overwritten by spaces, newlines kept.

    Lean block comments NEST (`/- /- -/ -/` is one comment), and doc comments are block comments,
    so a depth counter is needed. Returns None on an unterminated comment or string: that part
    cannot build either, and the caller refuses it with a message rather than guessing.
    """
    out = list(src)
    n = len(src)

    def blank(a, b):
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "

    i = 0
    while i < n:
        if src.startswith("--", i):
            j = src.find("\n", i)
            j = n if j == -1 else j
            blank(i, j)
            i = j
        elif src.startswith("/-", i):
            depth, j = 1, i + 2
            while j < n and depth:
                if src.startswith("/-", j):
                    depth, j = depth + 1, j + 2
                elif src.startswith("-/", j):
                    depth, j = depth - 1, j + 2
                else:
                    j += 1
            if depth:
                return None
            blank(i, j)
            i = j
        elif src[i] == '"':
            j = i + 1
            while j < n and src[j] != '"':
                j += 2 if src[j] == "\\" else 1
            if j >= n:
                return None
            blank(i, j + 1)
            i = j + 1
        elif src[i] == "'" and (i == 0 or not _ident_char(src[i - 1])):
            # A char literal, `'a'` or `'\n'`. A quote after an identifier character is a prime
            # (`h'`), which is part of the name and not a literal.
            m = re.compile(r"'(?:\\[^']*|[^'\\\n])'").match(src, i)
            if m:
                blank(i, m.end())
                i = m.end()
            else:
                i += 1
        else:
            i += 1
    return "".join(out)


def check_statement_form(section_text, first_line):
    """Die unless every sorry-like token in the statement section is a whole theorem proof.

    `first_line` is the file line number of the section's first line, for the message.
    """
    masked = mask_comments_and_strings(section_text)
    if masked is None:
        die("the `@statement` section has an unterminated comment or string literal")
    toks = [(m.group(0), m.start()) for m in TOKEN_RE.finditer(masked)]

    def line_of(pos):
        return first_line + masked.count("\n", 0, pos)

    def decl_tail(k):
        # Forward from token k to where the next command (or its modifiers) begins.
        end = k + 1
        while end < len(toks) and toks[end][0] not in COMMAND_TOKENS \
                and toks[end][0] not in MODIFIER_TOKENS:
            end += 1
        return [t for t, _ in toks[k:end]]

    def exactly_sorry(decl):
        return decl[-2:] == [":=", "sorry"] or decl[-3:] == [":=", "by", "sorry"]

    # The converse direction: every theorem is proved by sorry, not just every sorry in a
    # theorem. A statement that proves things is a statement plus part of its proof, and the
    # proof part is where proofs are adjudicated. (Of a @decls target, a proof would also simply
    # be discarded — statement-identity compares types, never proofs — so allowing one here would
    # publish a proof that nothing ever checked as the proof of this claim.)
    for k, (tok, pos) in enumerate(toks):
        if tok in ("theorem", "lemma") and not exactly_sorry(decl_tail(k)):
            die("`%s` on line %d of the `@statement` section is not proved by exactly `sorry`\n"
                "  In the statement every theorem's proof is `:= sorry` or `:= by sorry`; the "
                "proof belongs in the `@proof` section." % (tok, line_of(pos)))

    for k, (tok, pos) in enumerate(toks):
        if tok not in SORRY_TOKENS:
            continue
        # The declaration this sorry belongs to: back to the nearest command keyword ...
        start = k - 1
        while start >= 0 and toks[start][0] not in COMMAND_TOKENS:
            start -= 1
        # ... and forward to where the next command (or its modifiers) begins.
        decl = [t for t, _ in toks[max(start, 0):k]] + decl_tail(k)
        why = None
        if start < 0 or toks[start][0] not in ("theorem", "lemma"):
            why = "it is not in a `theorem` or `lemma`"
        elif tok != "sorry":
            why = "only a plain `sorry` may stand for a proof, not `%s`" % tok
        elif sum(1 for t in decl if t in SORRY_TOKENS) != 1:
            why = "the declaration has more than one sorry, so it is not its whole proof"
        elif not exactly_sorry(decl):
            why = "the proof must be exactly `:= sorry` or `:= by sorry`"
        if why:
            die("`%s` on line %d of the `@statement` section: %s\n"
                "  A statement carries definitions and theorem statements; every theorem's proof "
                "is exactly `sorry`\n"
                "  and nothing else may be. The proof belongs in the `@proof` section."
                % (tok, line_of(pos), why))


def extract_header_block(text):
    """Return the inner text of the LEADING `/-! ... -/` doc-comment block.

    Only a block that opens the file (ignoring leading blank lines) counts —
    a `/-! -/` further down the source is body, not header. Returns None if
    the file does not start with such a block.
    """
    # Skip a UTF-8 BOM and leading whitespace/blank lines.
    stripped = text.lstrip("﻿")
    lead = stripped.lstrip()
    if not lead.startswith("/-!"):
        return None
    # Find the matching close of THIS opening block. Lean block comments can
    # nest, but the form never emits a nested comment inside the header, and
    # the @gloss body is plain indented text; the first `-/` closes it.
    start = stripped.find("/-!")
    end = stripped.find("-/", start + 3)
    if end == -1:
        return None
    return stripped[start + 3:end]


def parse_header(block):
    """Parse the @-header lines out of the doc-comment inner text.

    Scalar @fields (@kind:, @title:, ...) are `@name: value`. @gloss: is a
    block field: everything after it (to the end of the header block) is the
    gloss body, dedented by the form's two-space indent.
    """
    lines = block.splitlines()
    fields = {}
    gloss_lines = []
    in_gloss = False

    for raw in lines:
        line = raw.rstrip("\n")
        # A new @field line ends any in-progress @gloss block.
        m = re.match(r"^\s*@([A-Za-z_]+)\s*:(.*)$", line)
        if m and not (in_gloss and not line.lstrip().startswith("@")):
            name = m.group(1).strip().lower()
            value = m.group(2).strip()
            if name == "gloss":
                in_gloss = True
                # Anything on the same line after `@gloss:` is unusual (the
                # form puts the body on following indented lines) but keep it.
                if value:
                    gloss_lines.append(value)
                continue
            in_gloss = False
            if name in SCALAR_FIELDS:
                fields[name] = value
            # unknown @field: ignore (forward-compatible)
            continue
        if in_gloss:
            # Gloss body line. The form indents each gloss line by two spaces;
            # strip up to two leading spaces so the JSON gloss is undented.
            gloss_lines.append(re.sub(r"^ {1,2}", "", line))

    fields["gloss"] = "\n".join(gloss_lines).strip("\n")
    return fields


def main(argv):
    # `--part statement|proof` prints that part of a two-part deposit instead of the JSON. It
    # runs the whole parse first, so a part is only ever emitted from a deposit that parsed.
    part = None
    if len(argv) == 4 and argv[1] == "--part" and argv[2] in ("statement", "proof"):
        part = argv[2]
        argv = [argv[0], argv[3]]
    if len(argv) != 2:
        die("usage: parse_deposit.py [--part statement|proof] <submission.lean>")
    path = argv[1]
    try:
        with open(path, "r", encoding="utf-8") as f:
            text = f.read()
    except OSError as e:
        die("cannot read %s: %s" % (path, e))

    imports, rest = split_leading_imports(text)
    for mod in imports:
        if not MODULE_RE.match(mod) or ".." in mod:
            die("illegal import %r (must be a dotted Lean module name)" % mod)

    block = extract_header_block(rest)
    if block is None:
        die("no leading /-! ... -/ metadata header block in %s" % path)

    # An import BELOW the header is not a style problem, it is a file that cannot build. Saying
    # so here costs nothing; letting it through spends a full container build to reach the same
    # conclusion with a worse message.
    close = rest.find("-/", rest.find("/-!") + 3)
    for ln in rest[close + 2:].splitlines():
        if re.match(r"^\s*import\b", ln):
            die("import below the metadata header in %s: %r\n"
                "  Lean requires every import to precede all declarations, and the `/-!` header "
                "is a declaration.\n"
                "  Put imports at the very top of your source and the form will hoist them above "
                "the header." % (path, ln.strip()))

    fields = parse_header(block)

    # Sections. `close` is relative to `rest`, which is `text` minus the hoisted imports.
    mode, parts = find_sections(text, len(text) - len(rest) + close)

    # Required scalar fields.
    for req in ("kind", "title", "decls", "pin"):
        if not fields.get(req):
            die("missing required @%s in header of %s" % (req, path))

    kind = fields["kind"]
    if kind not in VALID_KINDS:
        die("invalid @kind %r (must be one of %s)" % (kind, "|".join(VALID_KINDS)))

    pin = fields["pin"]
    if pin != PIN_REQUIRED:
        die("pin %r != required %r" % (pin, PIN_REQUIRED))

    decls = [d.strip() for d in fields["decls"].split(",") if d.strip()]
    if not decls:
        die("@decls resolved to an empty list in %s" % path)

    # Reject any decl containing a forbidden byte (whitespace, control, path or
    # shell/markdown-dangerous character) or a `..` sequence. Keeps a hostile
    # decl from breaking out of the gate's argv or the PR-comment markdown.
    for dn in decls:
        if ".." in dn or not all(decl_char_ok(c) for c in dn):
            die("illegal @decls entry %r (not a plausible Lean declaration name)" % dn)

    # @discharges (when present) names a CLAIM this deposit discharges. It is
    # interpolated by the gate into a registry path
    # (registry/claims/<discharges>/manifest.json) to select the FROZEN
    # reference R. Validate it to the exact claims-handle grammar
    # MTH.C-YYYY-NNNN, fail-closed: this forecloses path traversal (`../`,
    # absolute paths, embedded `/`) that would let a deposit point R at a file
    # it controls and pass statement-identity against its own forged reference.
    discharges = fields.get("discharges") or None
    if discharges is not None and not re.fullmatch(r"MTH\.C-[0-9]{4}-[0-9]{4,}", discharges):
        die("invalid @discharges %r (must be a claims handle MTH.C-YYYY-NNNN)" % discharges)

    # @mathlib (when present) pins the Mathlib revision the deposit is built against. Only the
    # GRAMMAR is checked here: this parser is deliberately database-free because the gate runs
    # it too, so whether a revision is one the bank actually has a cache and a trusted reference
    # for is decided by the caller (the API at intake, and the gate before it builds). Absent
    # means Lean-core only, which is every deposit before Phase 2b.
    mathlib = fields.get("mathlib") or None
    if mathlib is not None and not re.fullmatch(r"[0-9a-f]{40}", mathlib):
        die("invalid @mathlib %r (must be a 40-character lowercase git sha)" % mathlib)

    # Importing Mathlib without pinning a revision is a deposit that cannot build, and this is
    # decidable from the header alone — no database needed, so it belongs here. `@mathlib` is what
    # selects a Mathlib environment; without it the deposit resolves to Lean core, where Mathlib
    # is not on LEAN_PATH and the build dies with Lean's own "unknown module prefix 'Mathlib'"
    # after a full container build. Saying it now is the same verdict, minutes earlier, with a
    # message the depositor can act on.
    if mathlib is None:
        unpinned = [m for m in imports if m == "Mathlib" or m.startswith("Mathlib.")]
        if unpinned:
            die("imports %s but sets no @mathlib in %s\n"
                "  A Mathlib import needs @mathlib: <40-char revision> to select the build\n"
                "  environment that carries it. Without one the deposit is built against Lean\n"
                "  core, where Mathlib is not importable."
                % (", ".join(repr(m) for m in unpinned[:3]), path))

    if mode != "single":
        # A registry claim's statement is the registry's, frozen when the claim was posed; a
        # deposit that discharges it does not get to supply another. Were both allowed, the gate
        # would have two references and no principled way to prefer one, so neither is guessed.
        if discharges is not None:
            die("@discharges and a `/-! @statement -/` section together in %s\n"
                "  A deposit discharging a registry claim is checked against that claim's frozen "
                "statement,\n"
                "  so it carries no statement of its own: drop the markers and submit the proof "
                "alone." % path)
        # A posed claim has no proof, so it is a claim and nothing else; saying `result` of a
        # statement whose every theorem is `sorry` would publish an unproved result.
        if mode == "pose" and kind != "claim":
            die("a posed claim (`@statement` with no `@proof`) must be `@kind: claim`, not %r"
                % kind)
        lines = text.split("\n")
        st = parts["statement"]
        check_statement_form("\n".join(lines[st["start"]:st["end"]]), st["start"] + 1)

    if part is not None:
        if mode == "single":
            die("--part %s: %s is a single-part deposit (no section markers)" % (part, path))
        if part == "proof" and parts["proof"] is None:
            die("--part proof: %s poses a claim and has no `@proof` section" % path)
        sys.stdout.write(emit_part(text, parts, part))
        return 0

    # Title is human-facing and flows into the PR-comment markdown. Collapse all
    # whitespace (including newlines) to single spaces and cap length, so a
    # title cannot forge a report line (e.g. a fake "verdict: admit").
    title = re.sub(r"\s+", " ", fields["title"]).strip()[:200]

    out = {
        "kind": kind,
        "title": title,
        "module": fields.get("module") or "Submission",
        "decls": decls,
        "pin": pin,
        "mathlib": mathlib,
        "discharges": discharges,
        # The hoisted imports, so a caller can see what the deposit asked for without
        # re-parsing the file. What is actually IMPORTABLE is decided by LEAN_PATH, i.e. by the
        # environment the deposit pinned — a core environment offers Init/Std/Lean and nothing
        # more, so an unavailable import fails the build with Lean's own message.
        "imports": imports,
        "gloss": fields.get("gloss", ""),
        # `single` (no markers — exactly the format before sections existed), `two-part`, or
        # `pose`; and each section's 1-based inclusive line range, marker line first. See the
        # file header for the format. New keys only: every key above is unchanged.
        "mode": mode,
        "parts": parts,
    }
    sys.stdout.write(json.dumps(out) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
