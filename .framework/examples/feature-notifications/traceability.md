---
id: TRACE-001
status: draft
owner: "教学角色：交付负责人"
upstream: [PRD-001, SPEC-001]
---

# TRACE-001：计划追溯关系

**教学/模拟计划矩阵；全部尚未实现、尚未验证。**上游：[PRD-001](prd.md)、[SPEC-001](spec.md)；设计：[DESIGN-001](design.md)；任务：[TASKS-001](tasks.md)；测试：[QA-001](test-plan.md)；发布：[REL-001](release.md)。

| PRD | Spec/AC | 设计责任 | 实施 Ticket | 计划 TEST | 实际证据 | 发布 |
| --- | --- | --- | --- | --- | --- | --- |
| PRD-001 | SPEC-001/AC-01 | 本人读取与 UI 初始状态 | TKT-001、TKT-003 | TEST-001 | 待执行；无实现/PR | REL-001 / planned |
| PRD-001 | SPEC-001/AC-02 | 偏好写入事务与成功反馈 | TKT-001、TKT-003 | TEST-002 | 待执行；无实现/PR | REL-001 / planned |
| PRD-001 | SPEC-001/AC-03 | 退订与发送锁排序、界面说明 | TKT-002、TKT-003 | TEST-003 | 待执行；无实现/PR | REL-001 / planned |
| PRD-001 | SPEC-001/AC-04 | 幂等、版本冲突、旧响应处理 | TKT-001、TKT-003 | TEST-004、TEST-005 | 待执行；无实现/PR | REL-001 / planned |
| PRD-001 | SPEC-001/AC-05 | 会话归属、操作查询与 CSRF | TKT-001、TKT-004 | TEST-006 | 待执行；无实现/PR | REL-001 / planned |
| PRD-001 | SPEC-001/AC-06 | 编辑取消、停止等待和结果核实 | TKT-003 | TEST-007 | 待执行；无实现/PR | REL-001 / planned |
| PRD-001 | SPEC-001/AC-07 | 错误分类与恢复交互 | TKT-003 | TEST-008 | 待执行；无实现/PR | REL-001 / planned |
| PRD-001 | SPEC-001/AC-08 | 语义控件、焦点与响应式 | TKT-003 | TEST-009 | 待执行；无实现/PR | REL-001 / planned |
| PRD-001 | SPEC-001/AC-09 | 唯一投递、门禁与 unknown 对账 | TKT-002、TKT-004 | TEST-003、TEST-010 | 待执行；无实现/PR | REL-001 / planned |
| PRD-001 | SPEC-001/AC-10 | 性能预算、脱敏观测与期限 | TKT-004 | TEST-011、TEST-012 | 待执行；无实现/PR | REL-001 / planned |

TKT-005 对所有 AC 执行集成与独立验收；TKT-006 将通过门槛的真实版本关联到发布与观察。两者目前同样 backlog，不表示上表已验收。

## 变更与验收证据

当前矩阵只说明每条 AC 有计划任务及计划用例。采用时补实现版本、真实 PR/运行记录、验收结论和发布制品；不能通过把“待执行”批量替换成“通过”制造证据。行为改变先修订对应 Spec/设计，再更新受影响 Ticket 和 TEST。
