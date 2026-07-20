#!/bin/zsh
set -euo pipefail

cd "${0:A:h}/.."
swift build -c release

identity=${SPOTLIGHT_SIGNING_IDENTITY:-9257B8A858373198212307FFADAC84FC1B109BF5}
if ! security find-identity -v -p codesigning | grep -Fq "$identity"; then
  echo "Missing code-signing identity: $identity" >&2
  echo "A stable identity is required; ad-hoc signing would change the app identity on every build." >&2
  exit 1
fi

app=.build/Spotlight.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/Spotlight "$app/Contents/MacOS/Spotlight"
cp Info.plist "$app/Contents/Info.plist"
codesign --force --sign "$identity" --options runtime --timestamp=none "$app"
codesign --verify --deep --strict --verbose=2 "$app"

if [[ ${1:-} == --install ]]; then
  destination="$HOME/Applications/Spotlight.app"
  mkdir -p "$HOME/Applications"
  pkill -x Spotlight 2>/dev/null || true
  rm -rf "$destination"
  ditto "$app" "$destination"
  open "$destination"
  echo "$destination"
else
  echo "$PWD/$app"
fi
