#!/bin/zsh
set -euo pipefail

cd "${0:A:h}/.."

ci=false
if [[ ${1:-} == --ci ]]; then
  ci=true
elif [[ $# -ne 0 ]]; then
  echo "Usage: $0 [--ci]" >&2
  exit 2
fi

swift test
swift build -c release -Xswiftc -warnings-as-errors
./scripts/build-app.sh

if $ci; then
  echo "CI checks passed"
  exit 0
fi

identity=${LAUNCHER_SIGNING_IDENTITY:-9257B8A858373198212307FFADAC84FC1B109BF5}
driver=.build/LauncherIntegrationDriver
swiftc integration/LauncherIntegrationDriver.swift -o "$driver" -framework AppKit -framework ApplicationServices
codesign --force --sign "$identity" --options runtime --timestamp=none "$driver"
codesign --verify --strict --verbose=2 "$driver"

destination="$HOME/Applications/Launcher.app"
for pid in $(pgrep -x Launcher 2>/dev/null || true); do
  executable=$(ps -p "$pid" -o command= | sed 's/^ *//')
  if [[ "$executable" == "$destination/Contents/MacOS/Launcher" ]]; then
    kill -TERM "$pid"
  fi
done

log=$(mktemp "${TMPDIR:-/tmp}/launcher-integration.XXXXXX")
trap 'rm -f "$log"' EXIT
"$driver" "$PWD/.build/Launcher.app/Contents/MacOS/Launcher" "$log"
./scripts/build-app.sh --install
echo "All launcher checks passed"
