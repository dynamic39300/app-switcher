# AppSwitcher 商业服务

状态：本地商业闭环实现；真实商户收款、SMTP 送达、生产基础设施和普通用户正式下载尚待外部账号与发布验证。此 README 不表示已经可公开收款。HTTP 合同见 `docs/features/FEAT-002-commercialization/contract.md`，报价接口为 `GET /api/v1/orders/quote?planId=monthly`。

## 环境与运行

从仓库根执行；Python 3.12.14、uv 0.12.5。运行依赖和所有传递版本固定在 `web/uv.lock`，默认冻结安装：

```sh
uv python install 3.12
uv sync --directory web --frozen
uv run --directory web python manage.py migrate
uv run --directory web python manage.py init_development
uv run --directory web python manage.py runserver 127.0.0.1:8000 --noreload
```

开发邮件只写 `web/.runtime/mail/`，不会真实发信；账号邮箱可用 `smoke@example.test`。验证码、签名私钥、DB、测试授权 fixture 全部在 Git 忽略的 `.runtime/`，目录权限 700，秘密文件 600。不要复制其内容到工单、日志或仓库。签名公钥可从同目录的 `.public.pem` 导出原始 32-byte base64，配置到对应本地商业测试 App；生产必须使用单独的正式签名密钥。

仅需要本地测试付款时显式运行：

```sh
SIMULATED_PAYMENTS=1 uv run --directory web python manage.py runserver 127.0.0.1:8000 --noreload
```

模拟付款只在 `APPSWITCHER_ENV=development` 且显式开启时可用。生产开启模拟付款、开发邮件、缺少 secrets / HTTPS / PostgreSQL / SMTP /客服与主体身份时拒绝启动；未启用的真实支付渠道 API 与 UI 均关闭。没有正式已验证的 Release 登记时，下载入口诚实返回 `available:false`。

## 检查与工具

```sh
uv run --directory web python manage.py test commerce.tests
uv run --directory web ruff check .
uv run --directory web ruff format --check .
uv run --directory web python manage.py check
uv run --directory web python manage.py makemigrations --check --dry-run
uv run --directory web pip-audit --format json --output .runtime/dependency-audit.json
uv run --directory web python manage.py collectstatic --noinput
```

`test_concurrency` 的四项线程测试需要 PostgreSQL 行锁，SQLite 显示 skip，不能以此声称通过。为隔离测试注入 `DATABASE_URL` 和本地测试专用 `DATABASE_SSLMODE=disable`（`APPSWITCHER_ENV=development`）；测试用户必须能创建临时测试数据库。生产设置禁止关闭数据库 TLS，默认 `verify-full`，通过 `PGSSLROOTCERT` 指向供应商 CA。

跨 Swift 签名与真实 API 测试：

```sh
uv run --directory web python manage.py license_fixture .runtime/license-fixture.json
uv run --directory web python manage.py desktop_api_fixture .runtime/desktop-api-fixture.json
```

前者生成一次性测试密钥的公共签名资料；后者创建本地合成账号和 5 分钟有效、只能兑换一次的 code，fixture 必须作为秘密处理。运行 Swift 检查后删除第二个文件；这些命令在生产均拒绝执行。

新增 Python 使用 Ruff 格式与静态规则。未引入全项目 mypy：Django ORM 运行时模型通过迁移检查、API/安全负向测试、PostgreSQL 集成和消费者签名联测校验；需要新增复杂纯领域类型时再引入严格静态类型层。不能把此说明当作跳过运行检查的理由。

## 服务组成与数据

- `Account`：UUID、邮箱、一次试用起止；普通登录 OTP 不可用于 staff 后台登录。
- `ConsentRecord`：成功邮箱验证后保存账户、文档类型、版本、同意时间，账号/文档/版本唯一，不记录 IP；订单保存当次条款版本。创建订单必须带用户确认的 expectedAmount/expectedCurrency，只用于比较当前服务端价格，价格变化返回 409 要求重新确认，不能用客户端金额定价。
- `EmailChallenge`：10 分钟、最多 5 次校验、一次消耗；验证码只存带服务 secret 的 HMAC。邮箱和来源 IP 均限流；限流 key 只保存 HMAC，不持久化原始 IP。
- `DesktopAuthorization`：固定 `appswitcher://auth/callback`、S256 PKCE、5 分钟、明确浏览器确认，code 只保存 HMAC。桌面访问令牌 1 小时，刷新令牌 90 天并每次轮换；旧 refresh 重放撤销当前会话。数量不限，无硬件指纹。
- `Order` / `EntitlementGrant`：金额为分，服务端套餐定价；订单幂等键账号内唯一，渠道流水渠道内唯一。账户行锁串行化跨订单发放；一订单至多一 grant。报价与最终发放共享 `renewal_terms`，发放重新计算，不能信客户端日期。
- `Refund`：申请不立即撤权，后台有独立 `process_refund` 权限，渠道确认成功才撤销对应 grant；已消费时间不形成欠款，后续未使用权益向前连续排列并保留日历锚点。重试复用原退款单号，不创建第二笔退款。
- `SupportTicket` / `SupportMessage`：每账号隔离，后端按所属账号校验订单引用；客服追加回复，不修改客户历史。
- `Release`：正式 HTTPS URL、SHA256、版本和人工正式签名公证验证标记；管理操作有审计。此登记不会替代 root 发布脚本的实际签名公证验证。
- `AuditEvent`：记录必要动作、对象 ID、金额/渠道等，不记录验证码、令牌、私钥、付款人信息、窗口标题或键盘输入。

时间存 UTC aware datetime；JSON 返回 Unix 秒整数；月、季、年分别 1/3/12 个日历月，Asia/Shanghai 的锚点在月末夹取后保留。授权有效区间为 `[start,end)`。第一次成功发放时计费起算，延迟支付回调不吞掉用户时长；正在试用或已有未用权益时向后追加。

本地 JWS 固定 EdDSA / license-v1，签名含账号、会话、issuer、audience 与有效期；离线截止为连续已得权益到期与签发后 7 天的较早者。撤销/退款不能让完全离线的旧授权立即失效，窗口最多 7 天，此为明确产品边界。

## 支付协议依据与限制

适配器采用微信 API v3 **公钥模式**（固定公钥 ID 及可信商户后台导出的公钥），支付宝 V2 公钥 RSA2 模式。未实现平台证书自动下载或支付宝证书模式，不能混用配置。所有真实请求有 10 秒超时、禁止 HTTP 跳转；金额、订单、商户与应用需要匹配；服务器查单补发，浏览器支付返回页绝不直接开通。

官方协议核验于 2026-09-25：

- [微信 Native 下单](https://pay.wechatpay.cn/doc/v3/merchant/4012791877)：`POST /v3/pay/transactions/native`，金额整数分、商户订单号 UUID hex32；二维码本地绘制。
- [微信回调](https://pay.wechatpay.cn/doc/v3/merchant/4012791882)：原始 body RSA-SHA256 验签、公钥 ID 比对、时间戳 5 分钟窗口，再 AES-256-GCM 解密；同一业务事件幂等。
- [微信商户订单查询](https://pay.wechatpay.cn/doc/v3/merchant/4012791880)、[退款](https://pay.wechatpay.cn/doc/v3/merchant/4012791883)、[退款查询](https://pay.wechatpay.cn/doc/v3/merchant/4012791884)。所有响应也必须验签。
- [支付宝官方电脑网站支付接入](https://developer.alibaba.com/docs/doc.htm?articleId=105899&docType=1&source=search&treeId=270)：page.pay、trade.query、trade.refund、fastpay.refund.query；异步通知排除 sign/sign_type 后排序验签，JSON 响应按原始 response 子串验证，不能重排序列化后验签。

当前自动化支付测试使用本地新生成的 RSA 密钥、AES-GCM 密文、签名通知及模拟 HTTP 响应，证明协议处理、篡改拒绝与业务幂等；它们不能证明商户真实开通、沙盒连通或银行实结算。启用真实渠道前必须有小额下单、回调、主动查单、退款、对账的渠道验收记录。不得向真实收件人或商户发测试请求而冒称模拟。

## 生产部署、值守与恢复

生产必须设置 `APPSWITCHER_RUNTIME_DIR=/var/lib/appswitcher/runtime`，由普通服务用户可写；生产代码目录可以只读，所有运行数据从代码目录分离。配置名见 `.env.example`，该文件仅供说明，服务不自动读取 `.env`。通过部署 secret store 注入环境与只读密钥文件。生产 worker 使用普通系统用户，DB 业务角色只具备必要表 DML，迁移角色分开。反向代理终止 HTTPS、覆盖 `X-Forwarded-Proto` 并禁止外部直接连接应用端口时，才设 `TRUST_PROXY_HTTPS=1`。代理如位于 127.0.0.1，显式设 `TRUSTED_PROXY_IPS=127.0.0.1` 并由 Nginx `proxy_set_header X-Real-IP $remote_addr` 覆盖；仅配置中的直接代理地址可以提供单个有效 IP，否则该头被忽略。禁止直接信任客户端 X-Forwarded-For。代理限制 body 为 64 KiB，不记录请求体、query string、Authorization、Cookie；应用不开放跨域。后台路径需要 VPN/来源约束及运维身份保护，正式上线前补独立运营管理员与恢复流程。

```sh
uv sync --directory web --frozen --no-dev
uv run --directory web python manage.py migrate --noinput
uv run --directory web python manage.py collectstatic --noinput
uv run --directory web python manage.py check --deploy --fail-level WARNING
uv run --directory web gunicorn config.wsgi:application --bind 127.0.0.1:8000 --workers 2 --timeout 30 --access-logfile /dev/null
```

首次创建后台管理员用 `manage.py createsuperuser` 的交互终端，密码不要放命令行。普通客服只给工单查看/回复权限；订单、grant、审计不允许后台直接篡改；退款管理员另授 `commerce.process_refund`。拒绝退款前必须通过关联工单说明理由。

`GET /healthz` 是进程存活；`GET /readyz` 检查 DB 连接及生产签名 key。生产监控应观察 ready 失败、支付通知 4xx/5xx、超过几分钟的 pending 订单、processing 退款、邮件失败和工单积压，不采集敏感内容。实际告警平台与值守人仍需部署方接入。

运维调度器建议每分钟执行 `manage.py reconcile_payments`（每次最多 100 个支付 / 100 个退款），每日执行 `manage.py purge_expired_auth` 和 `manage.py clearsessions`。支付与退款都持久化 last_checked_at/next_check_at/sync_attempts，按到期排期取批次、先持久认领 5 分钟再请求渠道，失败仍向后排期，指数退避最多 6 小时；不会让头部 100 条长期 pending/失败订单饿死尾部，服务长时间停机后也不以 8 天年龄截断丢失订单。重试仅查单或用同一个商户退款 ID；不能因超时要求用户重复支付。补偿任务只处理已知订单，故障时保留 pending / processing 状态等待核验。

每天至少一次加密数据库备份，发布迁移前另做一次；使用外部 `PGSERVICE` / `PGPASSFILE`（600 权限）或秘密管理提供连接，命令行不要出现密码：

```sh
pg_dump --format=custom --no-owner --file /secure-backups/appswitcher.dump
# 在独立空恢复库执行；RESTORE_DATABASE 仅含数据库名，不含凭据。
pg_restore --exit-on-error --single-transaction --no-owner --dbname "$RESTORE_DATABASE" /secure-backups/appswitcher.dump
```

备份签名私钥与 `DJANGO_SECRET_KEY` 必须独立加密存储并控制访问。恢复后验证订单数量/金额汇总、grant 关系、试用时间、管理员登录，使用 `reconcile_payments` 与渠道核对备份时点之后的交易。恢复旧 DB 可能恢复已用 token 或旧权限，因此上线恢复流程须撤销全部旧网站/桌面会话并重新验证授权；不能只恢复 DB 就宣称业务一致。生产备份/恢复演练仍需真实部署环境完成。

回滚：先关闭真实支付入口、保留回调与查单；回退到兼容当前 schema 的上一服务制品；不要反向删除已写入的订单数据。不可兼容迁移需恢复演练与渠道对账后才能切换。当前 `0001_initial` 新建商业 schema，`0002` 增加协议同意与订单版本快照，`0003` 增加支付/退款补偿排期；没有旧生产数据迁移。

身份临时记录在过期 24 小时后清理；财务、退款与客服记录不由自动清理脚本删除，正式保留周期需按经营主体业务义务确定并在隐私政策定稿。核心本地窗口标题、快捷键内容从不上传本服务。

## 依赖来源与核验

[Django 官方下载页](https://www.djangoproject.com/download/) 核验 5.2.17 LTS，BSD；[cryptography 官方 changelog](https://github.com/pyca/cryptography/blob/main/CHANGELOG.rst) 核验 50.0.1，Apache/BSD；httpx BSD 用于有界外部 HTTP；psycopg LGPL 用于 PostgreSQL；Gunicorn MIT 用于 WSGI；WhiteNoise MIT 用于同域静态文件。Ruff MIT、pip-audit Apache 是开发检查工具。初次审计发现 cryptography 47 已知漏洞后已升级至 50.0.1，2026-09-25 重跑 `pip-audit` 无已知漏洞；完整版本与 hash 以锁文件为准，发版应重跑审计而不能永久依赖本次结果。
