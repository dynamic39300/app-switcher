# app-switcher

本项目采用 AI Native 框架 **0.1.0**，档位 **product**，生成日期 **2026-09-20**。

先完成 [项目配置](PROJECT.md)，再阅读 [项目文档索引](docs/README.md)。共享规范与模板在 [.framework](.framework/README.md)；产品边界、真实架构、命令和证据由本项目维护。

## 启动顺序

1. 填写项目目标、负责人、范围、风险和权威工作平台。
2. 完成 [架构与选型](docs/project/architecture.md)，创建需要的代码目录与真实工具配置。
3. 填写并验证 [命令入口](docs/project/commands.md)，接入业务质量检查。
4. 从 [材料模板](.framework/templates/artifacts/README.md) 开始第一条 [交付链路](.framework/docs/handbook/lifecycle.md)。

已有可执行文档检查：

```sh
python3 .framework/scripts/check_framework.py --root .
```

此检查覆盖文档与快照完整性，不运行业务测试。生成时没有业务代码、云资源或发布配置。

项目规则见 [overrides](docs/project/overrides.md)，云环境见 [CLOUD.md](CLOUD.md)，Agent 入口见 [AGENTS.md](AGENTS.md)。
