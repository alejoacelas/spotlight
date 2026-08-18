# Testing

## Automated model tests

`swift test` covers 27 cases, including:

- exact, prefix, word-prefix, internal, acronym and subsequence ranking;
- typo and diacritic tolerance;
- cancellable delayed auto-launch and ambiguous-query suppression;
- recent-use ordering;
- the six-result limit;
- persistent aliases, restoration and search by both alias and original name;
- transactional Carbon conflicts and corrupt shortcut recovery;
- synthetic catalog bundles, symlinks, failures and a live FSEvents refresh;
- a checked-in 20-app ranking fixture and a 500-app p95 latency budget;
- application exclusion from results;
- queries with no matches.

These tests use synthetic application records and bundles, so they run quickly and do not launch programs.

## Signed-app checks

`./scripts/check.sh` runs the tests, a warnings-as-errors release build, bundle assembly, stable signing, signing verification and a signed keyboard smoke test before installing `~/Applications/Launcher.app`.

- `codesign` to verify the bundle and its designated requirement;
- named accessibility identifiers for the window, focused search field and results table;
- the frontmost bundle identifier before and after showing and dismissing the non-activating panel;
- real CGEvents for Command-Space, text, arrows, Return, Escape, Command-1 through Command-6 and Command-K;
- an isolated six-row integration catalog that records selections instead of opening unrelated apps.

The signed driver needs Accessibility permission because it injects and inspects input. Launcher itself does not. `./scripts/check.sh --ci` runs every non-UI check without that grant.

Launcher also accepts development-only `--demo` and `--demo-query=…` arguments for deterministic visual inspection.
