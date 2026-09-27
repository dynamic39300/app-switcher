#!/bin/bash
# Package an already verified LOCAL app. Never presents this as a notarized distribution.
set -euo pipefail
if [[ $# -ne 2 ]]; then
    echo "Usage: bash scripts/package_local_preview.sh <local.app> <new-output.dmg>" >&2
    exit 1
fi
PREVIEW_APP="$1"
PREVIEW_DMG="$2"
if [[ ! -d "$PREVIEW_APP" || "$PREVIEW_DMG" != *.dmg || -e "$PREVIEW_DMG" || -L "$PREVIEW_DMG" ]]; then
    echo "需要已有应用与尚不存在的 .dmg 输出路径；拒绝覆盖" >&2
    exit 1
fi
PREVIEW_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PREVIEW_APP/Contents/Info.plist")"
PREVIEW_MODE="$(/usr/libexec/PlistBuddy -c 'Print :AppSwitcherCommerceMode' "$PREVIEW_APP/Contents/Info.plist")"
PREVIEW_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PREVIEW_APP/Contents/Info.plist")"
if [[ "$PREVIEW_ID" != com.appswitcher.app || "$PREVIEW_MODE" != local ]]; then
    echo "仅接受本项目 local 预览包；正式分发使用 release_macos.sh" >&2
    exit 1
fi
codesign --verify --deep --strict "$PREVIEW_APP"
"$PREVIEW_APP/Contents/MacOS/AppSwitcher" --verify-branding
PREVIEW_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/AppSwitcher-local-dmg.XXXXXX")"
trap 'rmdir "$PREVIEW_STAGE" 2>/dev/null || true' EXIT
# Keep staging recoverable rather than recursively removing a user-provided path.
ditto --norsrc --noextattr "$PREVIEW_APP" "$PREVIEW_STAGE/AppSwitcher.app"
ln -s /Applications "$PREVIEW_STAGE/Applications"
cp "$(dirname "$0")/local-preview-install.txt" "$PREVIEW_STAGE/本地预览说明.txt"
codesign --verify --deep --strict "$PREVIEW_STAGE/AppSwitcher.app"
mkdir -p "$(dirname "$PREVIEW_DMG")"
hdiutil create -quiet -volname "AppSwitcher $PREVIEW_VERSION Preview" -srcfolder "$PREVIEW_STAGE" -format UDZO "$PREVIEW_DMG"
hdiutil verify "$PREVIEW_DMG"
shasum -a 256 "$PREVIEW_DMG"
echo "本地预览 DMG（未公证，非官网正式安装包）: $PREVIEW_DMG"
echo "临时打包内容保留于: $PREVIEW_STAGE"
