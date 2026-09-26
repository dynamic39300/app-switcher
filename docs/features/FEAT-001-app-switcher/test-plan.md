---
id: QA-001
status: in-review
owner: "AppSwitcher 项目 owner（待填姓名）"
upstream: [SPEC-001]
---

# QA-001：测试计划

上游：[SPEC-001](spec.md)、[DESIGN-001](design.md)；结果与版本：[TRACE-001](traceability.md)、[REL-001](release.md)。覆盖 TKT-009、TKT-010 App 唤起修复及 TKT-011 自适应面板，遵循[测试规范](../../../.framework/docs/standards/testing.md)。

## 风险、范围与环境

本轮 **medium**：新增跨进程能力判定、对象生命周期和聚焦确认，错误可能把用户送到错误窗口；视觉为 low，但输入与取消涉及主体验。无网络、账号、第三方数据写入或窗口内容落盘。适配器的权限、超时、对象失效、真实结果不能只靠 mock 证明。

环境基线为本机 macOS 26.6.2、Apple Silicon、Swift 6.3.3；最终运行以实际记录为准。Domain 用合成应用和窗口对象描述，UI 渲染用合成标题与图标夹具。真实 App 测试只记录类别、结果、耗时及版本，不记录真实窗口标题或屏幕内容；跨 Space / 全屏与 ClassIn、微信、Chrome 等尚未实测的兼容性不可宣称通过。

## 用例矩阵

| TEST | AC | 操作 / 输入 | 可观察预期 | 层级 |
| --- | --- | --- | --- | --- |
| TEST-001 | AC-01 | 默认 / 已保存组合键和开启的 F→J 各唤出；覆盖层内按 F/J | 默认 App 模式，当前活动屏、真实图标与键标；F/J 为选择键，不重新触发手势；配置回归见 TEST-009 | 本地集成 / 人工 |
| TEST-002 | AC-02 | 普通 / 后台 / 自身进程、无内容窗 App、同 bundle 的不同 PID | 普通且非自身进程各一个 App 入口；无内容窗仍可选；不同 PID 的控制身份不混淆 | 纯函数 + 适配器 |
| TEST-003 | AC-03 | 相同输入重复、统计同分、同名 App | 映射确定，身份兜底；显示中键义不重排 | 纯函数 |
| TEST-004 | AC-04 | Safari / Slack / Spotify、中文名，26 / 38 / 39 个目标，中文输入法 | 字母冲突规则正确；有映射数字行完整可见，1–0/-/+ 可达，等号物理键选 +；超额提示 | 纯函数 + UI / 人工 |
| TEST-005 | AC-05 | 选择同 Space / 其他 Space 的 App 入口，包括多个同产品进程 | 对唯一可定位实例请求正常窗口呈现、核对原 PID；多实例不猜测重开，不批量 AX 恢复；按 App 实际行为观察窗口结果，不只看激活返回值 | 真实 App / 人工 |
| TEST-006 | AC-06 | 正常 / 加载中 Esc、点击另一 App、热键取消；激活失败前已切到无关 App | 不执行新目标切换；外部点击不被原前台抢回；迟到探测不重开面板；失败原因延后到下次唤出 | 集成 / 人工 |
| TEST-007 | AC-07 | 退出 / 新启 App、关闭 / 重建窗口后再唤出或选旧项 | 新快照重算，旧 token 不复用；失效反馈而非换到别窗 | 纯函数 + 集成 |
| TEST-008 | AC-08 | 未授予 / 中途撤销 AX 权限；F+J 无输入监控权限 | 窗口能力回退且解释 / 设置入口可用；App 入口可用范围单独判断；不申请录屏 | 权限 / 人工 |
| TEST-009 | AC-01、AC-09 | 菜单 / 齿轮设置、录制 / 取消 / 失焦 / 关闭、有效与无效组合、冲突、写入失败、重启、恢复默认、F→J 开关 | 保存即生效且重启保留；异常反馈不丢旧绑定，局部捕获与暂停原因正确；损坏配置可恢复、不改 usage；详细矩阵见 TKT-006 节 | 规则 / 存储 / 注册集成已通过，真实保存与重启已观察；其余人工交互见下表 |
| TEST-010 | AC-10 | 应用、窗口、空、失败、加载、760 pt 窄屏、数字行、窄屏数字行、短屏数字行九种合成场景；方向 / Enter / hover / 点击 | 石墨 / SF / 图标和层级正确，长名可辨，空键不选；hover / 方向选择唯一，短屏滚动可达；不请求录屏 | 合成渲染 + 人工 |
| TEST-011 | AC-11 | 有对象且可控 / 缺对象 / 空标题 / 同名 / raise 不支持 / main 不可写 / 部分失败 / 扫描时已最小化 | 仅所有窗口满足条件的 App 展开；任一不确定整个 App 单入口并标明范围；探测不恢复窗口，无数字窗口占键 | 纯函数 + 适配器 |
| TEST-012 | AC-12 | 同标题对象、标题变化、已入选目标随后最小化且另一窗也最小化、目标关闭、PID消失、读回不符 | token 始终指向原对象；仅恢复目标；PID + focused window 相等才成功；失败不试另一窗、不从无关 App 抢焦点 | 纯函数 / 控制边界 + 真实聚焦 |
| TEST-013 | AC-13 | AX 超时 / 无响应、快速 Tab、关闭后重开、连续确认 | 主界面响应、预算有限、仅当前 generation 生效；映射不异步变义，重复激活受抑制 | 集成 / 故障注入 |
| TEST-014 | AC-05、AC-07、AC-12 | 同包不同 exe helper 下可控 App 正常 / 最小化 / 最后窗口关闭 / 隐藏；真实同 exe 第二实例；回调身份守卫 | 四状态 reopen 后原进程前台且窗口可见，其他最小化窗保持；真多实例拒绝且不重开；TKT-013 Debug/Release 5/5。替换回调、未知 executableURL 与 reopen 在途取消仍未系统注入；窗口 probe 历史回归见 TKT-010 分期记录 | 跨进程隔离 AppActivationProbe + 历史窗口 probe + 守卫审阅 |
| TEST-015 | AC-10 | 普通 / 大屏 / 超宽屏、760 pt 窄宽、38 键、短屏、两模式及空 / 失败 / 加载状态，含 760×430 pt 的 38 个长标题窗口组合 | 面板依屏幕充分增大且安全边缘完整，Tab 外框稳定；普通 App 无重复「应用」或空副标题行；窗口标题 / 回退 / AX 名称保留，窄键帽图标与键标无重叠；短屏键盘可滚动、关键操作可达 | 合成视觉 + 独立代码审阅 |

## 重点回归

- **旧故障**：无标题 / 同名窗口原本各占一键、却按标题找首个对象。合成用例应证明它们现在整体回退；可控制目标的标题变化不会改指另一对象。
- **触发与输入**：既有 F+J 120ms 空闲 / 300ms 窗口及超时回放保留；快速正常输入、F 单键、F 后非 J、覆盖层内 F/J 均不丢字、不乱序。逐键日志移除后检查新运行不写键码日志。
- **实际聚焦**：至少一个可控原生测试 App 的双窗口，以 synthetic 标题验证真正 focused window；再按 owner 常用 App 逐个记录结果。原生夹具通过不代表 ClassIn / 微信 / Chrome 通过。
- **可视与可达**：默认与 760 pt 窄宽、长中英名称、数字行 38 键、强对比和减少动效；方向 / Enter 不能激活空位。VoiceOver 与 200% 字号另行记录，不以存在 accessibility label 代替完整符合性。
- **性能**：分别记录热键到首个 App 面板与 Tab 到窗口结果的时间，含慢 App / 超时；150ms 是首个 App 面板目标，未经测量不能标通过。
- **隐私**：审阅日志 / 统计写入路径和测试输出；真实标题只在内存，未进入日志或文件；没有屏幕捕获 / 录屏权限请求 / 私有 API。无需线上或网络测试。

## TKT-009 执行与证据（0.2.0）

实际脚本以[命令索引](../../project/commands.md)和仓库文件为准；`swift run CoreTests` 是现有最小测试运行器。以下为集成负责人于 2026-09-24 实际执行并回报的结果；文档协作者另执行了文档检查。可控真实窗口聚焦验证独立于 Core 测试，文档检查不验证业务行为。

| 运行 / 范围 | 命令或步骤 | 本轮状态 | 限制 |
| --- | --- | --- | --- |
| 业务构建与规则回归 | `swift build`、`swift run CoreTests` | Debug 构建无警告，60 项全部通过 | 规则层结果不替代真实系统交互 |
| 合成 UI 九场景 | `AppSwitcherApp --render-preview build/previews/2026-09-24` | 九张 PNG 已生成并目视检查，覆盖常用 / 窄屏 / 短屏及状态 | 合成截图不证明真实聚焦或系统权限；产物可由入口重新生成 |
| 文档完整性 | `python3 .framework/scripts/check_framework.py --root .`；`git diff --check` | 2026-09-24 文档协作者执行：86 个 Markdown，0 错误、0 警告；diff 检查通过 | 不属于业务测试；后续集成改动由负责人决定是否重跑 |
| 可控真实窗口 | Debug 验证入口 `AppSwitcherApp --verify-window-switching`，父 fixture + 子 driver | 全部跨进程隔离 AX 验证 PASS，详见下述覆盖范围 | 实际权限已可用，本次非 SKIP；仅操作验证创建的合成窗口 |
| Release 首次打包与验签 | `./scripts/build_app.sh`；`codesign --verify --deep --strict build/AppSwitcher.app` | 0.2.0 构建 / ad-hoc 签名及打包完成时严格验签通过，exit 0；同步目录随后附加属性导致延后验签失败 | `build/` 位于同步 Documents，不能视为长期签名有效的存放位置；最终试用包见 REL-001 |
| 原 build 包实际聚焦 | `build/AppSwitcher.app/Contents/MacOS/AppSwitcher --verify-window-switching` | 打包完成后全部跨进程隔离 AX 验证 PASS，exit 0 | 此次结果真实，但后续同步属性改变使该位置验签失败；不作为最终试用路径 |
| 最终试用包构建 | `APPSWITCHER_OUTPUT="$HOME/Applications/AppSwitcher-0.2.0.app" ./scripts/build_app.sh` | exit 0；制品为 `~/Applications/AppSwitcher-0.2.0.app` | 输出目录避开本项目 Documents 同步路径；未替换旧运行实例 |
| 最终试用包聚焦与延后验签 | `~/Applications/AppSwitcher-0.2.0.app/Contents/MacOS/AppSwitcher --verify-window-switching`；`codesign --verify --deep --strict --verbose=2 ~/Applications/AppSwitcher-0.2.0.app` | AX 全部 PASS、exit 0；probe 及后续文档修改后再次验签仍为 valid on disk / satisfies its Designated Requirement | xattr 仅 provenance，无 FinderInfo；本地 ad-hoc 制品，不代表公证或对外发布 |
| 用户常用 App / Space / 全屏 | ClassIn、微信、Chrome 的各状态 | 待真实兼容性验收 | 不擅自宣称全部兼容或全部不兼容 |
| 150ms / 输入 / 可访问性 | 性能采样、完整 F+J 输入回放、真实中文输入法、VoiceOver / 放大 | 待完整人工矩阵 | 物理键码规则通过不等于全部输入法实测通过 |

预览文件位于 `build/previews/2026-09-24/`：`01-applications`、`02-windows`、`03-empty`、`04-failure`、`05-narrow`、`06-overflow`、`07-loading`、`08-overflow-narrow`、`09-short-screen`（均为 `.png`）。它们使用合成数据；长名称与短屏渲染在目视检查反馈后修正并重新生成。

隔离 AX 验证实际覆盖：两个独立 AX 对象 / 唯一标题展开；驱动进程成为前台后把后台目标切至真实键盘焦点；修改标题后旧 token 仍选择原对象；同名 / 无标题整 App 回退；已入选的两个窗口随后最小化，预先取消的激活不恢复窗口，错误进程启动时间被拒绝，仅目标被恢复并获得焦点；关闭目标及使快照失效后明确失败、不改切另一窗；扫描时最小化且 `AXMain` 不可写的 App 保守回退。

首次失败及处理：旧开发路径的 SwiftShims 预编译缓存造成首次构建失败，`swift package clean` 后重新构建通过；初版 AX probe 同进程自查询得到 0 窗口，改为父 fixture / 子 driver 的真实跨进程验证后通过，未把最初失败跳过；打包目录被同步工具附加 FinderInfo 导致首次签名失败，构建脚本改为临时目录组装签名、无资源属性复制并再次严格验签，打包完成时通过且该包 AX probe 通过。后续复查发现 Documents 文件提供程序再次添加 FinderInfo，延后验签失败；最终使用可配置输出目录生成 `~/Applications/AppSwitcher-0.2.0.app`，在该包重跑 AX probe 和延后严格验签均通过。原 `build/` 包的签名不能因一次通过而视为长期有效。

TKT-009 的实现与上述本地验证完成；剩余第三方 App / 系统状态、完整权限 / 输入 / 可访问性及性能矩阵由 TKT-008 跟踪。以上路径保留为 0.2.0 构建验证的历史记录，后续实际安装路径、制品身份、SHA-256、旧包备份与回退以 REL-001 为权威，测试完成不等于对外发布。

## TKT-010：App 激活但没有可见窗口

预期：App 入口请求目标 App 的正常窗口呈现，系统 / App 选择应恢复或创建的窗口；测试夹具在正常、最小化、最后窗口关闭、隐藏四种状态均需观察真实窗口结果。生产路径不把 PID 正确当作可见窗口已经验证，不承诺所有 App 都响应 reopen 创建窗口；具体窗口选择仍用 AX 对象。

| 阶段 / 证据 | 实际结果 | 能证明 / 不能证明 |
| --- | --- | --- |
| 用户反馈与本机路径观察 | 用户报告按 S 无法唤起 Spotify。集成负责人确认覆盖层 S 映射 Spotify，按 S 后面板收起、usage 有 Spotify 激活记录，后续读取窗口数量为 0 | 选择路径确实触发；用户反馈时窗口究竟最小化或最后一窗已关闭尚未确认，不能声称完整复现其原始状态 |
| 修复前隔离红证据 | 系统适配协作者运行 `/tmp/appswitcher-app-activation-probe/probe` 两次均 exit 1：正常状态 success / visible=1；最小化、最后窗口关闭均 success / 前台 PID 正确，但 visible=0 | 证明生产 `activate` + PID 核验漏掉正常窗口呈现；临时夹具路径只是当次证据，不是仓库永久测试入口 |
| 最小修复与同夹具绿色证据 | 加入 `NSWorkspace.openApplication` 的生产 Provider 后，系统适配协作者使用原独立 `.app` fixture 直接调用新 Provider，正常 / 最小化 / 最后窗口关闭三场景均通过 | 与原红证据使用同一夹具；API 语义见 DESIGN-001，正式回归及 Spotify 现场仍需下列证据 |
| 新 Provider 规则回归 | 集成负责人执行 `swift run CoreTests`，exit 0，60 项全部通过 | 规则层通过，不代替窗口呈现的跨进程 / 现场验证 |
| Debug 构建 | `swift build`，exit 0，最终无编译警告 | 当前修复代码可构建 |
| 修复后 TEST-014 | Debug `--verify-app-activation` 四场景 visible / minimized / closed / hidden 全部 PASS，reopen 回调累计 1 / 2 / 3 / 4，始终同一 fixture PID；最小化场景另一窗口仍最小化 | 正式跨进程验证实际窗口呈现；不宣称多实例、替换返回或 reopen 在途取消已实测 |
| 原有具体窗口回归 | Debug `--verify-window-switching` 全部 PASS、exit 0，含预先取消、旧启动身份、目标恢复和过期 token 等 | window target 回归通过；取消 / 身份用例覆盖共用前置检查，不当成 App reopen 进行中取消的测试 |
| 身份与取消守卫审阅 | 同路径多实例拒绝、回调 PID / 启动时间匹配、取消 / 迟到回调不继续激活 | 本轮为代码审查；多实例 / 替换返回未实际注入，reopen 在途取消未做端到端实测 |
| 0.2.1 Release 构建 | `APPSWITCHER_OUTPUT="$HOME/Applications/AppSwitcher-0.2.1.app" ./scripts/build_app.sh` | exit 0，ad-hoc 签名与严格验签通过；仅本地制品，不是对外发布 |
| 0.2.1 Release 回归 | 打包后 `--verify-app-activation` 四场景 4/4 PASS；`--verify-window-switching` 全部 PASS，两者均 exit 0 | 与 Debug 的覆盖范围一致；多实例 / 替换返回 / reopen 在途取消仍非实际注入证据 |
| 0.2.1 本机安装 | 已替换安装到 `~/Applications/AppSwitcher.app`，原 PID 63063 退出；0.2.0 备份位于 `~/Library/Application Support/AppSwitcher/backups/AppSwitcher-0.2.0-20260924.app`，usage 保留 | 当前制品及运行记录以 REL-001 为权威 |
| 0.2.1 本机 Spotify 回归 | CUA 定位面板超时 / 快捷键注入受限；观察到 Spotify 可见窗口仍为 0，但未确认新版 S 选择已执行。已请用户在新版重试，尚无回复 | 现场验收待确认；该次观察既不能证明新版修复成功，也不能证明新版选择后仍失败；不推断其他 App / Space / 全屏兼容率 |

这次缺口属于 AC-05 的 App 呈现语义，不据此推翻原有精确窗口 token 策略。TKT-010 实现及上述受控 Debug / Release 验证已完成；Spotify 新版现场验收和其余第三方 / 系统矩阵继续由 TKT-008 跟踪。不能把合成 App 四状态通过称为 Spotify 已验证，也不能把共用前置取消检查称为 reopen 在途取消已验证。

## TKT-011：自适应面板与重复标签精简

范围为 **low** 的局部 UI 变更：根据活动显示器扩大面板、键帽及内容，去掉应用模式的重复「应用」副标题和空预留行，保留窗口真实标题、必要回退说明及无障碍语义。激活、候选、排序和权限代码不在修改范围；验证采用构建、合成多尺寸视觉与独立代码审阅，不重复运行未改动的原生焦点探针，也不据视觉结果新增第三方 App 兼容结论。

| 证据 | 当前结果 | 边界 |
| --- | --- | --- |
| 最终 Debug 构建与生成 | `swift build`、`--render-preview build/previews/0.2.2` 均 exit 0、无编译警告，生成 13 张预览 | 合成数据，不读取用户窗口 |
| 全部合成视觉检查 | 集成负责人已目视全部 13 张：应用面板 1324.8×705.2 pt；760 pt 窄宽窗口模式和 38 键；1324.8×520 pt 短屏；1920×1040 pt 屏对应 1766.4×852.8 pt 面板；2560×1080 pt 超宽屏对应 2355.2×885.6 pt 面板；另含笔记本、空 / 失败 / 加载等状态 | 图标 / 名称 / 键标清晰；短屏局部滚动且 footer 固定；重复「应用」已去掉，窗口标题 / 回退说明保留 |
| 独立审阅与修正复核 | 审阅发现窄短屏 + 窗口模式 + 38 键 + 两行名称 / 标题时图标可能与右上键标重叠；小于 70 pt 宽键帽改为独立水平区域，并新增 `13-windows-narrow-short`（760×430 pt） | 修正后重新检查 05 / 08 / 13，图标与键标分开、无重叠；13 的长标题省略而选中详情完整。审阅已完成，不将合成视觉视作真实键盘交互复验 |
| Release 构建 / 验签 | 最终 0.2.2 Release 打包 exit 0、无编译警告，ad-hoc 严格验签通过 | 本地制品，构建命令与制品身份以 REL-001 为权威 |
| 本机安装 / 启动 | 0.2.1 → 0.2.2 替换到 `~/Applications/AppSwitcher.app`，单一新 PID 75949，备用热键注册 true；usage 保留 | 旧版备份为 `~/Library/Application Support/AppSwitcher/backups/AppSwitcher-0.2.1-20260924.app`；启动证据不等于真实面板自动键盘验收 |

预览位于 `build/previews/0.2.2/`：`01-applications`、`02-windows`、`03-empty`、`04-failure`、`05-narrow`、`06-overflow`、`07-loading`、`08-overflow-narrow`、`09-short-screen`、`10-laptop`、`11-large-screen`、`12-ultrawide`、`13-windows-narrow-short`（均为 `.png`）。尺寸为逻辑 pt。

TKT-011 实现与 TEST-015 的上述本地视觉验证完成。本轮未做真实用户面板的自动键盘复验；完整 VoiceOver / 输入法 / 真实多屏交互与原有 Spotify 现场待验仍由 TKT-008 跟踪，未因本次布局修改宣称通过。

## TKT-006：自定义唤出快捷键（0.3.0）

风险为 **medium**，2026-09-24 完成实现与受影响本地验证。自动测试使用临时配置和真实隔离注册，不生成键盘事件、不读取第三方窗口内容。设置录制仅处理本窗口，不记录用户逐键输入。

| TEST-009 范围 | 实际结果与限制 |
| --- | --- |
| 规则与配置 | `swift run CoreTests` 75 项全通过；新增15项覆盖默认值、修饰键/键码校验、缺失、损坏、重建存储读回、非法保存保留旧文件。未现场制造真实配置损坏 |
| 排他冲突及事务 | Debug / Release `--verify-shortcuts` exit 0；真实跨进程排他冲突拒绝、注入持久化失败保留旧注册并释放新注册、同组合提交保存、成功替换释放旧键通过。注入的是持久化回调失败，不是制造用户磁盘故障 |
| 暂停与恢复 | Carbon实际暂停释放、恢复冲突失败、冲突释放后恢复、stop和子进程结束后释放通过；录制只捕获本窗、Esc/失焦/关闭恢复经独立代码审阅，尚未逐项人工操作验证 |
| 系统与第三方边界 | 本机 `CopySymbolicHotKeys` 确认默认 ⌃⌥Space 是已启用系统组合，启动拒绝注册。旧非排他 `options=0` 加新排他注册仍可成功，probe以NOTE记录；不承诺检测全部第三方监听或局部快捷键 |
| 设置真实流程 | CUA只读观察到用户正在录制，随后窗口显示已保存⌘E、F→J关闭、保存成功；文件 keyCode14 / modifiers8 / sequenceEnabledfalse一致。用户选择予以保留 |
| 重启与F→J | 最终进程重启后配置逐字节不变，启动日志组合注册true且F→J未启动。实际按新组合唤出、开关后的完整手势时序/回放仍待现场验证 |
| 设置视觉与入口 | 默认、录制、冲突、草稿4种合成预览均生成并目视通过；真实设置窗可访问且保存反馈可读。菜单/面板齿轮连接经编译和审阅；尚未逐入口执行完整操作，恢复默认、Tab焦点、VoiceOver/输入法仍属人工矩阵 |
| 独立复核 | 修复恢复失败后菜单误报、停用前排队F→J触发、权限不足仍显示全部生效。损坏配置提示保留至明确保存；无已注册组合时取消录制不清除启动错误 |
| 构建及安装 | 最终Debug无警告构建、Release打包、严格验签通过；0.3.0安装运行，PID82431，SHA及备份见REL-001；重启后CUA定位超时，不记作重启后界面或真实按键通过 |

TKT-006 的实现与上述本地验证完成，未执行的人工场景由 TKT-008 继续跟踪，不将TEST-009整体写成全矩阵通过。最终框架检查86个Markdown、0错误0警告；`git diff --check`通过。

本轮不改变 App reopen、AX token、窗口能力门禁或排序，不新增 Spotify、跨 Space 或第三方兼容结论。

## TKT-012：键帽图标放大（0.3.1）

2026-09-25，风险low，影响AC-10 / TEST-015。图标随键帽显著放大，预留文字与键标空间，并保留高分辨率图像表示。本轮不改候选、热键、排序、激活或配置，不新增模拟布局公式的单元测试，不重复原生聚焦/注册测试。

Debug构建无警告；16种合成布局已渲染，root检查常规/笔记本/超宽/大屏/缺图标及空/失败/38键/加载，独立协作者检查窗口、窄屏、短屏、38键长窗口标题等7场景，未见图标、键标、名称与窗口说明相互遮挡。09/13/14的底部裁切属于键盘滚动视口预期。原13场景之外增加1040×520pt长标题38窗、2560×1440pt可用大屏应用、缺失图标回退。

预览A/B位于 `build/previews/0.3.1` 与 `build/previews/0.3.1-sharp`。首次放大后ImageRenderer输出的系统图标偏软；Mail原图逻辑尺寸32pt，但表示包含最高2048px。将副本长边设256pt后同尺寸预览细节明显改善，生产与预览复用此准备函数。不能据此声称所有第三方原图资源都高清。

Release打包、最终制品预览与安装结果见REL-001。真实面板与用户输入、VoiceOver等现场验收边界仍独立保留，不把合成视觉写成真实按键验收。

## TKT-013：微信辅助进程导致应用切换被拒绝（0.3.2）

2026-09-25，风险 medium，影响 AC-05 / AC-07 / TEST-014。用户报告选择微信后面板重新出现。临时诊断日志连续 11 次记录同一个目标应用入口，返回「这个应用有多个运行实例，无法确认要恢复哪一个。请直接选择目标窗口。」；失败时前台仍为 AppSwitcher，触发已有失败反馈逻辑。

现场只读进程枚举确认：微信主进程 PID 72924、bundle ID `com.tencent.xinWeChat`、regular、可执行文件 `WeChat`；辅助进程 PID 73161、无 bundle ID、prohibited、可执行文件 `wxplayer`。两者的 bundle URL 都是 `/Applications/WeChat.app`。旧代码只按 bundle URL 计数，将辅助进程误算为第二个主实例，并在真正发出重开或激活请求前拒绝。

回归计划：在临时合成 `.app` 内增加独立可执行文件的辅助进程，明确验证它出现在真实 NSWorkspace 清单中且共用 bundle 路径，再执行原四状态测试；另外启动同 bundle、同可执行文件的第二个实例，验证真正有歧义时仍拒绝且不发送重开。保留 PID、启动身份与实际窗口结果断言；只读审阅不能替代这些新增执行证据。

实际执行结果：

| 验证 | 结果 |
| --- | --- |
| 修复前 Debug 红证据 | 同 bundle / 不同 executable / prohibited 的真实辅助进程前置成立；原四状态全部返回原多实例错误，reopenCallbacks=0，驱动仍在前台，exit 1 |
| 修复后 Debug 回归 | `swift build` 与 `.build/debug/AppSwitcherApp --verify-app-activation` exit 0，5/5 PASS；四状态成功呈现原进程窗口，同 exe 第二实例拒绝且目标 reopen 不增、驱动前台不变 |
| 原有规则 | `.build/debug/CoreTests` 75/75 PASS；Core 源码未变 |
| 最终 Release | `APPSWITCHER_OUTPUT="$HOME/Applications/AppSwitcher-0.3.2.app" ./scripts/build_app.sh` 无警告构建、ad-hoc 严格验签通过；该制品 `--verify-app-activation` 5/5 PASS、exit 0，fixture PID 98419 / driver 98424 |
| 独立只读复核 | 已知不同 exe 才排除、未知身份保守、同 exe 多实例保护及回调 PID / launchDate 约束均保留；未知 executableURL 未做系统故障注入 |
| 真实微信鼠标选择 | 最终安装包 PID 98688，CUA 实际点击当前面板的「4，微信，应用入口」；操作后只读系统状态确认微信原 PID 72924 为前台、存在 1 个正常尺寸屏幕内窗口且位于最前面，面板未重新出现；wxplayer PID 73161 仍在。不读取会话内容或窗口标题 |

保留中间失败：合成 helper 的 bundle ID 由系统继承主应用，最初要求 nil 的额外夹具前置 exit 2；改为验证实际共同身份，不按 bundle ID 排除 helper。第二个同 exe 进程已登记但 launchDate=nil，移除不属于计数规则的冗余夹具前置，仍严格验证 distinct PID / same bundle / same exe / regular / alive。一次修复后 closed 场景受到真实 Codex 获取前台干扰，未当作通过；最终完整 Debug 与 Release 重跑所有业务断言均通过。

新增 `--show-switcher` 仅供新启动实例打开正常面板，复用菜单入口；同时提供 `--show-settings` 时设置优先。现场验证通过该入口打开面板后真实点击微信，未据此宣称系统全局 ⌘E 注入已由自动化验证。首次启动后面板已不在前台，CUA 定位超时；重启新版后面板可访问，后续点击完成。隐藏后的面板 AX 定位超时不作为成功依据，微信前台与实际可见窗口读回才是证据。

TKT-013 本轮已验证的误拦截缺陷完成；不把 WorkBuddy、跨 Space / 全屏或所有第三方应用写为已修复。
