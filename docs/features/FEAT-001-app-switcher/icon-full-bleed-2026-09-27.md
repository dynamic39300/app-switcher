# 0.4.3：应用图标黑底铺满

日期：2026-09-27。范围：用户截图中应用程序列表的 AppSwitcher 图标外围出现浅色留白，要求黑色铺满。风险 low，纯图标资产调整，本机安装可回退。执行与自审：Codex。

## 变更与验收

- 延用 D1 四键菱形、三银一冰蓝构图，将石墨背景扩展至整个正方形，移除透明留白和外层底板边框。原始 D1 探索稿保留。
- 同一母版生成十个 16–1024 px iconset 表示并打包为 ICNS；应用内品牌位使用相同资源，菜单栏模板不变。
- 版本 0.4.3 local。验收：位图不透明且四边为暗色，打包签名与资源探针通过，安装后核对系统图标效果；快捷键和主题偏好保持。
- 不变更业务交互，键盘/焦点/错误状态无新增分支。验证采用资产检查、构建与安装冒烟，不新增业务测试。

## 执行记录

- `swift scripts/generate_app_icon.swift build/branding-0.4.3/AppIcon.iconset` 成功。母版 1254 × 1254 RGB、无 alpha；十张输出逐像素检查 alpha 全为 1，四边 RGB 最大分量小于 0.35，无透明或浅色边。256 px 输出与母版已目视核对。
- `APPSWITCHER_OUTPUT="$HOME/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.3-preview.app" ./scripts/build_app.sh` 成功，Release 构建、真实包内 `--verify-branding` 与 `AppSwitcher Dev` 自签名通过。签名曾等待系统钥匙串授权，完成后继续，未改用其他身份。
- `python3 scripts/test_app_bundle.py`：11/11 通过；`git diff --check` 通过；框架检查：118 个 Markdown，0 错误、0 警告。未重复业务规则和窗口焦点回归，此次无业务代码改动。
- `bash scripts/package_local_preview.sh "$HOME/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.3-preview.app" "$HOME/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.3-local-preview.dmg"` 成功，`hdiutil verify` 通过。首轮直接执行该脚本返回 permission denied，现有文件未设置执行位，改用其声明的 bash 解释器执行，未更改权限。
- 挂载只读 DMG，从其中的 `.app` 安装到 `~/Applications/AppSwitcher.app`，复制前后严格验签通过。安装后 `--verify-branding` 通过，Info.plist / Finder 均显示 0.4.3。DMG 已卸载。
- 已启动安装版，核对进程命令为 `/Users/wangxinlei/Applications/AppSwitcher.app/Contents/MacOS/AppSwitcher`（本次 PID 61634）。Finder 列表小图标和简介大图标实际截图均已目视确认：黑底覆盖系统圆角外轮廓，没有原先浅色底板包裹内层小图标。Spotlight/应用程序网格自动化窗口定位超时，未宣称该网格已复验；未清理系统缓存。
- 用户 `shortcuts.json` 与 `appearance.json` 更新前后 SHA256 分别保持 `117e3fb6f27536e27519cae6224652f0eb4d3f5474dee66b0b65783ceb8d2054`、`7a3f6316904fd498e8b16dbc676533e922e7454a367b67aef1904cbc8eab76cc`。菜单栏模板未修改。

## 制品与回退

- DMG：`~/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.3-local-preview.dmg`；SHA256 `c1f4e54a7f3101af4bce05c8d596d7e88ba05af84085b0367eebe68e8e82b4e5`。
- 最终安装包 `Contents/Resources/AppIcon.icns` SHA256：`c0ccceb5c667999822ffe5d297f0ea0030db36847e9d408088695c7055e21a35`。
- 旧版完整备份：`~/Library/Application Support/AppSwitcher/backups/AppSwitcher-0.4.2-before-full-bleed-20260927-093239.app`。回退时正常退出新版，保留新版后将备份恢复到个人 Applications 原路径并启动；不要同时运行两个版本，不删除用户配置。
- 本地自签名预览，未公证、未对外发布。单 Agent 自审，不代表独立 Mac 或 macOS 15 的系统图标显示已验证。
