---
id: DESIGN-001
status: in-review
owner: "AppSwitcher 项目 owner（待填姓名）"
upstream: [SPEC-001, RES-002]
---

# DESIGN-001：键盘覆盖层 App 切换器的技术设计

上游：[SPEC-001](spec.md)；验证：[QA-001](test-plan.md)、[TRACE-001](traceability.md)。遵循[架构规范](../../../.framework/docs/standards/architecture.md)、[工程规范](../../../.framework/docs/standards/engineering.md)、[UI/UX 规范](../../../.framework/docs/standards/ui-ux.md)、[安全隐私规范](../../../.framework/docs/standards/security-privacy.md)。2026-09-24 owner 授权系统修正和 UI 优化；核心决策见 [ADR-0001](../../adr/0001-capability-based-window-switching.md)。

## 方案与边界

沿用 SwiftPM + CLT、SwiftUI 内容视图、AppKit 菜单栏 agent（`LSUIElement=true`）和可接收键盘的 NSPanel。初次唤出只读取运行 App，默认每个普通进程一个键位；用户按 Tab 后异步发现窗口。窗口模式是全局候选视图，不是进入单个 App 的子菜单。

采用公开 AX 对象作为短期控制身份：枚举时注册对象，Domain / UI 只拿不透明 token。标题只是展示字段，不能作查找键；CG 窗口清单、数字编号、几何相似和 bundle ID 首个实例都不用于猜测目标对象。能力不足的 App 整体保留应用入口；窗口操作失败给中文反馈，不再次隐式尝试别窗。用户已转到无关 App 时保留消息至下次唤出，避免失败面板抢焦点。

App 路径在安装路径与可执行文件身份没有潜在多实例歧义时请求正常 reopen，再校验原进程身份、移交前台并核对 PID；这是 TKT-010 对 0.2.0 仅调用 `activate` 的修正。窗口路径仍只恢复目标最小化状态、设主窗口并抬起，验证前台 PID 与 `AXFocusedWindow` 是否为所选对象。两条路径都不使用 `activateAllWindows`，不批量 AX 恢复同 App 的所有窗口。App 负责响应 reopen 和选择呈现窗口，App 级结果不等于精确窗口或可见性验证。

## 模块、数据与信任边界

依赖：纯 Swift **Core ← Kit 系统适配 ← App 编排 / UI**。保持现有统计格式；本次窗口快照不进入持久化 schema。

| 模块 | 职责 / 契约 |
| --- | --- |
| `Candidate` / `CandidateFactory` | 显式区分 App 与窗口目标，关联运行 PID、展示标题及窗口 token；纯函数实行整 App 能力门禁 |
| `AppRanker` / `KeyAssigner` / `Key` | rank、组内顺序、38 键分配和 QWERTY 键义；身份兜底保证相同输入下确定性 |
| `KeyNavigation` | 可测试的方向选择与物理键码映射；输入法不改变选择键的含义 |
| `RunningAppsProvider` | 读取 `.regular` 且非自身进程，提供 App 身份与真实图标；App 模式不依赖窗口可见性 |
| AX 窗口适配 / token 注册表 | 公开 AX 枚举、能力查询、短超时；绑定 PID 与对象；会话结束或刷新时释放标题和引用 |
| `UsageTracker` / `UsageStore` | App 身份的激活计数 / 时间戳用于 rank，沿用现有本地存储，不存标题或窗口 token |
| `AppActivator` | 按明确目标执行激活，返回已核对结果或可解释失败；不把仅调用 API 当作成功 |
| `GlobalHotKey` | Carbon 注册与回调，默认 `⌃⌥Space`；TKT-006 增加事务式替换、注册冲突反馈及录制暂停 / 恢复 |
| `SequenceHotKey` | F→J 的 CGEventTap 序列检测：空闲 ≥120ms 后 F 暂扣（armed），300ms 内 J 触发，失败 / 超时回放。TKT-006 只增加启用开关与独立暂停原因；覆盖层与设置录制分别控制暂停，不能互相解除。需输入监控权限，不记录逐键输入 |
| `ShortcutSettingsWindow` / `ShortcutController` | 独立原生设置窗管理草稿与局部录制；协调校验、Carbon 注册和独立配置原子写入，失败保留原配置；不改 `UsageStore` |
| `AppShortcut` / `ShortcutPreferences` / `ShortcutStore` | Core 的物理键码、修饰位、有效组合与已知保留组合规则；Kit 负责独立 `shortcuts.json` 的校验读取与原子保存 |
| `AccessibilityGate` | 辅助功能检测、说明、系统设置入口；无 AX 权限仍可保留 App 级候选 |
| `OverlayController` | 两模式会话、加载 / 取消 / 激活状态、单次提交、generation 校验，编排 Provider、Domain 与 UI |
| `OverlayView` / `OverlayPanel` | SF / 石墨视觉、真实图标、候选可访问名称、选择焦点、中文状态；键盘与鼠标共用目标回调 |

窗口标题可能包含敏感内容。经辅助功能读取的标题和 AX 引用只存在于当前内存快照，禁止日志、统计、配置和测试资产记录真实标题；F+J 不记录逐键输入。没有网络、账号、屏幕内容、录屏请求或私有 API。App 身份枚举与 App 激活不被错误描述为一律需要辅助功能；窗口控制受系统 AX 授权及目标 App 实现约束。

## 能力门禁与会话

1. App 快照以运行 PID 区分同产品多个实例；统计仍按已有 App 身份聚合。
2. 窗口模式异步枚举公开 AX 窗口；确认窗口角色、对象有效性、`AXRaise` 支持、`AXMain` 可写，以及最小化目标可恢复。扫描时已经最小化且主窗口不可写的 App 保留应用入口；探测不为确认能力而还原用户窗口。已入选后才最小化的目标可在激活时恢复，再有界等待主窗口操作可用。
3. 标题去首尾空白后须非空，且在该 App 待展开集合内唯一。枚举失败 / 超时、缺对象、任一能力不足、重复 / 空标题都让整个 App 返回标为「应用入口」的候选，不只丢弃有问题的窗口后假装完整；未授权或完全没有可展开窗口时另给面板说明。
4. token 在系统适配层解析到原 AX 对象，绑定所属 PID；新快照不会把旧 token 复用给另一个窗口。改标题不改变控制身份，关闭后重建不能继承旧引用。
5. 一个显示周期只有一个生效快照；探测期间 UI 呈现加载并保持可取消，不把后台返回结果悄悄插入已可选择的键义。切模式、取消和再次唤出改变会话 generation，迟到回调丢弃。
6. 跨进程消息使用 120ms 超时，单 App 400ms、整个快照 2s 的探测预算，在途 IPC 可能追加一次超时。每 App 最多 64 个窗口、每快照最多 256 个描述、标题最多 2048 UTF-8 字节；超限保留 App 入口。这些是资源预算，不代表已测响应延迟。

## 激活与错误

- 选择 App：验证 PID / bundle 身份 / 启动时间仍对应原实例；将解析符号链接后的 `bundleURL` 相同进程作为身份核对范围；两侧 `executableURL` 均已知且解析后不同时，排除明确不同可执行文件的辅助进程；任一可执行文件路径未知时仍保守计入。仅当范围内只剩所选运行实例时调用 `NSWorkspace.openApplication`，配置 `activates=false`、`allowsRunningApplicationSubstitution=false`、`createsNewApplicationInstance=false`。完成回调复核返回进程的 PID / 启动时间，随后 `yieldActivation` → 激活原进程 → 有限等待并读回 frontmost PID。同安装路径及相同可执行文件的真实多实例，或路径信息不足形成的歧义，仍直接失败并提示选择具体窗口；缺少 `.app` bundle URL 时仅精确 PID 激活，不保证恢复窗口。请求失败或身份变化给明确失败，不把另一实例当作原目标。
- 选择窗口：验证 token 所属 PID / 对象有效 → 仅对目标解除最小化（如必要）→ 激活目标 App、设目标 `AXMain`、执行 `AXRaise` → 有限等待并核对 PID 和 focused window 对象。
- App reopen 完成回调的等待预算为 2 秒，配置不弹出额外系统提示、不加入最近项目；等待期间检查取消。迟到回调只写回结果，不能自行激活；已发给系统的 reopen 请求不可撤销，因此取消只能阻止尚未发出的请求或后续激活，不能承诺目标 App 从未处理请求。
- 能力探测不是成功保证；对象可在按键前失效、App 可忽略动作、系统可延迟换桌面。动作错误、超时、焦点不符有独立失败结果。前台仍为本应用或目标 App 时回应用模式给出说明；用户已经转到无关 App 时不抢前台，下次唤出再显示待处理消息。
- 激活期间阻止重复选择；取消只取消尚未提交的本轮选择 / 探测。不能承诺撤销已经由系统执行的聚焦动作。
- Esc / 热键取消时恢复原前台；外部点击取消尊重用户刚点击的应用，不抢回旧前台。

### TKT-010 的 API 依据与回归范围

Apple 的 [reopen 委托文档](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationshouldhandlereopen(_:hasvisiblewindows:)) 区分普通激活与 Finder / Dock 对运行中 App 的 reopen 请求，目标 App 可以自定义或拒绝默认窗口行为；该接口甚至将最小化窗口计入 `hasVisibleWindows`，因此不能据此承诺每个 App 一定恢复或创建窗口。[OpenConfiguration](https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration) 允许控制激活、替用不同路径实例和新建实例；本实现关闭这三项，将最终前台移交留到身份核对之后。[协作式激活](https://developer.apple.com/documentation/appkit/passing-control-from-one-app-to-another-with-cooperative-activation) 是请求，仍须读回结果。文档于 2026-09-24 核对。

`AppActivationProbe` 使用可控 App 夹具覆盖正常、最小化、最后窗口关闭、隐藏，验证实际窗口呈现而不只断言 PID；原有 `WindowSwitchingProbe` 同时回归，确保具体窗口不走 reopen，其取消 / 身份用例只证明共用前置检查。TKT-010 当时对多实例、替换返回及 reopen 进行中取消仅审阅守卫代码，未完成端到端注入；后续 TKT-013 扩展范围见下节。TKT-010 不改 UI、排序或窗口能力门禁；实际绿色范围由 QA-001 分期记录。

### TKT-013：同安装路径辅助进程的身份边界

现场微信主进程（`.regular`、bundle ID `com.tencent.xinWeChat`、可执行文件 `WeChat`）与辅助进程（`.prohibited`、无 bundle ID、可执行文件 `wxplayer`）共用 `/Applications/WeChat.app`。旧版只比较 `bundleURL`，在所选目标仍为正确主进程时误判有两个应用实例；reopen 被拒绝后 Controller 按既有失败恢复规则重开面板，造成用户所见的“弹窗再显示一次”。诊断捕获 11 次该拒绝；不记录窗口标题或聊天内容。

修复只收窄 reopen 前的实例歧义判断：明确不同可执行文件的同 bundle 辅助进程不算另一主实例；不以 `.regular` 过滤或 bundle ID 缺失直接跳过可疑进程。可执行文件信息不足保持保守，真实同 bundle / 同可执行文件多实例仍拒绝；原有目标 PID / 启动时间和 reopen 回调身份核对不变。无配置迁移，窗口 token 路径、排序和快捷键行为不变。

`AppActivationProbe` 已加入同一临时 `.app` 内实际运行的不同可执行文件 helper：旧守卫在四种窗口状态全部返回多实例错误，reopen 回调为 0；修复后 Debug 与 0.3.2 Release 均 5/5 通过，覆盖 helper 共存的四状态正常呈现，以及真实同可执行文件第二实例仍被拒绝且不发送 reopen。CoreTests 75/75、Release 严格验签和独立只读审阅通过；未知 executableURL、替换回调及 reopen 在途取消未做系统故障注入。

0.3.2 已安装到 `~/Applications/AppSwitcher.app`（PID 98688）。通过 CUA 实际点击面板微信入口后，只读系统确认原微信 PID 72924 获得前台、一个正常尺寸窗口可见且位于最前面，面板未重现；辅助进程 `wxplayer`（PID 73161）仍运行，证明复验保留了原缺陷触发条件。实际命令与制品身份见 QA-001 / REL-001。TKT-013 的已确认缺陷完成；此前 WorkBuddy 的两次普通切换成功不等于其原始失败已排除，也不由此次微信证据推定为同因。

## UI 与视觉契约

- 面板：深石墨背景、细边界和克制阴影，SF 系统字体；默认应用模式显示模式切换、候选数量，底部提供按键提示与当前选中目标完整文字。
- 面板按唤出时固定显示器的 `visibleFrame` 宽 92% / 高 82% 居中，至少留 16 pt 安全边缘，移除原 1080 pt 上限；Tab 切换保持同一外框。header / footer 固定，剩余键盘区域按 3 / 4 行均分，键帽最低 104 pt；短屏只滚动键盘区，选择自动滚入视野。数字行有任一映射即包含完整 12 键。
- 键帽：真实 App 图标、App 名（最多两行）和键标随可用键帽尺寸适度放大。应用模式移除重复「应用」字样及无意义副标题空行；窗口模式保留真实标题 /「应用入口」回退说明。长文本省略但完整语义可经选中详情、help 与无障碍标签获得。键帽宽度小于 70 pt 或放大图标接近右上角键标时，图标与键标放在独立水平区域，避免窄短屏、38 键和长窗口标题组合下重叠；其余尺寸保留右上角键标。
- TKT-012：图标目标取键宽68% / 键高52%与预留两行名称、窗口说明后的可用高度之小者，取消64pt上限；并排时再扣除键标实际槽位，紧凑键帽不强行抬高最小图标尺寸。保留NSImage多分辨率表示，将副本逻辑长边至少设为256pt，避免SwiftUI按默认32pt取图后放大；保持源图比例，不修改系统缓存原对象。
- 颜色、字体、间距、圆角、边界和焦点使用统一语义样式。普通键帽中性；hover / 当前选择用边框与背景反馈，空位安静但保留键盘形状，错误用中文文字而非仅颜色。
- 交互：映射键直达、鼠标点击选择、方向键可见导航、Enter 确认、Tab 切模式、Esc / 外部点击 / 全局热键取消。hover 和方向键共用一个选择状态，Enter 与高亮目标一致；修饰组合不误触普通选择。F+J 识别在覆盖层内暂停，F、J 作为普通候选键。
- 状态：应用、窗口、加载、空集合、能力回退、激活失败、超额截断；加载时说明正在识别窗口，失败按焦点规则即时或下次唤出反馈。容量提示与错误 / 权限信息合并，避免截断事实被覆盖。
- 可访问性：App 名 / 窗口名 / 键位具有语义标签，选中可见；尊重减少动效及增强对比度。完整 VoiceOver 与 200% 放大验证仍需记录实测。
- 合成视觉预览使用独立渲染入口，覆盖应用 / 窗口 / 空 / 失败 / 窄屏 / 38 键 / 加载 / 短屏，以及 TKT-011 新增的大屏、超宽屏布局；不读取用户窗口或请求录屏。尺寸均按 pt 描述，实际场景及结果见 QA-001。

### TKT-006：设置与注册一致性

沿用原生 AppKit / SwiftUI，不新增第三方快捷键库。菜单栏与覆盖层齿轮复用一个设置窗口，从覆盖层进入先结束面板会话。已保存设置与草稿分开；恢复默认只改变草稿，关闭丢弃未保存修改。录制器只处理本设置窗口的事件，Esc / 失焦 / 关闭退出录制；不增加全局键盘采集或按键日志。录制时暂时注销组合键，结束后恢复保存值；F→J 的启用状态与「覆盖层」「录制」暂停原因分离，最后一个原因移除后才可恢复。

规则层验证键码和修饰组合，至少一个 Command / Control / Option，可叠加 Shift；已知保留组合直接解释拒绝，`CopySymbolicHotKeys` 检查已启用系统组合，检查失败不继续提交。使用 `kEventHotKeyExclusive` 注册，反馈 Carbon 可检测的排他占用。系统适配实验已发现旧注册为非排他 `options=0` 时，新排他注册仍可能成功；因此不能保证发现所有第三方非排他注册、事件监听或应用局部快捷键，成功注册也不代表没有其他响应者，实际实验边界见 QA-001。

协调层保留旧配置与旧注册直至新注册和磁盘保存均成功；新注册失败保持旧绑定，原子写入失败释放新注册并保留旧绑定，失败反馈保留草稿。注册代次过滤迟到旧事件，已替换但释放失败的旧引用不再触发。注册和持久化的部分失败、重复保存及恢复异常须有独立验证。

配置存于 `~/Library/Application Support/AppSwitcher/shortcuts.json`，只保存物理键码、修饰位与 F→J 开关，单一写入责任归 `ShortcutController`，由 `ShortcutStore` 执行原子写入。缺失使用默认；损坏或无效配置保留原文件并提示默认降级，后续明确保存才覆盖。启动时有效保存组合被占用则提示不可用并保留菜单设置入口，不擅自换键；默认注册失败也明确反馈。`usage.json` 不迁移、不改写，窗口标题和逐键输入不进配置。0.3.0 已实现并本机安装，实际命令与验证边界见 QA-001 / REL-001。配置损坏提示保留至保存；F→J 权限不足单独提示，菜单只列实际运行手势。F→J 也使用触发代次使停用或暂停前排队事件失效。

## 验证与追溯

AC 到责任模块与测试以 [TRACE-001](traceability.md) 为单一矩阵。候选规则、身份边界、数字输入与导航可用合成数据自动验证；真实焦点、权限、Space / 全屏、F+J 不丢字、窗口标题敏感数据边界必须按 [QA-001](test-plan.md) 记录实际证据。App 面板 ≤ 150ms 是待测目标，异步窗口探测时间单独衡量。

TKT-009 的 Debug 构建、60 项规则测试、九张预览及父 fixture / 子 driver 的公开 AX 跨进程隔离验证已通过，具体范围与首次失败记录见 QA-001。该证据仅覆盖合成原生窗口，不代表 ClassIn / 微信 / Chrome、跨 Space / 全屏或完整输入法 / 可访问性矩阵已通过。

TKT-009 分为 Domain / 系统适配、Controller 集成、UI、规格同步四个所有权清晰的并行工作，由集成负责人处理共享接口。所有原有未提交行为保留，尤其 F+J 手势与输入回放语义；本轮仅移除不必要的逐键日志。

TKT-011 是用户授权的局部视觉调整，由集成负责人维护 UI / 预览，文档协作者只同步本节、规格和验收。Debug / Release 构建、13 张合成多尺寸视觉检查、独立代码审阅及本机 0.2.2 更新已完成；独立审阅发现的窄键帽重叠已修正并复核。激活路径未改动，不为本次样式变更重复执行原生焦点探针，也不扩大原有兼容性结论，详见 QA-001。

## 历史 spike 的适用范围

2026-09-20 本机 macOS 26.6.2 / Apple Silicon / Swift 6.3.3 的 spike 验证了特定构建上的 Carbon 热键、可激活面板、App 激活及最小化处理；这些观察不能自动证明所有 App 的精确聚焦。2026-09-22 对 CG window number 排序避免 z-order 抖动的改动是既有工作，仍不能保证删除窗口后的编号稳定，RES-002 已隔离复现该边界。

此前「Chrome / Chromium 的 AX 返回 0 所以不可用」「所有标题都必须录屏」「必须 Developer ID / TeamIdentifier 才能授权」是过宽推论，已被 [RES-002](multi-window-research-2026-09-24.md) 修正。AX 标题与 CG 标题的权限路径不同；签名影响授权身份稳定性，不构成本文无需证明的普遍权限禁令。当前窗口路径不需要 CG→AX 私有桥接、录屏或真实标题持久化。
