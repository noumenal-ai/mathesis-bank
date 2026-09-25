// The abstract avatar the generator draws for a person the record holds no
// photo of (`glyph` in crates/record/src/pages.rs), drawn here the same way so
// one login draws one glyph whichever renderer drew it: a 5×5 grid mirrored
// left to right from an FNV-1a hash of the lowercased login, in one of four
// tints. It is decorative; the person's name always stands beside it.

const SVG = "http://www.w3.org/2000/svg";
const MASK = (1n << 64n) - 1n;

export function glyphHash(login: string): bigint {
  let h = 0xcbf29ce484222325n;
  for (const byte of new TextEncoder().encode(login.toLowerCase())) {
    h ^= BigInt(byte);
    h = (h * 0x100000001b3n) & MASK;
  }
  return h;
}

export function glyphPath(login: string): { d: string; tint: number } {
  const h = glyphHash(login);
  let d = "";
  for (let row = 0n; row < 5n; row++) {
    for (let col = 0n; col < 3n; col++) {
      if (((h >> (row * 3n + col)) & 1n) === 1n) {
        for (const x of col === 2n ? [2n] : [col, 4n - col]) d += `M${x} ${row}h1v1h-1z`;
      }
    }
  }
  return { d, tint: Number((h >> 15n) % 4n) };
}

export function glyph(login: string, extraClass: string): SVGSVGElement {
  const { d, tint } = glyphPath(login);
  const svg = document.createElementNS(SVG, "svg");
  svg.setAttribute("class", `mth-glyph mth-glyph--${tint} ${extraClass}`);
  svg.setAttribute("viewBox", "-0.5 -0.5 6 6");
  svg.setAttribute("shape-rendering", "crispEdges");
  svg.setAttribute("aria-hidden", "true");
  svg.setAttribute("focusable", "false");
  const path = document.createElementNS(SVG, "path");
  path.setAttribute("d", d);
  svg.append(path);
  return svg;
}
