#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEME="gallery"
CONFIGURATION="Debug"
DESTINATION_DEVICE="${1:-iPhone 14}"
BUNDLE_ID="com.netdots.gallery"
DERIVED_DATA_PATH="$PROJECT_DIR/.derivedData"

cd "$PROJECT_DIR"

echo "▶ Building ${SCHEME} for simulator..."
xcodebuild build \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=iOS Simulator,name=${DESTINATION_DEVICE}" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -quiet

echo "▶ Resolving built app path..."
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug-iphonesimulator/${SCHEME}.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "✖ App not found at: $APP_PATH"
  exit 1
fi

echo "▶ Booting simulator: ${DESTINATION_DEVICE}"
xcrun simctl boot "$DESTINATION_DEVICE" >/dev/null 2>&1 || true
open -a Simulator >/dev/null 2>&1 || true

echo "▶ Installing app..."
xcrun simctl install "$DESTINATION_DEVICE" "$APP_PATH"

echo "▶ Launching app (${BUNDLE_ID})..."
xcrun simctl launch "$DESTINATION_DEVICE" "$BUNDLE_ID"

echo "✔ Done"
