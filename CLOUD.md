# app-switcher 云环境与部署

当前状态：FEAT-002 本地商业服务已建立，生产部署与外部身份尚未配置/验收。Claude 的指令文件为 [CLAUDE.md](CLAUDE.md)。

| 环境 | 用途/负责人 | 部署入口 | 观测入口 | 秘密引用 |
| --- | --- | --- | --- | --- |
| local | Codex 隔离开发/验收 | [web README](web/README.md)，127.0.0.1:8000 | /healthz、/readyz；开发模拟明确标识 | web/.runtime 被忽略，不发送其内容 |
| preview/staging | 适用时建立 | 待配置 | 待配置 | 使用组织秘密管理系统 |
| production | 上线前指定 owner | 待配置 | 待配置 | 不填写秘密值 |

上线前按 [运维规范](.framework/docs/standards/operations.md) 完成发布、迁移、健康检查、回退/向前修复、备份恢复和告警责任。运行步骤留在 [runbooks](docs/runbooks/README.md)，本文件只提供入口；涉及外部系统的执行遵循已确定的项目授权。

商业部署与 Mac 正式分发入口：[运行手册](docs/runbooks/commercial-release.md)、[实施验收](docs/features/FEAT-002-commercialization/verification.md)。仓库 deploy/ 是待注入真实域名/账号的配置模板，不代表已部署。
