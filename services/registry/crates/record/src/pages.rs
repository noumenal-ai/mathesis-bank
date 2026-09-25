//! Every generated page. A post shows its author, the claim and its DAG, in the
//! author's own words where the source has them (docstrings, attributed), and
//! nothing of the platform's: no description, comment, tag, score or reaction
//! (SPEC.md §8.5). Discussion lives on the forum, never on the record. Verification is the baseline every post meets, so a post
//! never states it; its ⋯ menu leads to the claim's and the argument's pages,
//! where the DOI, the citation and a small verification section live.

use crate::html::{B, EM_DASH, escape, label};
use crate::jsonc::ts;
use crate::model::{Claim, Profile};
use crate::snapshot::{ArgumentView, Snapshot};
use accession::{Accession, citation};

pub fn shell(page: &str, body: &str, profile_href: Option<&str>) -> String {
    format!(
        "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n\
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n\
<title>{title}</title>\n<link rel=\"stylesheet\" href=\"/assets/record.css\">\n\
<script type=\"module\" src=\"/assets/app.js\"></script>\n</head>\n\
<body data-page=\"{page}\" data-base-href=\"/\">\n{nav}\n{body}\n</body>\n</html>\n",
        title = escape(label("mathesis")),
        page = page,
        nav = nav(profile_href, page),
        body = body
    )
}

/// The nav is unconditional: the same items, labels and targets on every
/// generated page, so its bytes never vary.
pub fn nav(profile_href: Option<&str>, page: &str) -> String {
    let mut b = B::new();
    b.open("header", "class=\"mth-nav\"");
    b.open("a", "class=\"mth-nav__mark\" href=\"/\"");
    b.text(label("mathesis"));
    b.close("a");
    b.open("nav", "class=\"mth-nav__links\" aria-label=\"Mathesis\"");
    let mut items: Vec<(&str, &str)> = vec![("posts", "/")];
    if let Some(href) = profile_href {
        items.push(("profile", href));
    }
    items.push(("collection", "/collection/claims"));
    items.push(("write", "/ide/"));
    items.push(("about", "/about"));
    for (key, href) in items {
        let current = match (key, page) {
            ("posts", "posts")
            | ("profile", "profile")
            | ("collection", "collection")
            | ("write", "ide")
            | ("about", "about") => " aria-current=\"page\"",
            _ => "",
        };
        b.open(
            "a",
            &format!("class=\"mth-nav__link\" href=\"{href}\"{current}"),
        );
        b.text(label(key));
        b.close("a");
    }
    b.close("nav");
    b.close("header");
    b.s
}

/// A node's DOM id: the argument's accession and the node's own name, hashed to
/// a form that is a legal fragment identifier whatever a Lean decl contains.
fn node_anchor(argument: &str, decl: &str) -> String {
    let mut h: u64 = 0xcbf2_9ce4_8422_2325;
    for byte in decl.as_bytes() {
        h ^= *byte as u64;
        h = h.wrapping_mul(0x1000_0000_01b3);
    }
    format!("n-{}-{:016x}", argument.replace('.', "-"), h)
}

fn chip(b: &mut B, acc: &str, field: &str) {
    b.val(
        "a",
        field,
        acc,
        &format!("class=\"mth-chip\" href=\"/a/{acc}\""),
    );
}

// --------------------------------------------------------------- post regions

/// Region 1 — the claim.
fn region_claim(b: &mut B, claim: &Claim, clamp: bool) {
    b.open("section", "class=\"mth-post__claim\"");
    // The author's own words open the claim: attributed, above the statement
    // the kernel checked.
    if let Some(doc) = words(&claim.doc) {
        b.doc("claim.doc", doc, "mth-docstring--thesis");
    }
    b.open("div", "class=\"mth-kv\"");
    b.lab("span", "mth-kv__k", "decl");
    b.val(
        "span",
        "claim.decl_name",
        &claim.decl_name,
        "class=\"mth-mono\"",
    );
    b.close("div");
    b.statement(
        "claim.pretty",
        &claim.pretty,
        if clamp { "mth-lean--clamp" } else { "" },
    );
    b.open(
        "button",
        "class=\"mth-btn\" type=\"button\" data-copy=\"claim.pretty\"",
    );
    b.text(label("copy"));
    b.close("button");
    b.val("span", "clipboard.state", "", "class=\"mth-clip\" hidden");
    b.close("section");
}

/// Region 2 — the argument DAG. List layout is server-rendered and is the no-JS
/// form; the graph is emitted beside it with the fixed lattice geometry, so the
/// same record always yields the same SVG.
fn region_dag(b: &mut B, a: &ArgumentView, input: &Snapshot, in_stream: bool) {
    b.open("section", "class=\"mth-dag\" data-region=\"dag\"");
    let oversized = a.argument.node_count > 400 || a.argument.edge_count > 4000;
    b.open("div", "class=\"mth-dag__toolbar\"");
    b.lab("span", "mth-kv__k", "layout");
    b.open(
        "button",
        &format!(
            "class=\"mth-btn\" type=\"button\" data-layout=\"graph\"{}",
            if oversized {
                " disabled aria-disabled=\"true\""
            } else {
                ""
            }
        ),
    );
    b.text(label("graph"));
    b.close("button");
    b.open(
        "button",
        "class=\"mth-btn\" type=\"button\" data-layout=\"list\"",
    );
    b.text(label("list"));
    b.close("button");
    b.open(
        "button",
        "class=\"mth-btn\" type=\"button\" data-dag=\"expand-all\"",
    );
    b.text(label("expandAll"));
    b.close("button");
    b.open(
        "button",
        "class=\"mth-btn\" type=\"button\" data-dag=\"collapse-all\"",
    );
    b.text(label("collapseAll"));
    b.close("button");
    b.close("div");

    // The legend: one entry per role this argument has, in its colours.
    let root = a.nodes.iter().find(|n| n.is_root);
    b.open("div", "class=\"mth-dag__legend\"");
    for (role, key, present) in [
        ("thesis", "thesis", true),
        ("step", "step", a.nodes.len() > 1),
        (
            "hypothesis",
            "hypothesis",
            root.is_some_and(|r| !r.hypotheses.is_empty()),
        ),
        (
            "definition",
            "definition",
            a.leaves.iter().any(|l| l.role != "cited"),
        ),
        (
            "cited",
            "citedResult",
            a.leaves.iter().any(|l| l.role == "cited"),
        ),
    ] {
        if present {
            b.lab("span", &format!("mth-role mth-role--{role}"), key);
        }
    }
    b.close("div");

    if !oversized {
        dag_svg(b, a, in_stream);
    }

    b.open("ol", "class=\"mth-dag-list\" data-layout=\"list\"");
    for n in &a.nodes {
        b.open(
            "li",
            &format!(
                "class=\"mth-dag-list__item mth-dag-list__item--{}\" id=\"{}\" data-citable=\"{}\" data-decl=\"{}\"",
                if n.is_root { "thesis" } else { "step" },
                node_anchor(&a.argument.accession, &n.decl_name),
                n.citable,
                escape(&n.decl_name)
            ),
        );
        b.open("div", "class=\"mth-kv\"");
        b.lab("span", "mth-kv__k", "decl");
        b.val(
            "span",
            "argument_node.decl_name",
            &n.decl_name,
            "class=\"mth-mono\"",
        );
        b.lab("span", "mth-kv__k", "declarationKind");
        b.val("span", "argument_node.kind", &n.kind, "");
        b.close("div");
        // The thesis's own words open the post; a step's open its item.
        if !n.is_root {
            if let Some(doc) = words(&n.doc) {
                b.doc("argument_node.doc", doc, "");
            }
        }
        b.statement("argument_node.pretty", &n.pretty, "mth-lean--sm");
        if !n.dictionary_leaves.is_empty() {
            b.open("div", "class=\"mth-dag-list__leaves\"");
            for l in &n.dictionary_leaves {
                // A chip links to its blueprint anchor when the blueprint carries
                // one; base-substrate constants appear nowhere.
                match input.blueprint_anchor(l) {
                    Some(anchor) => {
                        b.val(
                            "a",
                            "dictionary_constant.name",
                            l,
                            &format!(
                                "class=\"mth-chip mth-chip--dict\" href=\"{}\"",
                                escape(&anchor)
                            ),
                        );
                    }
                    None => {
                        b.val(
                            "a",
                            "dictionary_constant.name",
                            l,
                            &format!(
                                "class=\"mth-chip mth-chip--dict\" href=\"#{}\"",
                                node_anchor(&a.argument.accession, l)
                            ),
                        );
                    }
                }
            }
            b.close("div");
        }
        let uses: Vec<&str> = a
            .edges
            .iter()
            .filter(|e| e.used_by == n.decl_name)
            .map(|e| e.uses.as_str())
            .collect();
        let used_by: Vec<&str> = a
            .edges
            .iter()
            .filter(|e| e.uses == n.decl_name)
            .map(|e| e.used_by.as_str())
            .collect();
        for (key, list) in [("uses", &uses), ("usedBy", &used_by)] {
            if list.is_empty() {
                continue;
            }
            b.open("details", "class=\"mth-disclosure\"");
            b.lab("summary", "", key);
            b.open("ul", "");
            for d in list.iter() {
                b.open("li", "");
                b.open(
                    "a",
                    &format!("href=\"#{}\"", node_anchor(&a.argument.accession, d)),
                );
                b.val("span", "argument_node.decl_name", d, "class=\"mth-mono\"");
                b.close("a");
                b.close("li");
            }
            b.close("ul");
            b.close("details");
        }
        b.close("li");
    }
    if let Some(root) = root {
        for (i, h) in root.hypotheses.iter().enumerate() {
            b.open(
                "li",
                &format!(
                    "class=\"mth-dag-list__item mth-dag-list__item--hypothesis\" id=\"{}\"",
                    hypothesis_anchor(&a.argument.accession, i)
                ),
            );
            b.open("div", "class=\"mth-kv\"");
            b.lab("span", "mth-role mth-role--hypothesis", "hypothesis");
            b.val(
                "span",
                "argument_hypothesis.name",
                &h.name,
                "class=\"mth-mono\"",
            );
            b.close("div");
            b.statement("argument_hypothesis.pretty", &h.pretty, "mth-lean--sm");
            b.close("li");
        }
    }
    for l in &a.leaves {
        let (role, key) = if l.role == "cited" {
            ("cited", "citedResult")
        } else {
            ("definition", "definition")
        };
        b.open(
            "li",
            &format!(
                "class=\"mth-dag-list__item mth-dag-list__item--{role}\" id=\"{}\" data-decl=\"{}\"",
                node_anchor(&a.argument.accession, &l.decl_name),
                escape(&l.decl_name)
            ),
        );
        b.open("div", "class=\"mth-kv\"");
        b.lab("span", &format!("mth-role mth-role--{role}"), key);
        b.val(
            "span",
            "dictionary_constant.name",
            &l.decl_name,
            "class=\"mth-mono\"",
        );
        b.val("span", "dictionary_constant.kind", &l.kind, "");
        if let Some(author) = &l.author {
            cited_person(b, input, author);
        }
        b.close("div");
        if let Some(doc) = words(&l.doc) {
            b.doc("dictionary_constant.doc", doc, "");
        }
        b.statement("dictionary_constant.pretty", &l.pretty, "mth-lean--sm");
        b.close("li");
    }
    b.close("ol");
    b.close("section");
}

/// A docstring worth rendering: present and not blank.
fn words(doc: &Option<String>) -> Option<&str> {
    doc.as_deref().filter(|d| !d.trim().is_empty())
}

fn hypothesis_anchor(argument: &str, i: usize) -> String {
    format!("h-{}-{i}", argument.replace('.', "-"))
}

/// One vertex of the drawn graph: a step of the argument (the thesis is its
/// root), a hypothesis of the thesis, or a definition or cited result the
/// argument rests on. `title` and `sub` are the two lines of its box, each a
/// catalogued field and its text.
struct Vertex<'a> {
    id: String,
    role: &'static str,
    depth: i32,
    rank: i32,
    title: (&'static str, String),
    sub: (&'static str, &'a str),
}

/// `x = 24 + depth·260`, `y = 24 + order·112`, one down and one up barycenter
/// pass with ties broken by id byte order (SPEC.md §8.5). A hypothesis sits one
/// column right of the thesis; a definition or cited result one column right of
/// the deepest step that uses it.
fn dag_svg(b: &mut B, a: &ArgumentView, in_stream: bool) {
    use std::collections::{HashMap, HashSet};
    let mut verts: Vec<Vertex> = Vec::new();
    let mut edges: Vec<(String, String)> = a
        .edges
        .iter()
        .map(|e| (e.used_by.clone(), e.uses.clone()))
        .collect();
    let mut leaf_depth: HashMap<&str, i32> = HashMap::new();
    for n in &a.nodes {
        verts.push(Vertex {
            id: n.decl_name.clone(),
            role: if n.is_root { "thesis" } else { "step" },
            depth: n.depth,
            rank: n.topo,
            title: ("argument_node.decl_name", short(&n.decl_name)),
            sub: ("argument_node.kind", &n.kind),
        });
        for l in &n.dictionary_leaves {
            let d = leaf_depth.entry(l.as_str()).or_insert(0);
            *d = (*d).max(n.depth + 1);
            edges.push((n.decl_name.clone(), l.clone()));
        }
        if n.is_root {
            for (i, h) in n.hypotheses.iter().enumerate() {
                let id = format!("hypothesis {i}");
                edges.push((n.decl_name.clone(), id.clone()));
                verts.push(Vertex {
                    id,
                    role: "hypothesis",
                    depth: 1,
                    rank: i as i32 - n.hypotheses.len() as i32,
                    title: ("argument_hypothesis.label", short_term(&h.pretty)),
                    sub: ("argument_hypothesis.name", &h.name),
                });
            }
        }
    }
    let base = a.nodes.len() as i32;
    for (i, l) in a.leaves.iter().enumerate() {
        let Some(&depth) = leaf_depth.get(l.decl_name.as_str()) else {
            continue;
        };
        verts.push(Vertex {
            id: l.decl_name.clone(),
            role: if l.role == "cited" { "cited" } else { "definition" },
            depth,
            rank: base + i as i32,
            title: ("dictionary_constant.name", short(&l.decl_name)),
            sub: ("dictionary_constant.kind", &l.kind),
        });
    }
    let ids: HashSet<&str> = verts.iter().map(|v| v.id.as_str()).collect();
    edges.retain(|(u, v)| ids.contains(u.as_str()) && ids.contains(v.as_str()));
    edges.sort();
    edges.dedup();

    let max_depth = verts.iter().map(|v| v.depth).max().unwrap_or(0);
    let mut columns: Vec<Vec<&Vertex>> = vec![Vec::new(); (max_depth + 1) as usize];
    for v in &verts {
        columns[v.depth as usize].push(v);
    }
    for c in columns.iter_mut() {
        c.sort_by(|x, y| x.rank.cmp(&y.rank).then(x.id.cmp(&y.id)));
    }
    let mut order: HashMap<&str, f64> = HashMap::new();
    for c in columns.iter() {
        for (i, v) in c.iter().enumerate() {
            order.insert(v.id.as_str(), i as f64);
        }
    }
    for pass in 0..2 {
        let range: Vec<usize> = if pass == 0 {
            (1..columns.len()).collect()
        } else {
            (0..columns.len().saturating_sub(1)).rev().collect()
        };
        for ci in range {
            let mut scored: Vec<(f64, &Vertex)> = columns[ci]
                .iter()
                .map(|v| {
                    let neighbours: Vec<f64> = edges
                        .iter()
                        .filter_map(|(used_by, uses)| {
                            if pass == 0 && *uses == v.id {
                                order.get(used_by.as_str()).copied()
                            } else if pass == 1 && *used_by == v.id {
                                order.get(uses.as_str()).copied()
                            } else {
                                None
                            }
                        })
                        .collect();
                    let score = if neighbours.is_empty() {
                        order.get(v.id.as_str()).copied().unwrap_or(0.0)
                    } else {
                        neighbours.iter().sum::<f64>() / neighbours.len() as f64
                    };
                    (score, *v)
                })
                .collect();
            scored.sort_by(|x, y| {
                x.0.partial_cmp(&y.0)
                    .unwrap_or(std::cmp::Ordering::Equal)
                    .then(x.1.id.cmp(&y.1.id))
            });
            columns[ci] = scored.iter().map(|(_, v)| *v).collect();
            for (i, v) in columns[ci].iter().enumerate() {
                order.insert(v.id.as_str(), i as f64);
            }
        }
    }
    let mut pos: HashMap<&str, (i32, i32)> = HashMap::new();
    let mut max_rows = 0usize;
    for (d, c) in columns.iter().enumerate() {
        max_rows = max_rows.max(c.len());
        for (i, v) in c.iter().enumerate() {
            pos.insert(v.id.as_str(), (24 + d as i32 * 260, 24 + i as i32 * 112));
        }
    }
    let w = 24 + (max_depth + 1) * 260;
    let h = 24 + max_rows as i32 * 112;
    b.raw(&format!(
        "<div class=\"mth-dag__viewport{}\">",
        if in_stream {
            " mth-dag__viewport--stream"
        } else {
            ""
        }
    ));
    b.raw(&format!(
        "<svg class=\"mth-dag__graph\" data-layout=\"graph\" viewBox=\"0 0 {w} {h}\" \
         width=\"{w}\" height=\"{h}\" role=\"presentation\">"
    ));
    for (used_by, uses) in &edges {
        let (Some(&(x1, y1)), Some(&(x2, y2))) =
            (pos.get(used_by.as_str()), pos.get(uses.as_str()))
        else {
            continue;
        };
        b.raw(&format!(
            "<path class=\"mth-dag__edge\" d=\"M{} {} C{} {} {} {} {} {}\"/>",
            x1 + 220,
            y1 + 44,
            x1 + 240,
            y1 + 44,
            x2 - 20,
            y2 + 44,
            x2,
            y2 + 44
        ));
    }
    for v in &verts {
        let Some(&(x, y)) = pos.get(v.id.as_str()) else {
            continue;
        };
        b.raw(&format!(
            "<g class=\"mth-dag__node mth-dag__node--{}\" transform=\"translate({x},{y})\">\
             <rect width=\"220\" height=\"88\" rx=\"4\"/>",
            v.role
        ));
        b.val("text", v.title.0, &v.title.1, "x=\"12\" y=\"24\"");
        b.val(
            "text",
            v.sub.0,
            v.sub.1,
            "x=\"12\" y=\"44\" class=\"mth-dag__kind\"",
        );
        b.raw("</g>");
    }
    b.raw("</svg>");
    b.raw("</div>");
}

/// A Lean expression shortened to fit a box: whitespace runs collapsed, then
/// cut at 26 characters like a decl name.
fn short_term(pretty: &str) -> String {
    let one: String = pretty.split_whitespace().collect::<Vec<_>>().join(" ");
    if one.chars().count() > 26 {
        one.chars().take(25).collect::<String>() + "…"
    } else {
        one
    }
}

fn short(decl: &str) -> String {
    let t = decl.rsplit('.').next().unwrap_or(decl);
    if t.chars().count() > 26 {
        t.chars().take(25).collect::<String>() + "…"
    } else {
        t.to_string()
    }
}

/// An argument's verification: seven rows, each a catalogue term and a data
/// value, in the small section closing the argument's own page.
fn region_verification(b: &mut B, a: &ArgumentView, input: &Snapshot) {
    b.open("section", "class=\"mth-verification\"");
    b.lab("h2", "mth-verification__title", "verification");
    b.open("dl", "class=\"mth-dl\"");
    b.row("replay", "replay_accepted", "accepted");
    if a.argument.axioms_reached.is_empty() {
        b.row("axioms", "axiom_manifest", "free");
    } else {
        b.lab("dt", "", "axioms");
        b.open("dd", "");
        for ax in &a.argument.axioms_reached {
            b.val("span", "axiom_manifest", ax, "class=\"mth-mono\"");
        }
        b.close("dd");
    }
    b.row(
        "statementIdentity",
        "statement_identity",
        &a.argument.statement_identity,
    );
    b.row("substrate", "substrate", &a.argument.substrate);
    b.row("dictionaryPin", "dictionary.label", &input.pin_label());
    b.lab("dt", "", "frozenExport");
    b.open("dd", "");
    b.val(
        "span",
        "argument.export_sha256",
        &a.argument.export_sha256[..12],
        "class=\"mth-mono\"",
    );
    b.open(
        "button",
        "class=\"mth-btn\" type=\"button\" data-copy=\"argument.export_sha256\"",
    );
    b.text(label("copy"));
    b.close("button");
    b.close("dd");
    b.row(
        "verified",
        "argument.created_at",
        &ts(&a.argument.created_at),
    );
    b.close("dl");
    b.close("section");
}

/// A cited person: their glyph and their name, linking to their GitHub profile
/// when the record holds one for them; the name alone otherwise.
fn cited_person(b: &mut B, input: &Snapshot, name: &str) {
    match input.person(name) {
        Some(person) => {
            b.open(
                "a",
                &format!(
                    "class=\"mth-person\" href=\"https://github.com/{}\"",
                    escape(&person.github)
                ),
            );
            b.raw(&glyph(&person.github, "mth-glyph--sm"));
            b.val("span", "argument.cites", name, "");
            b.close("a");
        }
        None => {
            b.val("span", "argument.cites", name, "");
        }
    }
}

/// A member as their photo and their name, linking to their profile; the name
/// alone when the record holds no such profile.
fn person_link(b: &mut B, input: &Snapshot, profile_id: uuid::Uuid, name: &str) {
    let Some(p) = input.profile(profile_id) else {
        b.val("span", "profile.citation_name", name, "");
        return;
    };
    b.open(
        "a",
        &format!("class=\"mth-person\" href=\"/u/{}/\"", escape(&p.login)),
    );
    match &p.avatar {
        Some(src) => b.raw(&format!(
            "<img class=\"mth-avatar mth-avatar--xs\" src=\"{}\" width=\"24\" height=\"24\" \
             data-attr-value=\"alt\" data-field=\"profile.citation_name\" alt=\"{}\">",
            escape(src),
            escape(&p.citation_name)
        )),
        None => b.raw(&glyph(&p.login, "mth-glyph--xs")),
    };
    b.val("span", "profile.citation_name", &p.citation_name, "");
    b.close("a");
}

/// An abstract avatar for a person the record holds no photo of: a 5×5 grid,
/// mirrored left to right, drawn from a hash of their GitHub login, in one of
/// four tints. The same login always draws the same glyph. It is decorative —
/// the person's name always stands beside it.
fn glyph(login: &str, class: &str) -> String {
    let mut h: u64 = 0xcbf2_9ce4_8422_2325;
    for byte in login.to_lowercase().as_bytes() {
        h ^= *byte as u64;
        h = h.wrapping_mul(0x1000_0000_01b3);
    }
    let mut d = String::new();
    for row in 0..5u64 {
        for col in 0..3u64 {
            if h >> (row * 3 + col) & 1 == 1 {
                for x in if col == 2 { vec![2] } else { vec![col, 4 - col] } {
                    d.push_str(&format!("M{x} {row}h1v1h-1z"));
                }
            }
        }
    }
    format!(
        "<svg class=\"mth-glyph mth-glyph--{tint} {class}\" viewBox=\"-0.5 -0.5 6 6\" \
         shape-rendering=\"crispEdges\" aria-hidden=\"true\" focusable=\"false\">\
         <path d=\"{d}\"/></svg>",
        tint = (h >> 15) % 4,
    )
}

/// The author, first: avatar, name and handle linking to the profile, then the
/// profile's kind, the date, the ⋯ menu when `more` names records, and the
/// authors of premises the argument cites.
fn region_author(
    b: &mut B,
    input: &Snapshot,
    profile_id: uuid::Uuid,
    when_field: &str,
    when: &str,
    cites: &[String],
    more: &[Record<'_>],
) {
    let Some(p) = input.profile(profile_id) else {
        return;
    };
    b.open("header", "class=\"mth-post__author\"");
    b.open(
        "a",
        &format!("class=\"mth-author\" href=\"/u/{}/\"", escape(&p.login)),
    );
    if let Some(src) = &p.avatar {
        b.raw(&format!(
            "<img class=\"mth-avatar mth-avatar--sm\" src=\"{}\" width=\"48\" height=\"48\" \
             data-attr-value=\"alt\" data-field=\"profile.citation_name\" alt=\"{}\">",
            escape(src),
            escape(&p.citation_name)
        ));
    }
    b.open("span", "class=\"mth-author__names\"");
    b.val(
        "span",
        "profile.citation_name",
        &p.citation_name,
        "class=\"mth-author__name\"",
    );
    b.val(
        "span",
        "profile.login",
        &p.login,
        "class=\"mth-author__handle\"",
    );
    b.close("span");
    b.close("a");
    b.open("span", "class=\"mth-author__meta\"");
    if let Some(kind) = &p.kind {
        b.val(
            "span",
            "profile.kind",
            kind,
            "class=\"mth-status mth-status--neutral\"",
        );
    }
    b.val("span", when_field, when, "class=\"mth-author__when\"");
    b.close("span");
    if !more.is_empty() {
        more_menu(b, more);
    }
    if !cites.is_empty() {
        b.open("span", "class=\"mth-author__cites\"");
        b.lab("span", "mth-kv__k", "cites");
        for name in cites {
            cited_person(b, input, name);
        }
        b.close("span");
    }
    b.close("header");
}

/// A record a post's ⋯ menu leads to: its `Accession kind` value, the field
/// its accession is carried in, and the accession.
struct Record<'a> {
    kind: &'static str,
    field: &'static str,
    accession: &'a str,
}

/// The ⋯ menu: a disclosure whose items are the post's claim and argument, each
/// linking to its page. It opens without scripts; the client closes it on an
/// outside click or Escape.
fn more_menu(b: &mut B, records: &[Record<'_>]) {
    b.open("details", "class=\"mth-more\"");
    b.open(
        "summary",
        &format!(
            "class=\"mth-more__button\" aria-label=\"{}\"",
            escape(label("dois"))
        ),
    );
    b.raw(
        "<svg class=\"mth-more__icon\" viewBox=\"0 0 16 16\" aria-hidden=\"true\" \
         focusable=\"false\"><circle cx=\"3\" cy=\"8\" r=\"1.5\"/><circle cx=\"8\" \
         cy=\"8\" r=\"1.5\"/><circle cx=\"13\" cy=\"8\" r=\"1.5\"/></svg>",
    );
    b.close("summary");
    b.open("div", "class=\"mth-more__menu\"");
    for r in records {
        b.open(
            "a",
            &format!("class=\"mth-more__item\" href=\"/a/{}\"", r.accession),
        );
        b.val("span", "accession.kind", r.kind, "class=\"mth-more__kind\"");
        b.val("span", r.field, r.accession, "class=\"mth-mono\"");
        b.close("a");
    }
    b.close("div");
    b.close("details");
}

/// The DOI, with the baked citation strings, on the claim's and the argument's
/// own pages.
fn region_doi(b: &mut B, acc: &Accession, field: &str, text: &str, bibtex: &str) {
    b.open("section", "class=\"mth-doi\"");
    b.open("div", "class=\"mth-kv\"");
    b.lab("span", "mth-kv__k", "doi");
    b.val("span", field, &acc.to_string(), "class=\"mth-mono\"");
    b.close("div");
    b.open(
        "div",
        &format!(
            "class=\"mth-cite\" data-citation-text=\"{}\" data-citation-bibtex=\"{}\" \
             data-attr-value=\"data-citation-text\" data-field=\"citation.text\"",
            escape(text),
            escape(bibtex)
        ),
    );
    b.lab("span", "mth-kv__k", "cite");
    b.open(
        "button",
        "class=\"mth-btn\" type=\"button\" data-copy=\"citation.text\"",
    );
    b.text(label("copy"));
    b.close("button");
    b.open(
        "button",
        "class=\"mth-btn\" type=\"button\" data-copy=\"citation.bibtex\" \
         data-attr-value=\"data-citation-bibtex\" data-field=\"citation.bibtex\"",
    );
    b.text(label("copyBibtex"));
    b.close("button");
    b.close("div");
    b.close("section");
}

pub fn post_card(b: &mut B, a: &ArgumentView, input: &Snapshot, in_stream: bool) {
    let claim = input
        .claim(&a.argument.claim_accession)
        .expect("claim of a post");
    b.open(
        "article",
        &format!(
            "class=\"mth-post\" data-accession=\"{}\" data-author-login=\"{}\"",
            a.argument.accession,
            escape(&a.argument.login)
        ),
    );
    region_author(
        b,
        input,
        a.argument.profile_id,
        "argument.created_at",
        &ts(&a.argument.created_at),
        &a.argument.cites,
        &[
            Record {
                kind: "Claim",
                field: "claim.accession",
                accession: &claim.accession,
            },
            Record {
                kind: "Argument",
                field: "argument.accession",
                accession: &a.argument.accession,
            },
        ],
    );
    region_claim(b, claim, in_stream);
    region_dag(b, a, input, in_stream);
    // Talk about the argument happens on the forum, one page per post; the
    // record carries only the way out.
    if let Some(forum) = &input.forum_base {
        b.open("footer", "class=\"mth-post__footer\"");
        b.open(
            "a",
            &format!(
                "class=\"mth-discuss\" href=\"{}/p/{}/\"",
                escape(forum.trim_end_matches('/')),
                a.argument.accession
            ),
        );
        b.text(label("discuss"));
        b.close("a");
        b.close("footer");
    }
    b.close("article");
}

// ------------------------------------------------------------------- the pages

pub fn posts_page(input: &Snapshot) -> B {
    let mut b = B::new();
    b.open("main", "class=\"mth-stream\"");
    b.open("div", "class=\"mth-controls\"");
    b.lab("label", "mth-controls__label", "profile");
    b.open(
        "select",
        "class=\"mth-select\" name=\"profile\" data-filter=\"profile\"",
    );
    b.open("option", "value=\"\"");
    b.text(label("all"));
    b.close("option");
    for p in &input.profiles {
        b.val(
            "option",
            "profile.login",
            &p.login,
            &format!("value=\"{}\"", escape(&p.login)),
        );
    }
    b.close("select");
    b.open(
        "button",
        "class=\"mth-btn\" type=\"button\" data-filter-clear=\"profile\"",
    );
    b.text(label("clear"));
    b.close("button");
    b.close("div");
    b.open("div", "class=\"mth-stream__list\" data-stream=\"posts\"");
    for p in &input.posts {
        if let Some(a) = input.argument(&p.argument_accession) {
            post_card(&mut b, a, input, true);
        }
    }
    b.close("div");
    b.close("main");
    b
}

pub fn collection_page(input: &Snapshot, bank: &str) -> B {
    let mut b = B::new();
    b.open("main", &format!("class=\"mth-bank\" data-bank=\"{bank}\""));
    b.open("div", "class=\"mth-bank__tabs\"");
    for (t, href, key) in [
        ("claims", "/collection/claims", "claims"),
        ("arguments", "/collection/arguments", "arguments"),
    ] {
        b.open(
            "a",
            &format!(
                "class=\"mth-bank__tab\" href=\"{href}\"{}",
                if t == bank {
                    " aria-current=\"page\""
                } else {
                    ""
                }
            ),
        );
        b.text(label(key));
        b.close("a");
    }
    b.close("div");

    b.open("form", "class=\"mth-controls\" data-facets=\"true\"");
    for (key, name, class) in [
        ("search", "q", "mth-field mth-field--search"),
        ("library", "library", "mth-field"),
        ("author", "author", "mth-field"),
        ("axiomManifest", "axioms", "mth-field"),
        ("from", "from", "mth-field mth-field--sm"),
        ("to", "to", "mth-field mth-field--sm"),
        ("doi", "doi", "mth-field"),
    ] {
        b.open("label", &format!("class=\"{class}\""));
        b.text(label(key));
        b.open(
            "input",
            &format!("class=\"mth-input\" type=\"text\" name=\"{name}\""),
        );
        b.close("label");
    }
    b.open("label", "class=\"mth-field mth-field--sm\"");
    b.text(label("sort"));
    b.open("select", "class=\"mth-select\" name=\"sort\"");
    b.open("option", "value=\"newest\"");
    b.text(label("newest"));
    b.close("option");
    b.open("option", "value=\"oldest\"");
    b.text(label("oldest"));
    b.close("option");
    b.close("select");
    b.close("label");
    b.open("button", "class=\"mth-btn\" type=\"submit\"");
    b.text(label("go"));
    b.close("button");
    b.open("button", "class=\"mth-btn\" type=\"reset\"");
    b.text(label("reset"));
    b.close("button");
    b.close("form");

    b.open("div", "class=\"mth-table-scroll\"");
    b.open("table", "class=\"mth-table\"");
    b.open("thead", "");
    b.open("tr", "");
    let cols: &[&str] = if bank == "claims" {
        &[
            "doi",
            "statement",
            "decl",
            "library",
            "axioms",
            "firstVerified",
        ]
    } else {
        &[
            "doi",
            "claim",
            "decl",
            "author",
            "axioms",
            "verified",
        ]
    };
    for c in cols {
        b.lab("th", "", c);
    }
    b.close("tr");
    b.close("thead");
    b.open("tbody", "data-rows=\"true\"");
    if bank == "claims" {
        for c in &input.claims {
            b.open("tr", "");
            b.open("td", "");
            chip(&mut b, &c.accession, "claim.accession");
            b.close("td");
            b.open("td", "");
            b.statement("claim.pretty", &c.pretty, "mth-lean--clamp-3");
            b.open(
                "button",
                "class=\"mth-btn mth-btn--xs\" type=\"button\" data-expand=\"row\"",
            );
            b.text(label("expand"));
            b.close("button");
            b.close("td");
            b.open("td", "");
            b.val(
                "span",
                "claim.decl_name",
                &c.decl_name,
                "class=\"mth-mono\"",
            );
            b.close("td");
            b.open("td", "");
            b.val("span", "claim.module", &c.module, "");
            b.close("td");
            b.open("td", "");
            let axioms = input.claim_axioms(&c.accession);
            if c.arguments_count == 0 {
                b.val("span", "null", EM_DASH, "");
            } else if axioms.is_empty() {
                b.val("span", "axiom_manifest", "free", "");
            } else {
                for a in &axioms {
                    b.val("span", "axiom_manifest", a, "class=\"mth-mono\"");
                }
            }
            b.close("td");
            b.open("td", "");
            b.val("span", "claim.first_verified", &ts(&c.created_at), "");
            b.close("td");
            b.close("tr");
        }
    } else {
        for a in &input.arguments {
            b.open("tr", "");
            b.open("td", "");
            chip(&mut b, &a.argument.accession, "argument.accession");
            b.close("td");
            b.open("td", "");
            chip(&mut b, &a.argument.claim_accession, "claim.accession");
            b.close("td");
            b.open("td", "");
            b.val(
                "span",
                "argument.root_decl_name",
                &a.argument.root_decl_name,
                "class=\"mth-mono\"",
            );
            b.close("td");
            b.open("td", "");
            b.val(
                "span",
                "profile.citation_name",
                &a.argument.citation_name,
                "",
            );
            b.close("td");
            b.open("td", "");
            if a.argument.axioms_reached.is_empty() {
                b.val("span", "axiom_manifest", "free", "");
            } else {
                for ax in &a.argument.axioms_reached {
                    b.val("span", "axiom_manifest", ax, "class=\"mth-mono\"");
                }
            }
            b.close("td");
            b.open("td", "");
            b.val(
                "span",
                "argument.created_at",
                &ts(&a.argument.created_at),
                "",
            );
            b.close("td");
            b.close("tr");
        }
    }
    b.close("tbody");
    b.close("table");
    b.close("div");
    b.close("main");
    b
}

/// About — a shell and a link slot. One `<main>`, exactly three element
/// children, and `#about-body` carries the verbatim bytes of `about/body.html`.
pub fn about_page(input: &Snapshot) -> B {
    let mut b = B::new();
    b.open("main", "class=\"mth-doc\"");
    b.lab("h1", "", "about");
    b.open(
        "div",
        "id=\"dictionary-slot\" class=\"mth-panel mth-dictionary-slot\"",
    );
    b.open(
        "a",
        &format!(
            "id=\"dictionary-link\" class=\"mth-btn mth-btn--lg\" href=\"{}\" rel=\"noopener\"",
            escape(&input.dictionary.blueprint_url)
        ),
    );
    b.text(label("dictionary"));
    b.close("a");
    b.val(
        "span",
        "dictionary.label",
        &input.pin_label(),
        "class=\"mth-mono\"",
    );
    b.close("div");
    b.open("div", "id=\"about-body\" class=\"record-prose\"");
    b.raw(&input.about_body);
    b.close("div");
    b.close("main");
    b
}

/// Login — the nav plus a `<main>` of exactly two things. `%REDIRECT_TO%` is the
/// one substitution `webd` performs, so a viewer with JavaScript disabled gets a
/// working sign-in link that preserves the destination.
pub fn login_page() -> B {
    let mut b = B::new();
    b.open("main", "class=\"mth-login\"");
    b.lab("h1", "", "signIn");
    b.open("a", "id=\"sign-in\" class=\"mth-btn mth-btn--primary\" href=\"/auth/github/start?redirect_to=%REDIRECT_TO%\"");
    b.text(label("signIn"));
    b.close("a");
    b.close("main");
    b
}

pub fn not_found_page() -> B {
    let mut b = B::new();
    b.open("main", "class=\"mth-doc\"");
    b.lab("h1", "", "notFound");
    b.close("main");
    b
}

/// The no-JavaScript form of the degraded surface: the same two strings, the
/// reason rendered at generation time so the page needs no client.
pub fn unavailable_page(message: &str) -> B {
    let mut b = B::new();
    b.open("main", "class=\"mth-doc\"");
    b.open("p", "data-role=\"error\"");
    b.text(message);
    b.close("p");
    // `href=""` resolves to the request's own URL, so one static document
    // reloads whichever of `/u/{login}`, `/profile` and `/submit` `webd` served
    // it for. A baked path could only name one of the three, and a client-side
    // `location.reload()` would contradict the page's whole reason to exist.
    b.open("a", "class=\"mth-btn\" href=\"\" data-reload=\"true\"");
    b.text(label("reload"));
    b.close("a");
    b.close("main");
    b
}

/// The Submit shell. Every visible string in it is a catalogue label; the SPA
/// mounts the editor and the verdict region into the four regions.
pub fn submit_page() -> B {
    let mut b = B::new();
    b.open("main", "class=\"mth-submit\"");

    b.open("section", "data-region=\"editor\"");
    b.open("div", "id=\"ide-editor\" class=\"mth-editor\"");
    b.close("div");
    b.open("div", "class=\"mth-kv\"");
    b.lab("span", "mth-kv__k", "status");
    b.val("span", "ide.status", "Elaborating", "id=\"ide-status\"");
    b.close("div");
    b.close("section");

    b.open("section", "data-region=\"designation\"");
    b.open("label", "class=\"mth-field mth-field--xl\"");
    b.text(label("claim"));
    b.open(
        "select",
        "class=\"mth-select\" id=\"claim-select\" name=\"claim_decl\"",
    );
    b.close("select");
    b.close("label");
    b.open("label", "class=\"mth-field\"");
    b.text(label("proves"));
    b.open(
        "input",
        "class=\"mth-input\" id=\"proves\" name=\"proves_doi\" type=\"text\"",
    );
    b.close("label");
    b.open(
        "button",
        "class=\"mth-btn mth-btn--primary\" id=\"submit\" type=\"button\"",
    );
    b.text(label("submit"));
    b.close("button");
    b.close("section");

    b.open(
        "section",
        "data-region=\"status\" id=\"verification-status\" hidden",
    );
    b.open("div", "class=\"mth-kv\"");
    b.lab("span", "mth-kv__k", "status");
    b.val(
        "span",
        "verification.state",
        "received",
        "id=\"verification-state\"",
    );
    b.close("div");
    b.open("div", "class=\"mth-kv\"");
    b.lab("span", "mth-kv__k", "logs");
    for key in ["build", "export", "adjudicate"] {
        b.open(
            "button",
            &format!("class=\"mth-btn\" type=\"button\" data-log=\"{key}\""),
        );
        b.text(label(key));
        b.close("button");
    }
    b.close("div");
    b.open("pre", "data-role=\"log\" id=\"log-body\" hidden");
    b.close("pre");
    b.close("section");

    b.open("section", "data-region=\"verdict\" id=\"verdict\" hidden");
    b.close("section");
    b.close("main");
    b
}

/// The IDE: write a deposit in the browser and open it as a pull request.
///
/// The page is a shell of catalogue labels; the client mounts the editor into
/// `#ide-editor` and fills the byline, the claim list and the problems. The
/// three modes share one layout, and `data-show` names the modes an element
/// belongs to, so the stylesheet shows the right ones before any script runs.
/// The pin chip carries the dictionary's toolchain and Mathlib revision, the
/// environment a deposit is built in.
pub fn ide_page(input: &Snapshot) -> B {
    let mut b = B::new();
    b.open("main", "class=\"mth-ide\" data-mode=\"argue\"");

    b.open(
        "div",
        &format!(
            "class=\"mth-ide__modes\" role=\"group\" aria-label=\"{}\"",
            escape(label("mode"))
        ),
    );
    for (mode, key, pressed) in [
        ("argue", "newArgument", "true"),
        ("pose", "poseClaim", "false"),
        ("prove", "proveClaim", "false"),
    ] {
        b.open(
            "button",
            &format!(
                "class=\"mth-ide__mode\" type=\"button\" data-mode=\"{mode}\" aria-pressed=\"{pressed}\""
            ),
        );
        b.text(label(key));
        b.close("button");
    }
    b.close("div");

    b.open("div", "class=\"mth-ide__grid\"");

    // ---- the people and the words: byline, claim, title, gloss ----
    b.open("aside", "class=\"mth-ide__aside\"");
    b.open("div", "class=\"mth-ide__byline\" id=\"ide-byline\"");
    b.close("div");
    b.open("label", "class=\"mth-field mth-ide__field\"");
    b.text(label("githubAccount"));
    b.open(
        "input",
        "class=\"mth-input\" id=\"ide-login\" type=\"text\" autocomplete=\"username\" \
         spellcheck=\"false\" autocapitalize=\"off\"",
    );
    b.close("label");

    b.open("div", "class=\"mth-ide__claim-pick\" data-show=\"prove\"");
    b.open("label", "class=\"mth-field mth-ide__field\"");
    b.text(label("claim"));
    b.open("select", "class=\"mth-select\" id=\"ide-claim\"");
    b.close("select");
    b.close("label");
    b.open(
        "div",
        "class=\"mth-ide__claim\" id=\"ide-claim-card\" hidden",
    );
    b.close("div");
    b.close("div");

    b.open(
        "label",
        "class=\"mth-field mth-ide__field\" data-show=\"argue pose\"",
    );
    b.text(label("titleField"));
    b.open(
        "input",
        "class=\"mth-input\" id=\"ide-title\" type=\"text\"",
    );
    b.close("label");

    b.open("label", "class=\"mth-field mth-ide__field\"");
    b.open("span", "data-show=\"argue prove\"");
    b.text(label("glossArgument"));
    b.close("span");
    b.open("span", "data-show=\"pose\"");
    b.text(label("glossClaim"));
    b.close("span");
    b.open(
        "textarea",
        "class=\"mth-input mth-ide__gloss\" id=\"ide-gloss\" rows=\"6\"",
    );
    b.close("textarea");
    b.close("label");
    b.close("aside");

    // ---- the two parts, and what leaves the page ----
    b.open("section", "class=\"mth-ide__work\"");
    b.open("div", "class=\"mth-ide__editor\"");
    b.open("div", "class=\"mth-ide__tabs\" role=\"tablist\"");
    for (tab, key, selected, show) in [
        ("statement", "statement", "true", ""),
        ("proof", "proof", "false", " data-show=\"argue prove\""),
    ] {
        b.open(
            "button",
            &format!(
                "class=\"mth-ide__tab\" type=\"button\" role=\"tab\" id=\"ide-tab-{tab}\" \
                 data-tab=\"{tab}\" aria-selected=\"{selected}\" aria-controls=\"ide-editor\"{show}"
            ),
        );
        b.text(label(key));
        b.close("button");
    }
    b.open("span", "class=\"mth-ide__pin\"");
    b.val(
        "span",
        "dictionary.toolchain",
        &input.dictionary.toolchain,
        "",
    );
    b.lab("span", "", "mathlib");
    b.val(
        "span",
        "dictionary.mathlib_rev",
        input
            .dictionary
            .mathlib_rev
            .get(..12)
            .unwrap_or(&input.dictionary.mathlib_rev),
        "",
    );
    b.close("span");
    b.close("div");
    b.open(
        "div",
        "class=\"mth-ide__code\" id=\"ide-editor\" role=\"tabpanel\"",
    );
    b.close("div");
    b.open("div", "class=\"mth-ide__lockline\" data-show=\"prove\"");
    b.text(label("statementLocked"));
    b.close("div");
    b.close("div");

    b.open("div", "class=\"mth-error-host\" id=\"ide-problems\"");
    b.close("div");

    b.open("div", "class=\"mth-ide__actions\"");
    b.open(
        "button",
        "class=\"mth-btn mth-btn--primary mth-btn--lg\" id=\"ide-submit\" type=\"button\"",
    );
    b.text(label("openPullRequest"));
    b.close("button");
    b.open(
        "button",
        "class=\"mth-btn mth-btn--lg mth-ide__external\" id=\"ide-lean\" type=\"button\"",
    );
    b.text(label("leanWeb"));
    b.close("button");
    b.open("span", "class=\"mth-ide__sent\" id=\"ide-sent\" hidden");
    b.close("span");
    b.close("div");
    b.close("section");

    b.close("div");
    b.close("main");
    b
}

/// One row of the profile's `DOIs` table: every accession the profile holds, of
/// either kind, in the one table SPEC.md §8.2 specifies.
struct DoiRow {
    accession: String,
    decl: String,
    /// The `Accession kind` value, `Claim` or `Argument` — the third of the
    /// three deliberately distinct `Kind` columns (SPEC.md §8).
    kind: &'static str,
    date: String,
}

pub fn profile_page(input: &Snapshot, p: &Profile) -> B {
    let mut b = B::new();
    let claims: Vec<&Claim> = input
        .claims
        .iter()
        .filter(|c| c.profile_id == p.id)
        .collect();
    let args: Vec<&ArgumentView> = input
        .arguments
        .iter()
        .filter(|a| a.argument.profile_id == p.id)
        .collect();
    b.open(
        "main",
        &format!("class=\"mth-profile\" data-profile-id=\"{}\"", p.id),
    );

    b.open("section", "class=\"mth-profile__identity\"");
    if let Some(src) = &p.avatar {
        b.raw(&format!(
            "<img class=\"mth-avatar mth-avatar--lg\" src=\"{}\" width=\"64\" height=\"64\" \
             data-attr-value=\"alt\" data-field=\"profile.citation_name\" alt=\"{}\">",
            escape(src),
            escape(&p.citation_name)
        ));
    }
    b.open("div", "class=\"mth-profile__who\"");
    b.val(
        "h1",
        "profile.citation_name",
        &p.citation_name,
        "class=\"mth-profile__name\"",
    );
    b.val(
        "span",
        "profile.login",
        &p.login,
        "class=\"mth-author__handle\"",
    );
    b.open("dl", "class=\"mth-dl\"");
    b.row(
        "profileKind",
        "profile.kind",
        p.kind.as_deref().unwrap_or(EM_DASH),
    );
    b.row("joined", "profile.created_at", &ts(&p.created_at));
    b.close("dl");
    b.close("div");
    b.close("section");

    b.open("section", "class=\"mth-profile__dois\"");
    b.lab("h2", "", "dois");
    b.open("div", "class=\"mth-table-scroll\"");
    b.open("table", "class=\"mth-table\"");
    b.open("thead", "");
    b.open("tr", "");
    for c in ["doi", "decl", "accessionKind", "date"] {
        b.lab("th", "", c);
    }
    b.close("tr");
    b.close("thead");
    b.open("tbody", "");
    let mut rows: Vec<DoiRow> = Vec::new();
    for c in &claims {
        rows.push(DoiRow {
            accession: c.accession.clone(),
            decl: c.decl_name.clone(),
            kind: "Claim",
            date: ts(&c.created_at),
        });
    }
    for a in &args {
        rows.push(DoiRow {
            accession: a.argument.accession.clone(),
            decl: a.argument.root_decl_name.clone(),
            kind: "Argument",
            date: ts(&a.argument.created_at),
        });
    }
    // Newest first, ties broken by accession, so the table is a total order
    // and two generations agree on it.
    rows.sort_by(|x, y| y.date.cmp(&x.date).then(x.accession.cmp(&y.accession)));
    for r in rows {
        let claim = r.kind == "Claim";
        b.open("tr", "");
        b.open("td", "");
        chip(
            &mut b,
            &r.accession,
            if claim {
                "claim.accession"
            } else {
                "argument.accession"
            },
        );
        b.close("td");
        b.open("td", "");
        let decl_field = if claim {
            "claim.decl_name"
        } else {
            "argument.root_decl_name"
        };
        b.val("span", decl_field, &r.decl, "class=\"mth-mono\"");
        b.close("td");
        b.open("td", "");
        b.val("span", "accession.kind", r.kind, "");
        b.close("td");
        b.open("td", "");
        b.val("span", "argument.created_at", &r.date, "");
        b.close("td");
        b.close("tr");
    }
    b.close("tbody");
    b.close("table");
    b.close("div");
    b.close("section");

    b.open("section", "class=\"mth-stream__list\"");
    for a in &args {
        post_card(&mut b, a, input, true);
    }
    b.close("section");
    b.close("main");
    b
}

/// A landing page: two regions, physically separated in the DOM, in storage and
/// in mutability. `#record` is a pure function of immutable rows plus the pin:
/// the post (or, for a claim, the claim and its arguments), then the DOI and the
/// citation, then a small verification section.
pub fn landing_page(input: &Snapshot, acc: &str) -> Option<B> {
    let a: Accession = acc.parse().ok()?;
    let mut b = B::new();
    let owner_id;
    b.open("main", "class=\"mth-stream\"");
    match a.kind {
        accession::Kind::Argument => {
            let view = input.argument(acc)?;
            owner_id = view.argument.profile_id.to_string();
            let date = view.argument.created_at.format("%Y-%m-%d").to_string();
            let c = citation(
                &view.argument.citation_name,
                &view.argument.root_decl_name,
                &a,
                &input.site_base,
                &date,
            );
            b.open(
                "article",
                &format!("class=\"landing\" data-accession=\"{acc}\" data-owner-profile-id=\"{owner_id}\""),
            );
            b.open(
                "section",
                "data-region=\"verified\" id=\"record\" class=\"mth-landing__record\"",
            );
            post_card(&mut b, view, input, false);
            b.open("div", "class=\"mth-record\"");
            region_doi(&mut b, &a, "argument.accession", &c.text, &c.bibtex);
            region_verification(&mut b, view, input);
            b.close("div");
            b.close("section");
        }
        accession::Kind::Claim => {
            let claim = input.claim(acc)?;
            owner_id = claim.profile_id.to_string();
            let date = claim.created_at.format("%Y-%m-%d").to_string();
            let c = citation(
                &claim.citation_name,
                &claim.decl_name,
                &a,
                &input.site_base,
                &date,
            );
            b.open(
                "article",
                &format!("class=\"landing\" data-accession=\"{acc}\" data-owner-profile-id=\"{owner_id}\""),
            );
            b.open(
                "section",
                "data-region=\"verified\" id=\"record\" class=\"mth-landing__record\"",
            );
            b.open("div", "class=\"mth-post\"");
            region_author(
                &mut b,
                input,
                claim.profile_id,
                "claim.first_verified",
                &ts(&claim.created_at),
                &[],
                &[],
            );
            region_claim(&mut b, claim, false);
            if claim.arguments_count > 0 {
                b.lab("h2", "", "arguments");
                b.open("div", "class=\"mth-table-scroll\"");
                b.open("table", "class=\"mth-table\"");
                b.open("thead", "");
                b.open("tr", "");
                for k in ["doi", "author", "date"] {
                    b.lab("th", "", k);
                }
                b.close("tr");
                b.close("thead");
                b.open("tbody", "");
                for arg in input
                    .arguments
                    .iter()
                    .filter(|x| x.argument.claim_accession == acc)
                {
                    b.open("tr", "");
                    b.open("td", "");
                    chip(&mut b, &arg.argument.accession, "argument.accession");
                    b.close("td");
                    b.open("td", "");
                    person_link(&mut b, input, arg.argument.profile_id, &arg.argument.citation_name);
                    b.close("td");
                    b.open("td", "");
                    b.val(
                        "span",
                        "argument.created_at",
                        &ts(&arg.argument.created_at),
                        "",
                    );
                    b.close("td");
                    b.close("tr");
                }
                b.close("tbody");
                b.close("table");
                b.close("div");
            }
            b.close("div");
            b.open("div", "class=\"mth-record\"");
            region_doi(&mut b, &a, "claim.accession", &c.text, &c.bibtex);
            b.open("section", "class=\"mth-verification\"");
            b.lab("h2", "mth-verification__title", "verification");
            b.open("dl", "class=\"mth-dl\"");
            b.row("library", "claim.module", &claim.module);
            b.row(
                "statementDigest",
                "claim.statement_digest",
                &claim.statement_digest[..12],
            );
            b.row(
                "firstVerified",
                "claim.first_verified",
                &ts(&claim.created_at),
            );
            b.close("dl");
            b.close("section");
            b.close("div");
            b.close("section");
        }
    }
    b.open("section", "data-region=\"author\" id=\"authored\"");
    b.close("section");
    b.close("article");
    b.close("main");
    Some(b)
}

/// Prefix every root-relative URL in a generated page with the path the record
/// is served under. Only attribute values that begin with a single `/` are
/// rewritten, so absolute URLs and protocol-relative ones pass through.
pub fn with_base(html: &str, base: &str) -> String {
    if base.is_empty() {
        return html.to_string();
    }
    let mut out = String::with_capacity(html.len() + 256);
    let mut rest = html;
    while let Some(i) = rest.find("=\"/") {
        let (head, tail) = rest.split_at(i);
        let attr_start = head.rfind(|c: char| c.is_whitespace()).map_or(0, |k| k + 1);
        let attr = &head[attr_start..];
        out.push_str(head);
        out.push_str("=\"");
        let after = &tail[2..];
        let rewrite = matches!(attr, "href" | "src" | "action" | "data-base-href")
            && !after.starts_with("//");
        if rewrite {
            out.push_str(base);
        }
        rest = after;
    }
    out.push_str(rest);
    out
}
