---
id: REL-001-UI-053
status: in-review
owner: "AppSwitcher 项目 owner（待填姓名）"
upstream: [SPEC-001, DESIGN-001, TASKS-001]
---

# 0.5.3 键盘面板界面调整（2026-10-02）

Owner 反馈现有面板有模板化观感、键帽过高且不像实体键盘。本轮缩短面板与键帽，普通屏幕键帽目标高宽约 1.07:1；宽屏面板最多 1680 pt。石墨主题改为中性深灰、弱渐变和更小圆角；悬停时只提亮表面/边界，按下仍保留短键程反馈。顶部应用数量与底部动作文案去掉重复表达。三主题和 38 键分配规则保持，短屏键盘区可滚动。

窄键帽只在卡片中显示图标、键标和截断名称，以免图标、长名称与窗口标题溢出。完整窗口标题仍由选中详情、悬停提示与无障碍标签呈现。预览使用合成 App 和标题，不读取用户实际窗口。合成预览位于 `build/previews/20261002-keyboard-ui-reviewed/`（本机可重建，不作为真实截图或 Git 制品）。

## 构建与验证

- 源码基线：`6e117ff00b14226c254881a717b3785c7cc3f90f` 加本轮未提交 UI 改动；版本号 0.5.3。
- `scripts/build_app.sh`：Release/local 构建、品牌检查、严格签名校验通过；候选 `~/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.5.3-ui-20261002.app`，arm64，本地 ad-hoc 签名，未公证。
- `swift run -c release CoreTests`：112/112；候选 `--verify-appearance`：全部通过，含内容高度与常规屏幕键帽近方形断言。候选 `--verify-overlay-drag`：最终一次全部通过，覆盖背景/标题/空键/底部拖动、应用点击、退出叉、设置、模式、三主题和键盘导航；仅一块显示器，未实测跨屏拖动。
- 交互探针首轮因原断言固定旧版面板高度而失败，调整为验证新尺寸上限；之后运行曾出现一次焦点/指针前提失败和一次主题状态波动，均保留为未定位的测试稳定性风险，不用最终复跑覆盖这些事实。合成预览已目视检查常规应用、38 键、银瓷与烟晶主题、窄短屏窗口；窄卡片标题溢出据此修正。
- `python3 .framework/scripts/check_framework.py --root .`：133 个 Markdown，0 错误、0 警告。`git diff --check` 通过。

## 本机安装与体验边界

- DMG：`~/Downloads/AppSwitcher-0.5.3-local-preview-20261002.dmg`；`hdiutil verify` 通过；SHA-256 `7c7228f9b751a35448f793fe7e7f6c00188baec6c0379bb9e915052a4cd3b526`。这是本地测试包，不是对外正式发布包。
- 从该 DMG 安装至 `/Applications/AppSwitcher.app`，安装后二进制与候选均为 SHA-256 `f44c308064745f6eca2eb68bd7211f7b7ad1cc40bbd56f5697735106ed7384a3`。旧 0.5.2 应用移至 `~/.Trash/AppSwitcher-old-packages-20261002/Previous-AppSwitcher-0.5.2.app`；随时可从废纸篓恢复。外观、快捷键与键位映射 3 个 JSON 在替换前后摘要一致。
- 启动 PID 56201，日志确认辅助功能授权有效、全局组合快捷键注册成功。原生 CUA 读取面板两次超时，因此未把真实面板视觉/鼠标手感记为通过；请 owner 用已保存的组合键唤出，检查图标与文字、鼠标悬停/点击、窗口模式及窄屏效果。此前微信文章页最终切换仍属 TKT-020，不能由本轮 UI 测试结案。
- 回退：退出当前 AppSwitcher，将 0.5.3 应用移到另一可恢复位置，再把废纸篓中上述 0.5.2 应用恢复到 `/Applications/AppSwitcher.app`。个人配置无需删除。
