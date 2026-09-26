#!/bin/bash
# Signed DMG -> Apple notarization -> staple -> Gatekeeper. No upload to the product website.
set -euo pipefail
cd "$(dirname "$0")/.."
export APPSWITCHER_BUILD_KIND=distribution
export APPSWITCHER_COMMERCE_MODE=commercial
export APPSWITCHER_CONFIGURATION=release
python3 scripts/app_bundle.py validate
if [[ "${APPSWITCHER_SIGN_IDENTITY:-}" != "Developer ID Application: "* ]]; then
    echo "需要正式 Developer ID Application 签名身份" >&2; exit 1
fi
if [[ -z "${APPSWITCHER_NOTARY_PROFILE:-}" ]]; then
    echo "需要 APPSWITCHER_NOTARY_PROFILE（已存入 Keychain 的公证配置名，不是密码）" >&2; exit 1
fi
if ! security find-identity -v -p codesigning | /usr/bin/grep -F -- "\"$APPSWITCHER_SIGN_IDENTITY\"" >/dev/null; then
    echo "没有可用的正式签名身份；未构建、提交或发布" >&2; exit 1
fi
xcrun --find notarytool >/dev/null
xcrun --find stapler >/dev/null
VERSION="$(cat VERSION)"
RELEASE_DIR="${APPSWITCHER_RELEASE_DIR:-build/releases/$VERSION}"
if [[ -e "$RELEASE_DIR" ]]; then
    echo "发布输出位置已存在，请使用新的 APPSWITCHER_RELEASE_DIR，避免覆盖证据" >&2; exit 1
fi
mkdir -p "$RELEASE_DIR"
RELEASE_DIR="$(cd "$RELEASE_DIR" && pwd)"
# Build the app inside the private temporary directory: synced Documents folders can
# asynchronously add FinderInfo to .app bundles and invalidate an otherwise valid signature.
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/AppSwitcher-dmg.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
export APPSWITCHER_OUTPUT="$STAGING_DIR/AppSwitcher.app"
./scripts/build_app.sh
cp "$APPSWITCHER_OUTPUT/Contents/Resources/build-provenance.json" "$RELEASE_DIR/build-provenance.json"
codesign --verify --deep --strict "$APPSWITCHER_OUTPUT"
ln -s /Applications "$STAGING_DIR/Applications"
cat > "$STAGING_DIR/安装与更新.txt" <<'TXT'
AppSwitcher 安装与更新

1. 将 AppSwitcher 拖入 Applications（应用程序）。
2. 如果已经安装，先从菜单栏退出旧版，然后选择替换。
3. 从“应用程序”打开 AppSwitcher，按引导完成登录和辅助功能授权。
4. 更新会保留原来的快捷键和本地偏好。无需先删除配置或卸载数据。
5. 升级签名身份后如果系统再次请求权限，请在系统设置中确认新版应用。

不要关闭 macOS 安全保护。遇到问题可使用应用菜单中的帮助与反馈。
TXT
DMG="$RELEASE_DIR/AppSwitcher-$VERSION-arm64.dmg"
codesign --verify --deep --strict "$APPSWITCHER_OUTPUT"
hdiutil create -quiet -volname "AppSwitcher $VERSION" -srcfolder "$STAGING_DIR" -format UDZO "$DMG"
codesign --sign "$APPSWITCHER_SIGN_IDENTITY" --timestamp --identifier com.appswitcher.app.dmg "$DMG"
hdiutil verify "$DMG"
codesign --verify --strict "$DMG"
# Submission may continue at Apple after this timeout. Preserve JSON/id; never blindly resubmit.
xcrun notarytool submit "$DMG" --keychain-profile "$APPSWITCHER_NOTARY_PROFILE" --wait --timeout 20m --output-format json > "$RELEASE_DIR/notarization.json"
NOTARY_ID="$(python3 - "$RELEASE_DIR/notarization.json" <<'PY'
import json, sys
record=json.load(open(sys.argv[1]))
if record.get('status') != 'Accepted':
    raise SystemExit('Apple 尚未接受公证；保留 submission id 查询，不发布')
print(record['id'])
PY
)"
xcrun notarytool log "$NOTARY_ID" --keychain-profile "$APPSWITCHER_NOTARY_PROFILE" "$RELEASE_DIR/notarization-log.json"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
shasum -a 256 "$DMG" > "$RELEASE_DIR/SHA256SUMS"
python3 scripts/release_manifest.py artifact "$DMG" "$RELEASE_DIR/notarization.json" "$RELEASE_DIR/build-provenance.json" "$RELEASE_DIR/manifest.json"
echo "已完成本机构建、公证与 DMG 校验: $RELEASE_DIR"
echo "尚需独立 Mac 的实际下载、安装、升级与权限验收，再登记官网正式下载。"
