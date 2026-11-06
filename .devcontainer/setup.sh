#!/usr/bin/env bash
# One-time setup for the codespace. Runs automatically after it is created.
# Everything lands in $HOME, which is kept when the codespace stops, so
# Flutter, the Android SDK and the Gradle cache stay warm between builds.
set -euo pipefail

FLUTTER_DIR="$HOME/flutter"
ANDROID_HOME="$HOME/android-sdk"

# ---- Flutter SDK (stable) ---------------------------------------------------
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

# ---- Android command-line tools ---------------------------------------------
# If this download ever 404s, get the current "Command line tools only" link
# from https://developer.android.com/studio#command-line-tools-only
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  curl -fsSL -o /tmp/cmdline-tools.zip \
    https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q /tmp/cmdline-tools.zip -d "$ANDROID_HOME/cmdline-tools"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm /tmp/cmdline-tools.zip
fi
export ANDROID_HOME
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# Accept licenses so Gradle can download any missing SDK / build-tools / NDK
# pieces by itself on the first build.
yes | sdkmanager --licenses > /dev/null || true
sdkmanager "platform-tools"

# ---- Flutter configuration ----------------------------------------------------
flutter config --android-sdk "$ANDROID_HOME"
flutter config --no-analytics
flutter precache --android

# ---- Project dependencies ------------------------------------------------------
flutter pub get || true

flutter doctor -v || true
echo "Setup finished."
