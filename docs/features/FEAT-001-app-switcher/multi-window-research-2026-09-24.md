---
id: RES-002
status: draft
owner: "AppSwitcher 项目 owner（待填姓名）"
upstream: [RES-001, SPEC-001, DESIGN-001]
---

# RES-002：同一 App 多窗口的识别与精确切换

核验日期：2026-09-24。问题来自当前覆盖层截图中的「ClassIn／窗口 N」「Google Chrome／窗口 N」等条目。本文是研究与建议，不修改既有产品范围或实现。

## 结论

**当前实现无法保证按这些键切到对应窗口；但不能据此认定 macOS 无法区分同一 App 的多个窗口。** 当前问题分三层：用户看不出「窗口 2」对应什么内容；显示编号会随窗口集合变化；激活代码没有使用已取得的窗口 ID，而是拿显示标题匹配 AX 窗口。无标题兜底编号和同名标题都会破坏这种匹配。

macOS 提供指向具体窗口的 Accessibility 对象，可以对该对象置前、设置主窗口及恢复最小化；标题不是其身份。是否能取得对象、对象是否仍有效、目标 App 是否支持操作、最终键盘焦点是否落对，仍需分别验证。跨 Spaces／全屏与部分自定义窗口不能作无条件兼容承诺。

## 当前代码证据

审计基线：仓库 HEAD `a1e40a6` 加本次研究开始时已有的未提交工作区；稳定排序代码属于既有改动。本次未修改业务代码。

| 已核验事实 | 位置 | 对当前页面的影响 |
| --- | --- | --- |
| 已读取窗口 PID、`kCGWindowNumber`、可用标题 | [RunningAppsProvider.swift](../../../Sources/AppSwitcherKit/RunningAppsProvider.swift)，25–44 行 | 系统枚举层已经区分了窗口。 |
| 候选 ID 是 `bundleID#windowNumber`，无标题多窗口按当前排序生成「窗口 N」 | [CandidateFactory.swift](../../../Sources/AppSwitcherCore/CandidateFactory.swift)，18–40 行 | 数字是本项目显示标签，不是系统窗口标题，也不是持久身份。 |
| 候选没有独立 PID、窗口句柄或控制目标字段 | [Candidate.swift](../../../Sources/AppSwitcherCore/Candidate.swift)，6–13 行 | 枚举结果和激活目标没有形成明确契约。 |
| 按 bundle ID 取第一个进程；调用 `activateAllWindows`；尝试恢复所有最小化窗口 | [AppActivator.swift](../../../Sources/AppSwitcherApp/AppActivator.swift)，8–29 行 | 先执行的是 App 级动作，不是只操作用户所选的一窗。 |
| 不读取候选 ID；仅以 `candidate.title == AXTitle` 选第一个匹配对象；不检查操作返回值和最终焦点 | 同上，32–44 行 | 「窗口 N」通常匹配不到；同名窗口取第一个；界面条目独立不等于切换目标独立。 |

由此可推断：截图中的某些键虽然展示为不同窗口，实际可能都只是激活同一个 App，最后显示的窗口取决于 App／系统状态。仅增加录屏权限、拿到更多标题，也不能解决同名标题、标题变化、ID 未参与控制的问题。

### 编号漂移的隔离复现

主调查 Agent 使用实际 Core 源码 `AppDescriptor`、`UsageStats`、`WindowDescriptor`、`WindowFilter`、`Candidate`、`CandidateFactory` 与合成数据组成临时 Swift 脚本运行，退出码 0：

| 输入 | 输出 |
| --- | --- |
| 同 App 三个无标题窗口 ID 为 101、102、103 | 分别为「窗口 1」「窗口 2」「窗口 3」 |
| 关闭 101，只保留 102、103 | 102 变成「窗口 1」，103 变成「窗口 2」 |
| 两个不同 ID 的窗口真实标题都为 `Untitled` | 候选 ID 不同，候选标题相同 |

这证明现有排序可以避免单纯 z-order 变化引起的重排，但不能保证增删窗口后的编号稳定。环境：macOS 26.6.2（25G83）、Swift 6.3.3、`arm64-apple-macosx26.0`。这是候选生成逻辑验证，不是对真实 App 的聚焦测试。

## 平台能力与边界

以下 Apple 页面及官方项目源码均于 2026-09-24 打开核验；源码固定 commit，滚动文档按核验日期理解。

| 发现 | 类型与依据 | 边界 |
| --- | --- | --- |
| `AXWindows` 返回代表该 App 各窗口的对象数组；`AXUIElementPerformAction` 对指定对象执行动作 | 官方 API：[AXWindows](https://developer.apple.com/documentation/applicationservices/kaxwindowsattribute?preferredLanguage=occ)、[PerformAction](https://developer.apple.com/documentation/applicationservices/1462091-axuielementperformaction) | 因此无标题／同名本身不会使对象身份消失；前提是 App 确实提供可用窗口对象。 |
| `AXRaise` 将指定窗置于 App 当前情况允许的最前位置；浮动窗仍可能在上方 | 官方 API：[AXRaise](https://developer.apple.com/documentation/applicationservices/kaxraiseaction?changes=_8) | 置前不等于已经验证全局键盘焦点。App 主窗口、前台 App 和 focused window 是不同状态。 |
| `AXMain`、`AXMinimized` 可写；前者是主文档窗，后者是最小化状态 | Apple 本机 SDK `AXAttributeConstants.h`，805–832 行；[Hammerspoon 对窗口对象的实现](https://github.com/Hammerspoon/hammerspoon/blob/23e387e2805a9890066366e0ac96c71b27f0cfd5/Hammerspoon/HSuicore.m#L879-L888) | 可只恢复选中的窗口。仍需查询支持能力、处理错误及动画时序，不能依赖一次写入即成功。 |
| `NSRunningApplication.activate` 目标是 App；`activateAllWindows` 将其全部窗口置前 | 官方 API：[activate](https://developer.apple.com/documentation/appkit/nsrunningapplication/activate(options:))、[activateAllWindows](https://developer.apple.com/documentation/appkit/nsapplication/activationoptions/activateallwindows) | API 参数没有指定外部目标窗口；其成功返回不能证明某个指定窗口已获得焦点。 |
| `kCGWindowNumber` 是当前用户会话内唯一的 window ID | 官方 API：[kCGWindowNumber](https://developer.apple.com/documentation/coregraphics/kcgwindownumber) | 不是 App 重启／窗口重建后仍代表同一业务内容的持久 ID；其数值大小也没有官方创建时间排序保证。 |
| AX 调用可返回不支持动作、无效对象、通信失败、App 未完整实现辅助功能等错误 | 官方 API：[PerformAction 错误说明](https://developer.apple.com/documentation/applicationservices/1462091-axuielementperformaction) | 必须区别「窗口不存在」「App 暂时无响应」「能力不支持」；超时不一定表示动作未执行。 |
| 成熟切换器也维护窗口对象与 CG ID，并处理失效和结果确认 | 实现事实：[AltTab AX→CG ID](https://github.com/lwouis/alt-tab-macos/blob/56891e08861e2d43fafb31d58a4c7fd9ba2289ec/src/macos/api-wrappers/AXUIElement.swift#L96-L104)、[聚焦流程](https://github.com/lwouis/alt-tab-macos/blob/56891e08861e2d43fafb31d58a4c7fd9ba2289ec/src/switcher/state/Window.swift#L385-L434) | AltTab 使用非公开 `_AXUIElementGetWindow`、`_SLPSSetFrontProcessWithOptions` 等。其可行性不能证明只用公开 API 就可无条件覆盖所有 App。 |
| 跨 Spaces／全屏的枚举、特殊窗口过滤存在额外限制 | 实现方文档：[Hammerspoon allWindows](https://www.hammerspoon.org/docs/hs.window.html#allWindows) | 这是该工具的已记录限制，不应扩大为所有 macOS 版本、所有访问路径均无法枚举。 |

**公开 API 路线的含义（建议）：** 从 AX 枚举得到具体对象并在适配器中保存短期引用，UI 持有独立 token，激活回到该引用，不需要把标题作为连接键。若继续以 CG 清单为主，再连接到 AX 对象，本次核验未找到 Apple 文档化的通用 CGWindowID→AXUIElement 直接映射 API；按标题／几何信息只能作为可能歧义的匹配，不能承诺唯一性。采用私有桥接需单独权衡兼容维护成本，不是本次研究已决定的方案。

## 对此前判断的修正

- **「Chrome 返回 AX 窗口数 0，所以 Chrome 永远不能窗口切换」证据不足。** [Chromium 官方源码](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/chrome_browser_application_mac.mm)包含按访问启用辅助功能及延时合并处理；[Electron 官方文档](https://www.electronjs.org/docs/latest/tutorial/accessibility)介绍 `AXManualAccessibility`。这些机制证明需要调查初始化／状态／应用实现，但不保证能解决本机的 `AXWindows = 0`。该源码为滚动 main，页面 blob 为 `823b03b27cc31d2535d748dcf79b3a1e78a3d7ca`。
- **「读所有窗口标题都必须录屏权限」过宽。** [Apple WWDC19 Session 701](https://developer.apple.com/videos/play/wwdc2019/701/)说明 Core Graphics 窗口名等信息受屏幕录制授权保护；AX 标题是辅助功能通道，不能把两个通道混为一谈。现有 Provider 恰好读取的是 `kCGWindowName`。
- **「macOS 26 必须 Developer ID／TeamIdentifier 才能取得权限」尚无普遍规则证据。** [Apple TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)说明 ad-hoc 签名身份与具体构建绑定，更新后授权身份不能稳定延续；这不等于绝对无法申请权限。旧记录应保留为特定构建上的观察，不能当平台定论。

## 对当前设计的建议

1. **默认一 App 一键。** 这是当前最清晰的可兑现行为。需要精确多窗口时，再进入该 App 的窗口选择；不要让多个「窗口 N」键暗示已经具备独立目标控制。
2. **按实际能力开放窗口条目。** 只有取得并验证过可操作窗口对象的 App 才提供窗口选择；拿不到、已失效或歧义时明确显示 App 级入口／切换失败，不能静默把 App 激活算成窗口切换成功。
3. **拆开三个字段。** 控制身份用短期窗口 token／对象，展示用标题或用户标签，排序用独立顺序。数字可作当前会话辅助编号，不能作为业务身份；若需稳定编号，需维护分配表而非每次重新 `enumerated()`。
4. **让用户能认出目标。** 标题有意义时展示标题；同名／无标题时仍需别名、位置说明或经授权的预览等线索。无论底层多准确，只显示数字都不能告诉用户哪个是聊天窗／课程窗。预览和标题采集会影响项目现有隐私范围，需另行进入设计。
5. **窗口切换以结果确认。** 只操作目标窗，完成后读取前台进程与 focused window，对照目标；记录脱敏错误类型及失败状态。不能只看 API 已调用或 App 已激活。

上述为研究建议，尚未修改 spec、design 或代码。后续最小验证应覆盖原生 App 及用户实际使用的 Chrome、ClassIn、微信：同名／无标题、目标最小化、关闭后重建、跨 Space／全屏、权限缺失／App 无响应；以实际聚焦结果决定支持范围。

## 验收证据与限制

- 已完成：截图语义分析、当前代码审计、官方 API 与开源实现查阅、实际 Core 源码的合成数据复现。
- 未执行：操作用户真实窗口、读取用户实时窗口标题、对 Chrome／ClassIn／微信进行真实聚焦实测。因此不能给出这些 App 的成功率或宣称全部兼容／全部不兼容。
- 本次仅新增本文；既有未提交文件保持原状。已执行 `python3 .framework/scripts/check_framework.py --root .`（Python 3.9.6）：85 个 Markdown，0 个错误、0 个警告；该检查不包含业务代码、系统聚焦或发布验证。
- 研究接受人：项目 owner（待确认）；复核触发：开始窗口级实现、目标 App／macOS 升级，或真实焦点验证出现失败。
