#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Dispatch.app"
DEST_DIR="${1:-/Applications}"
if [[ ! -w "$DEST_DIR" ]]; then
    DEST_DIR="$HOME/Applications"
fi

if [[ ! -d "$APP" ]]; then
    "$ROOT/scripts/build-app.sh"
fi

mkdir -p "$DEST_DIR"
rm -rf "$DEST_DIR/Dispatch.app"
cp -R "$APP" "$DEST_DIR/"
echo "Installed to: $DEST_DIR/Dispatch.app"
echo "Launch it with: open \"$DEST_DIR/Dispatch.app\""
