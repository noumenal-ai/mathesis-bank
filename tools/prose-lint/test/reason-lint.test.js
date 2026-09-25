// `reason-lint` (SPEC §6.3, §13): the gate on the one file that holds every
// message a verification can end with.

import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdtempSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { lintReasons } from "../src/reasons.js";
import { repo, here } from "./helpers.js";

const shared = join(repo, "shared/reasons.v1.json");
const base = () => JSON.parse(readFileSync(shared, "utf8"));
const lint = (json) => lintReasons("reasons.json", JSON.stringify(json, null, 2), []);
const find = (json, code) => json.reasons.find((r) => r.code === code);

test("the shipped reason table passes every rule", () => {
  assert.deepEqual(lintReasons(shared, readFileSync(shared, "utf8"), []), []);
});

test("reason-lint exits 0 on the shipped table and 1 on a broken one", () => {
  const cli = join(here, "..", "src", "reason-lint.js");
  const out = execFileSync(process.execPath, [cli, shared], { encoding: "utf8" });
  assert.match(out, new RegExp(`^reason-lint: ${base().reasons.length} reasons, 0 violations`));

  const dir = mkdtempSync(join(tmpdir(), "reason-lint-"));
  const broken = base();
  find(broken, "EXPORT_EMPTY").message_template = "We could not read this here, sorry!";
  const path = join(dir, "reasons.v1.json");
  writeFileSync(path, JSON.stringify(broken, null, 2));
  let code = 0;
  try {
    execFileSync(process.execPath, [cli, path], { encoding: "utf8", stdio: "pipe" });
  } catch (e) {
    code = e.status;
  }
  assert.equal(code, 1);
});

test("a template longer than 120 characters fails", () => {
  const j = base();
  find(j, "EXPORT_EMPTY").message_template = `The exporter produced an empty export ${"x".repeat(120)}`;
  assert.ok(lint(j).some((v) => v.kind === "bad_label" && /characters/.test(v.value)));
});

test("explanatory vocabulary fails", () => {
  const j = base();
  find(j, "EXPORT_EMPTY").message_template = "This export is empty; here is what you can do.";
  assert.ok(lint(j).some((v) => v.kind === "unknown_string"));
});

test("a template that ends in ! fails", () => {
  const j = base();
  find(j, "EXPORT_EMPTY").message_template = "The exporter produced an empty export!";
  assert.ok(lint(j).some((v) => v.kind === "bad_label" && v.value === "ends in !"));
});

test("a template naming neither a {param} nor its stage's object fails", () => {
  const j = base();
  find(j, "EXPORT_EMPTY").message_template = "Nothing came back.";
  assert.ok(lint(j).some((v) => /names neither/.test(v.value)));
});

test("a template carrying an internal-corpus handle fails the firewall", () => {
  const j = base();
  find(j, "EXPORT_EMPTY").message_template = "The exporter produced an empty WMSpec export.";
  assert.ok(lint(j).some((v) => v.kind === "firewall" && v.value === "WMSpec"));
});

test("a banned token in a template fails", () => {
  const j = base();
  find(j, "EXPORT_EMPTY").message_template = "The exporter produced a placeholder export.";
  assert.ok(lint(j).some((v) => v.kind === "banned_token"));
});

test("a parameter that is declared and never rendered fails", () => {
  const j = base();
  find(j, "EXPORT_EMPTY").params = ["bytes"];
  assert.ok(lint(j).some((v) => v.kind === "missing_data_field" && /bytes/.test(v.value)));
});

test("a {param} the entry does not declare fails", () => {
  const j = base();
  find(j, "EXPORT_EMPTY").message_template = "The exporter produced an empty export {detail}.";
  assert.ok(lint(j).some((v) => v.kind === "unknown_field" && /\{detail\}/.test(v.value)));
});

test("reason_has_producer: a code outside `degraded` with no emitter fails", () => {
  const j = base();
  find(j, "EXPORT_EMPTY").producer = null;
  assert.ok(lint(j).some((v) => v.value === "no emitting component"));
});

test("reason_has_producer: an emitter that does not own the stage fails", () => {
  const j = base();
  find(j, "EXPORT_EMPTY").producer = "gateway";
  assert.ok(lint(j).some((v) => /does not own stage export/.test(v.value)));
});

test("reason_has_producer: `degraded` is the one stage with no emitter", () => {
  const j = base();
  assert.equal(find(j, "REGISTRY_UNAVAILABLE").producer ?? null, null);
  find(j, "REGISTRY_UNAVAILABLE").producer = "serve";
  assert.ok(lint(j).some((v) => /degraded carries producer/.test(v.value)));
});

test("a duplicate code fails", () => {
  const j = base();
  j.reasons.push({ ...find(j, "EXPORT_EMPTY") });
  assert.ok(lint(j).some((v) => v.value === "duplicate code"));
});

test("a stage no code can reach fails", () => {
  const j = base();
  j.stages.push("ceremony");
  assert.ok(lint(j).some((v) => v.kind === "dead_label" && /ceremony/.test(v.value)));
});

test("every rendered reason message is recognised on a page", async () => {
  const { reasonMatchers } = await import("../src/lint.js");
  const matchers = reasonMatchers(base());
  const rendered = "The export is 268435457 bytes; the limit is 268435456.";
  assert.ok(matchers.some((m) => m.re.test(rendered)));
  assert.ok(!matchers.some((m) => m.re.test("This page shows the verified record")));
});
