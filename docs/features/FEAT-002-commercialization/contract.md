---
id: CONTRACT-002
status: accepted
owner: "项目 owner 授权 Codex 实施"
---

# 商业闭环共享契约 v1

2026-09-25：用户授权自主决策与目标模式实施。此为实施基线，接受不等于实现或生产可用。root 负责整合，backend 负责 web/（不含 templates/static），frontend 负责 web/templates/ 与 web/static/，desktop 负责 Swift 商业模块和 AppController/main 集成，root 负责打包、规范与发布验证。现有未提交工作保留。

## 实施选择与参数

Django 5.2 LTS（安装时锁定当前安全补丁）+ Python 3.12，开发 SQLite，生产 PostgreSQL。Django 提供会话、CSRF、后台、迁移；cryptography 提供 Ed25519 和支付 RSA/AES-GCM。官网为 Django 静态模板 + 原生 CSS/JS，不加独立前端构建链。生产环境配置不足时拒绝启动/开放相关能力，开发邮件与模拟支付永不允许在生产启用。

人民币价：monthly=900 分/1 月；quarterly=2400 分/3 月；yearly=7800 分/12 月。同功能，账号不限设备与并发数。14×24h 试用、7×24h 本地签名授权，1/3/12 滚动日历月按北京时间锚点计算；试用余量与已排队权益保留，已过期从首次成功发放起算。完整边界见[商业规则](../../project/commercialization-rules-2026-09-25.md)。

## 通用 HTTP 契约

JSON camelCase。时间为 UTC Unix 秒的整数或 null；货币 amount 为整数分。错误统一非 2xx + `{"error":{"code":"stable_code","message":"用户可理解的中文"}}`。网页身份使用 Django HttpOnly 会话 cookie，所有变更需 CSRF（cookie csrftoken → X-CSRFToken），仅支付通知与客户端 bearer/授权兑换接口按各自认证豁免；读取不做有副作用动作。App 只使用 bearer，不使用网页 cookie。生产仅 HTTPS，开发允许 localhost/127.0.0.1。

公开页面路径：`/`、`/pricing/`、`/download/`、`/login/`、`/account/`、`/orders/`、`/support/`、`/privacy/`、`/terms/`、`/desktop/authorize/`，后端均可渲染 index.html，前端按 pathname 展示。首页 ensure_csrf_cookie。网站 API 不返回客户端密钥或商户秘密。

- GET `/api/v1/config` → `{productName,environment,plans:[{id,name,months,amount,currency}],payments:{wechat:boolean,alipay:boolean,simulated:boolean},download:{available:boolean,url:string|null,version:string|null,minimumOS:"15.0",architecture:"arm64"},supportEmail:string|null,termsVersion:"2026-09-25",privacyVersion:"2026-09-25"}`。支付 false 时 UI 不能装作可收款；未有正式制品 download.available=false。开发/测试状态清晰显示。
- POST `/api/v1/auth/request-code` `{email}` → `{ok:true}`；验证码真实 SMTP 发信，开发文件邮件隔离保存且不在 API 返回。统一回复避免账号枚举，限流、有效期与失败次数约束。
- POST `/api/v1/auth/verify-code` `{email,code,acceptedTerms:true,termsVersion,privacyVersion}` → me；创建或登录统一账号，消耗验证码、轮换网站会话；服务端核对当前条款/隐私版本并记录接受时间，不额外保存IP。POST `/api/v1/auth/logout` → `{ok:true}`，仅结束当前网页会话。
- GET `/api/v1/me` → `{account:{id,email},entitlement:{status:"eligible"|"trial"|"paid"|"expired",trialEndsAt:number|null,paidUntil:number|null,validUntil:number|null},license:string|null}`。license 是给 bearer 客户端签发的 JWS；网页可以为 null。
- POST `/api/v1/trial/start` → me；明确操作才起算，按账号唯一且事务化，已购买/已用过不能新开。
- GET `/api/v1/sessions` → `{sessions:[{id,label,createdAt,lastSeenAt,current:boolean}]}`。POST `/api/v1/sessions/{id}/revoke` → `{ok:true}`，只可撤销自己的桌面会话，不限制数量。

## 浏览器登录回 App

仅允许 `appswitcher://auth/callback`，不允许任意 redirect。App 生成 32+ 字节随机 verifier 和 state，S256 challenge。

1. POST `/api/v1/desktop/start` `{codeChallenge,state,deviceName}` → `{authorizeUrl,expiresIn:300}`。服务端创建一次请求，网页 URL 包含 request=<opaque ID>，浏览器登录完成后仍需确认授权。
2. GET `/api/v1/desktop/request?request=...`（网页会话认证）→ `{deviceName,expiresAt}`，不泄露 code 或 challenge。
3. POST `/api/v1/desktop/approve`（网页会话 + CSRF）`{request}` → `{callbackUrl}`，URL 只带短时一次性 code 和原 state。已批准不能重新分配其他账号，过期或重复清晰拒绝。
4. POST `/api/v1/desktop/exchange` `{code,codeVerifier}` → `{accessToken,refreshToken,expiresIn:3600,sessionId,account:{id,email}}`。code 仅成功兑换一次，失败次数有限，PKCE 常量时间比较。refreshToken 90 天且使用后轮换；令牌服务端只存 hash。
5. POST `/api/v1/desktop/refresh` `{refreshToken}` → 同 exchange 结构，旧 refresh 不可重用。POST `/api/v1/desktop/logout`（bearer）撤销本会话 → `{ok:true}`。

JWS：固定 header `{"alg":"EdDSA","typ":"JWT","kid":"license-v1"}`；UTF8 JSON 的原始 base64url header.payload 字节以 Ed25519 签名，第三段 64-byte 签名 base64url。payload `{iss:<服务根URL无末尾slash>,aud:"appswitcher",sub:<account UUID string>,sid:<sessionId>,iat:<秒>,nbf:<秒>,exp:<秒>,entitlementUntil:<秒>,status:"trial"|"paid"}`。exp=min(连续已获批权益截止,iat+604800)。无有效权益时 license=null。客户端使用固定发行者与随包固定的 32-byte Ed25519 公钥（base64），校验算法/keyID/issuer/audience/account/session/times/signature，不接受响应自带的新公钥。时间回拨不延长授权；退出清理钥匙串凭证。当前没有网络配置的本地开发版保持原切换行为，正式商业包必须配置服务 URL 与验证公钥且不能通过运行时开关绕过。

## 订单、售后、更新

- GET `/api/v1/orders/quote?planId=...` → `{planId,amount,currency,startsAt,endsAt}`；只读预计时间，与发放共用日历算法，最终开通可能因延迟或其他购买变化。
- POST `/api/v1/orders` `{planId,channel:"wechat"|"alipay"|"simulated",idempotencyKey,acceptedTerms:true,termsVersion,expectedAmount,expectedCurrency}` → `{order:<下述结构>,payment:{kind:"qr"|"redirect"|"simulated",url:string|null}}`。channel 仅后台已配置且允许的渠道；价格来自服务端，订单保存结账时已同意的条款版本；expectedAmount/expectedCurrency只用于检测页面价格已变，不能作为定价来源，不一致409要求用户重新确认。
- GET `/api/v1/orders` → `{orders:[{id,planId,amount,currency,channel,status:"pending"|"paid"|"closed"|"refunded",createdAt,paidAt,startsAt,endsAt,refundStatus:string|null}]}`。仅自己的订单，分页/限制数量。
- GET `/api/v1/orders/{id}` → `{order,payment}`。POST `/api/v1/orders/{id}/sync` → 同结构，服务器查单/幂等补发；不能让用户自己声明支付成功。
- POST `/api/v1/orders/{id}/simulate` 仅明确 development 且 simulated 允许的隔离环境 → `{order,payment}`；生产路由拒绝。
- POST `/api/v1/orders/{id}/refund` `{reason}` → `{refund:{id,status}}`；提交申请不立即撤全部权益，后台审核并经渠道确认退款。后台查单、退款、发放有审计记录。
- GET `/api/v1/support` → `{tickets:[{id,subject,status,createdAt,messages:[{body,fromSupport,createdAt}]}]}`。POST 同路径 `{subject,body,orderId?}` → `{ticket:{id,subject,status,createdAt,messages:[]}}`。每账号隔离，输入大小限制。
- POST `/api/v1/support/{id}/messages` `{body}` → `{ok:true}`，保持工单历史。
- GET `/api/v1/releases/latest?version=...` → `{available:boolean,version:string|null,url:string|null,notes:string,minimumOS:"15.0",sha256:string|null}`。可用版本指通过发布登记的正式已验签公证包，不能默认把本地包开放下载。App 内检查版本后在 HTTPS 官网下载页进行清晰升级指导，保留配置；首期不静默执行下载文件。

## 当前外部依赖

域名、云资源、SMTP 发件、Apple 会员与正式签名身份、微信 Native / 支付宝电脑网站支付资质和凭据尚未核验。各模块可真实完成本地集成与渠道签名/回调/查单的协议测试；不能把沙盒/模拟结果称为已完成生产付款与分发。
