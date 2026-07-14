<!--ai-->
# Faster Future Development

The fastest route to a broader Raycast-style tool is to make each new command mostly data and business logic, while one tested shell owns search, ranking, actions, shortcuts and presentation.

## Reusable product architecture

Define one `Command` protocol with an identifier, title, keywords, icon, result provider and actions. Applications, windows, files, calculations and quick links then enter the same ranking and action pipeline instead of adding bespoke UI paths.

Build these reusable pieces next:

- a result-row component with title, subtitle, icon and shortcut labels;
- a navigable Command-K action panel with a stack and Back command;
- one shortcut registry with conflict reporting and import/export;
- a query-scoped ranking service that records chosen results;
- a permission broker that explains and requests one macOS capability at a time;
- a small JSON schema for user commands, aliases and workflows.

This is roughly 5–10 focused development days before it saves time. It becomes worthwhile around the third non-application result type or the tenth custom action.

## Better test infrastructure

- Add an XCUITest target for focus, typing, sheets and keyboard navigation once the UI changes more than monthly.
- Keep the current synthetic catalog and add fixtures for windows, files, duplicate names and shortcut conflicts.
- Build a signed test driver that posts keys, waits for named UI states and captures only the launcher window.
- Add diagnostic launch flags that inject a fixed catalog, fixed recency dates and shortcut conflicts.
- Record structured local events for query, ranking reason, selection and latency; exclude typed text by default.
- Run model tests and warnings-as-errors builds on a GitHub macOS runner.

The most valuable missing affordance is a deterministic UI driver. The current `CGEvent`, screenshot and process checks work, but a driver with named states would turn five manual shell steps into one repeatable assertion.

## Inputs that make implementation faster

The user can remove product ambiguity by keeping four short documents:

1. A keymap policy listing reserved, preferred and forbidden shortcuts.
2. Ten real navigation examples with the desired keystrokes and final focused window.
3. A ranking fixture: sample queries with the expected top three results.
4. A privacy policy for clipboard contents, file names, browser history and usage learning.

A 30-second screen recording of the desired interaction is more useful than a long visual specification. For ranking, a table of counterexamples is more useful than adjectives such as “smart” or “fuzzy.”

## macOS setup that saves intervention

- Keep the stable signing identity available and backed up securely.
- Decide in advance whether future window control may request Accessibility and whether clipboard history may store data on disk.
- Reserve a test shortcut range so integration tests do not collide with daily tools.
- Keep two harmless test applications and several synthetic `.app` bundles for launch, rename and duplicate-name checks.
- If UI automation becomes central, grant its signed test driver Accessibility once rather than granting changing command-line binaries repeatedly.

The production app should continue using the least privileged API available. Development convenience is not a reason to add Accessibility to Launcher when Carbon, AppKit or `NSWorkspace` can provide the feature directly.
<!--/ai-->
