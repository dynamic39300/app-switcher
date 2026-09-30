#!/bin/bash
# Signed App -> signed Installer PKG -> Apple notarization -> staple -> Gatekeeper.
# Produces a candidate only; public download requires independent Mac validation.
set -euo pipefail
cd "$(dirname "$0")/.."

export APPSWITCHER_BUILD_KIND=distribution
export APPSWITCHER_COMMERCE_MODE=commercial
export APPSWITCHER_CONFIGURATION=release
python3 scripts/app_bundle.py validate

if [[ "${APPSWITCHER_SIGN_IDENTITY:-}" != "Developer ID Application: "* ]]; then
    echo "需要 APPSWITCHER_SIGN_IDENTITY=Developer ID Application: …" >&2; exit 1
fi
if [[ "${APPSWITCHER_INSTALLER_SIGN_IDENTITY:-}" != "Developer ID Installer: "* ]]; then
    echo "需要 APPSWITCHER_INSTALLER_SIGN_IDENTITY=Developer ID Installer: …" >&2; exit 1
fi
if [[ -z "${APPSWITCHER_NOTARY_PROFILE:-}" ]]; then
    echo "需要 APPSWITCHER_NOTARY_PROFILE（Keychain 中已保存的公证配置名）" >&2; exit 1
fi
if ! security find-identity -v -p codesigning | /usr/bin/grep -F -- "\"$APPSWITCHER_SIGN_IDENTITY\"" >/dev/null; then
    echo "钥匙串中没有有效的 Developer ID Application 身份" >&2; exit 1
fi
# Installer certificates are not code-signing identities; -p codesigning hides them.
if ! security find-identity -v | /usr/bin/grep -F -- "\"$APPSWITCHER_INSTALLER_SIGN_IDENTITY\"" >/dev/null; then
    echo "钥匙串中没有有效的 Developer ID Installer 身份" >&2; exit 1
fi
python3 - <<'PY'
import os
import re

app = os.environ['APPSWITCHER_SIGN_IDENTITY']
installer = os.environ['APPSWITCHER_INSTALLER_SIGN_IDENTITY']
app_team = re.search(r'\(([A-Z0-9]{10})\)$', app)
installer_team = re.search(r'\(([A-Z0-9]{10})\)$', installer)
if not app_team or not installer_team or app_team.group(1) != installer_team.group(1):
    raise SystemExit('Application 与 Installer 身份必须有相同的 Apple Team ID')
PY
xcrun --find notarytool >/dev/null
xcrun --find stapler >/dev/null
command -v productbuild >/dev/null
command -v pkgutil >/dev/null

VERSION="$(cat VERSION)"
RELEASE_DIR="${APPSWITCHER_RELEASE_DIR:-build/releases/$VERSION-pkg}"
if [[ -e "$RELEASE_DIR" ]]; then
    echo "发布输出位置已存在，请使用新的 APPSWITCHER_RELEASE_DIR，避免覆盖证据" >&2; exit 1
fi
mkdir -p "$RELEASE_DIR"
RELEASE_DIR="$(cd "$RELEASE_DIR" && pwd)"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/AppSwitcher-pkg.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
export APPSWITCHER_OUTPUT="$STAGING_DIR/AppSwitcher.app"
./scripts/build_app.sh
cp "$APPSWITCHER_OUTPUT/Contents/Resources/build-provenance.json" "$RELEASE_DIR/build-provenance.json"
codesign --verify --deep --strict "$APPSWITCHER_OUTPUT"

PKG="$RELEASE_DIR/AppSwitcher-$VERSION-arm64.pkg"
productbuild --sign "$APPSWITCHER_INSTALLER_SIGN_IDENTITY" \
    --component "$APPSWITCHER_OUTPUT" /Applications "$PKG"
pkgutil --check-signature "$PKG" > "$RELEASE_DIR/installer-signature.txt"

# A timed-out submission can continue at Apple. Retain its ID; do not blindly retry.
xcrun notarytool submit "$PKG" --keychain-profile "$APPSWITCHER_NOTARY_PROFILE" \
    --wait --timeout 20m --output-format json > "$RELEASE_DIR/notarization.json"
NOTARY_ID="$(python3 - "$RELEASE_DIR/notarization.json" <<'PY'
import json, sys
record = json.load(open(sys.argv[1]))
if record.get('status') != 'Accepted':
    raise SystemExit('Apple 尚未接受公证；保留 submission id 查询，不发布')
print(record['id'])
PY
)"
xcrun notarytool log "$NOTARY_ID" --keychain-profile "$APPSWITCHER_NOTARY_PROFILE" \
    "$RELEASE_DIR/notarization-log.json"
xcrun stapler staple "$PKG"
xcrun stapler validate "$PKG"
pkgutil --check-signature "$PKG" > "$RELEASE_DIR/installer-signature.txt"
spctl --assess --type install --verbose=2 "$PKG"
shasum -a 256 "$PKG" > "$RELEASE_DIR/SHA256SUMS"
python3 scripts/release_manifest.py artifact "$PKG" "$RELEASE_DIR/notarization.json" \
    "$RELEASE_DIR/build-provenance.json" "$RELEASE_DIR/manifest.json"
echo "已完成本机构建、公证与 PKG 校验: $RELEASE_DIR"
echo "尚需独立 Mac 的实际下载、双击安装、登录、授权、升级与付款验收，再登记官网正式下载。"
