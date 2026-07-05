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
# This script parses ONLY that header (it does not read the Lean body) and
# prints one JSON object:
#   {kind, title, module, decls:[...], pin, discharges|null, gloss}
#
# It FAILS CLOSED (nonzero exit, error on stderr) when:
#   * the file has no leading /-! ... -/ block,
#   * a required field is missing (@kind, @title, @decls, @pin),
#   * @kind is not one of result|definition|claim,
#   * @pin is not exactly leanprover/lean4:v4.31.0,
#   * @decls is empty after splitting.
# A malformed deposit therefore never yields a parse the gate could act on.
# ---------------------------------------------------------------------------
import json
import re
import sys

PIN_REQUIRED = "leanprover/lean4:v4.31.0"
VALID_KINDS = ("result", "definition", "claim")

# The @-fields the header may carry. Everything the gate keys on is here; an
# unknown @-line is ignored (forward-compatible) rather than fatal.
SCALAR_FIELDS = ("kind", "title", "module", "decls", "pin", "discharges")


def die(msg):
    sys.stderr.write("parse_deposit: " + msg + "\n")
    sys.exit(1)


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
    if len(argv) != 2:
        die("usage: parse_deposit.py <submission.lean>")
    path = argv[1]
    try:
        with open(path, "r", encoding="utf-8") as f:
            text = f.read()
    except OSError as e:
        die("cannot read %s: %s" % (path, e))

    block = extract_header_block(text)
    if block is None:
        die("no leading /-! ... -/ metadata header block in %s" % path)

    fields = parse_header(block)

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

    out = {
        "kind": kind,
        "title": fields["title"],
        "module": fields.get("module") or "Submission",
        "decls": decls,
        "pin": pin,
        "discharges": fields.get("discharges") or None,
        "gloss": fields.get("gloss", ""),
    }
    sys.stdout.write(json.dumps(out) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
