#!/usr/bin/env bash
# Builds the Android APKs that point at your hosted server.
#   tool/build_release.sh https://swadharma-api.onrender.com
set -euo pipefail
cd "$(dirname "$0")/.."

URL="${1:-}"
if [[ -z "$URL" || ! "$URL" =~ ^https?:// ]]; then
  echo "Usage: tool/build_release.sh <server address, e.g. https://swadharma-api.onrender.com>" >&2
  exit 1
fi
URL="${URL%/}"

echo "Building release APKs for $URL ..."
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL="$URL"

echo
echo "Done. Send the client:"
ls -lh build/app/outputs/flutter-apk/*-release.apk | awk '{print "  " $5 "  " $9}'
echo
echo "app-arm64-v8a-release.apk works on almost every Android phone made since 2017."
