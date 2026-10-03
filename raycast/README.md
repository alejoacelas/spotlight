# Launcher for Raycast

Option–Space opens **Launch Applications**. This extension retains the native launcher's search ranking, custom names, hidden apps, recent-use ordering and automatic opening after a decisive match and a 90 ms typing pause. Raycast supplies the window and actions.

## Controls

| Key | Action |
|---|---|
| Return | Open selected application |
| Command–1 through Command–6 | Open a result by position |
| Command–R | Rename selected application |
| Command–K | Show actions, including Hide / Restore |
| Command–Shift–M | Manage applications without automatic opening |
| Command–Shift–R | Refresh applications |
| Command–Shift–P | Pause automatic opening for this view |

**Manage Launcher Applications** is also a separate Raycast command. It includes hidden applications. An empty name restores the original name; renaming only affects Launcher. Search still matches original names and bundle identifiers.

Assign global shortcuts to individual apps in Raycast Settings → Shortcuts. These are managed by Raycast independently of this extension. The native launcher's per-app shortcuts are not imported; none were configured during migration.

Automatic opening can be disabled permanently in the extension's preferences. Ambiguous strong matches stay open for selection. Pending automatic opening is cancelled by another query, selecting a different result, management actions or leaving the command. A native window-order check also suppresses opening when another app is in front or Command, Control or Option is held. Raycast controls keyboard composition and panel focus, so its interaction behavior is not identical to the native app.

## Install and develop

Requires macOS, Raycast, Node.js and the Xcode command-line tools.

```sh
cd raycast
npm ci
npm run dev
```

Development installs the extension locally; commands remain available after stopping the watcher. In Raycast Settings → Extensions → Launcher, assign Option–Space to **Launch Applications**. Quit the native Launcher and remove it from System Settings → General → Login Items before binding the same shortcut. Keep Raycast enabled at login.

```sh
npm run test
npm run typecheck
npm run build
```

The Swift helper reuses `Sources/Launcher/ApplicationCatalog.swift` for discovery, alias resolution and bundle deduplication. It is compiled for the current Mac; rebuild when moving to a different architecture. The TypeScript ranker is checked against the native app's shared ranking fixtures. Catalog refresh runs whenever a command opens and can be triggered manually; cached results appear immediately, and failed scans retain prior results.

Names, hidden apps and usage history are imported once from `com.alejoacelas.launcher`. Subsequent extension changes live in Raycast's extension support directory, in `settings.json`; the native defaults remain separate. No query history is saved and the extension makes no network requests.

To switch back, remove the extension's Option–Space binding, then open `~/Applications/Launcher.app`. The native app registers itself at login when opened. Changes made inside Raycast after migration are not copied back.
