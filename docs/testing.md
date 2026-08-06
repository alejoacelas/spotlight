---
human_edit_tracking:
  enabled: true
  history: []
---
# Testing

## Automated model tests

`swift test` covers:

- exact, prefix, word-prefix, internal, acronym and subsequence ranking;
- typo and diacritic tolerance;
- auto-launch only after two characters and only with one remaining match;
- recent-use ordering;
- the six-result limit;
- persistent aliases, restoration and search by both alias and original name;
- per-app shortcut display and persistence encoding;
- application exclusion from results;
- queries with no matches.

These tests use synthetic application records, so they run quickly and do not launch programs.

## Signed-app checks

The release bundle is installed before integration testing. I then use:

- `codesign` to verify the bundle and its designated requirement;
- `pgrep` to confirm Spotlight or a target application actually started;
- `defaults` to inspect persisted shortcut and alias preferences;
- `mdls` to confirm macOS exposes last-used metadata;
- `sfltool dumpbtm` to inspect the registered background/login item;
- `osascript` with System Events to read the frontmost application after an auto-launch;
- `screencapture` plus visual image inspection to check text clipping, row count, spacing, selection and dialogs.

Spotlight accepts development-only `--demo` and `--demo-query=…` arguments. They open the real production UI with a deterministic query, which makes visual and launch checks reproducible without changing normal behavior.

## Keyboard-path checks

For keyboard commands, a short Swift command creates `CGEvent` key events and posts them directly to the running Spotlight's process ID. This exercises the same AppKit key-equivalent path as a physical keypress. I use it for toggle, numbered-row, Command-K action, rename and shortcut-recorder checks.

The in-app computer-control bridge was also attempted, but it did not return app state in this run. The local macOS tools above provided deterministic evidence instead.
