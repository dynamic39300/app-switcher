#!/bin/bash
# 构建 AppSwitcher 可执行文件并打包成 .app 壳（菜单栏 agent + 签名）。
set -e
cd "$(dirname "$0")/.."

swift build -c release --product AppSwitcherApp

APP="build/AppSwitcher.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/AppSwitcherApp "$APP/Contents/MacOS/AppSwitcher"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>AppSwitcher</string>
	<key>CFBundleDisplayName</key><string>AppSwitcher</string>
	<key>CFBundleIdentifier</key><string>com.appswitcher.app</string>
	<key>CFBundleVersion</key><string>0.1.0</string>
	<key>CFBundleShortVersionString</key><string>0.1.0</string>
	<key>CFBundleExecutable</key><string>AppSwitcher</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>LSUIElement</key><true/>
	<key>NSHighResolutionCapable</key><true/>
	<key>LSMinimumSystemVersion</key><string>15.0</string>
</dict>
</plist>
PLIST

xattr -cr "$APP" 2>/dev/null || true
if codesign --force -s "AppSwitcher Dev" "$APP" 2>/dev/null; then
	echo "[sign] 自签名（AppSwitcher Dev）成功"
else
	codesign --force -s - "$APP"
	echo "[sign] 回退 ad-hoc 签名"
fi

echo "已生成: $(pwd)/$APP"
