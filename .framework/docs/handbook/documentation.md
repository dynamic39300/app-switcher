---
owner_role: documentation-owner
status: accepted
last_reviewed: 2026-09-20
next_review_due: 2026-12-20
---

# 文档目录与单一事实来源

## 业务项目的权威位置

| 内容 | 推荐位置 | 维护方式 |
| --- | --- | --- |
| 总目标、owner、工具与档位 | `PROJECT.md` | 项目启动和重大变化更新 |
| 业务词汇 | `CONTEXT.md` | 首次出现或语义变化时更新，只定义词汇 |
| 当前架构与选型 | `docs/project/architecture.md` | 实现变化时同步当前态 |
| 命令 | 实际脚本/包配置；`docs/project/commands.md` 提供入口 | 文档链接实际命令来源，执行核验 |
| 功能全链路 | `docs/features/<id-slug>/` | 按 PR 与版本更新 |
| 决策历史 | `docs/adr/NNNN-slug.md` | 历史决定不抹除，替代时互链 |
| 服务操作 | `docs/runbooks/` | 通过演练保持可用 |
| 通用规范 | `.framework/docs/` | 固定快照，按版本升级 |
| 项目差异 | `docs/project/overrides.md` | 说明规则、原因、责任与期限 |

## 功能目录建议

```text
docs/features/FEAT-001-notifications/
├── prd.md
├── spec.md
├── design.md                  # UI、技术设计可合一，小项目按需拆
├── tasks.md                   # 工作索引；外部看板为主时只保链接
├── test-plan.md
├── traceability.md
└── release.md
```

MAY 按功能实际需要增加契约、威胁模型、eval、截图或研究。小变更使用单份 `change.md`。文件夹名称稳定，标题可变；不要每次产品改名都移动全部历史链接。

## 元数据和写法

框架 `docs/handbook/`、`docs/standards/`、`docs/research/` 的规范/研究正文 MUST 含 `owner_role`、`status`、`last_reviewed`、`next_review_due`。索引 README 不必加。日期格式为 `YYYY-MM-DD`。这些字段用于人工责任和到期提醒，不表示签名批准。

项目材料使用模板内的 `id`、`status`、`owner` 与上游引用。`accepted` 前解决影响交付的 TBD；保留真正未知项时给调查人、期限与阻塞影响。草稿和模板允许占位符，项目命令占位状态不得当成已运行。

Markdown 以结论、流程、条件和证据为主；图表承担结构说明，正文定义语义。使用仓库相对链接；引用上游用直达原文的 URL，重要仓库文件优先 commit 固定链接。代码块中的示例路径不是已经存在的资产。

## 防漂移规则

MUST 在同一交付变更中同步行为、权限、契约、相关 spec 及发布所需测试；实现前先更新受影响的行为基线。非关键补充文档可以链接到有责任与期限的跟进任务，紧急事件按既有处置与例外流程记录。API 定义优先由机器可读契约生成文档；生成物标明源文件与重建命令。文档不能把无法执行的命令写成真实入口。

归档材料保留 ID、原因、替代文档和历史链接；当前索引只指向现行版本。聊天记录用于工作交接，稳定结论沉淀到权威材料，避免将全部聊天塞入 Agent 上下文。

## 自动检查边界

`check_framework.py` 检查内部 Markdown 文件路径、要求的元数据、日期有效性、版本一致性及已生成项目的快照哈希；逾期作为警告，可用 `--strict-review-dates` 升为失败。全仓文档发现跳过普通业务软链接且不跟随，快照和项目模板仍拒绝软链接。它不检查外部网址可用性、所有 Markdown 扩展语法、页内锚点或业务内容正确性。源仓库的项目模板含生成后才存在的路径，须经生成项目后的检查验证；持续测试包含该步骤。未配置业务测试时，只能报告文档检查通过。
