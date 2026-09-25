// The field catalogue (SPEC.md §8). Every `data-value="true"` element names one
// of these fields, and `prose-lint` skips its text only once the name resolves
// here. `npm run fields:export` writes it verbatim to
// services/registry/crates/record/fields.json.
//
// `source` says where the value comes from: `manifest` for a generated record
// field, `api` for a gateway response field, `ui` for an observable state of the
// surface itself. v0 declares exactly two `ui` fields.

export type Shape =
  | "enum"
  | "accession"
  | "timestamp"
  | "integer"
  | "sha256-prefix"
  | "decl"
  | "login"
  | "name"
  | "label"
  | "em-dash"
  | "lean-statement"
  | "lean-term"
  | "docstring"
  | "citation";

export interface Field {
  field: string;
  shape: Shape;
  source: "manifest" | "api" | "ui";
}

export const FIELDS: Field[] = [
  { field: "claim.accession", shape: "accession", source: "manifest" },
  { field: "claim.decl_name", shape: "decl", source: "manifest" },
  { field: "claim.pretty", shape: "lean-statement", source: "manifest" },
  { field: "claim.doc", shape: "docstring", source: "manifest" },
  { field: "claim.module", shape: "label", source: "manifest" },
  { field: "claim.statement_digest", shape: "sha256-prefix", source: "manifest" },
  { field: "claim.first_verified", shape: "timestamp", source: "manifest" },
  { field: "argument.accession", shape: "accession", source: "manifest" },
  { field: "argument.root_decl_name", shape: "decl", source: "manifest" },
  { field: "argument.export_sha256", shape: "sha256-prefix", source: "manifest" },
  { field: "argument.created_at", shape: "timestamp", source: "manifest" },
  { field: "argument.libraries_used", shape: "label", source: "manifest" },
  { field: "argument_node.decl_name", shape: "decl", source: "manifest" },
  { field: "argument_node.kind", shape: "enum", source: "manifest" },
  { field: "argument_node.pretty", shape: "lean-statement", source: "manifest" },
  { field: "argument_node.doc", shape: "docstring", source: "manifest" },
  { field: "argument_hypothesis.name", shape: "decl", source: "manifest" },
  { field: "argument_hypothesis.pretty", shape: "lean-statement", source: "manifest" },
  { field: "argument_hypothesis.label", shape: "lean-term", source: "manifest" },
  // The DAG's dictionary chips: a curated entry occurring in a node, which is
  // the one value the generated record renders that is neither the node's own
  // declaration nor a count.
  { field: "dictionary_constant.name", shape: "decl", source: "manifest" },
  { field: "dictionary_constant.kind", shape: "enum", source: "manifest" },
  { field: "dictionary_constant.pretty", shape: "lean-statement", source: "manifest" },
  { field: "dictionary_constant.doc", shape: "docstring", source: "manifest" },
  { field: "replay_accepted", shape: "enum", source: "manifest" },
  { field: "axiom_manifest", shape: "enum", source: "manifest" },
  { field: "statement_identity", shape: "enum", source: "manifest" },
  { field: "substrate", shape: "label", source: "manifest" },
  { field: "dictionary.label", shape: "label", source: "manifest" },
  { field: "dictionary.curation", shape: "enum", source: "manifest" },
  { field: "dictionary.toolchain", shape: "label", source: "manifest" },
  { field: "dictionary.mathlib_rev", shape: "sha256-prefix", source: "manifest" },
  { field: "profile.login", shape: "login", source: "manifest" },
  { field: "profile.citation_name", shape: "name", source: "manifest" },
  { field: "argument.cites", shape: "name", source: "manifest" },
  { field: "profile.kind", shape: "enum", source: "manifest" },
  { field: "profile.created_at", shape: "timestamp", source: "manifest" },
  { field: "accession.kind", shape: "enum", source: "manifest" },
  { field: "citation.text", shape: "citation", source: "manifest" },
  { field: "citation.bibtex", shape: "citation", source: "manifest" },
  { field: "facet.value", shape: "label", source: "api" },
  { field: "null", shape: "em-dash", source: "manifest" },
  { field: "verification.state", shape: "enum", source: "api" },
  { field: "verification.reason_code", shape: "enum", source: "api" },
  { field: "note.updated_at", shape: "timestamp", source: "api" },
  { field: "ide.status", shape: "enum", source: "ui" },
  { field: "clipboard.state", shape: "enum", source: "ui" },
];

// ---------------------------------------------------------------------------
// The manifest half of the check.
//
// `npm run fields:export -- --check` fails if the exported JSON disagrees with
// this file AND if any leaf of `schema/public-unit-manifest.v3.schema.json` has
// no `source: "manifest"` entry here (SPEC.md §8). A leaf names its catalogue
// field with an `x-field` annotation: the manifest's own JSON paths are not the
// field names — the manifest writes `decl_name` where the catalogue says
// `claim.decl_name` — so an annotation is the only thing that can carry the
// correspondence, and deriving it from the path would be a guess.
//
// The walk lives here rather than in the script so the same code answers the
// script and the test, and so a schema shape change fails in one place.

export interface SchemaNode {
  properties?: Record<string, SchemaNode>;
  items?: SchemaNode;
  oneOf?: SchemaNode[];
  anyOf?: SchemaNode[];
  allOf?: SchemaNode[];
  "x-field"?: string;
}

/** Every field a v3-manifest leaf names, in encounter order, deduplicated. */
export function manifestLeaves(schema: SchemaNode): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  const visit = (node: SchemaNode | undefined): void => {
    if (!node || typeof node !== "object") return;
    const named = node["x-field"];
    if (typeof named === "string" && !seen.has(named)) {
      seen.add(named);
      out.push(named);
    }
    if (node.properties) for (const child of Object.values(node.properties)) visit(child);
    visit(node.items);
    for (const branch of [node.oneOf, node.anyOf, node.allOf]) {
      if (branch) for (const child of branch) visit(child);
    }
  };
  visit(schema);
  return out;
}

export interface ManifestGap {
  field: string;
  /** `absent` when no entry exists; otherwise the source it wrongly carries. */
  reason: "absent" | "api" | "ui";
}

/**
 * The leaves the catalogue does not cover as manifest fields.
 *
 * A leaf declared `source: "api"` or `source: "ui"` is as much a failure as a
 * missing one: those two sources say "this value has no place in the generated
 * record", and a manifest leaf does, so the wrong source would let a generated
 * page render a value `prose-lint` checks against the wrong origin.
 */
export function manifestGaps(schema: SchemaNode, fields: Field[] = FIELDS): ManifestGap[] {
  const byName = new Map(fields.map((f) => [f.field, f] as const));
  const gaps: ManifestGap[] = [];
  for (const leaf of manifestLeaves(schema)) {
    const found = byName.get(leaf);
    if (!found) gaps.push({ field: leaf, reason: "absent" });
    else if (found.source !== "manifest") gaps.push({ field: leaf, reason: found.source });
  }
  return gaps;
}
