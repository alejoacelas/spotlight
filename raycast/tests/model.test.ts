import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { App, applySettings, decisive, matches } from "../src/model";
const app = (name: string, extra = {}): App => ({
  name,
  originalName: name,
  path: `/Applications/${name}.app`,
  ...extra,
});
test("native ranking fixtures retain their ordering", () => {
  const fixture = JSON.parse(
    readFileSync(
      require("node:path").join(
        __dirname,
        "../../Tests/LauncherTests/Fixtures/ranking.json",
      ),
      "utf8",
    ),
  );
  const apps = fixture.applications.map(
    (a: { name: string; lastUsedAt?: number }) =>
      app(a.name, { lastUsedAt: a.lastUsedAt }),
  );
  for (const c of fixture.cases)
    assert.deepEqual(
      matches(c.query, apps)
        .map((m) => m.app.name)
        .slice(0, c.expected.length),
      c.expected,
      c.query,
    );
});
test("ambiguous prefixes and one-letter queries cannot auto-open", () => {
  const apps = [app("Calendar"), app("Calculator"), app("Safari")];
  assert.equal(decisive("cal", matches("cal", apps)), undefined);
  assert.equal(decisive("s", matches("s", apps)), undefined);
  assert.equal(decisive("saf", matches("saf", apps))?.name, "Safari");
  assert.equal(
    decisive("clau", matches("clau", [app("Claude"), app("Calendar Utility")]))
      ?.name,
    "Claude",
  );
});
test("typos, accents, aliases, original names and bundle IDs remain searchable", () => {
  const apps = applySettings(
    [
      app("Café"),
      app("Safari", { bundleId: "apple.safari" }),
      app("ChatGPT", { bundleId: "com.openai.codex" }),
    ],
    { aliases: { "apple.safari": "Web" }, hidden: [], recent: {} },
  );
  for (const [query, name] of [
    ["cafe", "Café"],
    ["safri", "Web"],
    ["web", "Web"],
    ["codex", "ChatGPT"],
  ])
    assert.equal(matches(query, apps)[0]?.app.name, name);
});
test("hidden apps stay excluded and recent use breaks equal-quality ties", () => {
  const apps = applySettings([app("Alpha"), app("Beta"), app("Gamma")], {
    aliases: {},
    hidden: ["path:/Applications/Gamma.app"],
    recent: { "path:/Applications/Beta.app": 100 },
  });
  assert.deepEqual(
    matches("", apps).map((m) => m.app.name),
    ["Beta", "Alpha"],
  );
  assert.deepEqual(matches("gamma", apps), []);
  assert.equal(matches("zzzzzz", apps).length, 0);
});
