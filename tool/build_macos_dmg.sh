#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: build_macos_dmg.sh must be run on macOS with Xcode installed." >&2
  exit 2
fi

for command_name in flutter xcodebuild hdiutil; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Error: '$command_name' is required. Install Flutter and Xcode Command Line Tools first." >&2
    exit 2
  fi
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

flutter config --enable-macos-desktop
flutter pub get
flutter build macos --release --no-codesign

PRODUCTS_DIR="$PROJECT_ROOT/build/macos/Build/Products/Release"
APP_PATH="$(find "$PRODUCTS_DIR" -maxdepth 1 -type d -name '*.app' -print -quit)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Error: Flutter did not produce a macOS .app bundle in $PRODUCTS_DIR" >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cadence-dmg.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

DMG_PATH="$PRODUCTS_DIR/Cadence.dmg"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "Cadence" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

printf '\nDMG created: %s\n' "$DMG_PATH"
printf 'This local-testing build is unsigned and not notarized. macOS may require Control-click > Open the first time.\n'
