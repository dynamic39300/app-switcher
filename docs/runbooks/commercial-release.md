# AppSwitcher 商业服务与 Mac 发布运行手册

状态：2026-09-25 实施中。这里给出可评审的部署入口；本机执行证据见 [QA-002](../features/FEAT-002-commercialization/verification.md)。没有域名、云平台、商户和 Apple 身份就绪的证据，不能把以下部署步骤写成已执行。经营主体与值守负责人由实际运营身份落实，本任务中的代码/验证由 Codex 负责。

## 环境和账户

账户持有人可以先按[账号开通与接入交接](owner-account-setup.md)办理 Apple 会员、签名公证认证和微信/支付宝产品权限；本机已有一次性五阶段向导。办理记录不加载到生产环境，正式状态仍按以下部署与交易验收核实。

- 开发服务：`web/`，Django + Python 3.12，默认文件邮件/SQLite，不向真实收件人发信；模拟支付须显式开启，只在 development 可用。
- 生产服务：独立账号/数据库/密钥，真实经营域名 HTTPS、SMTP 发件、PostgreSQL TLS verify-full；环境变量及服务边界见 [web README](../../web/README.md) 与[示例配置](../../web/.env.example)。示例不自动载入，不含秘密。
- Mac：本机既有 0.3.2 继续可用；候选 0.4.0 与其隔离，Debug localhost 包不进入官网下载。
- 管理后台只开放给实际负责的运营人员，使用独立运维登录、来源访问约束；普通邮箱 OTP 登录不能登录 staff 后台。退款权限单独授予，工单人员不同时得到修改账号角色权限。

## 服务部署顺序

1. 准备固定发布目录 `/opt/appswitcher/releases/<source-id>/`，以 uv 0.12.5 执行冻结生产依赖安装；只读代码与 `/var/lib/appswitcher/runtime` 可写运行目录分开。源码和 uv.lock 同一版本部署，生成静态文件。
2. 使用迁移角色在维护窗口执行新 schema 迁移；业务运行角色只给必要 DML 权限。生产首次上线或迁移前备份；不能把开发 SQLite 带进生产。
3. 将当前配置注入 `/etc/appswitcher/commerce.env`（仅指定服务用户可读）或托管 secret store。私钥放受控只读文件，不写入源码/镜像；生产授权公钥固定进 Mac 签名包。`check --deploy --fail-level WARNING` 必须通过。
4. 依据 [systemd unit](../../deploy/appswitcher.service) 启动普通用户 Gunicorn；仅监听 loopback。配置[反向代理模板](../../deploy/nginx.conf.example)的真实域名和 TLS，`X-Real-IP` 必须由可信代理覆盖，显式声明 `TRUSTED_PROXY_IPS`；不信来自公网的伪造头。不应将带 SECRET 的环境文件发到聊天。
5. 验 `/healthz`、`/readyz`、静态资源、登录邮件实际送达、正确/错误验证码、网页与 App 回跳。健康响应只能说明部分服务可用，不能代替购买验收。
6. 配好真实渠道后，先验证固定测试账号的低额真实购买/查单/重复通知/退款/对账，再开放销售入口。记录订单 ID 和渠道状态，不记录付款密码、商户私钥或买家资料。任何渠道未获权限都保持禁用。
7. 启用每分钟[支付补偿定时器](../../deploy/appswitcher-reconcile.timer)和对应[任务](../../deploy/appswitcher-reconcile.service)。验证码/短期会话每日清理命令见 web README。
8. 发布观察期间检查关键 API 错误、邮件失败、长时间未确认订单和退款；关键路径通过后才扩大用户范围。首次公开前还需客服、经营信息、票据处理与适用备案材料，不凭模板声称这些已经具备。

Linux/systemd/nginx 配置当前仅完成静态设计；本机是 macOS，没有冒充实际 Linux 部署成功。GitHub Actions 新增 frozen 安装、PostgreSQL 17.11 并发与 Mac 测试流程；配置写入不等于远端 CI 已运行。

## Mac 正式分发

脚本 `scripts/build_app.sh` 支持 local / distribution。local 明示自签名或 ad-hoc，仅测试；distribution 缺 Developer ID 时立即失败，绝不回退成自签名正式包。正式服务源拒绝IANA示例域、测试域、非公网IP及不规范/编码主机、非法端口；该检查不查询DNS，也不证明域名归属或服务已部署。域名HTTPS与业务连通仍需实际验证。`VERSION` 是包版本源，URL scheme 为 appswitcher。

先在受控环境设置以下变量：

- `APPSWITCHER_SERVICE_URL`：自己的正式 HTTPS origin。
- `APPSWITCHER_LICENSE_PUBLIC_KEY`：服务端正式 Ed25519 公钥原始 32 字节的 base64；这是公开验证材料，私钥不能进 App。
- `APPSWITCHER_SIGN_IDENTITY`：钥匙串中实际存在的 `Developer ID Application: …`。
- `APPSWITCHER_NOTARY_PROFILE`：本人预先保存在 Keychain 的公证认证配置名，密码不放在命令行。
- 可选 `APPSWITCHER_RELEASE_DIR`：新输出目录；脚本拒绝覆盖已有发布记录。

执行 `./scripts/release_macos.sh`。脚本固定 commercial/release、arm64、Hardened Runtime 与安全时间戳；生成带 Applications 链接和安装说明的 UDZO DMG、签名、公证、附票据、Gatekeeper 检查；保留 Apple receipt/log、制品 SHA256 和源码摘要。构建前冻结版本/源码摘要，编译后核对源码及 Mach-O 架构，公证后只使用包内已签名的冻结记录生成 manifest。`preSigningExecutableSHA256` 是签名前的可执行文件摘要，最终下载完整性使用附票据后的 DMG SHA256。工具提交超时后 Apple 可能继续处理，须凭已记录 submission ID 查询，不重复盲目提交。

裸 `.app` 在私有临时目录完成构建和封装，避免本机 Documents/File Provider 给应用包异步增加 FinderInfo 而使验签失败。本地测试包也优先放非同步目录；“刚构建时验签通过”不能代替最终输出再次验签。正式输出保留 DMG 与证据，不把同步目录中的裸 App 作为官网下载品。

公证超时/失败时，以相同 Keychain profile 执行 `xcrun notarytool info <submission-id>` 和 `xcrun notarytool log <submission-id>`；只有 Accepted 且日志已检查后再对原 DMG staple/validate、执行 Gatekeeper 检查并生成 manifest。拒绝/待审制品绝不登记下载。正式步骤依据 [Apple 公证要求](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)、[自定义流程](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)和[包装分发](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)。

拿到最终 DMG 后，从实际 HTTPS 下载入口在独立 Mac 验首次下载、拖入 Applications、启动、辅助功能、登录、首次切换；再从前版升级并比较偏好。签名身份变化可能引起系统重新请求权限，必须实际验证说明，不能让用户关闭安全保护。验证失败时从官网撤下候选登记并保留已知可用包；配置目录不删除。验证记录通过后由管理员登记 Release 的版本、HTTPS 下载地址和 SHA256，勾选已验正式签名与公证；该勾选不是自动验收替代品。

检查更新首版采用 App 内检测新版、跳转可信官网的安装说明与下载；无静默执行远程安装器。升级前退出旧 App，替换应用包后重开，用户配置和 Keychain 凭证不放在包中。当前阶段没有证明真实普通用户升级已经通过。

## 故障与恢复

| 现象 | 诊断与止损 | 恢复与验收 |
| --- | --- | --- |
| 登录邮件不到 | 查看脱敏发送失败和 SMTP 状态，避免连续大量重发；已有有效离线许可仍可用 | 恢复邮件后用专用账号验证；日志不打印验证码 |
| 已付款未开通 | 根据账号/订单 ID 查订单和渠道，不让用户再付；查看补偿队列 | 原订单验签查单并幂等发放；核对一次权益与实际日期 |
| 退款长期处理中 | 使用原退款 ID 查渠道，不能另建重复退款 | 渠道确认后再调整权益；不覆盖已终态的并发退款结果 |
| 授权服务故障 | 检查ready、DB、签名配置，关新的购买入口以免继续欠交付 | 已签离线凭证按原期限继续；恢复后同步，不自行延长或清空客户设置 |
| 错误版本 | 下架 Release，停止新下载，保留错误制品摘要与日志 | 提供已知可用签名包，验证配置兼容；服务回滚仅到兼容schema版本 |
| 数据丢失 | 暂停新交易操作并保留通知证据，按备份/PITR恢复到隔离环境 | 撤销旧会话、渠道对账、补偿恢复点后交易；校验金额、订单、grant、退款一致再切回 |

生产建议使用有时间点恢复能力的托管 PostgreSQL，内部目标 RPO ≤5 分钟、RTO ≤1 小时，尚未在实际供应商验证，不作为公开 SLA。每日加密逻辑备份及每次迁移前备份是补充，不替代 PITR。恢复演练验证合成订单/退款/试用关系，不仅检查备份文件存在。没有事务日志的每日备份最多丢失一天新订单，无法仅凭渠道流水自动找回全部账号归属；此限制必须在选云服务时解决。

本地可重复演练：在隔离 PostgreSQL 测试角色下设置 `APPSWITCHER_ENV=test`、仅 loopback 的 `DATABASE_URL` 和 `DATABASE_SSLMODE=disable`，执行 `uv run --frozen --project web python scripts/verify_postgres_restore.py --pg-bin <本地PG工具目录>`。连接密码由受控环境提供，不粘贴到聊天。脚本新建两个随机命名数据库、迁移并生成合成账号/购买/续费/退款/工单/条款数据，执行 custom pg_dump 与单事务 pg_restore，核对全部表数据及序列后仅删除本次创建的数据库。产物保存在忽略目录 `build/restore-rehearsals/`。生产环境、远程地址、带连接查询参数的URL均拒绝，内部seed入口同样校验；清除 libpq 隐式连接覆盖项。此结果不代表生产备份、PITR、密钥备份或指定 RPO/RTO 已通过。

日志不保存请求体、Authorization/Cookie、查询串、窗口标题或按键；建议按服务故障需要设置有限保留与访问权限，正式保留政策随实际经营信息定稿。密钥备份另行加密保存并演练恢复；生产授权签名密钥轮换需要考虑旧 App 固定公钥，不应在事故中直接换 key 后认为所有旧版仍能验证。首发单一 key 的正常续期可保持公钥，受损时需发布新版并停止旧 key 签发。
