# TKT-015：鼠标拖动覆盖层与跨屏移动

日期：2026-09-26。依据：owner 要求按住鼠标移动大面板，包含从一个屏幕拖到另一个屏幕。风险 medium；范围为 AC-14 / TEST-016，并回归 AC-06 / AC-10。实现、Debug / 签名 Release 验证及本机预览更新完成。

## 行为与实现

- 标题、空白背景、空键位、底部说明可按住拖动；应用卡片仍用于点击选择，模式 / 设置 / 关闭按钮保留原交互。
- 采用系统 `WindowDragGesture`，跨屏途中不手动重定位。松手后按鼠标所在显示器收纳面板：尺寸仅在过大时缩小，保证目标屏安全边缘内完整可见。
- 仅初次显示计算居中外框，内容更新 / Tab 不再调用居中；本次显示期间位置保持，下次唤出重新按鼠标所在屏居中。没有新增持久化、权限申请或第三方窗口操作。
- `OverlayPlacement` 是 App 层几何函数；`OverlayDragProbe` 使用合成候选和回调，不调用真实候选激活、不记录用户窗口标题或屏幕内容。

## 首次失败与修正

第一轮背景拖动成功，但标题文字遮挡背景命中；给标题、空键位和底部非操作区域显式附加原生拖动手势，保持按钮独立。

第二轮大屏到小屏仍溢出：原生窗口移动生效，但 `.onEnded` 未回调，收纳未执行。改用 `GestureState` 从移动到复位的状态变化，包含手势取消路径。之后相同双屏测试通过；没有删除失败断言或改小预期范围。

## 验证与限制

- 工具链：Apple Swift 6.3.3、macOS 26.6.2、arm64。`swift build --product AppSwitcherApp` 通过。
- `.build/debug/AppSwitcherApp --verify-overlay-drag`：23 个断言通过。5 个几何断言覆盖不变框、常规屏、负坐标屏、纵向偏移和 760×430 窄短屏；18 个实际 UI 断言覆盖背景 / 标题 / 空键 / 底部拖动、无意外激活、候选点击、方向/Enter、Tab、模式/设置/关闭按钮、双向跨屏、超大面板缩小、更新保持、下次居中和 Esc。
- 双屏实际布局：内屏 1512×982，可用范围 `(59, 0, 1453, 949)`；外屏 2560×1440，范围 `(1512, -458, 2560, 1440)`。跨屏使用真实系统鼠标事件，未把直接设置 window.frame 当作真实拖动。
- `swift run CoreTests`：75/75 通过。`--render-preview build/previews/2026-09-26-panel-drag` 生成 16 张合成预览；目视常规应用与 760×430 长标题窗口布局，标题、按钮及短屏固定 footer / 键盘滚动区保持正常。本轮未声称目视全部 16 张。
- 最终签名候选包 `--verify-overlay-drag`：同样 23/23 通过，含真实双向跨屏；包内 `--verify-shortcuts`：20/20 通过，保留非排他注册无法保证检出的 NOTE。
- 无数据格式、账号、支付或第三方激活行为变化。单一 agent 自审；未验证物理触控板三指拖动、全屏 Space 跨屏、显示器热插拔、完整 VoiceOver 及全部旧兼容性矩阵，继续按 TKT-008 跟踪。

## 制品

构建命令：`APPSWITCHER_OUTPUT="$HOME/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.0-panel-drag.app" ./scripts/build_app.sh`。Release 编译及 `AppSwitcher Dev` 本地自签名已完成；不是公证或对外发布。

定向正常退出旧 PID 32337 后，以 `scripts/app_bundle.py publish` 替换原路径 `~/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.0-preview.app`，旧包保留为 `AppSwitcher-0.4.0-preview.app.previous-gd_lb2y4`。最终路径严格验签通过；新单一进程 PID 39174。版本仍为 0.4.0 local，可执行 SHA-256：`ba578b1650faf3f0a011e04473d85090249e7d43e00993f1c97d3913e8e2b1bf`。回退时正常退出预览程序，将同目录备份恢复为原路径、验签并启动，无配置迁移。

快捷键配置 SHA-256 前后仍为 `117e3fb6f27536e27519cae6224652f0eb4d3f5474dee66b0b65783ceb8d2054`，保留 ⌘E 与 F→J 开关。没有更改系统快捷键、登录项或权限。

运行态冒烟：先发送全局 ⌘E 并确认面板与前台身份，再将指针移动到顶部空白区域、按下 / 拖动 / 松开，面板 CG 外框从 `(117, 118, 1337, 779)` 变为 `(147, 148, 1337, 779)`，面板保持可见、前台正确。未点击任何真实候选。此前两次外部脚本冒烟未得可用结果（一次前置活动面板状态不成立，一次拖动后面板已消失），均如实失败；最终先定位指针的明确操作通过，未据早期自动化现象推断新的生产焦点缺陷或改动取消规则。
