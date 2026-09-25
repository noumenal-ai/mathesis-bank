// The two sections of a deposit file: the statement and the proof.
//
// A deposit is ONE file, so submitting it is one paste. After the hoisted
// imports and the `/-! @kind … -/` header it carries the statement part and the
// proof part, each introduced by a marker line of its own. The marker syntax is
// the CI's to define: it MUST match what `ci/parse_deposit.py` splits on. Until
// that parser lands its section markers, this function is the one place the
// syntax lives, so a change there is a change here and nowhere else.
//
// "Pose a claim" has no proof part and emits the statement section alone.

export const STATEMENT_MARKER = "/-! @statement -/";
export const PROOF_MARKER = "/-! @proof -/";

export interface Parts {
  /** The statement body, with its leading imports already hoisted out. */
  statement: string;
  /** The proof body, likewise; `null` for a posed claim. */
  proof: string | null;
}

/** The body of a deposit file below its header. Must match ci/parse_deposit.py. */
export function serializeParts(parts: Parts): string {
  const out = [STATEMENT_MARKER, trimBlank(parts.statement)];
  if (parts.proof !== null) out.push("", PROOF_MARKER, trimBlank(parts.proof));
  return out.join("\n");
}

/** Leading and trailing blank lines dropped; indentation inside kept. */
function trimBlank(text: string): string {
  return text.replace(/^(?:[ \t]*\n)+/, "").replace(/\s+$/, "");
}
