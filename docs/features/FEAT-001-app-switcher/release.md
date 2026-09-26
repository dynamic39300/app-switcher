---
id: REL-001
status: ready
owner: "AppSwitcher 项目 owner（待填姓名）"
upstream: [SPEC-001]
---

# REL-001：AppSwitcher 0.3.2 微信切换修复与本机安装记录

上游：[QA-001](test-plan.md)、[TRACE-001](traceability.md)、[ADR-0001](../../adr/0001-capability-based-window-switching.md)。本记录涵盖本地构建及用户明确授权的旧版替换、安装和启动，未对外分发。

`ready` 表示本地候选制品可用，且已完成本机安装启动；不表示第三方应用兼容矩阵或正式发布门槛已完成。

## 0.3.2：排除共用应用目录的辅助进程

2026-09-25，TKT-013 修复微信主程序与 `wxplayer` 共用 `WeChat.app` 时被误判为两个主实例的问题。现在只有同安装路径下潜在同一可执行文件的进程才构成歧义；已知不同可执行文件的辅助进程排除，未知身份仍保守计数。真正双开仍拒绝含歧义的重开请求，回调 PID / 启动身份核验不变。新增启动参数 `--show-switcher` 复用菜单显示入口，便于直接验证最终制品；无逐键或窗口内容日志。

最终安装位置 `~/Applications/AppSwitcher.app`，版本 **0.3.2**，运行 PID **98688**。可执行 SHA-256：`2fce2d6687f08f45160d5b407b36273f5b7a9cae500d03eba382972ecd5c1c3b`；ad-hoc 签名，候选及正式位置严格验签通过。源基线仍为 `a1e40a6` 加现有未提交工作区，本轮未创建提交。

验证：旧 guard 下四状态均因 helper 被误算而失败；修复后 Debug / Release `--verify-app-activation` 5/5 PASS，涵盖带同包 helper 的正常、最小化、关闭窗口、隐藏与同 exe 真多实例拒绝；原有 CoreTests 75/75 PASS。独立审阅与中间失败记录见 QA-001。最终面板通过 CUA 实际点击微信入口后，系统读回原微信 PID 72924 位于前台、一个正常尺寸窗口可见且最前；辅助进程 wxplayer PID 73161 仍在，误判条件确实仍存在。未将这次鼠标选择等同于自动化验证全局 ⌘E、跨 Space 或所有第三方兼容。

临时诊断 PID 74512 已定向退出，两个 `AppSwitcher-diagnose*.app` 移至废纸篓。旧正式 0.3.1 备份于 `~/Library/Application Support/AppSwitcher/backups/AppSwitcher-0.3.1-20260925.app`，新版首次 PID 98592 后为现场面板验证重启为最终 PID 98688。启动日志版本正确、组合注册 true；`shortcuts.json` SHA-256 前后一致：`ccfefee726015a78ca84604ae24fdfed10f44642593592b019820879b9d68a86`（⌘E、F→J 关闭）。使用数据保留，未修改权限、系统快捷键或登录项。

回退时退出身份已核对的新版进程，将上述 0.3.1 备份恢复至正式安装位置、严格验签后启动；配置兼容。WorkBuddy 原始失败仍未复现，独立记录保留，不据微信修复一并结案。

## 0.3.1 历史记录：键帽图标放大与清晰度

2026-09-25，TKT-012 按用户要求让应用图标随键帽尺寸更明显地放大。取消64pt上限，以键宽68% / 键高52%为目标，并为两行名称、窗口说明和键标预留空间；紧凑键帽采用图标与键标并排。系统图标副本保留多分辨率表示，逻辑长边至少256pt，改善默认32pt图像放大后的清晰度；不改原始系统缓存。第三方资源质量仍由对应App提供。

最终安装 `~/Applications/AppSwitcher.app`，版本 **0.3.1**，单一运行 PID **17459**。可执行 SHA-256：`a6f6296ffad4e8a2c7a601570c2eceebfacbd22b328b4fa459dcfcc53c5c2143`，ad-hoc签名；候选与正式路径严格验签通过。源基线仍为 `a1e40a6` 加现有未提交工作区。

实际检查：最终 `swift build` 无警告；`APPSWITCHER_OUTPUT="$HOME/Applications/AppSwitcher-0.3.1.app" ./scripts/build_app.sh` 通过。16场景合成视觉与独立窄短屏审阅通过，最终Release再次渲染全部16场景，root复核常规和窄屏差异场景；14张与清晰度对照预览逐字节相同。预览位于 `build/previews/0.3.1-release`，范围包括应用/窗口/空/加载/失败/缺图标、笔记本/大屏/超宽/窄短屏、38键长文本。未复测未改动的Core规则、AX或快捷键后端，也未将合成预览作为真实按键验收。

旧PID82431定向退出，原0.3.0保留在 `~/Library/Application Support/AppSwitcher/backups/AppSwitcher-0.3.0-20260925.app`。新进程启动显示0.3.1、组合注册true；`shortcuts.json` 逐字节保留（⌘E、F→J关闭），`usage.json` 保留。回退时退出新版、恢复上述App备份、严格验签后启动即可，配置兼容。未修改权限、登录项或系统快捷键。

## 0.3.0 历史记录：自定义唤出快捷键

以下为当时制品与PID记录，当前状态以上方0.3.2为准。

2026-09-24，按用户要求完成 TKT-006。菜单栏「快捷键设置…」及面板右上角齿轮打开原生设置窗；点击录制组合键，保存后注册并写入独立 `shortcuts.json`，支持恢复默认草稿和单独开关 F→J。取消 / 关闭不保存草稿，录制暂停与面板暂停分别管理；旧注册事件与停用前排队的 F→J 回调不再触发。

配置校验、已启用的系统快捷键与可检测的 Carbon 排他注册冲突均提供反馈。新组合或写入失败保留旧值；配置损坏、启动注册失败、录制后恢复失败、F→J 缺少输入监控权限都有明确状态。真实实验确认 macOS 允许新排他注册与另一进程已有非排他注册并存，因此不承诺检测全部第三方监听或应用内快捷键。

验证：`swift run CoreTests` 75 项通过；Debug 构建及 Release 打包通过；Debug / Release `--verify-shortcuts` 实际跨进程排他冲突、持久化失败回滚、同键保存、替换释放、暂停 / 恢复冲突及清理均通过，非排他边界单独记录 NOTE。四种设置合成预览已生成并目视检查。独立只读复核发现并修复暂停状态误报、F→J 过期触发及权限失败的成功误报。

首次启动时默认 ⌃⌥Space 注册失败；只读 `CopySymbolicHotKeys` 核对该组合已被本机启用的系统快捷键使用。随后真实设置窗口观察到用户完成录制与保存，界面显示 ⌘E、F→J 关闭及保存成功，配置文件同步为 keyCode 14 / modifiers 8 / sequenceEnabled false。保留这一用户选择，不恢复默认。实际自定义组合唤出、Esc / 失焦交互及其他第三方应用完整矩阵尚未现场验证。

最终安装 `~/Applications/AppSwitcher.app`，版本 **0.3.0**，单一运行 PID **82431**；可执行 SHA-256 `5472c32c1433ee368301029ba19c5a83148203b3f214c8ce6f7a34a449361bb7`。最终候选使用 `APPSWITCHER_OUTPUT="$HOME/Applications/AppSwitcher-0.3.0-verified.app" ./scripts/build_app.sh` 构建，ad-hoc 签名及正式安装路径严格验签通过。重启前后快捷键配置逐字节一致，启动日志确认已保存的组合注册 true，F→J 没有启动；重启后 UI 自动定位超时，因此不将它记为界面或真实按键验证。旧 0.2.2 已保留于 `~/Library/Application Support/AppSwitcher/backups/AppSwitcher-0.2.2-20260924.app`；`usage.json` 保留，未修改系统快捷键、权限、登录项。回退时先退出新版、备份 `shortcuts.json`，再恢复该 App 备份并验签启动；0.2.2 不读取新配置。

## 0.2.2 历史记录：屏幕自适应放大与精简卡片

以下版本与 PID 为当时记录，当前状态以上方 0.3.2 为准。

2026-09-24，TKT-011 按用户要求扩大覆盖层并删除逐卡重复的「应用」。当前安装 `~/Applications/AppSwitcher.app`，版本 **0.2.2**，单一运行 PID **75949**。可执行文件 SHA-256：`2ebf177f4c0c266e2d86155d9715ace5999e684af30f859d2fc8d7a37778acfe`；ad-hoc 签名，候选及最终安装路径严格验签通过。源基线仍为 `a1e40a6` 加现有未提交工作区。

- 面板使用本次活动屏可用区域的 92% 宽、82% 高，至少留 16pt 安全边缘，居中显示；移除 1080pt 宽度上限，切换模式保持面板尺寸。
- 键帽按键盘剩余高度均分，图标、应用名称和键标适度放大。低于 104pt 最小键高时仍仅键盘区滚动。窄键帽为图标和键标分配独立区域，避免长标题时重叠。
- 应用模式卡片显示图标、名称、快捷键，删除重复「应用」及副标题留位；窗口模式保留真实标题 / 回退「应用入口」，无障碍名称仍保留目标语义。

实际检查：`swift build` 通过、无编译警告；`.build/debug/AppSwitcherApp --render-preview build/previews/0.2.2` 生成并目视检查 13 个合成场景，包括应用 / 窗口 / 空 / 失败 / 加载、760pt 窄宽、38键、短屏、1280×720 / 1920×1040 / 2560×1080 可用屏，以及 760×430pt 满38窗长标题组合。独立审查发现的窄短屏图标 / 键标重叠边界已修复并重新渲染检查。预览只使用合成候选，不截取用户窗口。

`APPSWITCHER_OUTPUT="$HOME/Applications/AppSwitcher-0.2.2.app" ./scripts/build_app.sh` 通过；已验证候选改名安装到正式路径。旧 PID 71639 定向退出，0.2.1 保留在 `~/Library/Application Support/AppSwitcher/backups/AppSwitcher-0.2.1-20260924.app`；启动新版确认 0.2.2、备用热键注册 true、进程仍运行，`usage.json` 保留。回退时先退出新版，再恢复上述备份并验签启动。

本轮是低风险局部视觉修改，没有改候选、键位分配、窗口身份或激活后端，因此未重复原生聚焦测试；也不将合成视觉或启动日志写成真实快捷键 / Spotify 现场验收。原待验项继续跟踪。

## 0.2.1 历史记录：Spotify 唤起反馈后的修复

以下版本、PID 和制品信息为当时记录，当前运行状态以上方 0.3.2 为准。

2026-09-24，源基线仍为 `a1e40a6` 加现有未提交工作区及 TKT-010。当时安装：`~/Applications/AppSwitcher.app`，版本 **0.2.1**，运行 PID **71639**。可执行文件 SHA-256：`41ba708238acffc7e4516479536426a0cd3c3f10ba6253549d0d7c3f1d1fc836`；ad-hoc 签名，最终安装位置严格验签通过。

0.2.0 的 App 入口只调用进程激活并核对前台 PID。两次隔离红测试证明：目标最小化或最后窗口关闭时，可返回成功却没有可见窗口。0.2.1 对唯一运行实例发出正常 reopen 请求，核对返回 PID / 启动身份后协作移交前台。目标 App 负责窗口恢复或创建；生产路径不将前台 PID 当作可见性验证。具体窗口仍走 AX token 路径。

| 本轮检查 | 实际结果 |
| --- | --- |
| `swift run CoreTests` | 60 项通过 |
| `swift build` | 通过，无编译警告 |
| Debug `--verify-app-activation` | 普通、最小化、关闭最后窗口、隐藏四场景通过；真实 reopen 回调 1/2/3/4，前台原 PID 且有可见窗口；另一最小化窗保留 |
| Debug `--verify-window-switching` | 全通过，包含旧身份、取消、过期 token 和只恢复所选窗口 |
| `APPSWITCHER_OUTPUT="$HOME/Applications/AppSwitcher-0.2.1.app" ./scripts/build_app.sh` | Release 构建、打包、临时与最终制品严格验签通过 |
| 该 Release 包的两个 `--verify-*` 入口 | App 四场景及原跨进程窗口测试均通过，exit 0；不是权限跳过 |
| 独立只读复核 | 新增重开 / 身份 / 超时 / 取消路径未发现阻断缺陷；多实例、返回替换实例和 reopen 在途取消未作实际夹具注入 |
| 安装运行 | 旧 PID 63063 定向退出；替换为已验证制品。当前单一 PID 71639，启动日志显示 0.2.1、备用热键注册 true；启动日志不等于真实按键验收 |
| Spotify 现场结果 | 旧版面板 S 映射与激活记录已观察；新版自动化面板定位超时，未确认新版 S 已执行，因此不记为通过。已请求用户重试；原始故障时窗口状态未知 |

原 0.2.0 保留在 `~/Library/Application Support/AppSwitcher/backups/AppSwitcher-0.2.0-20260924.app`；旧 0.1.0 备份仍保留。`usage.json` 未删除或迁移。需要回退时先退出新版，再将该备份复制至 `~/Applications/AppSwitcher.app`、复核签名后启动。未修改登录项、系统权限或 Spotify 内容。

系统已接收的 reopen 请求不能撤销；取消 / 超时只保证迟到回调不再显式激活。目标在竞态中退出时系统仍可能重新启动它，但返回身份不符会阻止后续显式切换。第三方应用、跨 Space / 全屏及完整用户交互矩阵继续由 TKT-008 跟踪。

## 0.2.0 历史记录

以下保留上一轮安装与验证事实，其中版本号、PID、签名和当时的工具限制不代表当前 0.3.0 运行状态。

### 版本与范围

- 源基线：`a1e40a6` 加现有未提交改动与 TKT-009 本轮工作区；没有创建新提交。
- 0.2.0 当时安装位置：`~/Applications/AppSwitcher.app`；由已验证的 `~/Applications/AppSwitcher-0.2.0.app` 改为正式文件名，版本 0.2.0，bundle ID `com.appswitcher.app`，macOS 15+ / Apple Silicon。项目内 `build/AppSwitcher.app` 的重复构建包已移至废纸篓；脚本仍可重新生成该路径，但本机同步目录会再附加 FinderInfo，因此不作为安装位置。
- 可执行文件 SHA-256：`9451ee422983465461d60cf15c2ae79c9d483957b1a2c0d5d44ffe657de90a73`。本机制品使用 ad-hoc 签名。
- 默认每个运行中的普通应用进程一个入口；Tab 切到窗口模式，只有具可用对象、操作能力和可辨认标题的窗口才展开，其余回退应用入口。
- 控制使用会话 token 关联具体 AX 窗口，标题只用于展示；只恢复目标，读取实际前台 PID 和 focused window 后确认成功。
- 覆盖层更新为深石墨键盘、应用图标、单一选中状态、长名称/标题、完整数字行、方向键/Enter/鼠标输入；支持窄屏和短屏。
- 保留 F→J 与 ⌃⌥Space；移除全局逐键调试日志。标题只在内存，不请求屏幕录制，不截取屏幕内容。

### 验证记录

2026-09-24，Codex 在用户授权的工作区执行；环境为 macOS 26.6.2 / Swift 6.3.3 / Apple Silicon。

| 检查 | 结果与范围 |
| --- | --- |
| `swift build` | 通过，最终输出无编译警告 |
| `swift run CoreTests` | 60 项通过，覆盖候选回退、对象身份、排序、38 键映射和导航 |
| Debug `--render-preview build/previews/2026-09-24` | 九个合成场景成功生成并目视检查，包括窄屏 38 键、加载及短屏滚动；不代表真实用户应用兼容性 |
| Debug `--verify-window-switching` | 跨进程隔离 AX 验证通过；窗口改名、关闭、同名/无名回退、取消、过期身份/快照、目标最小化恢复和实际焦点均有覆盖 |
| `APPSWITCHER_OUTPUT="$HOME/Applications/AppSwitcher-0.2.0.app" ./scripts/build_app.sh` | Release 编译、打包通过；优先自签名不可用时按原策略回退 ad-hoc，临时目录及最终制品严格验签通过 |
| 打包后的 `--verify-window-switching` | 项目 build 包和最终 Applications 包均通过同一组 AX 验证，退出码 0，非权限跳过 |
| 本机安装与启动 | 用户明确要求卸载旧版、安装并启动新版；旧 PID 8959 已正常退出，正式安装路径验签仍有效，`open` 成功，确认单一新 PID 63063 运行 |
| 新实例运行抽查 | 对 PID 63063 的 sample 确认版本 0.2.0、主线程已进入 `NSApplication.run` 等待事件，`UsageTracker` 计时回调正在执行；不以此代替面板交互验收 |
| 框架检查与差异空白检查 | 86 个 Markdown，0 错误、0 警告；`git diff --check` 通过 |

首次 Debug 构建遇到旧用户目录的 SwiftShims 预编译缓存路径；执行 `swift package clean` 后恢复。初版自查询 AX 测试返回成功但窗口数为 0，已定位为本机进程查询自身窗口的限制，改用父子测试进程，不放宽生产能力门槛。

首次打包在同步目录出现 `com.apple.FinderInfo`，签名失败。临时目录组装/签名、无资源叉/扩展属性复制后即时验签通过，但文件提供程序随后又给项目目录内的包附加该属性，延后验签再次失败。构建脚本支持 `APPSWITCHER_OUTPUT`，本轮将最终制品输出到不在该同步目录内的 `~/Applications`，再验证签名和 AX 行为。元数据限制见 [Apple QA1940](https://developer.apple.com/library/archive/qa/qa1940/_index.html)。

### 操作与恢复

构建、启动、退出和隔离验证见[命令索引](../../project/commands.md)。当前启动命令为 `open "$HOME/Applications/AppSwitcher.app"`；若需要重开，应先从菜单退出已有实例，避免继续使用内存中的旧版本。上表中的带版本号构建 / AX 验证路径保留为当时实际执行记录，不再是当前安装路径。

本轮本机替换记录：用户明确授权后，定向请求旧 PID 8959 正常退出并确认退出；把 `build/AppSwitcher.app` 重复构建包和 `build/AppSwitcher 2.app`（0.1.0）移至废纸篓；把已验证的 Applications 候选改名为 `~/Applications/AppSwitcher.app` 并复核版本、签名及相同 SHA-256，再成功启动为单一 PID 63063。旧备份 `build/backups/AppSwitcher-before-0.2.0.app` 和现有 `usage.json` 保留；未修改登录项、启动项或系统权限。需回退时先退出新版，再把备份复制到非同步目录、复核签名后打开。

UI 工具定位菜单栏 App 超时，尚未完成本次安装后真实面板的目视 / 操作验收；此前九张合成预览与隔离 AX 通过的范围不变。当前运行检查确认新程序已经初始化并处理事件，不等于全部用户交互已验收。

安装后只读检查发现 PID 63063 没有已建立的键盘 event tap，系统设置的「输入监控」列表中也没有 AppSwitcher。已打开该设置页，未代为增加权限；F→J 仍需用户授权后重启验证。菜单栏「显示切换器」及备用 ⌃⌥Space 的代码入口保留，不把本轮自动 UI 定位失败记为已完成交互验证。

本地候选与正式发布状态分开。ClassIn、微信、Chrome 的实际兼容性、跨 Space/全屏、150ms、F+J 回放完整矩阵、VoiceOver/200% 字号和热键配置 UI（TKT-006）不因构建通过而视为完成，继续由 TKT-008/TKT-006 跟踪。
