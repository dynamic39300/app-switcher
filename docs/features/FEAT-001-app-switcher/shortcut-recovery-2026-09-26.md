# TKT-014：快捷键唤起与录制反馈恢复

日期：2026-09-26。风险：medium；影响 AC-01 / AC-09、TEST-009。当前状态：本机 ⌘E 已恢复可用，代码修复及 Debug / Release 回归通过；新包已签名、原路径替换并启动，重启后的实际录制、保存与全局 ⌘E 唤起通过。

## 现场与复现

诊断开始时本机运行的是 `~/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.0-preview.app`（0.4.0、local 模式、`AppSwitcher Dev` 自签名），PID 5855。`/Applications/AppSwitcher.app`、`~/Applications/AppSwitcher.app` 及 `shortcuts.json` 均不存在；过去的 0.3.2 / ⌘E 安装记录不能代替本机状态。

菜单显示「F → J 或 快捷键不可用 唤出」。设置窗口明确显示：默认 `⌃⌥Space` 已被系统快捷键占用，启动注册失败。菜单「显示切换器」能够打开面板。

操作设置窗口进入录制后，向当前 AppSwitcher 设置窗口发送 Command-E。窗口已显示新草稿 `⌘E`，保存按钮可用，但反馈仍显示旧 `⌃⌥Space` 的冲突错误。诊断截图只包含本应用设置，存于被忽略的 `build/diagnostics/shortcut-settings-before-save.png`，不采集切换面板内的用户应用或窗口标题。

实际点击保存成功：设置显示「已保存，新的唤出设置已生效」；文件为 keyCode=14、modifiers=8、sequenceEnabled=true。关闭设置后，发送真实系统键盘事件 Command-E，再读取本应用窗口存在性与尺寸：`PASS: Command-E opened switcher, 2356, 1157`。没有自动选择或控制任何目标 App。

自动化 AX 点击曾打开设置但前台仍为聊天应用；该现象不能证明产品的焦点实现有缺陷。后续录制、保存及真实全局事件均成功，未基于该现象修改激活策略。

## 原因与修复

启动默认组合冲突时，`GlobalHotKey.currentShortcut` 为空，而 `ShortcutController.statusMessage` 保留启动失败说明。录制结束时，`resume()` 没有需要恢复的注册并正常返回；旧实现却返回历史 `statusMessage`，使设置窗口把录制成功当作恢复错误，不展示「已录入草稿，保存后生效」。

修复让 `endRecording()` 的返回值只表示本次恢复失败；历史绑定状态继续保留在 `settingsStatus`，新组合保存成功后再清除。真实恢复失败仍返回错误。未改默认键、系统快捷键、权限设置、配置格式或 F→J 行为。

## 验证

- 先在 `ShortcutRegistrationProbe` 加入控制器实际调用路径：合成四修饰 F18 被子进程排他占用 → 控制器启动失败 → 开始与结束录制 → 保存 F19 → 重建控制器。使用临时配置、F→J 关闭，不触碰用户配置或键盘输入。
- 修复前：`swift build --product AppSwitcherApp && .build/debug/AppSwitcherApp --verify-shortcuts` 在「结束录制不把启动时旧组合冲突误报为本次录制失败」处 exit 1。
- 修复后：Debug 与 Release `--verify-shortcuts` 均 exit 0，20 个断言通过；包括历史错误保留、新键真实持久化/注册、重建恢复，以及录制期间原绑定被抢占时仍报告真实恢复错误。
- `swift run CoreTests`：75/75 通过。原非排他 Carbon 注册可能无法检出冲突的 NOTE 保留，未扩张冲突检测承诺。
- 工具链：Apple Swift 6.3.3 / arm64 macOS。新 Release 编译通过。

## 制品与当前运行边界

新包命令：`APPSWITCHER_OUTPUT="$HOME/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.0-shortcut-fix.app" ./scripts/build_app.sh`。

构建曾停在 `codesign --force --sign "AppSwitcher Dev"`；采样显示等待 `SecKeyCreateSignature` / SecurityServer，系统同时启动 SecurityAgent。随后签名正常返回成功，没有更改钥匙串访问策略或签名身份。候选包严格验签及包内 `--verify-shortcuts` 均 exit 0。

通过 `NSRunningApplication.terminate()` 定向正常退出旧 PID 5855，再以 `python3 scripts/app_bundle.py publish` 更新原预览路径。原包完整保留为 `~/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.0-preview.app.previous-p20xtcr5`，未写入 Applications 或更改登录项。新包启动 PID 32337，版本仍为 0.4.0 / local / `AppSwitcher Dev` 自签名；最终路径严格验签通过，可执行文件 SHA-256：`8eac2578b0c89479de62fac22aa7e26de800620447f2a90bbd7b8ec0a84d19df`。回退时先正常退出该预览包，将保留的旧包恢复到原路径、验签后启动；配置格式兼容。

新进程设置窗口读到已保存 ⌘E。实际点击录制、向本应用设置窗口发送 Command-E 后显示「已录入草稿，保存后生效。」；点击保存后显示「已保存，新的唤出设置已生效。」。关闭设置，再发送系统级 Command-E，确认本应用面板出现，尺寸 1334×779 pt；没有自动选择或控制任何目标 App。

当前快捷键文件 SHA-256：`117e3fb6f27536e27519cae6224652f0eb4d3f5474dee66b0b65783ceb8d2054`，替换、重启及再次保存前后相同。F→J 开关保持本机原有 true，本次未验证其完整手势/回放矩阵。候选属于本地预览，不是公证或对外发布；本次由单一 agent 自审，没有独立 agent 复核。
