---
id: REL-001
status: planned
owner: "AppSwitcher 项目 owner（待填姓名）"
upstream: [SPEC-001]
---

# REL-001：App 切换器发布记录

上游：[TRACE-001](traceability.md)、[QA-001](test-plan.md)；规则：[运行规范](../../../.framework/docs/standards/operations.md)。

## 版本与范围

- 源 commit、制品不可变标识：待产生（TKT-007 打包后填）。
- 依赖/配置/数据迁移版本：V1 无网络、无服务端；本地 `usage.json` 无迁移。
- 对应 Tickets 与 AC：TKT-001 至 TKT-008；AC-01 至 AC-10。
- 用户可见变化：全新本地工具，无兼容影响。不包含：窗口级切换、手动固定、Hold、切 Space。

## 发布条件与授权

- 环境：本机（个人使用，ad-hoc 签名）。
- 操作人、授权范围：仅本人；无对外分发授权。
- 必要审阅/证据：QA-001 全部适用用例有真实结果；AC-05/AC-08 有 spike 结论支撑。
- 发布窗口/渐进批次/特性开关：不适用（单机）。

## 操作与恢复

- 发布：把 `.app` 放入 `/Applications` 并启动。
- 观察：切换成功率、覆盖层延迟、跨桌面回弹情况（个人自测）。
- 恢复：删除 `.app` 即移除；无数据/外部副作用。无回滚概念。

## 验收证据

| 阶段 | 版本/环境/操作者/时间 | 真实结果 | 证据/问题 |
| --- | --- | --- | --- |
| 候选验证 | 待执行 | 待执行 | 待产生 |
| 部署 | 待执行 | 待执行 | 待产生 |
| 上线后关键旅程与观察 | 待执行 | 待执行 | 待产生 |

状态链：`planned → ready → released → verified`。未上线不得填 released/verified。
