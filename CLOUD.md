# app-switcher 云环境与部署

当前状态：尚未配置部署。Claude 的指令文件为 [CLAUDE.md](CLAUDE.md)。

| 环境 | 用途/负责人 | 部署入口 | 观测入口 | 秘密引用 |
| --- | --- | --- | --- | --- |
| local | 待配置 | [命令索引](docs/project/commands.md) | 待配置 | 仅说明环境变量名称 |
| preview/staging | 适用时建立 | 待配置 | 待配置 | 使用组织秘密管理系统 |
| production | 上线前指定 owner | 待配置 | 待配置 | 不填写秘密值 |

上线前按 [运维规范](.framework/docs/standards/operations.md) 完成发布、迁移、健康检查、回退/向前修复、备份恢复和告警责任。运行步骤留在 [runbooks](docs/runbooks/README.md)，本文件只提供入口；涉及外部系统的执行遵循已确定的项目授权。
