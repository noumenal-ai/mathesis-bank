import { defineConfig } from "vitest/config";
import type { Plugin } from "vite";
import tailwindcss from "@tailwindcss/vite";

// verify.yml's INV-2 lint refuses a star glyph (U+2605, U+2B50) anywhere in docs/, the client's
// bundles included, and Lean's abbreviation table maps `\bigstar` to one. That entry is an editor
// shortcut, not a ranking mark, but the lint cannot tell them apart and Lean has no use for it,
// so the IDE's copy of the table leaves it out. `enforce: "pre"` sees the raw JSON, before Vite
// turns it into a module.
const RANKING_GLYPH = /[★⭐]/u;
const abbreviationsWithoutRankingGlyphs: Plugin = {
  name: "abbreviations-without-ranking-glyphs",
  enforce: "pre",
  transform(code, id) {
    if (!id.replace(/\?.*$/, "").endsWith("/@leanprover/unicode-input/dist/abbreviations.json")) return null;
    const table = JSON.parse(code) as Record<string, string>;
    for (const [k, v] of Object.entries(table)) if (RANKING_GLYPH.test(v)) delete table[k];
    return { code: JSON.stringify(table), map: null };
  },
};

// DESIGN.md §1: one stylesheet, one SPA entry, both unhashed, written to
// web/dist-assets and COPYed into the webd image (SPEC.md §11.3). recordgen
// writes no assets at all (SPEC.md §10, R32), so the entry names are stable:
// a landing page's bytes must not change when a chunk hash changes.
//
// The editor's workers are ES modules: `@codingame/monaco-vscode-api` is
// code-split, and a UMD/IIFE worker format cannot carry a code-splitting build.
export default defineConfig({
  plugins: [abbreviationsWithoutRankingGlyphs, tailwindcss()],
  build: {
    outDir: "dist-assets",
    emptyOutDir: true,
    // DESIGN.md §1 specifies `cssCodeSplit: false` for a tree that held only
    // this project's own CSS. The editor island brings monaco-vscode's
    // stylesheet with it, and merging the two would put ~300 kB of editor CSS
    // in front of every reader of a record page. The contract that matters is
    // kept — ONE unhashed `assets/record.css`, which is the entry's CSS and the
    // sheet `css_covers_templates` compares — and the island's sheet is a
    // hashed chunk loaded only by /submit.
    cssCodeSplit: false,
    sourcemap: false,
    manifest: false,
    target: "es2022",
    // The editor is a large, lazily-loaded island; the record pages never pull
    // it in, so the warning is about a chunk no reader downloads.
    chunkSizeWarningLimit: 4096,
    rollupOptions: {
      input: { app: "src/main.tsx" },
      output: {
        entryFileNames: "assets/app.js",
        chunkFileNames: "assets/[name]-[hash].js",
        assetFileNames: (info) => {
          const name = info.names?.[0] ?? "";
          if (name.endsWith(".css")) return "assets/record.css";
          return "assets/[name]-[hash][extname]";
        },
      },
    },
  },
  test: {
    environment: "jsdom",
    include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
  },
});
