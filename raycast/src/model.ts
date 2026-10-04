export interface App {
  name: string;
  originalName: string;
  path: string;
  bundleId?: string;
  lastUsedAt?: number;
}
export interface Settings {
  aliases: Record<string, string>;
  hidden: string[];
  recent: Record<string, number>;
}
export interface Match {
  app: App;
  tier: number;
}
export const key = (app: { bundleId?: string; path: string }) =>
  app.bundleId ?? `path:${app.path}`;
export const normalize = (s: string) =>
  s
    .normalize("NFKD")
    .replace(/\p{M}/gu, "")
    .toLocaleLowerCase()
    .split(/[^\p{L}\p{N}]+/u)
    .filter(Boolean)
    .join(" ");
export function editDistance(left: string, right: string): number {
  const a = [...left],
    b = [...right];
  let previous = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 0; i < a.length; i++) {
    const current = [i + 1];
    for (let j = 0; j < b.length; j++)
      current[j + 1] = Math.min(
        current[j] + 1,
        previous[j + 1] + 1,
        previous[j] + (a[i] === b[j] ? 0 : 1),
      );
    previous = current;
  }
  return previous[b.length];
}
function tier(query: string, name: string): number | undefined {
  if (!query) return 7;
  if (!name) return;
  if (name === query) return 0;
  if (name.startsWith(query)) return 1;
  const words = name.split(" ");
  if (words.some((w) => w.startsWith(query))) return 2;
  if (name.includes(query)) return 3;
  if (
    words
      .map((w) => [...w][0])
      .join("")
      .startsWith(query.replaceAll(" ", ""))
  )
    return 4;
  const count = [...query].length;
  if (count < 4) return;
  let cursor = 0;
  const subsequence = [...query.replaceAll(" ", "")].every((c) => {
    const index = name.indexOf(c, cursor);
    cursor = index + 1;
    return index >= 0;
  });
  if (subsequence) return 5;
  const allowance = Math.max(1, Math.min(3, Math.floor(count / 4)));
  const targets = [
    name,
    ...words,
    ...words.map((_, i) => words.slice(i).join(" ")),
  ];
  if (
    targets.some(
      (t) =>
        editDistance(
          query,
          [...t]
            .slice(
              0,
              Math.max(count, Math.min([...t].length, count + allowance)),
            )
            .join(""),
        ) <= allowance,
    )
  )
    return 6;
}
export function applySettings(
  apps: App[],
  settings: Settings,
  includeHidden = false,
): App[] {
  return apps
    .filter((a) => includeHidden || !settings.hidden.includes(key(a)))
    .map((a) => ({
      ...a,
      name: settings.aliases[key(a)]?.trim() || a.originalName,
      lastUsedAt: Math.max(a.lastUsedAt ?? 0, settings.recent[key(a)] ?? 0),
    }));
}
export function matches(query: string, apps: App[], limit = 6): Match[] {
  const normalized = normalize(query);
  return apps
    .flatMap((app) => {
      const tiers = [app.name, app.originalName, app.bundleId ?? ""]
        .map((n) => tier(normalized, normalize(n)))
        .filter((t): t is number => t !== undefined);
      return tiers.length ? [{ app, tier: Math.min(...tiers) }] : [];
    })
    .sort(
      (a, b) =>
        a.tier - b.tier ||
        (b.app.lastUsedAt ?? 0) - (a.app.lastUsedAt ?? 0) ||
        a.app.name.localeCompare(b.app.name, undefined, {
          sensitivity: "base",
        }) ||
        a.app.path.localeCompare(b.app.path),
    )
    .slice(0, limit);
}
export function decisive(query: string, results: Match[]): App | undefined {
  const length = [...normalize(query)].length;
  if (length < 2) return;
  if (results.length === 1) return results[0].app;
  if (length >= 3 && results[0]?.tier <= 2 && results[1]?.tier > 2)
    return results[0].app;
}
