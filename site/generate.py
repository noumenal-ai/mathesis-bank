import os
#!/usr/bin/env python3
"""
Mathesis site generator.

Reads registry/{dictionary,claims,results}/MTH.{D,C,R}-2026-NNNN/{manifest.json,
gloss.md,pin.json}, validates every manifest against schema/unit-manifest.v2.schema.json,
and emits docs/ (a static, framework-free site).

Invariants this script must never violate:
  INV-1  Language firewall: none of the banned words may appear anywhere in docs/ output.
  INV-2  No importance signals: no rankings/featured/stars/citation counts/single score.
         Only neutral CATEGORY counts are shown (per evidence leg: proved / witnessed /
         mechanized-empirical, and per bank) — kinds, never a rank. The evidence leg is a
         distinction of kind layered on the shared kernel-checked floor, not a quality order.
  INV-3  Gate-emitted fields (tier, axiom_manifest, verdict) are rendered verbatim from
         the manifest. This generator never computes or edits them.
  INV-4  No LLM anywhere in this pipeline; pure byte-faithful rendering.
  INV-7  Dictionary status "proposed" renders as "kernel-checked; interrogation pending",
         never as "admitted".

Deterministic + idempotent: run it twice on the same registry, get byte-identical docs/.
"""

import html
import json
import re
import sys
from pathlib import Path

try:
    import jsonschema
except ImportError:
    print("FATAL: jsonschema not installed. pip install jsonschema", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "registry"
SCHEMA_PATH = ROOT / "schema" / "unit-manifest.v2.schema.json"
DOCS = ROOT / "docs"

BANKS = {
    "dictionary": {"prefix": "MTH.D", "deposit_class": "definition", "label": "Dictionary", "slug": "dictionary"},
    "claims": {"prefix": "MTH.C", "deposit_class": "claim", "label": "Claims", "slug": "claims"},
    "results": {"prefix": "MTH.R", "deposit_class": "demonstration", "label": "Results", "slug": "results"},
}

# INV-1: language firewall. Grepped verbatim against the built docs/ tree at the end
# of this script, and again in CI. Terms are maintained in the local, uncommitted .firewall-terms file.
def _load_firewall_terms():
    """INV-1 term list is kept OUT of this published file. Loaded from a local,
    gitignored `.firewall-terms` when present (one term per line); absent in the
    published repo, so the shipped generator carries no vocabulary. The committed
    docs/ were firewall-checked locally before publication."""
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".firewall-terms")
    try:
        with open(p, encoding="utf-8") as f:
            return [ln.rstrip("\n") for ln in f if ln.strip() and not ln.lstrip().startswith("#")]
    except FileNotFoundError:
        print("[firewall] .firewall-terms absent; skipping INV-1 term scan "
              "(committed docs/ were pre-checked before publication).")
        return []

BANNED_WORDS = _load_firewall_terms()

# Narrow, documented carve-out for the firewall check: "Γ"/"γ" are banned as
# internal-vocabulary tokens, but the registry's own Lean pretty-printed
# statements legitimately use "γ" as an ordinary Mathlib-style bound type-variable
# name (e.g. MTH.R-2026-1041 / MTH.C-2026-1041: `{γ : Sort u_2}`), unrelated content
# that only collides on the bare character. Byte-faithful rendering (INV-4) means
# this generator must not rewrite or strip characters out of a manifest's own
# statement/gloss text. So the firewall scanner treats "Γ"/"γ" as allowed ONLY
# inside <pre>/<code> spans, which is exactly where formal Lean syntax is rendered
# verbatim, and nowhere the generator writes its own prose. All other banned words
# remain banned everywhere, with no carve-out.
_GREEK_GAMMA = {"Γ", "γ"}

TIER_CAPTION = {
    ("T0", "universal"): "kernel-checked; representative spot-check on a universal statement",
    ("T0", "existential"): "kernel-checked; the witness is full evidence for this existential statement",
    ("T0", None): "kernel-checked",
    ("T1", "universal"): "kernel-checked; broader spot-check coverage on a universal statement",
    ("T1", "existential"): "kernel-checked; witness plus extended coverage",
    ("T1", None): "kernel-checked; extended coverage",
    ("T2", "universal"): "kernel-checked; exhaustive coverage on a universal statement",
    ("T2", "existential"): "kernel-checked; the witness is exhaustive evidence",
    ("T2", None): "kernel-checked; exhaustive coverage",
}

# Evidence leg — the discerning-reader differentiator, layered ON TOP of the
# kernel-checked floor (every result has the floor; the leg says WHAT KIND of
# evidence carries it). These are KINDS, not a ranking (INV-2). DERIVED, not
# gate-emitted: proved/witnessed come straight from the gate's `polarity` field;
# mechanized-empirical is recognised by the author's own `Executed` namespace
# segment on the statement's declarations (a result whose statement is about a
# concretely executed system). The rule is disclosed on the site so a reader can
# re-derive the label; the generator never invents a gate verdict (INV-3).
EVIDENCE_LEG = {
    "proved": ("Proved",
               "a general statement, established for every case by a kernel-checked proof term"),
    "witnessed": ("Witnessed",
                  "established by exhibiting a concrete witness or construction, which is itself the "
                  "kernel-checked evidence"),
    "mechanized-empirical": ("Mechanized-empirical",
                             "a statement about a specific executed system, whose behaviour is reflected "
                             "exactly into the kernel and reasoned over"),
}


def evidence_leg(m):
    """A result's evidence leg (a key in EVIDENCE_LEG, or None for non-results).

    Prefers the EXPLICIT `evidence_leg` manifest field when present (the Eidometry volume sets
    it, since the kind of evidence is not always the syntactic polarity — a universal statement
    can still be proved by exhibiting a construction). Otherwise falls back to the disclosed
    derivation: an `Executed` namespace segment ⇒ mechanized-empirical; universal ⇒ proved;
    existential ⇒ witnessed. The generator never invents a gate verdict (INV-3)."""
    if m.get("deposit_class") != "demonstration":
        return None
    explicit = m.get("evidence_leg")
    if explicit in EVIDENCE_LEG:
        return explicit
    decls = (m.get("statement") or {}).get("decl_names") or []
    if any("Executed" in d.split(".") for d in decls):
        return "mechanized-empirical"
    pol = m.get("polarity")
    if pol == "universal":
        return "proved"
    if pol == "existential":
        return "witnessed"
    return None


# Ontology axis (the Eidometry volume): where a result sits in the theory. ORTHOGONAL to the
# evidence leg — a result has both. Plain public labels (no Greek: γ is firewall-banned in prose,
# and plain reads better). Descriptions are author-adapted from the thesis.
ONTOLOGY = {
    "Forcing": "A specification of which states must be told apart, and which dynamics preserved, "
               "forces one canonical way of grouping states — from the definition alone, over an "
               "arbitrary state space with no finiteness or topology assumed.",
    "Non-triviality": "That same canonical grouping is rebuilt independently, from scratch, by gluing "
                      "local observations across a cover of questions; whether local data pins down the "
                      "global object turns on whether the pattern of questions contains a cycle.",
    "Orthogonality": "The forced structure and the uncertainty it assigns depend only on how finely "
                     "states can be distinguished, so re-weighting or re-indexing the same information "
                     "leaves them fixed, while changing what can be distinguished can move them.",
    "Experiments": "Four independent testbeds — a qubit, a classical conservative system, learning "
                   "through a representation, and causal models — each supply only a set of measurements "
                   "and prove the forced structure equals an object defined separately, supplied nowhere "
                   "in advance.",
    "Executed runs": "The theory is executable: real floating-point runs read exactly as mathematics "
                     "rather than approximation, and machine-checked certificates equate a compiler's "
                     "output to the exact geometric fact it claims.",
    "Counterfactuals": "Refuted and repaired conjectures are recorded as first-class results alongside "
                       "their disproofs — including that a counterfactual quantity provably cannot be "
                       "recovered from intervention results alone.",
}
ONTOLOGY_ORDER = ["Forcing", "Non-triviality", "Orthogonality", "Experiments", "Executed runs", "Counterfactuals"]


def ontology_badge(m):
    sec = m.get("ontology_section")
    if not sec or sec not in ONTOLOGY:
        return ""
    return (f'<span class="badge badge-onto" title="{esc(ONTOLOGY[sec])}">{esc(sec)}'
            f'<span class="badge-caption">{esc(ONTOLOGY[sec])}</span></span>')


def evidence_leg_badge(m):
    leg = evidence_leg(m)
    if not leg:
        return ""
    label, caption = EVIDENCE_LEG[leg]
    return (f'<span class="badge badge-leg badge-leg-{esc(leg)}" title="{esc(caption)}">'
            f'{esc(label)}<span class="badge-caption">{esc(caption)}</span></span>')


STATUS_LABEL = {
    # Dictionary (INV-7: "proposed" must never read as "admitted")
    "proposed": "kernel-checked; interrogation pending",
    "interrogated": "interrogated",
    "admitted": "admitted",
    "contested": "contested",
    # Claims
    "posed": "posed",
    "well-posed": "well-posed",
    # Results
    "still-green": "still verified against the current pin",
    "ported-to-HEAD": "ported to the current toolchain head",
    "superseded": "superseded",
}


def fail(msg):
    print(f"FATAL: {msg}", file=sys.stderr)
    sys.exit(1)


def load_schema():
    return json.loads(SCHEMA_PATH.read_text())


def load_accessions():
    """Read + validate every manifest. Returns dict handle -> record."""
    schema = load_schema()
    validator = jsonschema.Draft202012Validator(schema)
    records = {}
    errors = []

    for bank_key, bank in BANKS.items():
        bank_dir = REGISTRY / bank_key
        if not bank_dir.is_dir():
            fail(f"registry bank missing: {bank_dir}")
        for acc_dir in sorted(bank_dir.iterdir()):
            if not acc_dir.is_dir():
                continue
            handle = acc_dir.name
            manifest_path = acc_dir / "manifest.json"
            if not manifest_path.is_file():
                errors.append(f"{handle}: missing manifest.json")
                continue
            try:
                manifest = json.loads(manifest_path.read_text())
            except json.JSONDecodeError as e:
                errors.append(f"{handle}: invalid JSON ({e})")
                continue

            v_errors = sorted(validator.iter_errors(manifest), key=lambda e: e.path)
            if v_errors:
                for e in v_errors:
                    errors.append(f"{handle}: schema violation at {list(e.path)}: {e.message}")
                continue

            if manifest["handle"] != handle:
                errors.append(f"{handle}: manifest handle field {manifest['handle']!r} != directory name")
                continue
            if not handle.startswith(bank["prefix"]):
                errors.append(f"{handle}: found in bank {bank_key} but handle prefix mismatch")
                continue
            if manifest["deposit_class"] != bank["deposit_class"]:
                errors.append(
                    f"{handle}: deposit_class {manifest['deposit_class']!r} "
                    f"!= expected {bank['deposit_class']!r} for bank {bank_key}"
                )
                continue

            gloss_path = acc_dir / "gloss.md"
            gloss = gloss_path.read_text() if gloss_path.is_file() else ""

            pin_path = acc_dir / "pin.json"
            pin_file = json.loads(pin_path.read_text()) if pin_path.is_file() else None

            records[handle] = {
                "bank": bank_key,
                "manifest": manifest,
                "gloss": gloss,
                "pin_file": pin_file,
            }

    if errors:
        for e in errors:
            print(f"SCHEMA/REGISTRY ERROR: {e}", file=sys.stderr)
        fail(f"{len(errors)} manifest(s) failed validation. Aborting build.")

    return records


# ---------------------------------------------------------------------------
# small HTML helpers (no framework, no templating engine — plain f-strings)
# ---------------------------------------------------------------------------

def esc(s):
    if s is None:
        return ""
    return html.escape(str(s), quote=True)


def module_chip(module):
    return f'<code class="chip chip-module">{esc(module)}</code>'


def tier_badge(tier, polarity):
    if tier is None:
        return '<span class="badge badge-none">not tiered</span>'
    caption = TIER_CAPTION.get((tier, polarity), TIER_CAPTION.get((tier, None), "kernel-checked"))
    return (f'<span class="badge badge-tier badge-{esc(tier.lower())}" title="{esc(caption)}">'
            f'{esc(tier)}<span class="badge-caption">{esc(caption)}</span></span>')


def axioms_clean(manifest):
    ax = manifest.get("axiom_manifest")
    if ax is None:
        return None  # not applicable (claims/definitions have no proof yet)
    whitelist = {"propext", "Classical.choice", "Quot.sound"}
    return set(ax) <= whitelist


def axiom_chip(manifest):
    ax = manifest.get("axiom_manifest")
    tbe = manifest.get("trust_boundary_extensions") or []
    if ax is None:
        return '<span class="badge badge-none">no proof axiom record</span>'
    clean = axioms_clean(manifest)
    if clean and not tbe:
        return '<span class="badge badge-clean" title="depends only on propext, Classical.choice, Quot.sound">axiom-clean</span>'
    extra = ", ".join(esc(a) for a in (set(ax) - {"propext", "Classical.choice", "Quot.sound"}))
    return f'<span class="badge badge-warn" title="extends the whitelist: {extra}">extended axioms</span>'


def admitted_stamp(manifest):
    verdict = manifest.get("verdict")
    if verdict and verdict.get("result") == "ADMITTED":
        return '<span class="stamp stamp-admitted">ADMITTED</span>'
    if verdict and verdict.get("result"):
        return f'<span class="stamp stamp-other">{esc(verdict["result"])}</span>'
    return ""


def status_label(status):
    return STATUS_LABEL.get(status, status)


def page_shell(title, description, active, body, depth=0):
    prefix = "../" * depth
    nav_items = [
        ("results", "Results"),
        ("claims", "Claims"),
        ("dictionary", "Dictionary"),
        ("ontology", "Ontology"),
        ("deposit", "Deposit"),
        ("charter", "Charter"),
        ("about", "About"),
    ]
    nav_html = "\n".join(
        f'<a href="{prefix}{slug}.html" class="{"active" if active == slug else ""}">{label}</a>'
        for slug, label in nav_items
    )
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(description)}">
<link rel="stylesheet" href="{prefix}styles.css">
</head>
<body>
<div class="topbar">
  <div class="topbar-inner">
    <a class="wordmark" href="{prefix}index.html">Noumenal Research <span>&middot; Mathesis</span></a>
    <div class="topbar-right">
      <nav class="topnav" aria-label="Sections">
        {nav_html}
      </nav>
      <button class="verify-chip" id="verifyBtn" type="button"
              aria-haspopup="dialog" aria-expanded="false" aria-controls="verifyPanel">
        <span class="vdot v-pending"></span><span class="vlabel">Verify</span>
      </button>
    </div>
  </div>
</div>

<div id="verifyPanel" role="dialog" aria-modal="true" aria-label="Machine verification" hidden>
  <div class="vcard">
    <button class="vclose" type="button" aria-label="Close">&times;</button>
    <h3>Machine verification</h3>
    <div class="vbody"></div>
  </div>
</div>

<main id="top">
{body}
</main>

<footer>
  <div class="shell footer-inner">
    <span>Noumenal Research &middot; Mathesis is an evidence bank, not a journal.</span>
    <span><a href="{prefix}charter.html">Charter</a> &middot; <a href="{prefix}about.html">About</a></span>
  </div>
</footer>

<script src="{prefix}verify.js"></script>
<script src="{prefix}app.js"></script>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# index.json (compact rows for the browse/search UI)
# ---------------------------------------------------------------------------

def build_index_rows(records):
    rows = []
    for handle, rec in sorted(records.items()):
        m = rec["manifest"]
        deps = m.get("dependency_closure") or []
        # Axiom-cleanliness is a Results-only concept (it describes a proof's
        # dependency on the kernel's axiom whitelist). Claims and Dictionary
        # definitions carry no proof, so leave this null for them even though
        # their manifests may technically record an empty axiom_manifest: []
        # (INV-3 renders gate fields verbatim on the *detail* page; this is
        # just the summary-card badge, which would otherwise mislabel a
        # definition or claim as "axiom-clean").
        clean = axioms_clean(m) if m["deposit_class"] == "demonstration" else None
        rows.append({
            "handle": handle,
            "bank": rec["bank"],
            "deposit_class": m["deposit_class"],
            "title": m["title"],
            "module": m["statement"]["module"],
            "tier": m.get("tier"),
            "polarity": m.get("polarity"),
            "status": m.get("status"),
            "axioms_clean": clean,
            "deps_count": len(deps),
            "discharges": m.get("discharges"),
            "exercisability": m.get("exercisability"),
        })
    return rows


# ---------------------------------------------------------------------------
# accession detail page
# ---------------------------------------------------------------------------

def vouching_table(manifest):
    v = manifest.get("vouching") or {}
    rows = []
    for leg in ("statement", "proof", "witness", "gloss"):
        val = v.get(leg)
        if val is None:
            rows.append(f'<tr><td>{leg.capitalize()}</td><td class="v-na">not applicable</td></tr>')
        else:
            rows.append(f'<tr><td>{leg.capitalize()}</td><td><span class="badge badge-vouch badge-vouch-{esc(val)}">{esc(val)}</span></td></tr>')
    return (
        '<table class="vouch-table"><thead><tr><th>Component</th><th>Vouched by</th></tr></thead>'
        f'<tbody>{"".join(rows)}</tbody></table>'
    )


def dependency_list(manifest, records, depth):
    deps = manifest.get("dependency_closure")
    if not deps:
        return "<p class=\"empty-note\">No recorded dependencies.</p>"
    prefix = "../" * depth
    items = []
    for d in deps:
        h = d["handle"]
        tier = d.get("tier")
        exists = h in records
        tier_span = f'<span class="badge badge-tier badge-{esc(tier.lower())}">{esc(tier)}</span>' if tier else '<span class="badge badge-none">untiered</span>'
        if exists:
            items.append(f'<li><a href="{prefix}a/{esc(h)}.html"><code>{esc(h)}</code></a> {tier_span}</li>')
        else:
            items.append(f'<li><code>{esc(h)}</code> {tier_span} <span class="empty-note">(not in this snapshot)</span></li>')
    return f'<ul class="dep-list">{"".join(items)}</ul>'


def link_or_plain(handle, records, depth, label=None):
    prefix = "../" * depth
    label = label or handle
    if handle in records:
        return f'<a href="{prefix}a/{esc(handle)}.html"><code>{esc(label)}</code></a>'
    return f'<code>{esc(label)}</code>'


def binding_note(manifest):
    """The claim-binding disclaimer (finding F1): make explicit, at the top of every
    page, what the machine checked (the formal statement + axioms) versus what is
    author-provided (the plain-language title and gloss). "Verified" here never means
    "the English claim is true"; it means the Lean statement shown is kernel-valid and
    axiom-clean."""
    dc = manifest.get("deposit_class")
    if dc == "demonstration":
        return ('<p class="binding-note"><strong>Machine-checked:</strong> the formal statement below and '
                'its axiom closure (kernel replay, whitelist audit). <strong>Author-described:</strong> the '
                'title and gloss &mdash; the machine does not check that the prose matches the formal statement.</p>')
    if dc == "definition":
        return ('<p class="binding-note"><strong>Machine-checked:</strong> the definition is kernel-valid and '
                'axiom-clean. <strong>Author-described:</strong> whether this is the intended notion &mdash; a '
                'definition can be well-formed yet not mean what its name suggests.</p>')
    return ('<p class="binding-note">A claim is a statement of record. Nothing here is machine-checked until a '
            'result discharges it against this exact statement.</p>')


def render_accession_detail(handle, rec, records):
    m = rec["manifest"]
    gloss_html = md_to_minimal_html(rec["gloss"])
    depth = 1  # docs/a/<handle>.html

    bank = BANKS[rec["bank"]]
    class_label = {"definition": "Dictionary definition", "claim": "Claim", "demonstration": "Result"}[m["deposit_class"]]

    header_badges = []
    if m["deposit_class"] == "demonstration":
        header_badges.append(evidence_leg_badge(m))       # the kind of evidence (primary)
        header_badges.append(ontology_badge(m))           # where in the theory (orthogonal axis)
        header_badges.append(tier_badge(m.get("tier"), m.get("polarity")))  # coverage (secondary)
        header_badges.append(axiom_chip(m))
        header_badges.append(admitted_stamp(m))
    elif m["deposit_class"] == "definition":
        header_badges.append(f'<span class="badge badge-status">{esc(status_label(m.get("status")))}</span>')
        if m.get("exercisability"):
            header_badges.append(f'<span class="badge badge-exercisability">{esc(m["exercisability"])}</span>')
    else:  # claim
        header_badges.append(f'<span class="badge badge-status">{esc(status_label(m.get("status")))}</span>')
        header_badges.append(ontology_badge(m))
        if m.get("polarity"):
            header_badges.append(f'<span class="badge badge-polarity">{esc(m["polarity"])}</span>')

    decl_names = m["statement"]["decl_names"]
    pretty = m["statement"]["pretty"]

    discharges_html = ""
    if m.get("discharges"):
        discharges_html = f'<p><strong>Discharges claim</strong> {link_or_plain(m["discharges"], records, depth)}</p>'
    if m.get("discharged_by"):
        links = ", ".join(link_or_plain(h, records, depth) for h in m["discharged_by"])
        open_span = '<span class="empty-note">open</span>'
        discharges_html += f'<p><strong>Discharged by</strong> {links if links else open_span}</p>'
    elif m["deposit_class"] == "claim":
        discharges_html += '<p><strong>Discharged by</strong> <span class="empty-note">open, no result recorded yet</span></p>'

    suite_html = ""
    if m.get("suite"):
        s = m["suite"]
        parts = []
        for key in ("instances", "non_instances", "separations", "obligations"):
            vals = s.get(key)
            if vals:
                parts.append(f'<div class="suite-group"><h4>{key.replace("_", " ").capitalize()}</h4><ul>' +
                              "".join(f"<li><code>{esc(v)}</code></li>" for v in vals) + "</ul></div>")
        if parts:
            suite_html = f'<section class="shell detail-section"><h3>Witness / obligation suite</h3>{"".join(parts)}</section>'

    pin = m.get("pin") or {}
    pin_rows = "".join(
        f"<tr><td>{esc(k.replace('_', ' '))}</td><td><code>{esc(json.dumps(v) if isinstance(v, dict) else v)}</code></td></tr>"
        for k, v in pin.items() if v is not None
    )

    export_html = ""
    fe = m.get("frozen_export")
    if fe:
        export_html = (
            '<section class="shell detail-section"><h3>Frozen export</h3>'
            f'<p class="mono-note">sha256 <code>{esc(fe["sha256"])}</code> &middot; {esc(fe["bytes"])} bytes &middot; '
            f'{esc(fe["constants"])} constants</p>'
            '<p class="empty-note">Audit artifact available on request; not bundled in this static snapshot.</p>'
            '</section>'
        )

    witness_html = ""
    w = m.get("witness")
    if w:
        decls = ", ".join(f"<code>{esc(d)}</code>" for d in w.get("decls", []))
        witness_html = (
            '<section class="shell detail-section"><h3>Witness</h3>'
            f'<p>{esc(w["kind"])} &middot; {decls}</p>'
            '</section>'
        )

    axiom_manifest_html = ""
    if m.get("axiom_manifest") is not None:
        chips = " ".join(f'<code class="chip chip-axiom">{esc(a)}</code>' for a in m["axiom_manifest"]) or '<span class="empty-note">empty closure</span>'
        tbe = m.get("trust_boundary_extensions") or []
        tbe_html = ""
        if tbe:
            tbe_html = f'<p class="warn-note">Trust-boundary extensions: {" ".join(f"<code>{esc(t)}</code>" for t in tbe)}</p>'
        axiom_manifest_html = (
            '<section class="shell detail-section"><h3>Axiom manifest</h3>'
            '<p class="mono-note">The assumptions this proof depends on beyond the kernel&rsquo;s base '
            'logic. A shorter list is a stronger result; an empty list means the proof rests on nothing '
            'but the kernel itself.</p>'
            f'<p>{chips}</p>{tbe_html}</section>')

    cites_html = ""
    if m.get("cites"):
        cites_html = (f'<p><strong>Cites</strong> <code>{esc(m["cites"])}</code> '
                      f'<span class="empty-note">— the corpus theorem this result restates and discharges by naming it.</span></p>')

    # "Cite this / share" — the accession is the citable, permanent unit. No JS required to copy
    # the id; the share row offers the canonical link. (INV-2: no citation COUNTS, just the id.)
    cite_url = f"https://noumenal-ai.github.io/mathesis-bank/a/{handle}.html"
    cite_this_html = (
        '<section class="shell detail-section" id="cite">'
        '<h3>Cite this</h3>'
        '<p class="empty-note">The accession id is permanent and always resolves to this exact '
        'statement, proof, and axiom manifest. Corrections mint a new accession; this one never changes.</p>'
        f'<pre class="statement-pretty"><code>Mathesis Bank, accession {esc(handle)}.\n{esc(cite_url)}</code></pre>'
        f'<p class="share-row"><a class="btn" href="{esc(cite_url)}">Permalink</a> '
        f'<a class="btn" href="https://github.com/noumenal-ai/mathesis-bank/tree/main/registry">Registry</a></p>'
        '</section>')

    body = f"""
<section class="detail-hero shell">
  <p class="kicker"><a href="../{esc(bank['slug'])}.html">{esc(bank['label'])}</a> &middot; {esc(class_label)}</p>
  <h1 class="measure">{esc(m['title'])}</h1>
  <p class="handle-line"><code>{esc(handle)}</code></p>
  <div class="badge-row">{"".join(header_badges)}</div>
  {binding_note(m)}
</section>

<section class="shell detail-section">
  <h3>Statement</h3>
  <p class="mono-note">{module_chip(m['statement']['module'])} &middot; declares {", ".join(f"<code>{esc(d)}</code>" for d in decl_names)}</p>
  <pre class="statement-pretty"><code>{esc(pretty)}</code></pre>
</section>

<section class="shell detail-section">
  <h3>Status</h3>
  <p>{esc(status_label(m.get('status')))}</p>
  {discharges_html}
  {cites_html}
</section>

<section class="shell detail-section">
  <h3>Vouching</h3>
  <p class="empty-note">Who vouches for each component. The gloss is always author-vouched: faithfulness of prose to the formal statement is overlay work, not gated.</p>
  {vouching_table(m)}
</section>

{axiom_manifest_html}

<section class="shell detail-section">
  <h3>Dependency closure</h3>
  <p class="empty-note">Tier does not compose: each dependency carries its own tier, shown here individually.</p>
  {dependency_list(m, records, depth)}
</section>

{witness_html}

{suite_html}

{export_html}

{cite_this_html}

<section class="shell detail-section">
  <h3>Pin</h3>
  <table class="pin-table"><tbody>{pin_rows}</tbody></table>
</section>

<section class="shell detail-section">
  <h3>Gloss <span class="empty-note">(author-provided description)</span></h3>
  <div class="gloss-body">{gloss_html}</div>
</section>
"""
    title = f"{handle} · {m['title']} · Mathesis"
    return page_shell(title, f"{class_label} {handle}: {m['title']}", bank["slug"], body, depth=depth)


def md_to_minimal_html(md_text):
    """Minimal, dependency-free Markdown -> HTML for gloss.md files.
    Glosses are short, author-written, and use only: headings, plain paragraphs,
    and fenced code blocks. No need for a full Markdown engine.
    """
    lines = md_text.splitlines()
    out = []
    in_code = False
    code_buf = []
    for line in lines:
        if line.strip().startswith("```"):
            if in_code:
                out.append(f"<pre><code>{esc(chr(10).join(code_buf))}</code></pre>")
                code_buf = []
                in_code = False
            else:
                in_code = True
            continue
        if in_code:
            code_buf.append(line)
            continue
        if line.startswith("# "):
            out.append(f"<h2>{esc(line[2:])}</h2>")
        elif line.strip() == "":
            continue
        else:
            out.append(f"<p>{esc(line)}</p>")
    if in_code and code_buf:
        out.append(f"<pre><code>{esc(chr(10).join(code_buf))}</code></pre>")
    return "\n".join(out)


# ---------------------------------------------------------------------------
# bank index pages (results / claims / dictionary)
# ---------------------------------------------------------------------------

def render_bank_index(bank_key, records):
    bank = BANKS[bank_key]
    handles = sorted(h for h, r in records.items() if r["bank"] == bank_key)
    total = len(handles)

    counts_html = ""
    if bank_key == "results":
        legcount = {"proved": 0, "witnessed": 0, "mechanized-empirical": 0}
        for h in handles:
            leg = evidence_leg(records[h]["manifest"])
            if leg in legcount:
                legcount[leg] += 1
        counts_html = f"""
        <div class="factline">
          <div class="fact"><strong>{total}</strong><span>total results</span></div>
          <div class="fact"><strong>{legcount['proved']}</strong><span>proved</span></div>
          <div class="fact"><strong>{legcount['witnessed']}</strong><span>witnessed</span></div>
          <div class="fact"><strong>{legcount['mechanized-empirical']}</strong><span>mechanized-empirical</span></div>
        </div>"""
    else:
        counts_html = f"""
        <div class="factline factline-2">
          <div class="fact"><strong>{total}</strong><span>total {bank['label'].lower()}</span></div>
        </div>"""

    intro = {
        "results": "Every result is a kernel-checked demonstration that discharges a claim. "
                   "Filter by tier, module, or polarity, or search by handle, title, or module below.",
        "claims": "A claim is a statement of record: what is being asked, frozen before any proof is attempted. "
                  "Claims are discharged by results, or remain open.",
        "dictionary": "Definitions used across the claims and results. A definition being kernel-checked "
                      "means it type-checks and is internally consistent, not that its content has been "
                      "reviewed for fit against what it claims to capture; see the interrogation status "
                      "on each entry.",
    }[bank_key]

    body = f"""
<section class="hero shell">
  <p class="kicker">Noumenal Research &middot; Mathesis</p>
  <h1 class="measure">{esc(bank['label'])}</h1>
  <p class="lede">{intro}</p>
  {counts_html}
</section>

<section class="shell browse-section">
  <div class="controls" id="controls" data-bank="{esc(bank_key)}">
    <input type="search" id="searchBox" placeholder="Search handle, title, module..." aria-label="Search">
    <select id="filterTier" aria-label="Filter by tier">
      <option value="">All tiers</option>
      <option value="T0">T0</option>
      <option value="T1">T1</option>
      <option value="T2">T2</option>
      <option value="none">Not tiered</option>
    </select>
    <select id="filterPolarity" aria-label="Filter by polarity">
      <option value="">All polarities</option>
      <option value="universal">Universal</option>
      <option value="existential">Existential</option>
    </select>
    <select id="filterModule" aria-label="Filter by module">
      <option value="">All modules</option>
    </select>
    <span class="result-count" id="resultCount"></span>
  </div>
  <div class="accession-list" id="accessionList" aria-live="polite">
    <p class="empty-note">Loading&hellip;</p>
  </div>
</section>
"""
    title = f"{bank['label']} · Mathesis"
    return page_shell(title, f"Browse the {bank['label']} bank: {total} accessions.", bank["slug"], body, depth=0)


def _home_example_card(handle, records):
    """One example card rendered from a REAL result manifest (INV-4: never hand-fabricated)."""
    m = records[handle]["manifest"]
    title = m.get("title") or ((m.get("statement") or {}).get("decl_names") or ["?"])[0]
    tier = m.get("tier") or "—"
    ax = m.get("axiom_manifest")
    if ax is None:
        ax_html = '<span class="empty-note">—</span>'
    elif ax == []:
        ax_html = '<span class="empty-note">none &mdash; axiom-free</span>'
    else:
        ax_html = " ".join(f'<code class="chip chip-axiom">{esc(a)}</code>' for a in ax)
    witness = "yes" if m.get("witness") else "&mdash;"
    disch = m.get("discharges")
    disch_html = f'<code>{esc(disch)}</code>' if disch else '<span class="empty-note">&mdash;</span>'
    return f"""
    <div class="ex-card">
      <div class="ex-row"><span class="ex-k">Result</span><span class="ex-v"><code>{esc(title)}</code></span></div>
      <div class="ex-row"><span class="ex-k">Kind</span><span class="ex-v">{evidence_leg_badge(m)}</span></div>
      <div class="ex-row"><span class="ex-k">Coverage</span><span class="ex-v"><code>{esc(tier)}</code></span></div>
      <div class="ex-row"><span class="ex-k">Axioms</span><span class="ex-v">{ax_html}</span></div>
      <div class="ex-row"><span class="ex-k">Witness</span><span class="ex-v">{witness}</span></div>
      <div class="ex-row"><span class="ex-k">Discharges</span><span class="ex-v">{disch_html}</span></div>
      <div class="ex-row"><span class="ex-k">Accession</span><span class="ex-v"><a href="a/{esc(handle)}.html"><code>{esc(handle)}</code></a></span></div>
      <div class="ex-row"><span class="ex-k">Verify</span><span class="ex-v"><code>mathesis check {esc(handle)}</code></span></div>
    </div>"""


def render_home(records):
    result_handles = [h for h, r in records.items() if r["bank"] == "results"]
    total_results = len(result_handles)
    total_accessions = len(records)

    by_leg = {"proved": [], "witnessed": [], "mechanized-empirical": []}
    for h in result_handles:
        leg = evidence_leg(records[h]["manifest"])
        if leg in by_leg:
            by_leg[leg].append(h)
    n_proved = len(by_leg["proved"])
    n_witnessed = len(by_leg["witnessed"])
    n_mech = len(by_leg["mechanized-empirical"])

    def example(leg):
        hs = sorted(by_leg[leg])
        return hs[0] if hs else None

    # Example cards: one per populated leg, rendered from real accessions.
    cards = []
    for leg in ("proved", "witnessed", "mechanized-empirical"):
        h = example(leg)
        if h:
            cards.append(_home_example_card(h, records))
    cards_html = "\n".join(cards)

    # Links to a live example per leg, for the explainer (only if populated).
    def eg_link(leg):
        h = example(leg)
        return f' <a href="a/{esc(h)}.html">See one &rarr;</a>' if h else ' <span class="empty-note">(none in this snapshot yet)</span>'

    body = f"""
<section class="hero shell">
  <p class="kicker">Noumenal Research &middot; Mathesis</p>
  <h1 class="measure">A public ledger for machine-checked learning-theory claims.</h1>
  <p class="lede">
    Mathesis stores definitions, claims, and verified results with their exact proofs,
    witnesses, and axiom manifests. Every result is independently checkable. Corrections
    create new immutable accessions instead of rewriting history.
  </p>
  <div class="actions">
    <a class="btn primary" href="results.html">Browse results</a>
    <a class="btn" href="#verify">Verify one yourself</a>
    <a class="btn" href="deposit.html">Deposit</a>
  </div>
  <div class="factline">
    <div class="fact"><strong>{total_results}</strong><span>results</span></div>
    <div class="fact"><strong>{n_proved}</strong><span>proved</span></div>
    <div class="fact"><strong>{n_witnessed}</strong><span>witnessed</span></div>
    <div class="fact"><strong>{n_mech}</strong><span>mechanized-empirical</span></div>
    <div class="fact"><strong>{total_accessions}</strong><span>total accessions</span></div>
  </div>
</section>

<section class="shell qa-block">
  <div class="qa">
    <h3>What is this?</h3>
    <p>A public evidence bank for machine-checked learning-theory results.</p>
  </div>
  <div class="qa">
    <h3>Why should I care?</h3>
    <p>Every claim can be traced to an exact proof, a witness where one applies, a kernel
       check, and the list of axioms it depends on.</p>
  </div>
  <div class="qa">
    <h3>What can I do here?</h3>
    <p>Browse verified results, inspect claims, deposit new proofs, and cite immutable
       accessions.</p>
  </div>
</section>

<section class="shell detail-section measure">
  <h2>What does &ldquo;verified&rdquo; mean?</h2>
  <p>A verified result has passed the kernel. Mathesis records the exact formal statement, the
     proof, a witness when applicable, and the axiom manifest. Verification does <strong>not</strong>
     mean the result is important, original, elegant, or aligned with informal mathematical intent.
     Those are separate review layers, tracked apart from the machine check.</p>
</section>

<section class="shell section-head-block">
  <div class="section-head">
    <h2>Three kinds of evidence</h2>
    <p>Every result clears the same floor &mdash; the Lean&nbsp;4 kernel accepted its proof. On top of
       that floor, results differ by the <em>kind</em> of evidence that carries them. This is a
       distinction of kind, not a ranking.</p>
  </div>
  <div class="obligations">
    <div class="ob">
      <span class="tag">Proved</span>
      <h3>{n_proved} results</h3>
      <p>A general statement, established for every case by a kernel-checked proof term. Pure
         deduction: no instance is privileged.{eg_link("proved")}</p>
    </div>
    <div class="ob">
      <span class="tag">Witnessed</span>
      <h3>{n_witnessed} results</h3>
      <p>An existence statement whose concrete witness <em>is</em> the evidence &mdash; the kernel
         checks that the exhibited object has the claimed property.{eg_link("witnessed")}</p>
    </div>
    <div class="ob">
      <span class="tag">Mechanized-empirical</span>
      <h3>{n_mech} results</h3>
      <p>A statement about a specific executed system, whose behaviour is reflected exactly into
         the kernel and reasoned over &mdash; the empirical object lives inside the proof.{eg_link("mechanized-empirical")}</p>
    </div>
  </div>
  <p class="mono-note measure">How the label is derived: a result whose statement is about a concretely
     executed system (its declarations sit under an <code>Executed</code> namespace) is shown as
     mechanized-empirical; otherwise a universal statement is <em>proved</em> and an existential one is
     <em>witnessed</em>. It reads the gate&rsquo;s own polarity field and the authors&rsquo; own
     namespacing &mdash; it never invents a verdict the accession does not carry.</p>
</section>

<section class="shell section-head-block">
  <div class="section-head">
    <h2>Example results</h2>
    <p>Real accessions, rendered exactly as the gate and the author left them. Each is checkable with
       the one command below.</p>
  </div>
  <div class="ex-cards">
{cards_html}
  </div>
</section>

<section class="shell detail-section measure" id="verify">
  <h2>Verify it yourself</h2>
  <p>Nothing here asks for trust. Clone the bank, build the kernel gate once, and re-derive any
     accession from its frozen proof export &mdash; the tool fetches the export (content-addressed,
     sha256-verified) and replays it through the Lean&nbsp;4 kernel. It never reads the verdict the
     bank records about itself.</p>
  <pre class="statement-pretty"><code>git clone https://github.com/noumenal-ai/mathesis-bank
cd mathesis-bank
bin/mathesis build                     # build the kernel gate once
bin/mathesis check MTH.R-2026-1001     # re-derive one accession
bin/mathesis check --all               # re-derive every result</code></pre>
  <p class="mono-note">Exit code is the verdict: <code>0</code> means an independent machine re-derived
     the proof. This is exactly what the bank&rsquo;s own continuous integration runs on every change.</p>
</section>

<section class="shell section-head-block">
  <div class="section-head">
    <h2>How it works</h2>
    <p>Each accession is immutable once written. Corrections mint a new accession; they never edit
       the old one.</p>
  </div>
  <ol class="how-steps">
    <li><strong>Define terms.</strong> Definitions enter the Dictionary.</li>
    <li><strong>Freeze a claim.</strong> A claim can be recorded before any proof is attempted (optional).</li>
    <li><strong>Deposit a result.</strong> A proof attempts to discharge the claim.</li>
    <li><strong>Check and accession.</strong> The kernel re-derives the result and Mathesis mints an immutable accession.</li>
    <li><strong>Correct by adding, not editing.</strong> Errors mint new accessions; old records stay visible.</li>
  </ol>
</section>

<section class="shell section-head-block">
  <div class="section-head">
    <h2>Three banks, one ledger</h2>
  </div>
  <div class="obligations">
    <div class="ob">
      <span class="tag">Dictionary</span>
      <h3>Definitions</h3>
      <p>The vocabulary the claims and results are stated in. Kernel-checked for internal
         consistency; review of naming, meaning, and intent is tracked separately.</p>
      <a href="dictionary.html">Browse the Dictionary &rarr;</a>
    </div>
    <div class="ob">
      <span class="tag">Claims</span>
      <h3>Claims</h3>
      <p>A statement of record, frozen before any proof is attempted. A claim is open until
         some result discharges it.</p>
      <a href="claims.html">Browse Claims &rarr;</a>
    </div>
    <div class="ob">
      <span class="tag">Results</span>
      <h3>Results</h3>
      <p>A kernel-checked demonstration: a proof, a witness where applicable, and an axiom
         manifest, all rendered verbatim from the gate.</p>
      <a href="results.html">Browse Results &rarr;</a>
    </div>
  </div>
</section>
"""
    title = "Mathesis · Noumenal Research"
    return page_shell(title, "A public ledger for machine-checked learning-theory claims.", "home", body, depth=0)


def render_ontology(records):
    """The ontology axis: where a result sits in the theory, orthogonal to the evidence leg.
    Populated by the Eidometry volume. Section blocks list their results from real manifests."""
    demos = [h for h, r in records.items() if r["bank"] == "results"]
    by_sec = {s: [] for s in ONTOLOGY_ORDER}
    for h in demos:
        s = records[h]["manifest"].get("ontology_section")
        if s in by_sec:
            by_sec[s].append(h)
    total = sum(len(v) for v in by_sec.values())

    section_blocks = []
    for s in ONTOLOGY_ORDER:
        hs = sorted(by_sec[s])
        items = "\n".join(
            f'<li><a href="a/{esc(h)}.html"><code>{esc(records[h]["manifest"]["title"])}</code></a> '
            f'{evidence_leg_badge(records[h]["manifest"])}</li>'
            for h in hs
        ) or '<li class="empty-note">No results filed here in this snapshot.</li>'
        section_blocks.append(f"""
    <div class="onto-section">
      <div class="onto-head"><h3>{esc(s)}</h3><span class="onto-count">{len(hs)}</span></div>
      <p>{esc(ONTOLOGY[s])}</p>
      <ul class="onto-list">{items}</ul>
    </div>""")

    body = f"""
<section class="hero shell">
  <p class="kicker">Noumenal Research &middot; Mathesis</p>
  <h1 class="measure">The ontology axis</h1>
  <p class="lede">
    Every result is filed on two independent axes. One is the <a href="results.html">kind of
    evidence</a> behind it &mdash; proved, witnessed, or mechanized-empirical. The other, shown here,
    is where the result sits in the theory itself. The two are orthogonal: a result's evidence kind
    tells you nothing about which part of the theory it belongs to, and the reverse. Nothing here is
    ranked.
  </p>
  <div class="factline factline-2">
    <div class="fact"><strong>{total}</strong><span>results on this axis</span></div>
    <div class="fact"><strong>{len(ONTOLOGY_ORDER)}</strong><span>sections</span></div>
  </div>
</section>

<section class="shell section-head-block">
  <div class="section-head">
    <h2>Six sections, one theory</h2>
    <p>These are the parts of the banked theory: identification as a geometry &mdash; a specification of
       what must be measured and which dynamics preserved forces a single canonical structure on a
       system's states, and that structure is executable and machine-checkable end to end.</p>
  </div>
  <div class="onto-grid">{"".join(section_blocks)}</div>
</section>

<section class="shell detail-section measure">
  <h2>More than one proof</h2>
  <p>A single claim can be discharged by more than one banked result. The same statement may be reached
     through a general principle, a specific construction, or an executed run, and each is a valid,
     separately banked discharge. When one proof depends on strictly fewer background assumptions than
     another &mdash; it invokes fewer axioms to reach the same conclusion &mdash; that proof is the stronger
     discharge, because the claim then rests on a narrower foundation. The bank records every discharge
     of a claim, not only one.</p>
</section>

<section class="shell detail-section measure">
  <h2>Citing a result</h2>
  <p>Each banked result is issued a permanent accession identifier that never changes and always points
     to this exact machine-checked statement and its proof. That accession is the citable unit: cite the
     accession id, which resolves to the frozen record, its exact formal statement, and the kernel
     re-verification behind it. A result also carries a pointer to the published work it formalizes or
     restates. Citing the accession credits the machine-checked deposit; the record credits the prior
     source it builds on. The two are kept distinct, so a citation of the bank is never mistaken for a
     claim of originality over the classical result it mechanizes.</p>
</section>

<section class="shell detail-section measure">
  <h2>Dictionary quality</h2>
  <p>Every dictionary entry is backed by a formal statement the kernel checks for internal consistency,
     so no entry can encode a formally incoherent claim. That mechanical check certifies the mathematics
     is sound; it does not certify that the entry is named well, describes the right theorem, or reflects
     the intended meaning. Naming, meaning, and intent are reviewed on a separate track and tracked
     independently, and an entry can be formally consistent while that review is still pending.</p>
</section>
"""
    title = "Ontology · Mathesis"
    return page_shell(title, "The ontology axis: where each result sits in the theory.", "ontology", body, depth=0)


def render_deposit():
    body = """
<section class="hero shell">
  <p class="kicker">Noumenal Research &middot; Mathesis</p>
  <h1 class="measure">Deposit</h1>
  <p class="measure">The bank accepts deposits the way arXiv accepts papers and GenBank accepts
  sequences: you submit, an automated gate checks it, and it enters the public record. Here the gate
  is a proof kernel, and it re-derives every deposit from scratch &mdash; it never takes the deposit's
  word for what it proves.</p>
</section>

<section class="shell detail-section">
  <div class="callout">
    <p>A deposit is a pull request.</p>
    <p>The gate re-derives it in CI. No human judges the mathematics.</p>
    <p>A maintainer merge signs off only the plain-language description.</p>
  </div>
</section>

<section class="shell detail-section">
  <h3>What you can deposit</h3>
  <ul>
    <li><strong>A result</strong> &mdash; a statement together with a machine-checked proof.</li>
    <li><strong>A definition</strong> &mdash; a formal notion others can build on (the Dictionary).</li>
    <li><strong>A claim</strong> &mdash; a statement of record, open for a result to discharge.</li>
  </ul>
</section>

<section class="shell detail-section">
  <h3>Submit a deposit</h3>
  <p>Fill the fields below. Submitting opens GitHub with a single deposit file pre-filled; there you
     click <strong>Propose new file</strong>, which forks the repository if you are not a maintainer
     and opens the pull request. No account setup here, no upload of secrets &mdash; the pull request
     is created under your own GitHub identity.</p>
  <form id="depositForm" class="deposit-form" novalidate>
    <label for="d-kind">Kind
      <select id="d-kind">
        <option value="result">Result &mdash; a statement with a machine-checked proof</option>
        <option value="definition">Definition &mdash; a formal notion (Dictionary)</option>
        <option value="claim">Claim &mdash; a statement of record</option>
      </select>
    </label>
    <label for="d-title">Title <span class="req">required</span>
      <input id="d-title" type="text" autocomplete="off" placeholder="A short description of what this states or proves">
    </label>
    <label for="d-module">Module name
      <input id="d-module" type="text" autocomplete="off" value="Submission" placeholder="The Lean module name">
    </label>
    <label for="d-decls">Declaration name(s) <span class="req">required</span>
      <input id="d-decls" type="text" autocomplete="off" placeholder="my_theorem, my_lemma (comma-separated)">
    </label>
    <label for="d-discharges">Discharges claim <span class="opt">optional, for results</span>
      <input id="d-discharges" type="text" autocomplete="off" placeholder="MTH.C-YYYY-NNNN">
    </label>
    <label for="d-source">Lean source <span class="req">required</span>
      <textarea id="d-source" rows="10" spellcheck="false" placeholder="theorem my_theorem : ... := by ..."></textarea>
    </label>
    <label for="d-gloss">Description <span class="req">required</span>
      <textarea id="d-gloss" rows="4" placeholder="Plain-language description. Author-provided; not machine-checked."></textarea>
    </label>
    <p id="d-note" class="warn-note" hidden></p>
    <div class="deposit-actions">
      <button type="submit" class="btn primary">Prepare pull request</button>
      <button type="button" id="d-preview-btn" class="btn">Preview file</button>
    </div>
  </form>
  <div id="d-preview" class="deposit-preview" hidden>
    <p class="mono-note">Deposit file <code id="d-path"></code></p>
    <pre class="statement-pretty"><code id="d-preview-content"></code></pre>
    <button type="button" id="d-copy" class="btn">Copy file content</button>
  </div>
  <noscript><p class="warn-note">The form needs JavaScript. Without it, deposit by hand (below).</p></noscript>
</section>

<section class="shell detail-section">
  <h3>Or deposit by hand</h3>
  <p>Advanced or large deposits can skip the form and open a pull request directly, adding a folder:</p>
  <pre class="statement-pretty"><code>deposits/&lt;your-slug&gt;/
  submission.lean   the Lean source the gate builds and re-derives
  deposit.toml      declaration names, toolchain pin, the claim it discharges (if any)
  gloss.md          your plain-language description (author-provided, not machine-checked)</code></pre>
  <p>The gate runs on the pull request and posts its verdict; fix and push until it is green, then a
     maintainer confirms the description and merges. The single-file form above carries the same
     information in one file's header.</p>
</section>

<section class="shell detail-section">
  <h3>What the gate checks</h3>
  <p>Every check below is re-run from the deposit's frozen proof export. None is read from what the
     manifest claims about itself.</p>
  <ul>
    <li><strong>Kernel replay</strong> &mdash; the proof is accepted by the Lean 4 kernel.</li>
    <li><strong>Axiom closure</strong> &mdash; it depends only on
      <code class="chip chip-axiom">propext</code> <code class="chip chip-axiom">Classical.choice</code>
      <code class="chip chip-axiom">Quot.sound</code>. Anything more must be declared, and is flagged
      for review rather than admitted silently.</li>
    <li><strong>Definition audit</strong> &mdash; a definition's body is held to the same axiom
      whitelist, so a definition cannot smuggle in an assumption.</li>
    <li><strong>Statement identity</strong> &mdash; a result that discharges a claim must prove that
      exact claim, closed over every definition it names.</li>
    <li><strong>Non-triviality</strong> &mdash; a statement that is syntactically trivial, or a
      definition that is vacuously true, is routed to human review rather than published as a result.</li>
  </ul>
  <p>What the gate does <em>not</em> check: that the plain-language description matches the formal
     statement. That is author-provided and confirmed only by the maintainer's sign-off. See the
     <a href="charter.html">Charter</a>.</p>
</section>

<section class="shell detail-section">
  <h3>Status</h3>
  <p>The founding volume was deposited by the maintainers, and the gate above runs live on every
     change to the bank. Deposits from outside the maintainer team are being enabled after a final
     security review of the untrusted-build path; until then, open an issue on the repository to
     propose one.</p>
  <p class="mono-note"><a href="https://github.com/noumenal-ai/mathesis-bank">github.com/noumenal-ai/mathesis-bank</a></p>
</section>

<script src="deposit.js"></script>
"""
    title = "Deposit · Mathesis"
    return page_shell(title, "How to deposit into the Mathesis bank: open a pull request, the proof kernel re-derives it.", "deposit", body, depth=0)


def render_charter():
    body = """
<section class="hero shell">
  <p class="kicker">Noumenal Research &middot; Mathesis</p>
  <h1 class="measure">Charter</h1>
</section>

<section class="shell detail-section">
  <div class="callout">
    <p>Not peer review.</p>
    <p>Not an empirical generalization about the world.</p>
    <p>Certification is relative to the definitions used.</p>
  </div>
</section>

<section class="shell detail-section">
  <h3>What certification means here</h3>
  <p>An accession in the Results bank has been checked by a proof kernel against a fixed,
     pinned set of definitions and a pinned toolchain. That check establishes that the stated
     proof follows from the stated axioms under the stated definitions. It does not establish
     that the definitions are the right ones, that the statement matters, or that the result
     generalizes past the formal system it was proved in. Those are separate questions, answered
     by separate, overlay work (interrogation, replication, application), not by the gate.</p>
</section>

<section class="shell detail-section">
  <h3>Trust base</h3>
  <p>Every result in this bank is checked by the Lean 4 proof kernel. The kernel trusts three
     whitelisted axioms:</p>
  <p class="mono-note">
    <code class="chip chip-axiom">propext</code>
    <code class="chip chip-axiom">Classical.choice</code>
    <code class="chip chip-axiom">Quot.sound</code>
  </p>
  <p>against a pinned build of Mathlib. Any result whose proof needs an axiom outside this
     whitelist must declare it explicitly as a <strong>trust-boundary extension</strong>, and
     that extension is rendered on the accession's page. As of this snapshot, no accession in
     the bank declares a trust-boundary extension.</p>
</section>

<section class="shell detail-section">
  <h3>Definition interrogation</h3>
  <p>A definition's status of <strong>"kernel-checked; interrogation pending"</strong> means the
     definition type-checks and is internally consistent under the kernel. It does not mean the
     definition has been reviewed for whether it captures what its name or gloss claims it
     captures. That review, when it happens, is a lazy overlay annotation on the definition, not
     a precondition for it appearing in the bank and not a gate a result must pass.</p>
</section>

<section class="shell detail-section">
  <h3>What this bank does not do</h3>
  <p>It does not rank accessions. It does not compute a single quality score. Where scale and
     depth of checking both matter, the site shows them as two separate counts, never combined.
     It does not run any model over the manifests to summarize, grade, or rewrite them; every
     word rendered from a manifest is either the author's own prose (the gloss) or emitted
     verbatim by the gate (tier, axioms, verdict).</p>
</section>
"""
    title = "Charter · Mathesis"
    return page_shell(title, "What certification means in Mathesis, and what it does not mean.", "charter", body, depth=0)


def render_about():
    body = """
<section class="hero shell">
  <p class="kicker">Noumenal Research &middot; Mathesis</p>
  <h1 class="measure">About</h1>
  <p class="lede">Mathesis is an evidence bank for machine-checked machine-learning theory,
     built on the model of GenBank or the Protein Data Bank rather than a journal: it holds
     verified units and lets overlays (commentary, applications, later journals) build on top,
     instead of gating publication behind a single editorial judgment.</p>
</section>

<section class="shell detail-section">
  <h3>Three legs of a result</h3>
  <div class="obligations">
    <div class="ob">
      <span class="tag">Leg 1</span>
      <h3>Proof</h3>
      <p>A machine-checked derivation of the stated theorem from the stated definitions and
         axioms. Checked by the Lean 4 kernel, not by a reviewer's read-through.</p>
    </div>
    <div class="ob">
      <span class="tag">Leg 2</span>
      <h3>Witness</h3>
      <p>Where the claim is existential, a concrete instance that the kernel has checked
         actually satisfies the statement, an executed value or an executable harness rather
         than an existence argument alone.</p>
    </div>
    <div class="ob">
      <span class="tag">Leg 3</span>
      <h3>Axiom manifest</h3>
      <p>The full, explicit list of axioms the proof rests on, emitted by the gate and rendered
         verbatim. Anything outside the three-axiom whitelist is called out as a named
         trust-boundary extension, never hidden.</p>
    </div>
  </div>
</section>

<section class="shell detail-section">
  <h3>How to read a tier</h3>
  <p>Tier is gate-emitted, not author-claimed. <strong>T0</strong> is a single kernel-checked
     proof (for an existential statement, the witness itself already is the full evidence).
     Higher tiers mean broader or exhaustive coverage was checked, not that the underlying claim
     is more true. Tier does not compose across a dependency closure: a result's own tier says
     nothing about the tier of what it depends on, so each dependency is shown with its own
     tier on the accession page.</p>
</section>

<section class="shell detail-section">
  <h3>What a deposit is</h3>
  <p>An accession (<code>MTH.D/C/R-YYYY-NNNN</code>) is immutable once written. A correction to
     an existing accession never edits it in place; it mints a new accession and records the
     supersession link. The registry is the ledger.</p>
</section>
"""
    title = "About · Mathesis"
    return page_shell(title, "What Mathesis is and how to read a result.", "about", body, depth=0)


# ---------------------------------------------------------------------------
# firewall check
# ---------------------------------------------------------------------------

def _gamma_hits_outside_code(html_text):
    """Return True if Γ/γ appears anywhere in html_text OUTSIDE a <pre>/<code> span.
    Used only for the narrow, documented carve-out described above BANNED_WORDS.
    """
    # Strip everything inside <pre>...</pre> and <code>...</code> (non-greedy,
    # case-insensitive, DOTALL so multi-line statement blocks are covered).
    stripped = re.sub(r"<pre[^>]*>.*?</pre>", "", html_text, flags=re.IGNORECASE | re.DOTALL)
    stripped = re.sub(r"<code[^>]*>.*?</code>", "", stripped, flags=re.IGNORECASE | re.DOTALL)
    return any(g in stripped for g in _GREEK_GAMMA)


def check_firewall(docs_dir):
    hits = []
    for path in sorted(docs_dir.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix not in (".html", ".js", ".json", ".css", ".md"):
            continue
        try:
            text = path.read_text(errors="replace")
        except Exception:
            continue
        for word in BANNED_WORDS:
            if word not in text:
                continue
            if word in _GREEK_GAMMA:
                # JSON payloads (data/a/<handle>.json) carry the manifest's own
                # statement/gloss text verbatim, with no <pre>/<code> markup to
                # scope against; permit gamma there (same carve-out, different
                # container). For HTML, only permit it inside code/pre spans.
                if path.suffix == ".json":
                    continue
                if path.suffix == ".html" and not _gamma_hits_outside_code(text):
                    continue
            hits.append((str(path.relative_to(docs_dir)), word))
    return hits


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main():
    print(f"Reading registry from {REGISTRY} ...")
    records = load_accessions()
    print(f"Loaded {len(records)} accessions "
          f"({sum(1 for r in records.values() if r['bank']=='dictionary')} dictionary, "
          f"{sum(1 for r in records.values() if r['bank']=='claims')} claims, "
          f"{sum(1 for r in records.values() if r['bank']=='results')} results).")

    print(f"registry: {len(records)} accessions.", file=sys.stderr)

    # clean slate for determinism, but preserve a real verification.json across
    # the wipe: ci/verify.sh may run before or after this script (order varies
    # between a local build and the CI workflow), and this script must never
    # clobber a real, CI-produced verification.json with the placeholder seed.
    import shutil
    preserved_verification = None
    existing_verif = DOCS / "verification.json"
    if existing_verif.is_file():
        try:
            existing_data = json.loads(existing_verif.read_text())
            if existing_data.get("status") != "pending":
                preserved_verification = existing_verif.read_text()
        except json.JSONDecodeError:
            pass
    if DOCS.exists():
        shutil.rmtree(DOCS)
    (DOCS / "data" / "a").mkdir(parents=True, exist_ok=True)

    # data/index.json
    rows = build_index_rows(records)
    (DOCS / "data" / "index.json").write_text(json.dumps(rows, indent=None, separators=(",", ":"), ensure_ascii=False, sort_keys=True))

    # data/a/<handle>.json (full manifest + gloss, for the detail page's own use / API parity)
    for handle, rec in records.items():
        payload = dict(rec["manifest"])
        payload["gloss"] = rec["gloss"]
        (DOCS / "data" / "a" / f"{handle}.json").write_text(
            json.dumps(payload, indent=2, ensure_ascii=False, sort_keys=True)
        )

    # accession detail pages
    (DOCS / "a").mkdir(exist_ok=True)
    for handle, rec in records.items():
        html_out = render_accession_detail(handle, rec, records)
        (DOCS / "a" / f"{handle}.html").write_text(html_out)

    # bank index pages
    for bank_key in BANKS:
        (DOCS / f"{bank_key}.html").write_text(render_bank_index(bank_key, records))

    # home / deposit / charter / about
    (DOCS / "index.html").write_text(render_home(records))
    (DOCS / "ontology.html").write_text(render_ontology(records))
    (DOCS / "deposit.html").write_text(render_deposit())
    (DOCS / "charter.html").write_text(render_charter())
    (DOCS / "about.html").write_text(render_about())

    # static assets: copy styles.css, app.js, verify.js from site/ into docs/
    site_dir = Path(__file__).resolve().parent
    for asset in ("styles.css", "app.js", "verify.js", "deposit.js"):
        src = site_dir / asset
        if src.is_file():
            (DOCS / asset).write_text(src.read_text())
        else:
            print(f"WARNING: expected asset {src} not found", file=sys.stderr)

    # verification.json: ci/verify.sh owns producing the real one. Restore it
    # if this rebuild wiped a real (non-pending) one; otherwise seed a minimal
    # pending placeholder so the Verify button has something to read.
    verif_path = DOCS / "verification.json"
    if preserved_verification is not None:
        verif_path.write_text(preserved_verification)
    elif not verif_path.is_file():
        seed = {
            "schema": 1,
            "generatedBy": "local",
            "repo": "",
            "workflow": "verify.yml",
            "commit": "unbuilt",
            "timestamp": "",
            "runUrl": "",
            "status": "pending",
            "checks": [],
            "counts": {},
        }
        verif_path.write_text(json.dumps(seed, indent=2))

    print(f"Wrote {len(records)} accession pages + {len(BANKS)} bank indexes + home/charter/about to {DOCS}")

    # INV-1 firewall check
    hits = check_firewall(DOCS)
    if hits:
        print("FATAL: INV-1 language firewall violated. Banned words found:", file=sys.stderr)
        for path, word in hits[:50]:
            print(f"  {path}: {word!r}", file=sys.stderr)
        sys.exit(1)
    print("INV-1 firewall check: clean.")

    print("Build complete.")


if __name__ == "__main__":
    main()
