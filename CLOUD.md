# app-switcher 云环境与部署

当前状态：FEAT-002 本地商业服务已建立，生产部署与外部身份尚未配置/验收。Claude 的指令文件为 [CLAUDE.md](CLAUDE.md)。

| 环境 | 用途/负责人 | 部署入口 | 观测入口 | 秘密引用 |
| --- | --- | --- | --- | --- |
| local | Codex 隔离开发/验收 | [web README](web/README.md)，127.0.0.1:8000 | /healthz、/readyz；开发模拟明确标识 | web/.runtime 被忽略，不发送其内容 |
| preview/staging | 适用时建立 | 待配置 | 待配置 | 使用组织秘密管理系统 |
| production | 上线前指定 owner | 待配置 | 待配置 | 不填写秘密值 |

上线前按 [运维规范](.framework/docs/standards/operations.md) 完成发布、迁移、健康检查、回退/向前修复、备份恢复和告警责任。运行步骤留在 [runbooks](docs/runbooks/README.md)，本文件只提供入口；涉及外部系统的执行遵循已确定的项目授权。

商业部署与 Mac 正式分发入口：[运行手册](docs/runbooks/commercial-release.md)、[实施验收](docs/features/FEAT-002-commercialization/verification.md)。仓库 deploy/ 是待注入真实域名/账号的配置模板，不代表已部署。

## 2026-09-29 现有云资源线索

owner 反馈已有个人阿里云账号，提供的控制台截图显示北京地域轻量应用服务器 `Ubuntu-wzwq` 运行中，Ubuntu 24.04、2 vCPU、4 GiB 内存、50 GiB ESSD 云盘，已分配公网 IP，到期时间 2027-05-24 23:59:59。详细状态见[办理进度](docs/runbooks/owner-application-guide-2026-09-28.md)。

该资源目前仅作为待核验的部署候选：尚未确认现有用途、备案资源资格、账户/个体工商户主体适用性、架构/负载、数据库与备份安排；本轮未远程登录或部署。生产环境表继续保留“待配置”，不将控制台运行状态视为本项目服务已运行。优先核验已有资源，避免重复采购。
