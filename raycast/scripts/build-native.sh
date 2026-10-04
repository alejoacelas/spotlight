#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swiftc -O ../Sources/Launcher/LauncherModel.swift ../Sources/Launcher/ApplicationCatalog.swift native/main.swift -o assets/launcher-helper
