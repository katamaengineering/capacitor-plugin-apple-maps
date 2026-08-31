#!/usr/bin/env bash
#
# Runs the plugin's XCTest suite on whatever iPhone simulator is installed.
# Selecting by UDID keeps this working across machines and CI images (which
# ship different iPhone models) without hardcoding a device name.
#
# Override the device with:  SIMULATOR_UDID=<udid> npm run test:ios
set -euo pipefail

SCHEME="CapacitorPluginAppleMaps"

UDID="${SIMULATOR_UDID:-}"
if [ -z "${UDID}" ]; then
  UDID=$(xcrun simctl list devices available \
    | grep -iE 'iPhone' \
    | grep -oiE '[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}' \
    | head -n 1 || true)
fi

if [ -z "${UDID}" ]; then
  echo "No available iPhone simulator found. Install one via Xcode > Settings > Components." >&2
  exit 1
fi

echo "Testing on simulator ${UDID}"
exec xcodebuild test \
  -scheme "${SCHEME}" \
  -destination "platform=iOS Simulator,id=${UDID}"
