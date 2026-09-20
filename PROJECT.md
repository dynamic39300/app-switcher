# app-switcher 项目配置

状态：owner 填写中；框架版本：0.1.0；采用档位：product。

## 产品边界

- 最终负责人：待填写姓名。
- 目标用户与核心问题：macOS 重度键盘用户（先服务 owner 本人，后续开放），在大量 App / 多桌面 / 分屏间高频切换 App 时希望手不离键盘、有确定性键位。
- 成功标准与验证期限：唤出一次 + 按一键即切到目标 App；覆盖层显示延迟 ≤ 150ms；字母键位确定可形成肌肉记忆。首版自测验证。
- 本期范围 / 明确不做：见 [FEAT-001 PRD](docs/features/FEAT-001-app-switcher/prd.md)（V1 为 App 级切换 + 自动字母分配 + 键盘形状覆盖层；不做窗口级/手动固定/Hold/切 Space）。
- 核心领域词汇：[CONTEXT.md](CONTEXT.md)。

## 约束与责任

- 主要风险等级及理由：整体 low；跨桌面激活（AC-05）与权限引导（AC-08）为 medium（影响核心价值与信任，无外部副作用），按 [low/medium/high 定义](.framework/docs/standards/testing.md)。
- 数据敏感级别、地域与保留需求：仅本地存储 app 身份（bundle id/名称）与激活次数/时间戳；不采集窗口标题、屏幕内容，不联网。无地域合规约束（单机）。
- 技术 / 设计 / 验收 / 发布负责人：待指定；单人可兼任，需记录自审限制。
- 工期、维护资源、成本和依赖：单人项目；V1 估算见 [TASKS-001](docs/features/FEAT-001-app-switcher/tasks.md)，不构成承诺。
- 既有授权与外部动作边界：仅本地实现与隔离测试；无对外发布、联网、修改外部凭据授权，见 [项目规则](docs/project/overrides.md)。

## 权威信息源

| 内容 | 权威位置 |
| --- | --- |
| 产品目标与当前配置 | 本文件 |
| 行为规格与功能记录 | [功能目录](docs/features/README.md) |
| Ticket 与排期 | [TASKS-001](docs/features/FEAT-001-app-switcher/tasks.md)（暂以仓库内文件为权威，接入看板后迁移） |
| 当前架构与技术版本 | [架构](docs/project/architecture.md) + 实际工具配置 |
| 命令 | [命令入口](docs/project/commands.md) + 实际脚本 |
| 通用规范 | [.framework](.framework/README.md) |
| 规范偏离与例外 | [项目规则](docs/project/overrides.md) |

## 采用与升级记录

| 日期 | 版本 | 决策/验证/限制 |
| --- | --- | --- |
| 2026-09-20 | 0.1.0 | 骨架生成；完成 FEAT-001 调研/PRD/spec/设计/tickets 文档，业务初始化与验证待完成 |
