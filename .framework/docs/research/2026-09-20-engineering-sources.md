---
owner_role: framework-maintainer
status: accepted
last_reviewed: 2026-09-20
next_review_due: 2026-12-20
---

# 工程标准的一手来源核验与采纳记录

核验日期：2026-09-20。范围：UI 与无障碍、应用/AI 安全、契约、测试、Agent 评估、可观测性与可靠性。仅使用标准组织、官方项目仓库和作者所在组织发布的一手资料；未用搜索摘要、社区转载或 GitHub star 数量证明结论。

本文记录依据与适用边界，不将外部资料整篇复制为本框架标准。`accepted` 表示这些来源及采纳决定进入当前方法论基线，不代表任何业务项目已通过相关认证或验证。

## 核验清单

| 一手来源 | 已核验的事实/主张 | 本框架采纳 | 边界与后续关注 |
| --- | --- | --- | --- |
| [W3C WCAG 2.2 固定版本](https://www.w3.org/TR/2024/REC-WCAG22-20241212/)；[官方源码仓库](https://github.com/w3c/wcag) | 2024-12-12 的 Recommendation；含可测试成功准则、键盘、焦点、错误、状态消息与符合性要求 | [UI 规范](../standards/ui-ux.md)将 WCAG 2.2 AA 作为建议目标，要求明确范围与人工验证 | 不是所有项目已符合 AA；自动扫描不覆盖全部成功准则，Web 规范也不能直接代替原生平台要求 |
| [OWASP ASVS 官方仓库](https://github.com/OWASP/ASVS) | 核验时 README 标明稳定版本 5.0.0（2025 年 5 月）；条目引用推荐带版本；主分支持续变化 | [安全规范](../standards/security-privacy.md)建议按风险映射具体要求并保留版本号 | 本框架没有复制 ASVS 全量要求或宣称 ASVS 认证；项目应自行选择适用等级与验证范围 |
| [OWASP LLM01:2025 Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/) | 区分直接/间接注入，建议最小权限、独立输出校验、内容隔离及高风险动作控制 | [AI 工程](../standards/ai-engineering.md)将工具权限、目标校验与审计放在可信执行层 | 不宣称 system prompt、RAG、过滤或一次红队测试能完全防止注入；授权范围由项目治理确定 |
| [OpenAPI 3.2.1 固定版本](https://spec.openapis.org/oas/v3.2.1.html)；[官方仓库](https://github.com/OAI/OpenAPI-Specification) | 核验时 latest 指向 3.2.1，文档日期 2026-09-10；其职责是描述 HTTP API | [架构规范](../standards/architecture.md)采用机器可读契约、格式版本和业务版本分离、工具链兼容验证 | 没有要求项目立即使用 3.2.1；消费者和生成器的支持情况需要项目验证，schema 不证明业务兼容 |
| [Google Testing Blog：Just Say No to More End-to-End Tests](https://testing.googleblog.com/2015/04/just-say-no-to-more-end-to-end-tests.html) | 2015 年官方文章讨论 E2E 的反馈与维护成本，给出的比例是经验起点，并说明各团队不同 | [测试规范](../standards/testing.md)选择能覆盖风险的较小测试层级，保留关键 E2E | 属于历史经验文，不作为“最新测试架构”；未强制 70/20/10、测试金字塔形状或全仓覆盖率阈值 |
| [Anthropic：Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) | 2026-01-09 官方工程文章区分 task、trial、grader、outcome，讨论代码/模型/人工评分与重复尝试 | [AI 工程](../standards/ai-engineering.md)检查真实终态、固定评分规则并观察非确定性 | 这是厂商实践，不是通用认证；本框架不绑定 Anthropic 产品，阈值和样本量由任务风险决定 |
| [OpenTelemetry：Signals](https://opentelemetry.io/docs/concepts/signals/) | 官方文档定义 trace、metrics、logs 等信号及采集/处理/导出职责 | [运维规范](../standards/operations.md)建议统一可观测上下文，按故障定位需求收集信号 | 不把安装 SDK 等同于具备 SLO、有效告警或完整观测；实验能力与稳定级别在选型时复核 |
| [Google SRE：Service Level Objectives](https://sre.google/sre-book/service-level-objectives/) | 区分 SLI、SLO、SLA，强调选择与用户体验有关的少量指标 | [运维规范](../standards/operations.md)要求定义指标分母、时间窗口、目标与响应动作 | 不直接照搬 Google 的组织规模、服务等级或值守流程；小团队可用最小 runbook 落地 |

## 本框架自行作出的综合决定

以下属于框架设计判断，不声称由上述来源逐条要求：

1. **风险与规模分离。** `low/medium/high` 评估一次变更的风险；lean/product/platform 评估采用复杂度。小项目也可能需要高风险验证。
2. **能力先于技术。** 先写用户任务、数据约束和运行目标，再比较方案；模块化单体只作为小团队可调整的初始候选。
3. **质量证据贴近实际结果。** 代码单元测试、契约测试、真实集成、UI 走查、AI eval、恢复演练各自证明不同风险，不相互替代。
4. **规范有适用条件。** 没有产品模型不需要模型评估，没有持久数据不需要数据库恢复；声明不适用需给出真实理由。
5. **强制要求可以有治理例外。** MUST 例外必须可追踪、有限期并有补偿；SHOULD 可记录理由后不采用。例外不能消除外部强制义务。
6. **不追逐最新版本。** 研究日期、所选版本、兼容证据与升级触发条件共同组成可更新基线。

## 复核方式

下次复核应重新打开官方来源，比较稳定版本、废弃能力、风险建议和项目真实故障，而不是只更新日期。将新证据与本框架条目对应，提出可审阅变更，并先在代表项目试用。重大事件、依赖停止维护、供应商行为变化或真实事故可提前触发复核，日常升级流程见[复用与升级](../handbook/reuse-and-upgrades.md)。

核验中 OWASP 项目官网首次读取失败，改用其官方 GitHub 仓库核验 ASVS 状态；没有将失败页面当成证据。除明确固定版本的规范外，动态文档在未来可能变化；本记录保存的是核验当日的结论。
