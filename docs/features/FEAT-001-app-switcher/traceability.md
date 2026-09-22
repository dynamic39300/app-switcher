---
id: TRACE-001
status: draft
owner: "AppSwitcher 项目 owner（待填姓名）"
upstream: [SPEC-001]
---

# TRACE-001：追溯矩阵

上游：[SPEC-001](spec.md)、[DESIGN-001](design.md)、[TASKS-001](tasks.md)、[QA-001](test-plan.md)。稳定 ID 链：`PRD-001 → SPEC-001/AC-xx → TKT-00x → TEST-0xx`。

## AC 到设计 / Ticket / 测试

| AC | 设计位置 | Ticket | 测试 |
| --- | --- | --- | --- |
| AC-01 唤出 | `OverlayController`/`OverlayPanel`/`GlobalHotKey` | TKT-004、TKT-005 | TEST-001 |
| AC-02 候选过滤 | `RunningAppsProvider` | TKT-003 | TEST-002 |
| AC-03 分配确定性 | `KeyAssigner` | TKT-002 | TEST-003 |
| AC-04 冲突/就近/溢出 | `KeyAssigner` | TKT-002 | TEST-004 |
| AC-05 切换/跨桌面 | `AppActivator` | TKT-001、TKT-005 | TEST-005 |
| AC-06 取消三路径 | `OverlayController` | TKT-005 | TEST-006 |
| AC-07 集合变化重分配 | `OverlayController`+`RunningAppsProvider` | TKT-003、TKT-005 | TEST-007 |
| AC-08 权限引导 | `AccessibilityGate` | TKT-001、TKT-006 | TEST-008 |
| AC-09 热键配置/冲突 | `GlobalHotKey`+`SettingsView` | TKT-006 | TEST-009 |
| AC-10 显示/可访问性/无屏幕录制 | `OverlayView`+整体 | TKT-004、TKT-007 | TEST-010 |

## 依赖 / 并行 / 归属

- 契约冻结：`AppCandidate`/`Key`/`KeyAssigner`（TKT-002）先定，供 TKT-003/004 并行。
- 风险前置：TKT-001 spike 结论回填 SPEC-001（AC-05、AC-08）与 DESIGN-001，结论未回填前不进入 TKT-005 依赖实现。

## 状态

| 项 | 状态 |
| --- | --- |
| SPEC-001 | draft（行为基线；AC-02 已按 spike 校准） |
| TKT-001~005、TKT-007 | done |
| TKT-006 | in-progress（热键配置 UI 遗留） |
| TKT-008 | in-progress（待 owner 端到端验收） |
| TEST-001 至 TEST-010 | 单测部分（AC-02/03/04）已覆盖；端到端人工用例待验收 |
| 发布记录 | REL-001 状态 ready |

规格接受、任务完成与版本发布是不同状态；本矩阵不充当任何「已实现/已验证」的证明。
