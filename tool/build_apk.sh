#!/usr/bin/env bash
# Usage (inside the codespace):
#   bash tool/build_apk.sh              # profile build (use this to test map speed)
#   bash tool/build_apk.sh release      # release build
#   bash tool/build_apk.sh debug        # fastest to build, but slow to run
#
# Builds only for 64-bit ARM phones (almost every modern Android phone), which
# is noticeably faster than building every architecture.
set -euo pipefail

MODE="${1:-profile}"

git pull --ff-only
flutter pub get
flutter build apk "--$MODE" --target-platform android-arm64

APK="build/app/outputs/flutter-apk/app-$MODE.apk"
ls -lh "$APK"
echo
echo "To download it, run this on YOUR OWN computer (needs the GitHub CLI):"
echo "  gh codespace cp -e 'remote:$PWD/$APK' ."
