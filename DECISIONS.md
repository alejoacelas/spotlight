# Launcher decisions

## Core decisions

### Scope

- [Use Raycast as the primary launcher and retain the native fallback](#decision-1).

### macOS identity

- [Keep stable signing and fail when the identity is unavailable](#decision-2).

### Interaction reliability

- [Preserve focus and observable hotkey failures](#decision-3).

### Verification

- [Use the consolidated gate and distinguish CI from signed UI verification](#decision-4).
- [Measure accidental launches without storing queries](#decision-5).

## Details

<a id="decision-1"></a>

### Use Raycast as the primary launcher and retain the native fallback

Raycast owns the primary launcher window and Option–Space binding. Preserve the custom matching and decisive automatic opening in the extension, and reuse the native application catalog. Exact native window appearance is not a requirement. Keep the native app and its defaults available for rollback, but disable its login item while Raycast owns the shortcut. Extension settings are imported once and then stored independently. See [Raycast setup](raycast/README.md) and [implementation e920d35](https://github.com/alejoacelas/spotlight/commit/e920d35).

The earlier reliability comparison chose existing application-launcher behavior over adopting Sol’s broader runtime. The ignored pinned Sol clone is reference material; do not start it casually because startup registers hotkeys and unrelated services. See [docs/launcher-reliability-audit.md](docs/launcher-reliability-audit.md).

<a id="decision-2"></a>

### Keep stable signing and fail when the identity is unavailable

Ad-hoc rebuilds can break privacy identity. Build the app and integration driver with the expected stable identity; Launcher itself does not need the driver’s Accessibility grant. See [scripts/build-app.sh](scripts/build-app.sh).

<a id="decision-3"></a>

### Preserve focus and observable hotkey failures

For the native fallback, the non-activating panel and transactional hotkey registration address silent failure risks. Raycast controls its own panel and global shortcuts; do not assume native focus behavior applies to extensions. Keep catalog refresh failure-preserving and automatic launch cancellable; changes must not trade away prior foreground-app focus or stored shortcuts. See [docs/launcher-reliability-audit.md](docs/launcher-reliability-audit.md).

<a id="decision-4"></a>

### Use the consolidated gate and distinguish CI from signed UI verification

For the native app, scripts/check.sh runs the local signed keyboard workflow and installs; --ci omits UI and installation. Passing non-UI checks does not prove permission availability or real keyboard behavior. See [scripts/check.sh](scripts/check.sh).

<a id="decision-5"></a>

### Measure accidental launches without storing queries

Aggregate selection and latency counters support the planned dogfood threshold. The observation period is not completed merely because implementation and smoke checks passed. See [docs/launcher-reliability-audit.md](docs/launcher-reliability-audit.md). History inspected: [27e714d](https://github.com/alejoacelas/spotlight/commit/27e714d), [e4910a0](https://github.com/alejoacelas/spotlight/commit/e4910a0).

## Decision log

- 2026-10-03: Move the daily launcher into Raycast, preserving custom search behavior while accepting Raycast’s window appearance. Keep the native app as a fallback and give only one launcher the Option–Space binding. [e920d35](https://github.com/alejoacelas/spotlight/commit/e920d35).
