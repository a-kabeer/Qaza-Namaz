#!/usr/bin/env bash
set -euo pipefail
ANDROID_APP="$(realpath "$1")"
EVIDENCE_DIR="$(realpath "$2")"
cd "$ANDROID_APP"

if ! flutter pub get >"$EVIDENCE_DIR/android-pub-get.txt" 2>&1; then
  cat "$EVIDENCE_DIR/android-pub-get.txt"
  exit 1
fi
cat "$EVIDENCE_DIR/android-pub-get.txt"

if ! flutter test integration_test/powersync_encryption_test.dart -d emulator-5554 --reporter expanded >"$EVIDENCE_DIR/android-encryption-test.txt" 2>&1; then
  cat "$EVIDENCE_DIR/android-encryption-test.txt"
  exit 1
fi
cat "$EVIDENCE_DIR/android-encryption-test.txt"

if ! flutter build apk --release --target-platform android-arm64 >"$EVIDENCE_DIR/android-release-build.txt" 2>&1; then
  cat "$EVIDENCE_DIR/android-release-build.txt"
  exit 1
fi
stat --format='release_apk_bytes=%s' build/app/outputs/flutter-apk/app-release.apk >>"$EVIDENCE_DIR/android-release-build.txt"
cat "$EVIDENCE_DIR/android-release-build.txt"
