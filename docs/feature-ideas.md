<!--ai-->
# Feature Ideas

The filter is simple: reduce the time or attention required to move from an intention to the right application, window, file or action.

Estimates assume one developer extending the current native Swift app, with automated model tests and signed-app verification. Measure actual use before building anything estimated above three days.

## Highest leverage next

| Feature | User-visible result | Estimate |
|---|---|---:|
| Window results | Search and jump to a specific open window, not merely its app. | 2–4 days |
| Recent files | Search files recently opened by the matched app and open them directly. | 2–5 days |
| App actions | Command-K actions for new window, hide, quit and reveal in Finder. | 1–2 days |
| Learned ranking | Reorder by query-specific launch history, not only global recency. | 1–2 days plus two weeks of usage data |
| Keywords | Give one app several searchable aliases without changing its displayed name. | 0.5–1 day |

Window results are the best next bet if switching between several windows of the same app is common. Recent files win if most navigation starts from a document rather than an application.

## Fast commands

- Calculator, unit conversion and timezone conversion inline.
- Quick links with parameters, such as opening a named project or searching a chosen site.
- Clipboard history with explicit retention and exclusion rules.
- Short workflows that run several commands, then focus the resulting app.
- Window layouts such as left half, right half, next display and restore previous frame.
- Direct commands for system settings, audio output, focus modes and display controls.

These widen the app's privacy and permission surface. Clipboard history and system control should remain separate modules that can be disabled completely.

## Navigation quality

- Back navigation after drilling into actions or files.
- Pinned results that still yield to a strong exact match.
- A usage explanation showing why a result ranked where it did.
- Search tokens such as `app:`, `window:` or `file:` only when ordinary fuzzy search becomes ambiguous.
- Drag-and-drop a file onto an app result.
- A compact detail pane for the selected result, hidden by default.

## Reliability

- A menu-bar health view for shortcut conflicts, catalog age and login-item state.
- Automatic catalog refresh when applications are installed, moved or removed.
- Export and import aliases, shortcuts and workflows as readable JSON.
- A safe mode that starts without third-party commands if one crashes repeatedly.
<!--/ai-->
