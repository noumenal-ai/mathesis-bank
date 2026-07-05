/* Mathesis browse/filter/search UI.
 * Vanilla JS, no framework, no external libs. Operates client-side over
 * docs/data/index.json (430 rows total — trivial scale). Only runs on pages
 * that have the #accessionList / #controls markup (the three bank index pages);
 * a no-op elsewhere.
 */
(function () {
  "use strict";

  const list = document.getElementById("accessionList");
  const controls = document.getElementById("controls");
  if (!list || !controls) return;

  const bank = controls.dataset.bank; // "results" | "claims" | "dictionary"
  const searchBox = document.getElementById("searchBox");
  const filterTier = document.getElementById("filterTier");
  const filterPolarity = document.getElementById("filterPolarity");
  const filterModule = document.getElementById("filterModule");
  const resultCount = document.getElementById("resultCount");

  const esc = (t) => String(t == null ? "" : t).replace(/[&<>]/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]));

  const TIER_CAPTION = {
    "T0|universal": "kernel-checked; representative spot-check on a universal statement",
    "T0|existential": "kernel-checked; the witness is full evidence for this existential statement",
    "T0|null": "kernel-checked",
    "T1|universal": "kernel-checked; broader spot-check coverage on a universal statement",
    "T1|existential": "kernel-checked; witness plus extended coverage",
    "T1|null": "kernel-checked; extended coverage",
    "T2|universal": "kernel-checked; exhaustive coverage on a universal statement",
    "T2|existential": "kernel-checked; the witness is exhaustive evidence",
    "T2|null": "kernel-checked; exhaustive coverage",
  };

  function tierBadge(row) {
    if (!row.tier) return '<span class="badge badge-none">not tiered</span>';
    const key = row.tier + "|" + (row.polarity || "null");
    const caption = TIER_CAPTION[key] || "kernel-checked";
    return `<span class="badge badge-tier badge-${esc(row.tier.toLowerCase())}" title="${esc(caption)}">${esc(row.tier)}</span>`;
  }

  function axiomBadge(row) {
    if (row.axioms_clean === null || row.axioms_clean === undefined) return "";
    return row.axioms_clean
      ? '<span class="badge badge-clean">axiom-clean</span>'
      : '<span class="badge badge-warn">extended axioms</span>';
  }

  function statusBadge(row) {
    if (!row.status) return "";
    const STATUS_LABEL = {
      proposed: "kernel-checked; interrogation pending",
      interrogated: "interrogated",
      admitted: "admitted",
      contested: "contested",
      posed: "posed",
      "well-posed": "well-posed",
      "still-green": "verified against current pin",
      "ported-to-HEAD": "ported to current head",
      superseded: "superseded",
    };
    return `<span class="badge badge-status">${esc(STATUS_LABEL[row.status] || row.status)}</span>`;
  }

  function cardHtml(row) {
    const badges = [tierBadge(row), axiomBadge(row), statusBadge(row)].filter(Boolean).join(" ");
    const polTag = row.polarity ? `<span>${esc(row.polarity)}</span>` : "";
    const deps = row.deps_count ? `<span>${row.deps_count} dependenc${row.deps_count === 1 ? "y" : "ies"}</span>` : "";
    return `<a class="acc-card" href="a/${esc(row.handle)}.html">
      <span class="acc-handle"><code>${esc(row.handle)}</code></span>
      <span class="acc-main">
        <span class="acc-title">${esc(row.title)}</span>
        <span class="acc-sub"><code class="chip chip-module">${esc(row.module)}</code>${polTag}${deps}</span>
      </span>
      <span class="acc-badges">${badges}</span>
    </a>`;
  }

  let rows = [];

  function applyFilters() {
    const q = (searchBox.value || "").trim().toLowerCase();
    const tier = filterTier.value;
    const polarity = filterPolarity.value;
    const mod = filterModule.value;

    let filtered = rows;
    if (q) {
      filtered = filtered.filter((r) =>
        r.handle.toLowerCase().includes(q) ||
        r.title.toLowerCase().includes(q) ||
        r.module.toLowerCase().includes(q));
    }
    if (tier) {
      filtered = filtered.filter((r) => (tier === "none" ? !r.tier : r.tier === tier));
    }
    if (polarity) {
      filtered = filtered.filter((r) => r.polarity === polarity);
    }
    if (mod) {
      filtered = filtered.filter((r) => r.module === mod);
    }

    // stable sort by handle (INV-2: never sort by a quality proxy)
    filtered = filtered.slice().sort((a, b) => (a.handle < b.handle ? -1 : a.handle > b.handle ? 1 : 0));

    resultCount.textContent = `${filtered.length} / ${rows.length}`;
    list.innerHTML = filtered.length
      ? filtered.map(cardHtml).join("")
      : '<p class="empty-note">No accessions match these filters.</p>';
  }

  function populateModuleFilter() {
    const modules = Array.from(new Set(rows.map((r) => r.module))).sort();
    for (const m of modules) {
      const opt = document.createElement("option");
      opt.value = m;
      opt.textContent = m;
      filterModule.appendChild(opt);
    }
  }

  fetch("data/index.json", { cache: "no-store" })
    .then((r) => r.json())
    .then((data) => {
      rows = data.filter((r) => r.bank === bank);
      populateModuleFilter();
      applyFilters();
    })
    .catch(() => {
      list.innerHTML = '<p class="empty-note">Could not load the accession index.</p>';
    });

  searchBox.addEventListener("input", applyFilters);
  filterTier.addEventListener("change", applyFilters);
  filterPolarity.addEventListener("change", applyFilters);
  filterModule.addEventListener("change", applyFilters);
})();
