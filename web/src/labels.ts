// The frozen label catalogue (SPEC.md §8). Every string a viewer can see is a
// member of this catalogue, a data value read from a record, or a reason message
// from shared/reasons.v1.json. A new visible string requires an entry here and a
// reviewer-visible diff.
//
// `npm run labels:export` writes this verbatim to
// services/registry/crates/record/labels.json, which the Rust templates and
// prose-lint both read. There is one authored source; nothing else declares a
// label.

export const LABELS = {
  // chrome and nav
  mathesis: "Mathesis",
  posts: "Posts",
  profile: "Profile",
  collection: "Collection",
  about: "About",
  signIn: "Sign in",
  dictionary: "Dictionary",
  notFound: "Not found",

  // objects and columns
  claim: "Claim",
  claims: "Claims",
  arguments: "Arguments",
  statement: "Statement",
  statementDigest: "Statement digest",
  decl: "Decl",
  library: "Library",
  doi: "DOI",
  dois: "DOIs",
  author: "Author",
  uses: "Uses",
  usedBy: "Used by",

  // the three Kind columns, deliberately three distinct labels
  profileKind: "Profile kind",
  declarationKind: "Declaration kind",
  accessionKind: "Accession kind",

  // verification block
  verification: "Verification",
  replay: "Replay",
  axioms: "Axioms",
  axiomManifest: "Axiom manifest",
  statementIdentity: "Statement identity",
  substrate: "Substrate",
  dictionaryPin: "Dictionary pin",
  frozenExport: "Frozen export",
  verified: "Verified",
  firstVerified: "First verified",
  joined: "Joined",
  date: "Date",

  // controls
  search: "Search",
  go: "Go",
  from: "From",
  to: "To",
  sort: "Sort",
  newest: "Newest",
  oldest: "Oldest",
  clear: "Clear",
  reset: "Reset",
  all: "All",
  reload: "Reload",
  expand: "Expand",
  collapse: "Collapse",
  expandAll: "Expand all",
  collapseAll: "Collapse all",
  layout: "Layout",
  graph: "Graph",
  thesis: "Thesis",
  step: "Step",
  hypothesis: "Hypothesis",
  definition: "Definition",
  citedResult: "Cited result",
  list: "List",
  cite: "Cite",
  copy: "Copy",
  copyBibtex: "Copy BibTeX",
  cites: "Cites",
  discuss: "Discuss",

  // sections and terms rendered as headings

  // submit and verification progress
  submit: "Submit",
  proves: "Proves",
  status: "Status",
  logs: "Logs",
  build: "Build",
  export: "Export",
  adjudicate: "Adjudicate",

  // the IDE
  write: "Write",
  mode: "Mode",
  newArgument: "New argument",
  poseClaim: "Pose a claim",
  proveClaim: "Prove a claim",
  proof: "Proof",
  titleField: "Title",
  glossArgument: "What the argument says",
  glossClaim: "What the claim says",
  githubAccount: "GitHub account",
  posedBy: "Posed by",
  statementLocked: "Statement locked",
  mathlib: "Mathlib",
  openPullRequest: "Open pull request",
  leanWeb: "Lean 4 Web",
  pasteFromClipboard: "Paste from clipboard",
} as const;

export type LabelKey = keyof typeof LABELS;

/// The values the surface renders inside `data-value="true"`. They are listed
/// because the client emits them too; each is the string form of a catalogue
/// field, except the em dash, which is the single permitted rendering of a null
/// field and is allowed by name.
///
/// `Elaborating`, `Ready` and `Copied` are values and not labels: they are
/// states the surface is in, they carry a field, and classifying them as labels
/// is what left their snapshots with no lawful way to pass.
export const VALUES = {
  person: "person",
  agent: "agent",
  accepted: "accepted",
  pass: "pass",
  notApplicable: "not-applicable",
  free: "free",
  initial: "initial",
  received: "received",
  queued: "queued",
  building: "building",
  exporting: "exporting",
  adjudicating: "adjudicating",
  assembling: "assembling",
  admitted: "admitted",
  rejected: "rejected",
  failed: "failed",
  claim: "Claim",
  argument: "Argument",
  elaborating: "Elaborating",
  ready: "Ready",
  copied: "Copied",
  emDash: "\u2014",
} as const;

export type ValueKey = keyof typeof VALUES;

/** The catalogue as a flat list, which is what the export script writes. */
export const VALUE_LIST = Object.values(VALUES);
