#!/usr/bin/env bash
# Vercel's build image does not include the Flutter SDK, so we fetch a
# pinned stable release ourselves, then build the Flutter web app.
# This script is invoked via vercel.json -> "buildCommand".
set -euo pipefail

FLUTTER_DIR="$HOME/flutter"

echo "==> Installing Flutter (stable channel)..."
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --no-analytics --enable-web
flutter --version

echo "==> Fetching packages..."
flutter pub get

echo "==> Building Flutter web release..."
flutter build web --release --base-href "/"

echo "==> Build complete: build/web"
