# Reproduce the launcher audit

The audit compares Spotlight commit `6a02d9e` with Sol commit `45fe2c3` and release `2.1.352`.

## Inputs

- The local Spotlight repository and its installed signed `Launcher.app`.
- `https://github.com/ospfranco/sol`, cloned beside Spotlight as `/Users/alejo/best/work/tools/sol`.
- Sol's source, commit history, latest GitHub release metadata and launcher-related issues.

## Checks

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

Download release `2.1.352` to a temporary directory, expand it with `ditto -x -k`, then inspect it with `du` and `codesign -dv --verbose=2`. Do not launch it: normal startup registers global hotkeys and starts unrelated clipboard and update services.

## Source paths inspected

Spotlight:

- `ApplicationCatalog.swift`
- `SpotlightModel.swift`
- `SpotlightWindowController.swift`
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

## Decision method

Compare only the existing application-launcher behavior. Count a Sol pattern as reusable when it closes a current failure without bringing its runtime or another feature. Rank work by silent-failure risk first, then interaction latency, then maintenance cost.
