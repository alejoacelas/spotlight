# Launcher reliability audit

Keep the native Swift launcher. Port four macOS lifecycle patterns from Sol; do not strip or fork Sol.

This recommendation preserves Spotlight's current scope: find and open applications, rank likely matches, auto-open a decisive match, rename or remove results, assign shortcuts, and start at login. It adds no result types or commands.

## Why not use Sol as the base?

| | Spotlight | Sol 2.1.352 |
| --- | ---: | ---: |
| Launcher-owned source | 1,160 Swift lines | 38,623 Swift, Objective-C and TypeScript lines in the app |
| Release bundle | 392 KB | 38 MB |
| Observed idle memory | 40 MB | Not run: launching Sol would register hotkeys and start clipboard and updater services |
| Automated tests | 12 model tests | No test files or CI workflow in the repository |
| Runtime | AppKit | React Native macOS, Hermes and native bridges |

Sol's launcher is not an isolated component. Its window and hotkeys call a native event emitter; search lives in a 1,353-line MobX store; selection and opening live in a second keystroke store; rendering uses React Native and a patched list library. Keeping that code means keeping most of Sol's runtime. Removing the runtime means rewriting the launcher around the extracted ideas.

The extra surface has caused failures outside the feature set we need. Sol has reports of [intermittent shortcut failure](https://github.com/ospfranco/sol/issues/290), [incorrect search results](https://github.com/ospfranco/sol/issues/176), [selection opening a hidden result](https://github.com/ospfranco/sol/issues/300), and [Hermes memory exhaustion](https://github.com/ospfranco/sol/issues/294). Some are fixed, but they show the cost of sharing one state machine across unrelated widgets. Sol also still has an open request for [internal app-name matches](https://github.com/ospfranco/sol/issues/312), which Spotlight already supports.

Sol remains useful as tested field experience. Its repository has 852 commits since October 2024 and a current notarized release. We should copy the small native patterns that address failures we can reproduce or explain.

## Reliability work

### 1. Keep the existing app identity

The checked-out branch renamed the product and bundle identifier from `Launcher` / `com.alejoacelas.launcher` to `Spotlight` / `com.alejoacelas.spotlight`. The installed app, running process, login item and preference domain still use Launcher. Those preferences contain the real aliases, excluded apps and Command-Space choice.

Installing the branch as written would:

- leave the old Launcher installed, running and registered at login;
- register a second login item and compete for Command-Space;
- start with empty aliases, exclusions and per-app shortcuts because `UserDefaults.standard` moved domains;
- make the build script's `pkill -x Spotlight` match Apple's own `/System/Library/CoreServices/Spotlight.app` process.

Revert the product rename and retain `com.alejoacelas.launcher`. The user-facing name can change later only with an explicit migration that copies preferences, unregisters the old login item, replaces the old bundle and never targets a process by a name shared with macOS. A name change has no launcher reliability benefit.

Acceptance checks:

- one installed bundle, process, preference domain and login item exist after upgrade;
- the current aliases and exclusions survive the upgrade;
- the old build upgrades in place and Command-Space works without a restart;
- the install script resolves the exact installed bundle and process instead of using a shared process name.

Estimate: 0.5 day. Do this before installing or integration-testing the branch.

### 2. Preserve the previously focused app

Spotlight currently activates itself before showing a borderless panel. Escape then hides the only window without explicitly restoring the previous application. This can leave a menu-bar accessory as the active app with no visible UI.

Use a non-activating `NSPanel`, as [Sol does](https://github.com/ospfranco/sol/blob/45fe2c3d673f92c276b250f1dc9e6af552a4a67f/macos/sol-macOS/views/Panel.swift), and hide it from `windowDidResignKey`. Remove `NSApp.activate` from the ordinary show path; activate only for the action sheets that need it.

Acceptance checks:

- Command-Space focuses the search field on every invocation and every Space.
- Escape, a second Command-Space, clicking outside, and launching an app all leave the expected app frontmost.
- The panel appears over full-screen apps and on the display containing the pointer.
- An open action sheet closes cleanly when the launcher is toggled.

Estimate: 0.5–1 day including a signed-app keyboard test.

### 3. Make the application catalog complete and self-refreshing

Spotlight scans the three standard Applications directories once at launch and only refreshes from the menu. On this Mac those roots contain 92 apps. It misses Finder because Finder lives in `/System/Library/CoreServices`, and installed, moved or removed apps remain stale until a manual refresh or restart.

Keep the current background scan and atomic replacement, then add the narrow parts of [Sol's application searcher](https://github.com/ospfranco/sol/blob/45fe2c3d673f92c276b250f1dc9e6af552a4a67f/macos/sol-macOS/lib/ApplicationSearcher.swift):

- include explicit CoreServices apps such as Finder rather than recursively exposing every helper;
- resolve aliases and symbolic links before deduplication;
- watch only the catalog roots, debounce changes, and refresh off the main thread;
- recreate the watcher after wake;
- retain the previous catalog if a refresh fails and expose the failure in the menu.

Do not copy Sol's force unwraps, Sentry coupling, four-level generic recursion, or scan-on-every-show behavior.

Acceptance checks:

- install, move, rename and remove a synthetic `.app`; results change within two seconds without reopening Spotlight;
- Finder and the intended system utilities appear exactly once;
- duplicate bundle identifiers choose deterministically and a broken alias does not abort the scan;
- sleep/wake leaves refresh working;
- a denied directory or transient read error cannot replace a good catalog with an empty one.

Estimate: 1–2 days.

### 4. Make shortcut registration transactional and observable

The 72-line Carbon wrapper is the right size and needs no Accessibility grant. It currently ignores failure from `InstallEventHandler`, unregisters the old key before it knows the new one works, and can show a shortcut as selected after registration failed. Per-app shortcuts that fail during startup remain displayed even though they do nothing.

Harden the existing wrapper instead of adopting Sol's third-party `HotKey` dependency:

- fail construction if the Carbon event handler cannot be installed;
- register a replacement before committing it, preserving the working registration on failure;
- store registered and desired shortcut state separately;
- show failed registrations beside the affected item and in the menu;
- retry after wake and session activation, then report failure instead of silently continuing;
- validate persisted key codes and recover from corrupt preferences.

This directly guards the failure described by Sol's maintainer: “The keyboard listener sometimes just fails. Restarting the app fixes it.” See [issue 290](https://github.com/ospfranco/sol/issues/290).

Acceptance checks:

- deliberately collide with a harmless registered shortcut; the prior shortcut keeps working;
- restart with one unavailable per-app shortcut; other shortcuts work and the unavailable one is visibly marked;
- wake the Mac and verify the launcher and per-app shortcuts without restarting;
- corrupt the saved shortcut data; Spotlight starts with defaults and reports the reset once.

Estimate: 1 day.

### 5. Make ranking behavior empirical and durable

The custom matcher is preferable to Sol's MiniSearch configuration: its exact, prefix, word-prefix, substring, acronym, subsequence and typo tiers are readable and covered by tests. Keep it.

The remaining weaknesses are in policy and evidence:

- only 12 synthetic tests define ranking behavior;
- recent use breaks only numerically identical scores, so it rarely changes typed-query order;
- recency depends on macOS metadata at restart, which may be absent or delayed;
- an alias replaces the original searchable name, contradicting `docs/testing.md`;
- auto-launch fires synchronously after two characters, so a transient partial query can open the wrong app before the next keystroke.

Fix these without changing the visible feature set:

- record Spotlight launches by stable application key and persist the timestamp;
- rank by match tier first, then launcher recency within the tier, then deterministic name and path order;
- search both alias and original name while displaying the alias;
- build a checked-in fixture of 20–30 real query → ordered-result expectations, with app identities anonymized if necessary;
- make auto-launch cancellable and wait 75–100 ms for another keystroke; never auto-launch marked text from an input method;
- record local latency and chosen-result counters without retaining query text.

Thresholds:

- warm hotkey to focused input: p95 under 50 ms;
- keystroke to reranked rows for 500 synthetic apps: p95 under 16 ms;
- accidental auto-launches in the fixture and a one-week dogfood sample: zero;
- a strong exact or leading match must never lose to history.

Estimate: 1–2 days plus one week of passive use before calling the ranking settled.

### 6. Test the native boundaries

The model tests and warnings-as-errors release build pass. They do not exercise the failure-prone boundaries: catalog enumeration, Carbon registration, focus, window dismissal, preferences or `NSWorkspace` opening.

Add three layers:

1. Inject catalog roots and preferences so tests can create synthetic `.app` bundles, aliases, duplicates and corrupt state.
2. Test the Carbon registry with reserved test shortcuts and assert rollback after conflicts.
3. Add one signed integration driver for show, focus, type, arrows, Return, Escape, Command-1 through Command-6 and Command-K. Assert named accessibility state and the frontmost bundle identifier instead of relying on screenshots alone.

Run `swift test`, a warnings-as-errors release build, bundle signing verification, and the integration smoke test in one command. CI can run the first two; the signed local test covers macOS integration.

Estimate: 1–2 days. This overlaps the tests included in the estimates above.

## What to remove or defer

For the current feature boundary, remove stale promises and avoid infrastructure that only helps a larger command palette:

- Correct `docs/testing.md`: aliases currently replace, rather than supplement, the original search term until the ranking fix lands.
- Remove the unused `renameAction` distinction or make Command-R open the rename sheet directly; today Command-R and Command-K call the same action panel.
- Remove the read-only “Start at Login” menu row unless it becomes an actual toggle. Login registration itself is part of current behavior.
- Archive `docs/feature-ideas.md` and `docs/development-affordances.md` outside the operational docs. They optimize for adding result types, which is explicitly out of scope.
- Do not add a command protocol, permissions broker, import/export, telemetry service, update framework, JavaScript runtime, search dependency or Accessibility event tap.

If the intended product is narrower than the README—only Command-Space, type, arrows, Return and Escape—strip Spotlight's rename, removal and per-app shortcut code. That should reduce the current code by roughly 300–400 lines. It is still a smaller and safer change than stripping Sol.

## Sequence

1. Restore the Launcher identity and make upgrades replace the installed app in place.
2. Fix panel activation and add the signed focus test.
3. Make Carbon registration transactional and test conflicts and wake.
4. Make the catalog complete, watched and failure-preserving.
5. Lock ranking to real fixtures, persist launch recency and debounce auto-launch.
6. Delete stale documentation and unused paths.

The implementation is about 5–8 focused development days. The recommendation changes only if the launcher grows beyond applications: at a third result type, Sol's shared command architecture becomes worth reconsidering, but its React Native application still should not become the base by default.

## Evidence captured

- Sol commit audited: [`45fe2c3`](https://github.com/ospfranco/sol/tree/45fe2c3d673f92c276b250f1dc9e6af552a4a67f).
- Sol release audited: [`2.1.352`](https://github.com/ospfranco/sol/releases/tag/2.1.352), published August 12, 2026; 14 MB download and 38 MB expanded.
- Spotlight commit audited: `6a02d9e`; clean `swift test` with 12 tests and clean warnings-as-errors release build on August 18, 2026.
- Current installed `Launcher.app`: 392 KB, stable `Switcher Local Code Signing` signature, 40 MB observed resident memory after almost three days running.
- Current machine state: one enabled `com.alejoacelas.launcher` login item and a populated `com.alejoacelas.launcher` preference domain; no Spotlight-domain preferences.
