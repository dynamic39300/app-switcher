#!/bin/bash
# 把 SPM 编译出的裸二进制，手工打包成最小 .app 壳并 ad-hoc 签名。
# 目的：让 Carbon 全局热键事件能派发，并让「辅助功能」权限能干净地授给 .app。
set -e
cd "$(dirname "$0")"

swift build

APP="build/Spike.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/debug/TKT001Spike "$APP/Contents/MacOS/TKT001Spike"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>AppSwitcherSpike</string>
	<key>CFBundleDisplayName</key><string>AppSwitcher Spike</string>
	<key>CFBundleIdentifier</key><string>com.appswitcher.spike</string>
	<key>CFBundleVersion</key><string>0.1.0</string>
	<key>CFBundleShortVersionString</key><string>0.1.0</string>
	<key>CFBundleExecutable</key><string>TKT001Spike</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>LSUIElement</key><true/>
	<key>NSHighResolutionCapable</key><true/>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
	codesign --force -s - "$APP" && echo "[sign] ad-hoc 签名成功"
else
	echo "[sign] 无 codesign，跳过（.app 仍可运行，但授权可能不稳）"
fi

echo "已生成: $(pwd)/$APP"
