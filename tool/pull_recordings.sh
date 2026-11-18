#!/usr/bin/env bash
# Copies the recordings of the diagnostics page from a phone to
# build/recordings. An iPhone or iPad needs Xcode; an Android phone needs adb
# and a debug or profile build of the app.
#
# usage: tool/pull_recordings.sh [device id]   (default: the first phone)
set -euo pipefail
cd "$(dirname "$0")/.."

IOS_APP=com.markosyan.flutterZxingExample
ANDROID_APP=com.markosyan.flutter_zxing_example
OUT=build/recordings
mkdir -p "$OUT"

read -r ID PLATFORM < <(cd example && flutter devices --machine 2>/dev/null | python3 -c "
import json, sys
wanted = sys.argv[1]
phones = [d for d in json.load(sys.stdin) if d['targetPlatform'].startswith(('ios', 'android'))]
match = [d for d in phones if not wanted or wanted in (d['id'], d['name'])]
print(match[0]['id'], match[0]['targetPlatform']) if match else print('', '')
" "${1:-}")

if [ -z "${ID:-}" ]; then
  echo "error: no phone found${1:+ with the id or name $1} (make devices)" >&2
  exit 1
fi

case "$PLATFORM" in
  ios)
    xcrun devicectl device copy from --device "$ID" \
      --domain-type appDataContainer --domain-identifier "$IOS_APP" \
      --source Documents/recordings --destination "$OUT"
    ;;
  *)
    adb -s "$ID" exec-out run-as "$ANDROID_APP" tar c -C app_flutter/recordings . | tar x -C "$OUT"
    ;;
esac
echo "Recordings in $OUT:"
ls -lh "$OUT"
