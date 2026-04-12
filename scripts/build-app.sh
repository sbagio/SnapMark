#!/usr/bin/env bash
# SnapMark — Build + Bundle Script
#
# Produces SnapMark.app in the project root using swift build.
# No Xcode required. Requires macOS 15+ SDK (Command Line Tools).
#
# Usage:
#   ./scripts/build-app.sh             # Release build (default)
#   ./scripts/build-app.sh debug       # Debug build

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

CONFIG="${1:-release}"
if [ "$CONFIG" = "debug" ]; then
    SWIFT_CONFIG="debug"
    BUILD_DIR=".build/debug"
else
    SWIFT_CONFIG="release"
    BUILD_DIR=".build/release"
fi

APP_BUNDLE="$PROJECT_DIR/SnapMark.app"
BINARY_NAME="SnapMark"
BUNDLE_ID="com.snapmark.app"

# ── 1. Security gate ────────────────────────────────────────────────────────
echo "▶ Running package age check…"
"$SCRIPT_DIR/check-package-ages.sh"

# ── 2. Compile ──────────────────────────────────────────────────────────────
echo ""
echo "▶ Building ($SWIFT_CONFIG)…"
swift build -c "$SWIFT_CONFIG"

# ── 3. Assemble .app bundle ─────────────────────────────────────────────────
echo ""
echo "▶ Assembling SnapMark.app…"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Binary
cp "$BUILD_DIR/$BINARY_NAME" "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME"

# Info.plist — substitute build variables
sed \
    -e "s/\$(EXECUTABLE_NAME)/$BINARY_NAME/g" \
    -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/$BUNDLE_ID/g" \
    "SnapMark/Info.plist" > "$APP_BUNDLE/Contents/Info.plist"

# Build AppIcon.icns using iconutil (simpler and more reliable than actool).
# Source PNGs live in Assets.xcassets/AppIcon.appiconset/ and are pre-generated
# by scripts/generate-icon.swift. iconutil expects a .iconset folder with
# specific filenames, so we assemble a temporary one and convert.
ICONSET_DIR=$(mktemp -d)
APPICONSET="$PROJECT_DIR/SnapMark/Resources/Assets.xcassets/AppIcon.appiconset"

if [ -f "$APPICONSET/app-16.png" ]; then
    echo "  Building AppIcon.icns…"
    cp "$APPICONSET/app-16.png"   "$ICONSET_DIR/icon_16x16.png"
    cp "$APPICONSET/app-32.png"   "$ICONSET_DIR/icon_16x16@2x.png"
    cp "$APPICONSET/app-32.png"   "$ICONSET_DIR/icon_32x32.png"
    cp "$APPICONSET/app-64.png"   "$ICONSET_DIR/icon_32x32@2x.png"
    cp "$APPICONSET/app-128.png"  "$ICONSET_DIR/icon_128x128.png"
    cp "$APPICONSET/app-256.png"  "$ICONSET_DIR/icon_128x128@2x.png"
    cp "$APPICONSET/app-256.png"  "$ICONSET_DIR/icon_256x256.png"
    cp "$APPICONSET/app-512.png"  "$ICONSET_DIR/icon_256x256@2x.png"
    cp "$APPICONSET/app-512.png"  "$ICONSET_DIR/icon_512x512.png"
    cp "$APPICONSET/app-1024.png" "$ICONSET_DIR/icon_512x512@2x.png"

    # Rename temp dir with .iconset suffix (iconutil requirement)
    ICONSET="${ICONSET_DIR}.iconset"
    mv "$ICONSET_DIR" "$ICONSET"

    iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET"
    echo "  ✓ AppIcon.icns written"
else
    echo "  ⚠ Icon PNGs not found — run: swift scripts/generate-icon.swift"
fi

# ── 4. Code-sign ─────────────────────────────────────────────────────────────
# Use the stable self-signed certificate so TCC persists the Screen Recording
# grant across rebuilds. Fall back to ad-hoc only if cert isn't set up yet.
CERT_NAME="SnapMark Dev"
if security find-certificate -c "$CERT_NAME" \
        "$HOME/Library/Keychains/login.keychain-db" &>/dev/null; then
    echo "▶ Signing with certificate '$CERT_NAME'…"
    codesign --force --sign "$CERT_NAME" "$APP_BUNDLE"
else
    echo "▶ Signing (ad-hoc — run ./scripts/setup-signing.sh for persistent TCC grants)…"
    codesign --force --sign "-" "$APP_BUNDLE"
fi

# ── 5. Strip quarantine ──────────────────────────────────────────────────────
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

# ── Done ────────────────────────────────────────────────────────────────────
echo ""
echo "✓ Built: $APP_BUNDLE"
echo ""
echo "Install:  cp -r SnapMark.app /Applications/"
echo "Launch:   open /Applications/SnapMark.app"
echo ""
echo "On first launch, grant Screen Recording permission:"
echo "  System Settings → Privacy & Security → Screen Recording → SnapMark ON"
echo "Then restart the app (Screen Recording requires restart to take effect)."
