---
id: TRACE-001
status: in-review
owner: "AppSwitcher 项目 owner（待填姓名）"
upstream: [SPEC-001]
---

# TRACE-001：追溯矩阵

上游：[SPEC-001](spec.md)、[DESIGN-001](design.md)、[TASKS-001](tasks.md)、[QA-001](test-plan.md)。稳定 ID 链：`PRD-001 → SPEC-001/AC-xx → TKT-00x → TEST-0xx`。2026-09-24 行为变更依据 owner 对 [RES-002](multi-window-research-2026-09-24.md) 建议的接受与系统修改授权。

## AC 到设计 / Ticket / 测试

| AC | 当前设计责任 | 实施 / 验收 Ticket | 测试 |
| --- | --- | --- | --- |
| AC-01 默认 App 模式唤出 | `OverlayController` / `OverlayPanel` / 两种触发器与保存配置 | TKT-004、005、006、009 / 008 | TEST-001、009 |
| AC-02 每个普通进程一个入口 | `RunningAppsProvider` / `CandidateFactory` / PID 目标 | TKT-003、009 / 008 | TEST-002 |
| AC-03 确定映射与快照 | `AppRanker` / `KeyAssigner` / 会话 generation | TKT-002、009 | TEST-003、013 |
| AC-04 冲突 / 数字行 / 38 键 | `KeyAssigner` / `KeyNavigation` / `OverlayView` | TKT-002、009 | TEST-004 |
| AC-05 App 正常窗口呈现及激活 | `RunningAppsProvider` 的 reopen / 安装路径与可执行文件身份核对 / PID 激活路径 | TKT-001、005、009、010、013 / 008 | TEST-005、014 |
| AC-06 取消与焦点 | `OverlayController` / `OverlayPanel` | TKT-005、009 / 008 | TEST-006、013 |
| AC-07 集合变化与失效目标 | Provider / token 注册表 / Controller / reopen 身份核对与多实例保护 | TKT-003、005、009、010、013 / 008 | TEST-007、012、014 |
| AC-08 权限与回退 | `AccessibilityGate` / AX 能力探测 | TKT-001、006、009 / 008 | TEST-008 |
| AC-09 热键设置 / 录制 / 冲突 / 回滚 / 持久化 | 原生设置窗 / 配置协调与独立 JSON / `GlobalHotKey` 系统与排他冲突检查 / `SequenceHotKey` 暂停原因 | TKT-006 | TEST-009 |
| AC-10 视觉 / 屏幕适配 / 键盘 / 状态 / 无录屏 | `OverlayView` / `OverlayPanel` / 视觉 token / `KeyNavigation` | TKT-004、007、009、011 / 008 | TEST-010、015 |
| AC-11 按能力窗口展开 | `CandidateFactory` / AX 枚举与能力门禁 | TKT-009 / 008 | TEST-011 |
| AC-12 对象身份与精确聚焦 | token 注册表 / `AppActivator` / focused window 读回；与 App reopen 分流 | TKT-009、010 / 008 | TEST-012、014 |
| AC-13 超时与会话竞态 | AX 短超时 / Controller generation / 单次提交 | TKT-009 / 008 | TEST-013 |

## 状态与证据边界

| 项 | 状态 |
| --- | --- |
| PRD-001 / SPEC-001 | accepted：owner 已授权意图，本轮实现与测试独立验收 |
| DESIGN-001 / QA-001 | 本轮实现与本地证据已同步；完整环境验收仍按 QA / TKT-008 继续 |
| TKT-001 至 005、007 | 历史完成记录见 TASKS-001，不自动证明新契约通过 |
| TKT-006 | done（实现与本地验证）：0.3.0已安装运行；Core75、Debug/Release注册回滚、四场景视觉、严格验签通过，真实用户保存与重启注册已观察；人工余项与冲突检测边界见QA-001 |
| TKT-008 | in-progress：新版 Spotify 现场、其他真实 App / 权限 / Space / 全屏、性能与可访问性验收 |
| TKT-009 | done（实现与本地验证）：Debug 构建无警告，60 项测试、九张预览、跨进程隔离 AX、Release 打包 / 验签及同制品 AX probe 通过 |
| TKT-010 | done（实现与受控验证）：Debug / Release App 四状态与窗口 probe、CoreTests 60 项、构建及严格验签通过；0.2.1 已本机安装，Spotify 现场留 TKT-008 |
| TKT-012 | 图标随键帽放大及多分辨率图像准备，AC-10 / TEST-015；视觉与本机交付证据见QA-001 / REL-001 |
| TKT-011 | done（实现与本地视觉验证）：Debug / Release 无警告构建、13 张预览全部目视、独立审阅及窄键帽修正复核完成；严格验签通过，0.2.2 已本机安装并启动 |
| TKT-013 | done（已确认缺陷的修复与验证）：旧守卫 helper 共存四状态全失败且 reopen=0；修复后 Debug / Release 五场景全通过，含真实同 exe 多实例拒绝。CoreTests 75/75、独立只读复核、严格验签通过；0.3.2 已安装，实际点击微信后原进程前台、正常窗口可见且最前，helper 仍在且面板未重现。未知 executableURL 仅审阅，不代表 WorkBuddy 原始失败已解决；证据见 QA-001 / REL-001 |
| TEST-001 至 015 | 既有通过范围见 QA；TEST-014 已加入同 bundle 不同 exe helper 与真实同 exe 多实例系统回归；未知 executableURL / 替换返回 / reopen 在途取消仅守卫审阅，TEST-015 合成视觉与独立审阅通过，未做真实面板自动键盘复验；TEST-009 已有规则 / 注册 / 保存 / 重启证据，未执行人工项见 QA；完整第三方 / 系统人工矩阵未宣称通过 |
| 发布 | 以 REL-001 的实际制品和证据为准，本轮尚不宣称对外发布 |

共享模型和切换结果契约由集成负责人协调后，系统适配、UI 和文档按文件所有权并行；集成测试由负责人统一执行。规格接受、代码完成、人工验收和发布是独立状态。
