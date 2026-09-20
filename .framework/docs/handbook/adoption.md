---
owner_role: project-lead
status: accepted
last_reviewed: 2026-09-20
next_review_due: 2026-12-20
---

# 项目采用与初始化

## 选择档位

档位决定默认文档深度，风险决定单个变更的验证强度。小项目同样可能处理高风险支付或个人数据。

| 档位 | 适合 | 最小交付材料 | 扩展材料 |
| --- | --- | --- | --- |
| lean | 单人验证、内部小工具、库原型 | 项目配置、一份轻量变更、验收与实际证据 | 发生重大选型时补 ADR |
| product | 长期产品、多人协作 | PRD、spec、设计、tickets、测试计划、发布记录 | UI、数据、运行手册、风险登记 |
| platform | 多系统、多团队、共享能力 | product 全部 + 跨项目契约、兼容和迁移计划、责任边界 | SLO、威胁模型、容量与灾备演练 |

通过 `--profile` 写入采用意图；生成器提供相同基础材料，**不会自动证明项目满足该档位，也不会安装技术栈**。

## 生成新项目

在本框架根目录运行，Python 3.10+ 即可：

生成器适配 macOS、Linux、Windows 的原子无覆盖重命名；目前仅在 macOS 本地验证，Linux/macOS CI 已配置但尚未远程执行，其他平台不保证支持。

```sh
python3 scripts/init_project.py --name my-product --profile product --dest ../my-product --dry-run
python3 scripts/init_project.py --name my-product --profile product --dest ../my-product
python3 ../my-product/.framework/scripts/check_framework.py --root ../my-product
```

目标目录必须尚不存在、父目录已存在；生成器拒绝覆盖已有项目、目录软链接以及框架目录内的目标，不会初始化 Git 或安装包。名称只允许小写字母、数字和连字符，且首字符为字母。失败时保留原目录状态，暂存目录会清理。

生成结果：

```text
my-product/
├── README.md / PROJECT.md / CONTEXT.md
├── AGENTS.md / CLAUDE.md / CLOUD.md
├── .framework/                  # 采用版本的规范、模板、示例、清单与检查器
├── .github/                     # 文档 CI、PR 模板、Copilot 适配
├── docs/
│   ├── README.md
│   ├── project/                 # 命令、项目规则、架构与选型
│   ├── features/                # 每个功能一组材料
│   ├── adr/                     # 真实决策
│   └── runbooks/                # 真实运行手册
└── .editorconfig / .gitignore
```

选型后再创建实际代码目录：单体可用 `src/`、`tests/`；确有独立部署单元时用 `apps/`、`services/`；共享代码用 `packages/`。不要为了匹配目录树先创造空服务。参考 [技术配置](../../profiles/README.md)。

## 完成初始化的清单

1. 在 `PROJECT.md` 填写产品目标、owner、档位、风险、采用版本和管理平台；指定业务事实来源。
2. 在 `CONTEXT.md` 写真实业务词汇；在 `docs/project/architecture.md` 记录候选、约束、版本与选择理由。
3. 将 `docs/project/commands.md` 中的待配置状态替换为从实际工具验证过的安装、开发、构建、测试和发布命令。
4. 将权限边界、质量门槛、负责人和例外写入 `docs/project/overrides.md`，有合适账号后配置 CODEOWNERS 与分支保护。
5. 从 `.framework/templates/artifacts/` 复制第一份 `lean-change.md` 或 PRD/spec，写实际验收条件。
6. 完成 [Agent 验收](agents.md)：检查目标工具实际加载的指令、允许命令、验证结果与失败报告。
7. 运行文档检查、业务检查；记录哪些仍未配置。在代表性非生产环境完成发布、回退及适用的数据恢复演练；首次生产发布按门槛执行并观察。

启动工作可以在一次工作时段内完成，但工期以约束和人员为准，不把模板中的示例时间当承诺。

## 手动复制与现有项目接入

最稳妥的手动方式：先生成临时新项目，再逐项复制根 Agent 文件、项目文档和 `.framework/`，检查每项 diff。保留现有 README、CI、命令和业务目录，按需合并入口与文档检查任务。`templates/project/` 含 `{{PROJECT_NAME}}`、`{{PROFILE}}`、`{{FRAMEWORK_VERSION}}` 等占位符，直接复制时必须替换，且单独复制它不会带上规范快照。

已有项目采用顺序：先补索引和命令 → 为下一项真实变更补规格与证据 → 接入有价值的质量门槛 → 再清理历史文档。不要为了采用框架一次性改完所有旧代码或重写历史规格。`scripts/init_project.py` 刻意不支持原地覆盖；现有项目的合并由可评审变更完成。

## 首次试点建议

选择一个边界清晰、能在短周期内发布的功能。记录采用花费、规格返工、遗漏缺陷和真实交付周期。复盘后只上收跨项目可复用的部分；项目特有规则留在项目配置。
