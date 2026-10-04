import { Cache, environment } from "@raycast/api";
import { execFile, spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { promisify } from "node:util";
import { join } from "node:path";
import {
  existsSync,
  readFileSync,
  writeFileSync,
  mkdirSync,
  renameSync,
} from "node:fs";
import { App, Settings } from "./model";
const exec = promisify(execFile);
const cache = new Cache();
const helper = () => join(environment.assetsPath, "launcher-helper");
export const loadApps = (): App[] => JSON.parse(cache.get("apps") ?? "[]");
export const loadSettings = (): Settings | undefined => {
  const path = join(environment.supportPath, "settings.json");
  return existsSync(path) ? JSON.parse(readFileSync(path, "utf8")) : undefined;
};
export const saveSettings = (settings: Settings) => {
  mkdirSync(environment.supportPath, { recursive: true });
  const path = join(environment.supportPath, "settings.json");
  writeFileSync(path + ".tmp", JSON.stringify(settings), { mode: 0o600 });
  renameSync(path + ".tmp", path);
};
export async function refreshApps(): Promise<{
  apps: App[];
  settings: Settings;
  failures: string[];
}> {
  const { stdout } = await exec(helper(), [], {
    maxBuffer: 8 * 1024 * 1024,
    timeout: 15000,
  });
  const snapshot = JSON.parse(stdout) as {
    applications: Omit<App, "originalName">[];
    aliases: Settings["aliases"];
    hidden: string[];
    recent: Settings["recent"];
    failures: string[];
  };
  const previous = loadApps();
  const apps =
    snapshot.failures.length && previous.length
      ? previous
      : snapshot.applications.map((a) => ({ ...a, originalName: a.name }));
  const settings = loadSettings() ?? {
    aliases: snapshot.aliases,
    hidden: snapshot.hidden,
    recent: snapshot.recent,
  };
  cache.set("apps", JSON.stringify(apps));
  saveSettings(settings);
  return { apps, settings, failures: snapshot.failures };
}
// Keep the focus guard warm while the command is mounted; no process launch per keystroke.
export function createFocusGuard() {
  const child = spawn(helper(), ["frontmost-server"], {
    stdio: ["pipe", "pipe", "ignore"],
  });
  let sequence = 0;
  const waiting = new Map<number, (front: boolean) => void>();
  const lines = createInterface({ input: child.stdout });
  lines.on("line", (line) => {
    try {
      const reply = JSON.parse(line);
      waiting.get(reply.id)?.(reply.front === true);
    } catch {
      /* Invalid responses never authorize opening. */
    }
  });
  const fail = () => {
    for (const resolve of [...waiting.values()]) resolve(false);
  };
  child.on("error", fail);
  child.on("exit", fail);
  child.stdin.on("error", fail);
  return {
    check: (signal: AbortSignal): Promise<boolean> =>
      new Promise((resolve) => {
        if (signal.aborted || child.exitCode !== null || child.killed) {
          resolve(false);
          return;
        }
        const id = ++sequence;
        const done = (front: boolean) => {
          clearTimeout(timeout);
          waiting.delete(id);
          signal.removeEventListener("abort", aborted);
          resolve(front);
        };
        const aborted = () => done(false);
        const timeout = setTimeout(() => done(false), 1000);
        waiting.set(id, done);
        signal.addEventListener("abort", aborted, { once: true });
        child.stdin.write(`${id}\n`);
      }),
    close: () => {
      fail();
      lines.close();
      child.kill();
    },
  };
}
