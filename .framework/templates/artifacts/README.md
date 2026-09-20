# 交付材料模板

先按[生命周期](../../docs/handbook/lifecycle.md)选择需要的材料，再复制到业务项目的功能目录或权威位置；目录约定见[文档规范](../../docs/handbook/documentation.md)。模板中待填写、待验证、待执行的内容必须按项目补齐，不能直接视为已经完成。

## 按场景选择

| 场景 | 模板 | 何时需要 |
| --- | --- | --- |
| 新项目启动 | [项目章程](project-charter.md) | 确定目标、负责人、采用档位、授权与第一里程碑 |
| 问题仍待澄清 | [Brief](brief.md)、[研究](research.md) | 收集证据，区分事实与假设 |
| 新功能 | [PRD](prd.md)、[Spec](spec.md) | 先明确价值范围，再形成可验收的行为契约 |
| 实现方案 | [技术设计](technical-design.md)、[UI 设计](ui-design.md) | Spec 草案之后；技术与 UI 可并行，再回校 Spec |
| 关键取舍或跨团队提案 | [ADR](adr.md)、[RFC](rfc.md) | ADR 留存决策，RFC 用于达成决策前的讨论 |
| 安全边界改变 | [威胁模型](threat-model.md) | 身份、租户、敏感数据、外部动作等改变时 |
| 开始实施 | [Ticket](ticket.md)、[Agent 任务](agent-task.md) | Ticket 管理交付；Agent 任务界定一次委派范围 |
| 验证功能与风险 | [测试计划](test-plan.md)、[追溯矩阵](traceability.md) | 将每条 AC 对应到实现任务和验证方法 |
| 产品含模型能力 | [Eval 计划](eval-plan.md) | 模型、提示、检索、工具策略变更时；仅 AI 辅助编程不需要 |
| 准备发布或运行 | [发布记录](release.md)、[Runbook](runbook.md) | 明确制品、操作授权、健康标准和恢复路径 |
| 低风险小改动 | [轻量变更](lean-change.md) | 一个文件承载目标、影响与验证即可 |
| 暂时偏离适用 MUST | [例外](exception.md) | 必须有风险接受人、替代控制、期限与回补任务 |
| 发布/事故之后 | [复盘](retrospective.md) | 将实际效果、故障和流程改进带回项目与框架 |

不用为每个需求填写全部模板。已有明确预期的 bug 可直接用 Ticket；UI 与技术设计可合成 `design.md`；跨模块、高风险内容可以拆开以便评审。

## 共同填写规则

- 用项目的稳定 ID 替换模板 ID；`owner` 落到具体的人。`upstream` 填稳定 ID，正文提供相对链接或外部直接链接。
- 材料状态使用 `draft → in-review → accepted → superseded / archived`；Ticket 使用 `backlog → ready → in-progress → in-review → done`，阻塞使用 `blocked` 并记录原因；发布使用 `planned → ready → released → verified / rolled-back`。
- 材料 accepted 不表示已实现。Ticket done 需要对应 AC 的真实证据、版本、必要审阅和遗留项；发布 verified 还需要发布后的观察结果。
- 证据写环境、版本、命令/步骤、时间、结果、产物链接。未运行写“待执行”或“阻塞”，不填写虚构的成功日志、PR、截图或发布地址。
- 按[测试风险](../../docs/standards/testing.md)判断 `low / medium / high`，不以项目大小替代风险判断。适用 MUST 的例外走[例外模板](exception.md)，不适用条目写明理由。
- 复制后把模板中的相对规范链接调整为业务项目内的 `.framework/docs/` 或项目实际位置；待填写的代码路径用 code span 表示，不创建不存在的文件链接。

完整但未实施的教学链路见[通知订阅示例](../../examples/feature-notifications/README.md)。
