import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { mountIde } from "./mount";

function page(): void {
  document.body.innerHTML = `
    <div class="mth-ide" data-mode="argue">
      <button class="mth-ide__mode" data-mode="argue"></button>
      <button class="mth-ide__mode" data-mode="pose"></button>
      <button class="mth-ide__mode" data-mode="prove"></button>
      <input id="ide-title">
      <textarea id="ide-gloss"></textarea>
      <div id="ide-editor"></div>
    </div>`;
}

function memoryStorage(): Storage {
  const m = new Map<string, string>();
  return {
    get length() {
      return m.size;
    },
    clear: () => m.clear(),
    getItem: (k) => m.get(k) ?? null,
    key: (i) => [...m.keys()][i] ?? null,
    removeItem: (k) => void m.delete(k),
    setItem: (k, v) => void m.set(k, String(v)),
  };
}

// jsdom does no layout; CodeMirror measures text ranges, so give it empty ones.
Range.prototype.getClientRects = () => [] as unknown as DOMRectList;
Range.prototype.getBoundingClientRect = () => new DOMRect();

const gloss = ():HTMLTextAreaElement => document.querySelector("#ide-gloss") as HTMLTextAreaElement;
const pick = (mode: string): void =>
  (document.querySelector(`.mth-ide__mode[data-mode="${mode}"]`) as HTMLButtonElement).click();

describe("the gloss", () => {
  beforeEach(() => {
    vi.stubGlobal("localStorage", memoryStorage());
    vi.stubGlobal("fetch", vi.fn(() => Promise.reject(new Error("offline"))));
    page();
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    document.body.innerHTML = "";
  });

  it("belongs to one mode, and does not follow a switch to another", () => {
    mountIde(document);
    gloss().value = "what the argument shows";
    pick("pose");
    expect(gloss().value).toBe("");
    pick("prove");
    expect(gloss().value).toBe("");
    pick("argue");
    expect(gloss().value).toBe("what the argument shows");
  });

  it("keeps a gloss saved before glosses were per mode", () => {
    window.localStorage.setItem("mathesis.ide.v1", JSON.stringify({ gloss: "kept" }));
    mountIde(document);
    expect(gloss().value).toBe("kept");
  });
});
