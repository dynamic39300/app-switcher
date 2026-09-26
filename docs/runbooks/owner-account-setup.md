# AppSwitcher 账号开通与接入交接

2026-09-26。官网与商业服务已经完成本地实施，正式上线仍需真实账号和服务。以下步骤供实际账户持有人办理；申请、协议、身份验证及会员付款在官方平台完成。已有自主实施授权继续有效，不需要重新批准产品方案。

## 使用本机向导

本次生成的一次性向导位于项目的 `build/onboarding/AppSwitcher-开通向导.command`。在 Finder 中双击，或在项目目录的终端运行：

```bash
bash build/onboarding/AppSwitcher-开通向导.command
```

向导依次打开五组官方入口。审核尚未完成也能保存当前进度，随时 Ctrl-C，重跑时回车保留上次值。只收集 8 项办理状态和 4 项可选公开标识；记录保存在同目录的 `readiness.env`，文件权限 600，不纳入 Git。这个文件是交接数据，不是运行配置，**不要 source，也不要复制为生产 `.env`**。

脚本位于被忽略的临时产物目录，清理 `build/` 会删除向导和进度；本页保留完整办理依据。向导不安装证书、不运行公证命令、不申请产品、不购买资源。它保存本人填报的进度，后续工程接入仍须独立核验。

## 五个办理阶段

| 阶段 | 本人操作与官方入口 | 向导保存的数据 |
| --- | --- | --- |
| Apple 会员 | 按实际登记身份在[Apple Developer 注册入口](https://developer.apple.com/programs/enroll/)办理。大陆 App 流程参见[官方说明](https://developer.apple.com/cn/help/account/membership/enrolling-in-the-app)。提交申请后等待实际会员生效，组织资格以 Apple 核验为准。 | `APPLE_MEMBERSHIP_STATUS` |
| 签名证书 | 会员生效后，按[Developer ID 官方步骤](https://developer.apple.com/help/account/certificates/create-developer-id-certificates)创建 Developer ID Application；在发布 Mac [生成 CSR](https://developer.apple.com/help/account/certificates/create-a-certificate-signing-request)，提交后将证书安装到生成密钥的钥匙串。DMG 不因此需要 Installer 证书。 | `DEVELOPER_ID_STATUS`；安装完成后由工程检查有效签名身份，不需复制私钥 |
| 公证认证 | 由本人按照[官方公证流程](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)在终端交互配置钥匙串 profile。下面给出命令；向导不会代为执行。 | `NOTARY_PROFILE_STATUS`、`NOTARY_PROFILE_NAME`；profile 不是制品公证结果 |
| 微信支付 | 按[Native 接入准备](https://pay.wechatpay.cn/doc/v3/merchant/4015614538)与[权限申请指引](https://pay.wechatpay.cn/doc/v3/merchant/4012791875)分别确认商户申请、Native 权限、已认证 AppID 与商户号绑定。 | `WECHAT_MERCHANT_STATUS`、`WECHAT_NATIVE_STATUS`、`WECHAT_APP_BINDING_STATUS`；可选 `WECHAT_MERCHANT_ID`、`WECHAT_APP_ID` |
| 支付宝 | 在[商家产品入口](https://b.alipay.com/signing/home.htm)申请电脑网站支付，并按[网页应用接入流程](https://open.alipay.com/module/webApp)完成创建、开发配置、审核上线。具体菜单及材料以本人账户实际显示为准。 | `ALIPAY_WEBSITE_PAYMENT_STATUS`、`ALIPAY_APPLICATION_STATUS`；可选 `ALIPAY_APP_ID` |

公证认证命令（需本人操作，使用新 profile 名避免覆盖其他项目配置）：

```bash
xcrun notarytool store-credentials "AppSwitcher-notary"
```

官方工具会交互询问认证材料，并联系 Apple 验证后保存到钥匙串。密码只填在官方工具提示中，不放到命令参数、向导或聊天。已通过本机 `store-credentials --help` 核对交互行为，尚未执行保存或提交 App。后续发布只引用实际 profile 名。

状态值为 `pending`、`applying`、`needs_action` 或 `owner_reported_ready`。最后一种仅表示本人填报就绪，不是程序检测结果。若应用开发配置需要尚未具备的正式服务地址或公钥，记录待补充即可，不填虚构资料。

身份证件、营业执照、结算资料仅由本人提交官方平台；密码、验证码、APIv3 密钥、Apple App 专用密码、商户或支付宝应用私钥、`.p12/.p8` 不进入此记录。微信的公开开发标识与秘密材料划分见[官方开发参数说明](https://pay.wechatpay.cn/doc/v3/merchant/4013070756)。

## 服务入口交接

另外需要提供已有的正式域名、云平台名称及服务器地址、事务邮件服务名称、可公开的经营主体名称和客服联系方式。只发送这些名称与开通进度；密码或私钥通过受控部署环境配置。尚未选择云平台时先说明未准备，不将组织的其他服务器默认用于本产品。

已有入口后，工程依照[商业发布运行手册](commercial-release.md)接入 HTTPS、PostgreSQL、SMTP 与密钥管理，核验真实邮件送达；支付权限和签名身份就绪后，再完成真实购买、续费、退款、对账、公证及独立 Mac 的官网下载和升级。注册账号或填完向导本身不代表商业闭环已经上线。

## 本次检查范围

本机 `/bin/bash` 3.2.57 语法检查通过；模板库保持原样；独立静态审阅确认 5 阶段、8 状态、4 公开标识、输入不作为代码执行、进度只写本地。未运行交互式端到端、未创建账号、未提交审核、未读取秘密。未安装 ShellCheck，因此不声称已通过该检查。官方入口核验于 2026-09-26；支付宝登录后的动态菜单及准入条件未作推测。
