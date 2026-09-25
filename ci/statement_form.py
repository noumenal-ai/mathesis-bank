#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# Mathesis — the form of a two-part deposit's statement, read off its EXPORT.
#
#   ci/statement_form.py <statement.export> <decl1> [<decl2> ...]
#   ci/statement_form.py --audit <adj.json> <n> <decl1..decln> [<root> ...]
#
# The first form checks the shape and prints the roots (below). The second
# reads the adjudicator's report on R, which the gate obtains by running it
# over the @decls plus those roots, and decides the statement's legs — see
# `audit` for why that run's exit code cannot be the answer.
#
# A statement (see ci/parse_deposit.py, "TWO-PART DEPOSITS") is definitions
# plus theorem statements whose every proof is exactly `sorry`. parse_deposit.py
# checks that on the SOURCE, which is cheap and names the line, but a lexer
# cannot see through a notation or a macro that expands to `sorry`, and the
# source is not what gets frozen. The export is. So the gate checks the form
# again here, on the lean4export text of the statement's @decls closure — the
# exact bytes that become the reference R.
#
# For each target it requires:
#   * the target is a `theorem` in R;
#   * its TYPE never mentions `sorryAx` (a statement about a sorry is a
#     statement about nothing);
#   * its VALUE is exactly an elaborated `sorry`: some leading `fun` binders
#     (no more than the type has `∀`s to introduce), then `sorryAx A false`
#     with Lean's unique-sorry tag as an optional third argument, and nothing
#     else — the tag built only from Name/Nat literal constructors, and every
#     other constant in the value one that the target's own type mentions.
#     A real proof has to name something the statement does not (`Eq.refl`,
#     `True.intro`, a lemma), so it cannot fit through this shape;
#
# and prints, one per line, the ROOTS of the statement: every constant a
# target's type mentions directly (including structure names reached only
# through a projection, as the adjudicator's own closure does). The gate hands
# the roots to `mathesis-adjudicate` as targets over R and requires each to
# pass the axiom audit. Every definition the statement depends on is reachable
# from a root, so that is the check that the DEFINITIONS are axiom-clean —
# sorry-free, permitted axioms only, no redefinition of a trusted constant —
# done by the trusted exe and not by this script.
#
# WHAT THIS IS NOT: a kernel. It reads structure and names, never types, and a
# pass here admits nothing. R is replayed through the trusted kernel by the
# same adjudicator run, and it is that run's verdict the gate keys on. This
# script only decides whether the statement has the SHAPE of a statement.
#
# Fails closed: any record it cannot interpret, any reference to an interned
# name/expression it has not seen, is an error, not a skip.
# ---------------------------------------------------------------------------
import json
import sys

# The constants Lean's unique-sorry tag is built from. Since Lean 4.17 an explicit `sorry`
# elaborates to `sorryAx (Lean.Name → T) false <tag>`, where <tag> is a Name literal recording
# where the sorry was written. Measured at v4.31.0:
#   theorem double_eq (n : Nat) : double n = 2 * n := sorry
#     value: fun n => sorryAx (Lean.Name → double n = 2 * n) Bool.false
#                       (Lean.Name.num (Lean.Name.str ... "_hyg") 12)
TAG_CONSTS = frozenset((
    "Lean.Name", "Lean.Name.anonymous", "Lean.Name.str", "Lean.Name.num",
    "OfNat.ofNat", "instOfNatNat", "Nat", "String",
))


def die(msg):
    sys.stderr.write("statement_form: " + msg + "\n")
    sys.exit(1)


class Export:
    """Just enough of lean4export format 3.1.0 to walk names and expressions.

    The authority on the format is `loadFrozenText` (backend-gate/Mathesis/Manifest.lean); see
    ci/export_stats.py for the record shapes. An `inductive` record bundles several constants.
    """

    def __init__(self, path):
        self.names = {0: None}  # 0 is the anonymous name
        self.exprs = {}
        self.decls = {}  # constant name -> (kind, record)
        try:
            fh = open(path, "r", encoding="utf-8")
        except OSError as e:
            die("cannot read %s: %s" % (path, e))
        with fh:
            for n, raw in enumerate(fh, 1):
                if not raw.strip():
                    continue
                try:
                    rec = json.loads(raw)
                except ValueError:
                    die("line %d of %s is not JSON" % (n, path))
                self._add(rec, n)

    def name(self, i):
        if i not in self.names:
            die("reference to an undeclared name #%s" % i)
        return self.names[i]

    def _add(self, rec, n):
        if "in" in rec:
            if "str" in rec:
                pre = self.name(rec["str"]["pre"])
                self.names[rec["in"]] = (pre + "." if pre else "") + rec["str"]["str"]
            elif "num" in rec:
                pre = self.name(rec["num"]["pre"])
                self.names[rec["in"]] = (pre + "." if pre else "") + str(rec["num"]["i"])
            else:
                die("line %d: unrecognised name record" % n)
        elif "ie" in rec:
            self.exprs[rec["ie"]] = rec
        elif "il" in rec or "meta" in rec:
            pass  # levels carry no constants; the meta header is informational
        elif "inductive" in rec:
            for group in ("types", "ctors", "recs"):
                for c in rec["inductive"].get(group) or []:
                    self.decls[self.name(c["name"])] = (group, c)
        else:
            for kind in ("thm", "def", "axiom", "opaque", "quot"):
                if kind in rec:
                    self.decls[self.name(rec[kind]["name"])] = (kind, rec[kind])
                    break
            else:
                die("line %d: unrecognised record %s" % (n, sorted(rec)[:3]))

    def node(self, i):
        e = self.exprs.get(i)
        if e is None:
            die("reference to an undeclared expression #%s" % i)
        for k in e:
            if k != "ie":
                return k, e[k]
        die("expression #%s has no body" % i)

    def children(self, i):
        k, v = self.node(i)
        if k == "app":
            return [v["fn"], v["arg"]]
        if k in ("lam", "forallE"):
            return [v["type"], v["body"]]
        if k == "letE":
            return [v["type"], v["value"], v["body"]]
        if k == "mdata":
            return [v["expr"]]
        if k == "proj":
            return [v["struct"]]
        if k in ("const", "bvar", "sort", "natVal", "strVal", "fvar", "mvar", "lit"):
            return []
        die("unrecognised expression kind %r (#%s)" % (k, i))

    def consts(self, i, with_proj=True):
        """Every constant named in expression `i`, plus (with_proj) projection structure names —
        the same set `runForUsedConsts` enqueues for a type in the adjudicator."""
        out, seen, stack = set(), set(), [i]
        while stack:
            j = stack.pop()
            if j in seen:
                continue
            seen.add(j)
            k, v = self.node(j)
            if k == "const":
                out.add(self.name(v["name"]))
            elif k == "proj" and with_proj:
                out.add(self.name(v["typeName"]))
            stack.extend(self.children(j))
        return out

    def spine(self, i):
        """(head, [args]) of an application."""
        args = []
        k, v = self.node(i)
        while k == "app":
            args.append(v["arg"])
            i = v["fn"]
            k, v = self.node(i)
        return i, args[::-1]


def check_target(ex, decl):
    """Die unless `decl` is a theorem of R whose value is exactly `sorry`. Return its roots."""
    if decl not in ex.decls:
        die("@decls target %r is not in the statement export" % decl)
    kind, rec = ex.decls[decl]
    if kind != "thm":
        die("@decls target %r is a %s in the statement, not a theorem\n"
            "  A statement's targets are theorem statements, each proved by exactly `sorry`."
            % (decl, {"def": "definition", "types": "type"}.get(kind, kind)))

    type_consts = ex.consts(rec["type"])
    if "sorryAx" in type_consts:
        die("the statement of %r itself mentions `sorry`" % decl)

    # Leading binders: a `fun` for each `∀` the elaborator introduced before reaching `sorry`.
    foralls, t = 0, rec["type"]
    while ex.node(t)[0] == "forallE":
        foralls += 1
        t = ex.node(t)[1]["body"]
    lams, body, binder_types = 0, rec["value"], []
    while ex.node(body)[0] == "lam":
        lams += 1
        binder_types.append(ex.node(body)[1]["type"])
        body = ex.node(body)[1]["body"]

    head, args = ex.spine(body)
    hk, hv = ex.node(head)
    bad = None
    if hk != "const" or ex.name(hv["name"]) != "sorryAx":
        bad = "its proof is not `sorry`"
    elif lams > foralls:
        bad = "its proof introduces more binders than its statement has"
    elif len(args) not in (2, 3):
        bad = "its `sorry` is applied to something"
    else:
        synth_k, synth_v = ex.node(args[1])
        if synth_k != "const" or ex.name(synth_v["name"]) != "Bool.false":
            # `sorryAx _ true` is a SYNTHETIC sorry: the elaborator's stand-in for a term that
            # failed to elaborate, which a successful build never leaves behind.
            bad = "its `sorry` is not an explicit one"
        elif len(args) == 3:
            tag = ex.consts(args[2])
            kinds = set()
            stack = [args[2]]
            while stack:
                j = stack.pop()
                kinds.add(ex.node(j)[0])
                stack.extend(ex.children(j))
            if not tag <= TAG_CONSTS or not kinds <= {"app", "const", "natVal", "strVal"}:
                bad = "its `sorry` carries a tag that is not a name literal"
    if bad is None:
        allowed = type_consts | TAG_CONSTS | {"sorryAx", "Bool", "Bool.false"}
        extra = set()
        for j in binder_types + [args[0]]:
            extra |= ex.consts(j) - allowed
        if extra:
            bad = "its proof names %s, which its statement does not" % ", ".join(
                "`%s`" % x for x in sorted(extra)[:5])
    if bad:
        die("@decls target %r: %s\n"
            "  Every theorem in the `@statement` section is proved by exactly `sorry`; the "
            "proof goes in `@proof`." % (decl, bad))
    return type_consts


def clean(s, n=160):
    # Names here come from the depositor's export. Lean permits «quoted» identifiers holding
    # almost anything, so strip what would break out of an inline code span or forge a report
    # row — the same reasoning as the gate's own rendering of candidate target rows.
    s = " ".join(str(s).split())
    return s.replace("`", "").replace("|", "")[:n]


def audit(argv):
    """Read the adjudicator's report on R and decide the statement legs.

        statement_form.py --audit <adj.json> <n> <decl1..decln> [<root> ...]

    The adjudicator was run over R with the @decls AND the roots as targets. The exit code of
    that run is 1 by construction — every @decl reaches sorryAx, which is the point of a
    statement — so it cannot be keyed on. This reads the report instead, and requires:
      * replay of R accepted by the trusted kernel;
      * each @decl a theorem whose audit fails for exactly one reason: sorryAx. Any other failure
        (another illegal axiom, a redefinition) is a real one. Only sorryAx can be reached
        through a value that check_target passed, so a clean root set makes this deterministic;
      * each root's audit PASSING: the definitions are sorry-free and use permitted axioms only.
    Prints `ROW <markdown>` lines, `TRIVIAL <text>` lines, then `VERDICT ok|fail`.
    """
    try:
        rep = json.load(open(argv[0], "r", encoding="utf-8"))
        n = int(argv[1])
    except (OSError, ValueError, IndexError):
        die("--audit: unreadable report or arguments")
    decls, roots = argv[2:2 + n], argv[2 + n:]
    if len(decls) != n or not decls:
        die("--audit: expected %d decls" % n)
    targets = {t.get("decl"): t for t in (rep.get("targets") or []) if isinstance(t, dict)}
    rows, trivial, ok = [], [], True

    replay = (rep.get("replay") or {}).get("accepted") is True
    ok &= replay
    rows.append("| replay R (trusted kernel) | %s |" % ("pass" if replay else "**fail**"))

    def reason(t):
        if t is None:
            return "absent from the report"
        if t.get("illegal_axiom"):
            return "illegal axiom `%s`" % clean(t["illegal_axiom"])
        if t.get("redefined_constant"):
            return "redefines `%s`, which the trusted reference defines differently" % clean(
                t["redefined_constant"])
        return clean(t.get("failure") or "fail")

    for d in decls:
        t = targets.get(d)
        good = (t is not None and t.get("kind") == "theorem" and t.get("axiom_audit") == "fail"
                and t.get("illegal_axiom") == "sorryAx"
                and t.get("failure") == "illegal axiom reached: 'sorryAx'")
        ok &= good
        rows.append("| `%s` proved by exactly `sorry` | %s |" % (
            clean(d), "pass" if good else "**fail** (%s)" % reason(t)))
        if t is not None and t.get("triviality"):
            trivial.append("%s: %s" % (clean(d), clean(t["triviality"])))

    failed = []
    for r in roots:
        t = targets.get(r)
        if t is None or t.get("axiom_audit") != "pass":
            failed.append((r, t))
    if failed:
        ok = False
        for r, t in failed:
            rows.append("| definitions: axioms `%s` (%s) | **fail** (%s) |" % (
                clean(r), clean((t or {}).get("kind", "absent")), reason(t)))
    else:
        rows.append("| definitions axiom-clean (%d constant%s the statement names) | pass |" % (
            len(roots), "" if len(roots) == 1 else "s"))

    for r in rows:
        sys.stdout.write("ROW " + r + "\n")
    for t in trivial:
        sys.stdout.write("TRIVIAL " + t + "\n")
    sys.stdout.write("VERDICT " + ("ok" if ok else "fail") + "\n")
    return 0


def main(argv):
    if len(argv) >= 2 and argv[1] == "--audit":
        return audit(argv[2:])
    if len(argv) < 3:
        die("usage: statement_form.py <statement.export> <decl1> [<decl2> ...]\n"
            "       statement_form.py --audit <adj.json> <n> <decl1..decln> [<root> ...]")
    ex = Export(argv[1])
    decls = argv[2:]
    roots = set()
    for d in decls:
        roots |= check_target(ex, d)
    # A root that is itself a sorry'd theorem (a statement whose TYPE mentions a proof of another
    # statement) is left in on purpose: the adjudicator's audit of it then fails on sorryAx and
    # the statement is refused. What it states would depend on a proof nobody has given.
    for r in sorted(roots):
        sys.stdout.write(r + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
