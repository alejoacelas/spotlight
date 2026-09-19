# REPLICATE

## Finish the workspace migration

The human wanted the remaining folder reorganization finished and authorized interrupting conflicting sessions.

- Preserved this repository and its instruction wording, declared the tools group, and made CLAUDE.md import AGENTS.md. Its current path is /Users/alejo/best/tools/stable/spotlight. Moved the retired archive into ~/best/archive/ while leaving the active implementation unchanged.

Agent session 01a072fe-84d6-73f3-b37e-3bb912088c38 · Commits spotlight: fd2da80

## Agent instructions cleanup — 2026-09-19

Alejo asked to refresh project instructions and remove redundant Claude instruction files where native AGENTS.md loading is available.

- Updated the applicable instructions and removed redundant local Claude copies; distinct content and preserved snapshots remain.
- Checked instruction references and shared-context freshness; native Claude loading requires 2.1.277+ with the built-in feature enabled.

Agent session 01a0b915-3eb2-78b2-9add-6ba48ad9a3b1 · Commits bab757c45c6b725e96033d572c731eeef466bfb4

## Explicit startup instructions

Alejo wanted shared instructions selected deliberately at startup, without copied text or automatic parent inheritance.

- Removed agent-context YAML and generated shared text; retained project-specific instructions locally.
- Shared groups: tools. Selection now lives in the machine's context registry; startup does not rewrite this file.

Agent session 01a0b915-3eb2-78b2-9add-6ba48ad9a3b1 · Commits 3613dcd

<a id="construction-records"></a>

## Construction records

Preserved records from the former construction-notes folder.

<a id="record-launcher-reliability-audit"></a>

### Reproduce the launcher reliability work

The audit compared Launcher commit `6a02d9e` with Sol commit `45fe2c3` and release `2.1.352`. Implementation kept the native app and ported only the panel, catalog and lifecycle patterns described in the audit.

#### Inputs

- The local Spotlight repository and its installed signed `Launcher.app`.
- `https://github.com/ospfranco/sol`, cloned inside the launcher as `sol/` and left unmodified.
- Sol's source, commit history, latest GitHub release metadata and launcher-related issues.

#### Checks

From `spotlight/`:

```sh
swift test
swift build -c release -Xswiftc -warnings-as-errors
find Sources Tests -type f -name '*.swift' -print0 | xargs -0 wc -l
du -sh "$HOME/Applications/Launcher.app"
ps -axo pid,rss,etime,command | rg '[L]auncher.app'
plutil -p Info.plist
plutil -p "$HOME/Applications/Launcher.app/Contents/Info.plist"
defaults read com.alejoacelas.launcher
sfltool dumpbtm | rg -C 3 'com\.alejoacelas\.(launcher|spotlight)'
```

The maintained release gate replaces the individual build commands:

```sh
./scripts/check.sh       # tests, release, signing, signed UI smoke test, install
./scripts/check.sh --ci  # same non-UI checks, without permission or installation
```

The UI driver launches an isolated six-row catalog, asserts the named window state and prior frontmost application, and exercises Command-Space, text, arrows, Return, Escape, Command-1 through Command-6 and Command-K. Only the signed driver needs Accessibility permission; Launcher does not.

From `sol/`:

```sh
git rev-list --count HEAD
find src macos/sol-macOS -type f \( -name '*.swift' -o -name '*.m' -o -name '*.mm' -o -name '*.h' -o -name '*.tsx' -o -name '*.ts' -o -name '*.js' \) -print0 | xargs -0 wc -l
gh release list --repo ospfranco/sol --limit 10
gh api repos/ospfranco/sol/releases/latest
gh issue view 290 --repo ospfranco/sol
gh issue view 294 --repo ospfranco/sol
gh issue view 300 --repo ospfranco/sol
gh issue view 312 --repo ospfranco/sol
```

The reference clone is intentionally ignored rather than vendored or added as a submodule. Recreate it from the launcher root with:

```sh
git clone https://github.com/ospfranco/sol sol
git -C sol checkout 45fe2c3d673f92c276b250f1dc9e6af552a4a67f
```

Download release `2.1.352` to a temporary directory, expand it with `ditto -x -k`, then inspect it with `du` and `codesign -dv --verbose=2`. Do not launch it: normal startup registers global hotkeys and starts unrelated clipboard and update services.

#### Source paths inspected

Launcher:

- `ApplicationCatalog.swift`
- `LauncherModel.swift`
- `LauncherWindowController.swift`
- `GlobalHotKey.swift`
- `AppShortcut.swift`
- `main.swift`
- all model tests and operational documentation

Sol:

- `ApplicationSearcher.swift`
- `Panel.swift` and `PanelManager.swift`
- `HotKeyManager.swift`
- `MainInput.tsx` and `search.widget.tsx`
- search, UI and keystroke stores
- package manifests, build configuration, recent path history and launcher-related issues

#### Decision method

Compare only the existing application-launcher behavior. Count a Sol pattern as reusable when it closes a current failure without bringing its runtime or another feature. Rank work by silent-failure risk first, then interaction latency, then maintenance cost.
