---
id: RES-20260920-REPOSITORY-PRACTICES
title: GitHub 仓库治理与规格驱动开发调研
owner_role: framework-maintainer
status: accepted
last_reviewed: 2026-09-20
next_review_due: 2026-10-20
---

# GitHub 仓库治理与规格驱动开发调研

本框架应复用成熟项目的**可追溯决策、行为规格、模块责任、可执行校验和反馈闭环**，根据项目风险决定文档深度。目录规模、工具品牌或生成文档数量不能作为成熟度的替代指标。

本文的 `accepted` 表示采纳为初始研究基线；不表示其他项目已按此通过验收，也不表示每项建议都已自动执行。

## 研究范围与证据边界

研究对象覆盖两类规格驱动工具（Spec Kit、OpenSpec）、两个大型产品/平台仓库（VS Code、Supabase）、两类长期技术治理机制（Kubernetes KEP、Rust RFC）。选择它们是为了比较不同约束下的做法，未按星标数排名，也不声称已穷尽行业最佳实践。

以下“已核验事实”来自维护方公开的仓库文件或官方文档；“本框架建议”是结合本项目目标作出的设计判断。公开文档能证明维护方描述的机制，不能单独证明每个 PR 均执行了机制或该机制改善了生产效率。本次未对上游 CI、审批权限、发布过程作运行审计。

核验日期为 **2026-09-20**。先读取官方网页，再通过 `git ls-remote <repo> HEAD` 获取提交 SHA，并重新读取固定 SHA 下的文件。这里的 SHA 是本次远端返回的快照，未据此推断发布日期。GitHub REST API 本次受限流影响，没有把未取得的 API 信息补写为事实。

| 仓库 | 本次核验的固定 SHA | 关注的问题 |
| --- | --- | --- |
| `github/spec-kit` | `d4229c071c7ea3885b43e8a7739847300f618f13` | 项目原则与特性规格如何进入实施 |
| `Fission-AI/OpenSpec` | `bae58cf61479986431bb798acbe5a688a591c18c` | 已有系统如何持续维护规格与变更 |
| `microsoft/vscode` | `832cf23c5887351668f61c8648eb9c2ec6ee7d23` | 贡献入口、问题分流与产品完成标准 |
| `kubernetes/enhancements` | `0469acb1d9444635135faf5a6c6711486b1a9040` | 长生命周期设计与生产就绪 |
| `supabase/supabase` | `2a75ff7ae6e0059b34f2c242febd2916d17fc5de` | 多应用、共享组件与 Agent 导航 |
| `rust-lang/rfcs` | `51783df9a76c355de7ceebeae101cba47f8ca463` | 重大决策、替代方案与实施跟踪 |

VS Code 的 Development Process 来自独立 Wiki，**不属于表中代码仓库 SHA 的固定内容**；GitHub CODEOWNERS 文档同样为可变网页。两处均在正文明确标注，后续复查须重新核验。

## 已核验事实与本框架建议

### 1. Spec Kit：稳定原则与按特性交付

**已核验事实。** README 将项目原则与每个特性的规格、计划、任务、实现、收敛验证连接起来；特性开发、缺陷修复、想法评估是独立入口，后两者为按需扩展。当前文档包含 `implement → converge` 的反复验证过程，不能把早期教程中的命令列表当作永久接口。[Spec Kit README，固定快照](https://github.com/github/spec-kit/blob/d4229c071c7ea3885b43e8a7739847300f618f13/README.md)

其 `AGENTS.md` 给出具体集成开发入口、相关目录、验证步骤；集成安装清单记录文件哈希，卸载时默认跳过用户已改动的文件。这些是该工具的实现约定，不是所有 Agent 的通用协议。[Spec Kit AGENTS.md，固定快照](https://github.com/github/spec-kit/blob/d4229c071c7ea3885b43e8a7739847300f618f13/AGENTS.md)

**本框架建议。** 稳定原则集中维护，特性内容按唯一 ID 串联。新功能走完整证据链；低风险修复可以从问题与回归验证进入。复制模板时记录来源版本与文件基线，升级前识别下游修改。

**适用边界。** 采纳产物关系，不把某一版斜杠命令、Python 运行时或 `.specify/` 目录设为所有项目的前置依赖。收敛报告必须附测试证据，不能单凭 Agent 宣布完成。

### 2. OpenSpec：现行规格与变更增量分离

**已核验事实。** `docs/concepts.md` 区分描述当前行为的 `specs/` 与提出修改的 `changes/`；变更含 proposal、规格增量、design、tasks，归档时将增量合入现行规格。它把规格定位为可观察行为及场景，技术方案另存；工作流允许迭代，文档依赖可以形成图，并建议按风险使用不同深度。[OpenSpec Concepts，固定快照](https://github.com/Fission-AI/OpenSpec/blob/bae58cf61479986431bb798acbe5a688a591c18c/docs/concepts.md)

**本框架建议。** 为每项能力保留一个明确的现行规格，另存本次变更记录。PRD 回答用户价值和范围，Spec 回答行为和验收，技术设计回答实现约束。实施发现新事实时更新关联产物，避免相同需求在多份文档中各自演变。

**适用边界。** “允许迭代”不意味着高风险发布没有验收条件；“变更目录分离”也不能消除两个变更修改同一行为的语义冲突。接入 OpenSpec 时，应选择它或本框架的对应路径作为权威位置，并提供映射，避免同时维护两份现行规格。

### 3. VS Code：贡献入口与产品完成标准

**已核验事实。** `CONTRIBUTING.md` 指导贡献者先定位正确仓库、搜索重复问题、提交单一问题，并给出环境、复现步骤、预期与实际差异等字段；同时说明问题自动分流机制。[VS Code CONTRIBUTING.md，固定快照](https://github.com/microsoft/vscode/blob/832cf23c5887351668f61c8648eb9c2ec6ee7d23/CONTRIBUTING.md)

官方 Wiki 的 Development Process 将路线图、迭代计划、问题、测试计划和发布说明相连。其 DoD 包括键盘操作、读屏、不同主题支持；还描述发布前集中测试和预发布反馈。**该 Wiki 为可变链接，页面显示的最后编辑时间为 2021-09-27，因此这里只采纳其已公开的流程设计，不据此断言当前团队仍完全遵循相同节奏。**[VS Code Development Process，2026-09-20 核验](https://github.com/microsoft/vscode/wiki/Development-Process)

**本框架建议。** 将可访问性、错误/空白/加载状态、说明文档和可观测性纳入功能完成标准；缺陷模板必须能支持复现；发布前提供用户或业务代表验证的入口。

**适用边界。** 不统一规定月度迭代、固定冻结周或桌面软件的发布渠道。Web、移动端、内部工具可以采用不同发布周期，但必须保留验收与回滚证据。

### 4. Kubernetes KEP：设计有状态，发布有证据

**已核验事实。** KEP 模板包含目标/非目标、风险、测试计划、升级/降级、生产就绪、监控、回滚与替代方案。模板明确：文档已合并不等于完成或获准实施；`provisional` 仍是工作文档，转为 `implementable` 有审批要求。[KEP README 模板，固定快照](https://github.com/kubernetes/enhancements/blob/0469acb1d9444635135faf5a6c6711486b1a9040/keps/NNNN-kep-template/README.md)

`kep.yaml` 分别记录状态、成熟阶段、作者、评审者、批准者、目标里程碑和替代关系，展示了设计状态与发布成熟度可以独立表达。[KEP 元数据模板，固定快照](https://github.com/kubernetes/enhancements/blob/0469acb1d9444635135faf5a6c6711486b1a9040/keps/NNNN-kep-template/kep.yaml)

**本框架建议。** Spec 状态、Ticket 状态和部署状态分别记录；不能因文档 `accepted` 或代码已合并就标注功能已上线。涉及数据迁移、权限、安全、公共 API、跨项目影响时，补齐生产就绪与回滚设计。

**适用边界。** 小团队无需复制 SIG 组织、完整 KEP 状态集或全部发布签署步骤。依据风险选择检查项；不适用项说明原因，避免为了填表虚构指标。

### 5. Supabase：共享资产、路径责任和简明 Agent 导航

**已核验事实。** `DEVELOPERS.md` 描述以 `apps/` 容纳网站、控制台和文档，以 `packages/` 共享 UI、配置、类型配置等，并提供本地启动与按应用运行入口。[Supabase DEVELOPERS.md，固定快照](https://github.com/supabase/supabase/blob/2a75ff7ae6e0059b34f2c242febd2916d17fc5de/DEVELOPERS.md)

根 `AGENTS.md` 提供目录用途表、常用命令、生成文件边界、UI 复用规则及子目录 Agent 文件入口。`.github/CODEOWNERS` 将 UI、文档、控制台和部分敏感路径指向不同团队。[Supabase AGENTS.md，固定快照](https://github.com/supabase/supabase/blob/2a75ff7ae6e0059b34f2c242febd2916d17fc5de/AGENTS.md)、[Supabase CODEOWNERS，固定快照](https://github.com/supabase/supabase/blob/2a75ff7ae6e0059b34f2c242febd2916d17fc5de/.github/CODEOWNERS)

贡献指南要求问题上下文、关联 Issue，并为新增功能设置先讨论设计的入口。[Supabase CONTRIBUTING.md，固定快照](https://github.com/supabase/supabase/blob/2a75ff7ae6e0059b34f2c242febd2916d17fc5de/CONTRIBUTING.md)

**本框架建议。** 根 Agent 文件承担导航、运行和约束入口，具体领域规则就近维护；UI、契约、工具配置等复用资产必须有责任人。实际使用的命令以项目脚本与 CI 为准，复制初始化模板后应逐条验证。

**适用边界。** 多应用 monorepo 是一种组织选择，不意味着所有新项目都需要 pnpm、Turborepo、Next.js 或相同 UI 框架。单服务可以使用较小结构；跨仓库复用应通过有版本的包、契约或模板发布。

### 6. Rust RFC：重大方案保留取舍，实施另行跟踪

**已核验事实。** Rust 将重大变更与一般修复/文档改动区分；RFC 获采纳不表示已有实施优先级或负责人，实施有独立跟踪 Issue。[Rust RFC 流程，固定快照](https://github.com/rust-lang/rfcs/blob/51783df9a76c355de7ceebeae101cba47f8ca463/README.md)

模板要求说明用户动机、使用示例、设计细节、缺点、替代方案、既有实践和未决问题，并区分未来可能性与当前采纳理由。[Rust RFC 模板，固定快照](https://github.com/rust-lang/rfcs/blob/51783df9a76c355de7ceebeae101cba47f8ca463/0000-template.md)

**本框架建议。** 架构决策记录至少包含约束、候选方案、取舍、后果与复查触发条件；Ticket 单独承载执行责任、依赖、估算和验收条件。记录“暂不做”也能帮助未来项目避免重复争论。

**适用边界。** 不照搬语言生态的长评议周期。团队需要快速决策时，可由明确的责任人完成简化评审，保留理由与异议即可。

### 7. GitHub CODEOWNERS：文件与强制规则是两层配置

**已核验事实。** GitHub 支持 `.github/`、根目录或 `docs/` 中的 `CODEOWNERS`，按此顺序采用首个匹配文件；评审使用 PR 基础分支的配置，最后匹配规则优先。仅添加文件不会自动强制所有者批准，还需要相应的保护/评审设置；团队或用户也须具备有效权限。**此处为可变官方文档，没有固定 SHA。**[GitHub About code owners，2026-09-20 核验](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)

**本框架建议。** 初始化时区分“模板文件已复制”和“仓库规则已启用”；将真实团队映射、基础分支规则和一次评审演练列入落地清单。不能把模板里的占位所有者当作实际治理已经生效。

## 初始采纳矩阵

以下为本框架的设计选择，依据上节对应来源；并非声称所有上游仓库共享同一套标准。

| 做法 | 初始决定 | 建议落地位置/行为 | 调整边界 |
| --- | --- | --- | --- |
| 稳定项目原则与特性产物分开 | 采纳 | 根入口链接原则；特性使用统一 ID | 避免多份“宪章”互相冲突 |
| 当前行为与变更历史分开 | 采纳 | 现行 Spec 加变更记录，交付后回写 | 一种能力只有一个权威规格 |
| PRD、Spec、技术设计、Ticket 分工 | 采纳 | 同一需求的价值、行为、方案和执行互链 | 小改动可合并承载，信息不可遗漏 |
| 风险决定文档与评审深度 | 采纳 | 常规路径与高风险扩展检查 | 不按固定文档数量衡量完成度 |
| Agent 根入口加领域规则 | 采纳 | 导航、命令、禁止手改的生成物、局部入口 | 加载范围仍以所用 Agent 工具规则为准 |
| 完成标准包含 UI/测试/发布证据 | 采纳 | Ticket 和 PR 关联验收证据 | UI 项目适用可访问性与状态覆盖 |
| CODEOWNERS 与自动校验 | 采纳 | 文件责任加平台规则与有效 CI | 复制文件后仍须验证执行效果 |
| 共享组件、配置与契约版本化 | 采纳 | 按实际需求建共享包或跨仓库发布 | 不强制 monorepo 或某一技术栈 |
| 固定月度节奏、完整 KEP/RFC 组织流程 | 不设为默认 | 仅在团队约束要求时启用 | 不能以大型项目规模推导本项目需求 |
| 同时安装全部规格工具 | 不设为默认 | 先用可读文档和脚本验证流程 | 接入工具须有路径映射与退出方式 |

## 更新触发条件与复查方法

以下为本框架的维护要求，目的是让研究改变可执行实践；不是只收藏更多链接。

| 触发条件 | 应执行的动作 | 完成证据 |
| --- | --- | --- |
| 到达 `next_review_due` | 对比上述 SHA 与上游相关文件的新版本；动态网页重新读取 | 更新研究记录、采纳/暂缓理由和下次日期 |
| Agent 指令加载规则或规格工具产物结构变化 | 在小型示例中验证兼容性，再决定适配 | 实际命令、产物差异、迁移或回退步骤 |
| 两个采用项目出现同类规范偏差 | 判断共性缺口，修订通用规则；个别需求保留为项目覆盖 | 关联问题、修订提案、受影响项目清单 |
| 出现规格与实现不一致、遗漏测试或发布事故 | 找到缺失的检查点，改进模板或自动校验 | 问题复盘、回归用例、对应规范变更 |
| 共享契约、UI 资产或技术基线发生不兼容变化 | 发布新版本并给出兼容期和迁移说明 | 版本差异、消费项目验证结果 |
| 上游来源删除、迁移或停止维护 | 保留历史 SHA，寻找替代证据并重新评估依赖 | 新来源与替换/保留决定 |

每次研究更新按“新证据 → 适用性判断 → 小范围试用 → 规范/模板变更 → 采用项目验证 → 发布版本”推进。上游有新功能仅触发评估；只有在本项目约束下能解释收益、代价及迁移路径时才推广。

本次研究的永久链接用于保存原始依据；后续更新另记新 SHA，避免把旧结论静默改成貌似一直正确的历史。引用以摘要和链接为主；若未来直接复制上游模板或代码，应同时核对对应版本许可证并保留所需声明。
