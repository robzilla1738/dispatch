#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Building release binary"
swift build -c release --product Dispatch
BIN_DIR="$(swift build -c release --show-bin-path)"

APP_NAME="Dispatch"
APP_DIR="$ROOT/dist/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"

echo "==> Assembling $APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES" "$FRAMEWORKS"

cp "$BIN_DIR/Dispatch" "$MACOS/Dispatch"
chmod +x "$MACOS/Dispatch"

if [[ -d "$ROOT/.cache/sparkle/2.10.0/Sparkle.framework" ]]; then
    ditto "$ROOT/.cache/sparkle/2.10.0/Sparkle.framework" "$FRAMEWORKS/Sparkle.framework"
fi
if [[ -f "$ROOT/licenses/Sparkle.txt" ]]; then
    mkdir -p "$RESOURCES/licenses"
    cp "$ROOT/licenses/Sparkle.txt" "$RESOURCES/licenses/Sparkle.txt"
fi

# SwiftPM emits the resource bundle beside the executable. The generated
# Bundle.module accessor looks in Bundle.main.resourceURL first.
for bundle in "$BIN_DIR"/*.bundle(N); do
    cp -R "$bundle" "$RESOURCES/"
done

cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Sources/DispatchApp/Resources/AppIcon-Release.icns" "$RESOURCES/AppIcon.icns"
printf 'APPL????' > "$CONTENTS/PkgInfo"

echo "==> Signing (ad hoc)"
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "==> Verifying"
codesign --verify --deep --strict "$APP_DIR"
plutil -lint "$CONTENTS/Info.plist" >/dev/null
du -sh "$APP_DIR"
echo "Built: $APP_DIR"
