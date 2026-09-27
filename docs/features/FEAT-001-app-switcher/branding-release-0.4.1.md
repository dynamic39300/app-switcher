# TKT-016：0.4.1 菱形图标与最新本地预览

日期：2026-09-26；风险 medium（资源、打包和本机更新）。依据 owner 要求更新安装包、菜单栏图标与当前版本样式。产品名不变，保留用户已经确认的 [D1 母版与菜单栏线稿](../../../assets/branding/README.md)，不覆盖设计历史。

## 范围

- Finder / 应用包图标：D1 四键菱形、石墨底、银色主体和底部冰蓝色键帽；从原母版生成 16–1024 px 的十种 iconset 输入，不重新画旧键盘。
- 菜单栏：18 pt 单色线框，18 / 36 px 透明表示，`isTemplate=true`，辅助功能名 AppSwitcher。
- 应用内：大面板与账号页品牌位使用同一母版。模式按钮、设置页键盘符号仍表达功能，不批量替换语义图标。
- `VERSION=0.4.1`，包含已完成的快捷键录制修复和面板拖动 / 双屏适配；不改变账号/支付/权限或用户偏好。
- 生成 local 预览 DMG，明确自签名、未公证、非官网正式分发；不执行 `release_macos.sh`、不上传网站或发布 GitHub Release。

## 验证记录

最终状态补记：钥匙串签名后来完成，0.4.1 候选保留；用户随后要求三主题并存，因此实际安装与 DMG 合并升级为 0.4.2，最终品牌探针、严格验签、原生UI与全局唤起通过。当前制品路径、摘要、回退与边界以[0.4.2 主题交付](appearance-themes-2026-09-26.md)为准，下列“等待签名”为当时记录。

- `swift build --product AppSwitcherApp`、Debug `--verify-branding` 通过：实际资源加载器、菜单模板、18 pt 与透明 1x / 2x、辅助功能名。
- `swift scripts/generate_app_icon.swift build/branding-0.4.1/AppIcon.iconset`、`iconutil -c icns …` 通过；256 px 输出已目视，与已确认 D1 一致。
- `python3 scripts/test_app_bundle.py`：11/11 通过，新增母版改变后源码摘要变化并拒绝旧构建证据。其他配置和发布保护没有放宽。
- `bash -n scripts/build_app.sh scripts/package_local_preview.sh` 通过。
- `--render-preview build/previews/0.4.1-branding` 生成 16 张合成面板预览；目视常规应用场景，已换成菱形品牌，未修改原键盘布局。本轮不宣称目视全部场景。
- 构建中 `--verify-branding` 已检查真实 `.app` 包内 ICNS 1024 px 表示与模板；签名阶段等待系统钥匙串授权。最终制品、DMG和安装冒烟待回填。

## 回退与边界

安装前保留当前 0.4.0 预览包，核对进程身份后正常退出。用户快捷键文件不改；新版安装在个人 Applications，避免与历史候选目录混淆。若升级失败，正常退出新版并打开保留的旧包即可回退；不删除偏好、不变更系统快捷键、权限或登录项。

这是单一 agent 自审的本机预览交付；独立 Mac 下载 / Gatekeeper / 首次安装与完整可访问性不在本轮通过范围。
