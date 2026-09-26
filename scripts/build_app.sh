#!/bin/bash
# Build a local or explicitly configured distribution bundle. Never silently downgrade distribution signing.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 scripts/app_bundle.py validate
BUILD_KIND="${APPSWITCHER_BUILD_KIND:-local}"
CONFIGURATION="${APPSWITCHER_CONFIGURATION:-release}"
OUTPUT="${APPSWITCHER_OUTPUT:-build/AppSwitcher.app}"
if [[ "$BUILD_KIND" == "distribution" ]]; then
    if [[ "${APPSWITCHER_SIGN_IDENTITY:-}" != "Developer ID Application: "* ]]; then
        echo "正式分发需 APPSWITCHER_SIGN_IDENTITY=Developer ID Application: …" >&2
        exit 1
    fi
    if ! security find-identity -v -p codesigning | /usr/bin/grep -F -- "\"$APPSWITCHER_SIGN_IDENTITY\"" >/dev/null; then
        echo "钥匙串中没有匹配的有效 Developer ID Application 身份" >&2
        exit 1
    fi
fi

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/AppSwitcher-build.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
python3 scripts/release_manifest.py capture "$STAGING_DIR/source.json"
BUILD_ARGS=(-c "$CONFIGURATION")
if [[ "$BUILD_KIND" == "distribution" ]]; then BUILD_ARGS+=(--arch arm64); fi
swift build "${BUILD_ARGS[@]}" --product AppSwitcherApp
BINARY_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
python3 scripts/release_manifest.py verify "$STAGING_DIR/source.json" "$BINARY_DIR/AppSwitcherApp"
APP="$STAGING_DIR/AppSwitcher.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swift scripts/generate_app_icon.swift "$STAGING_DIR/AppIcon.iconset"
iconutil -c icns "$STAGING_DIR/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp -X "$BINARY_DIR/AppSwitcherApp" "$APP/Contents/MacOS/AppSwitcher"
cp "$STAGING_DIR/source.json" "$APP/Contents/Resources/build-provenance.json"
python3 scripts/app_bundle.py plist "$APP/Contents/Info.plist"
xattr -cr "$APP" 2>/dev/null || true

if [[ "$BUILD_KIND" == "distribution" ]]; then
    codesign --force --options runtime --timestamp --sign "$APPSWITCHER_SIGN_IDENTITY" "$APP"
elif codesign --force --sign "AppSwitcher Dev" "$APP" 2>/dev/null; then
    echo "[sign] 本地自签名成功；不可作为官网正式发布包"
else
    codesign --force --sign - "$APP"
    echo "[sign] 本地 ad-hoc 签名；不可作为官网正式发布包"
fi
codesign --verify --deep --strict "$APP"
python3 scripts/app_bundle.py publish "$APP" "$OUTPUT"
