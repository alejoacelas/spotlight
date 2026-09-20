# Launcher decisions

## Core decisions

### Scope

- [Keep the small native launcher and borrow only relevant Sol patterns](#decision-1).

### macOS identity

- [Keep stable signing and fail when the identity is unavailable](#decision-2).

### Interaction reliability

- [Preserve focus and observable hotkey failures](#decision-3).

### Verification

- [Use the consolidated gate and distinguish CI from signed UI verification](#decision-4).
- [Measure accidental launches without storing queries](#decision-5).

## Details

<a id="decision-1"></a>

### Keep the small native launcher and borrow only relevant Sol patterns

The reliability comparison chose existing application-launcher behavior over adopting Sol’s broader runtime. The ignored pinned Sol clone is reference material; do not start it casually because startup registers hotkeys and unrelated services. See [docs/launcher-reliability-audit.md](docs/launcher-reliability-audit.md).

<a id="decision-2"></a>

### Keep stable signing and fail when the identity is unavailable

Ad-hoc rebuilds can break privacy identity. Build the app and integration driver with the expected stable identity; Launcher itself does not need the driver’s Accessibility grant. See [scripts/build-app.sh](scripts/build-app.sh).

<a id="decision-3"></a>

### Preserve focus and observable hotkey failures

The non-activating panel and transactional hotkey registration address silent failure risks. Keep catalog refresh failure-preserving and automatic launch cancellable; changes must not trade away prior foreground-app focus or stored shortcuts. See [docs/launcher-reliability-audit.md](docs/launcher-reliability-audit.md).

<a id="decision-4"></a>

### Use the consolidated gate and distinguish CI from signed UI verification

scripts/check.sh runs the local signed keyboard workflow and installs; --ci omits UI and installation. Passing non-UI checks does not prove permission availability or real keyboard behavior. See [scripts/check.sh](scripts/check.sh).

<a id="decision-5"></a>

### Measure accidental launches without storing queries

Aggregate selection and latency counters support the planned dogfood threshold. The observation period is not completed merely because implementation and smoke checks passed. See [docs/launcher-reliability-audit.md](docs/launcher-reliability-audit.md). History inspected: [27e714d](https://github.com/alejoacelas/spotlight/commit/27e714d), [e4910a0](https://github.com/alejoacelas/spotlight/commit/e4910a0).
