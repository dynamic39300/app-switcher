# AppSwitcher 对外发布账号与资质：官方来源核对

核对日期：2026-09-28。范围：中国大陆个体工商户经营、官网注册/登录、网页购买微信 Native 与支付宝电脑网站支付、官网分发 macOS PKG。本文只记录公开官方资料可证实的要求；平台后台显示的准入、具体材料与审核结果仍须账户持有人核实。这里的微信/支付宝支付账号与 AppSwitcher 用户账号是两件事。

## 已由官方资料证实

| 事项 | 核对结果 | 官方依据 |
| --- | --- | --- |
| Apple 会员类型 | Apple 将 `sole proprietor/single person business` 列在个人加入路径，要求法定姓名、达到当地成年年龄、有双重认证的 Apple Account；身份核验后同意协议并购买会员，公布基准费用为每年 USD 99，实际当地价格以申请页为准。组织加入路径要求独立法人实体、D-U-N-S 等。中国“个体工商户”与 Apple 英文法律分类的最终对应仍以 Apple 审核为准。 | [Apple 会员申请](https://developer.apple.com/programs/enroll/) |
| Apple 签名身份 | 官网独立分发的 Mac App 用 **Developer ID Application** 签名；若主交付物是双击启动 macOS 安装器的 PKG，包另用 **Developer ID Installer** 签名。这是同一会员下的两种证书，不是两份付费会员。Apple 标准的本地证书创建权限是 Account Holder；Apple 文档也列有受授权管理员使用云托管证书的例外。 | [Apple Developer ID 证书](https://developer.apple.com/help/account/certificates/create-developer-id-certificates)、[Apple 打包说明](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution) |
| Apple 证书申请 | 可在发布 Mac 的“钥匙串访问”中用“证书助理 → 从证书颁发机构请求证书”生成 CSR；在 Apple 开发者后台“Certificates, Identifiers & Profiles → Certificates → + → Developer ID”分别选择 Application/Installer、上传 CSR、下载 `.cer`，并双击装入有对应私钥的钥匙串。CSR 本身并非私钥。 | [Apple CSR 指南](https://developer.apple.com/help/account/certificates/create-a-certificate-signing-request)、[Apple Developer ID 证书](https://developer.apple.com/help/account/certificates/create-developer-id-certificates) |
| Apple 公证 | 向官网用户发软件还须以 Developer ID 签所有可执行内容、启用 Hardened Runtime 与安全时间戳，并提交实际分发的 PKG 给 Apple 公证；Accepted 后附加票据并在另一台 Mac 测试安装和启动。`notarytool` 可用 Apple Account + App 专用密码 + Team ID 或 App Store Connect API key 认证，并将凭据保存为本机钥匙串 profile；这属于构建/发布步骤，不是第三种证书。 | [Apple 公证要求](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)、[Apple 公证凭据](https://developer.apple.com/documentation/technotes/tn3147-migrating-to-the-latest-notarization-tool)、[Apple 打包验证](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution) |
| 微信产品选型 | 微信 Native 是 **PC 浏览器展示二维码、买家微信扫码** 的支付产品；官方列明支持个体工商户。它与移动 App 内拉起微信的“APP 支付”是不同产品。 | [Native 产品介绍](https://pay.wechatpay.cn/doc/v3/merchant/4012791874) |
| 微信开通链条 | 需要微信支付商户号 `mchid`，以及可用于 Native 的**已认证**服务号/适用公众号、小程序或移动应用 `appid`。有商户号时由超级管理员在“商户平台 → 产品中心 → Native 支付 → 申请开通”；没有商户号可在入驻时一并申请。还须由对应公众/开放平台确认 `mchid` 与 `appid` 的授权绑定。仅开通商户号或仅持有公众号都不足以发起生产 Native 交易。 | [Native 接入准备](https://pay.wechatpay.cn/doc/v3/merchant/4015614538)、[Native 权限申请](https://pay.wechatpay.cn/doc/v3/merchant/4012791875) |
| 微信官网条件 | 微信对新商户申请 Native 的 PC 网站经营场景要求填写网站域名；其说明明确称 PC 网站域名需有 ICP 备案，并视域名备案主体是否一致要求网站授权函。商户入驻资料包括营业执照、经营者证件、结算银行账户，且需有效客服联系方式；准确材料和经营类目以开户页为准。 | [Native 权限申请](https://pay.wechatpay.cn/doc/v3/merchant/4012791875)、[微信商户申请材料](https://pay.wechatpay.cn/static/applyment_guide/applyment_detail_app.shtml) |
| 微信 API 参数 | 对现有服务端 APIv3 接入，还需商户 API 证书/私钥与序列号、APIv3 密钥，以及微信支付公钥或平台证书来完成请求签名、通知解密/验签；这些是**秘密/加密材料**，不写入仓库、聊天或普通进度表。 | [微信开发必要参数](https://pay.wechatpay.cn/doc/v3/merchant/4013070756) |
| 支付宝产品选型 | 支付宝商家产品入口把“电脑网站支付”列为商家网站付款产品；与“手机网站支付”“APP 支付”分列。商家自行接入自身软件，开放平台对应的是“自用型应用”流程，而非替别的商户开发的第三方/ISV 应用。 | [支付宝商家产品入口](https://b.alipay.com/signing/home.htm)、[支付宝自用型与第三方应用](https://open.alipay.com/platform/accessProcessPage.htm) |
| 支付宝开通链条 | 支付宝的网页/移动应用公开流程为创建应用、配置密钥/网关、提交审核上线；电脑网站支付另需在商家产品入口申请/签约。公开页面没有证明“个体工商户一律可获准该产品”，也没有证明“创建应用即开通收款”。须以账户后台的主体认证、产品签约与应用上线三个状态分别核实。 | [支付宝网页应用流程](https://open.alipay.com/module/webApp)、[支付宝商家产品入口](https://b.alipay.com/signing/home.htm) |
| 官网备案/许可分类 | 国务院现行《互联网信息服务管理办法》将经营性互联网信息服务置于许可、非经营性置于备案；网站实际业务如何归类、是否须另办增值电信业务经营许可，不能仅凭“软件收费”三个字在本文断定，须按拟用服务器/主体所在地的接入商和省通信管理局要求核实。独立于此，微信 Native 的 PC 网站准入文件已明确要求网站域名 ICP 备案。 | [现行《互联网信息服务管理办法》](https://xzfg.moj.gov.cn/front/law/detail?LawID=1756&Query=%E4%BA%92%E8%81%94%E7%BD%91+1+2)、[工信部门备案/许可指南](https://hunca.miit.gov.cn/bsfw/bszn/art/2024/art_7ef0d8bd3b0d433ba4b9b277f883f74d.html)、[微信 Native 权限申请](https://pay.wechatpay.cn/doc/v3/merchant/4012791875) |

## 平台后台与上线前仍待核实

1. Apple 是否批准以个人路径加入、会员生效状态、Team ID、两种 Developer ID 证书是否均为有效身份，以及公证认证方式。Apple 的姓名显示和续期安排也需账户持有人按实际页面确认。[Apple 会员申请](https://developer.apple.com/programs/enroll/)
2. 微信用于 Native 的 AppID 选哪一种；**macOS 桌面应用并不自动等于微信开放平台“移动应用”**。选择服务号或小程序可能比误选移动应用更贴合网页收款，但认证资格、额外费用与关联主体须按相应官方账号页面核实。还需检查 Native 权限、AppID 绑定、实际经营类目/费率与结算账户。[Native 接入准备](https://pay.wechatpay.cn/doc/v3/merchant/4015614538)、[Native 权限申请](https://pay.wechatpay.cn/doc/v3/merchant/4012791875)
3. 支付宝个体工商户在当前账户中应使用何种认证/结算方式、是否可签“电脑网站支付”、需提交的经营网址/ICP备案与补充资料、应用是否已上线，公开页不足以代替账户后台审核。[支付宝商家产品入口](https://b.alipay.com/signing/home.htm)、[支付宝自用型应用](https://open.alipay.com/platform/accessProcessPage.htm)
4. 官网还需可访问的自有域名、生产 HTTPS、实际邮件发送通道、云服务/数据库、公开经营与客服信息、隐私政策及退款/用户条款。这是当前项目的生产运营/技术依赖，**不能误称全部都是独立行政许可或平台账号**；服务接入清单见[商业发布运行手册](../../runbooks/commercial-release.md)。向接入商和主管通信管理局核实网站备案或经营许可分类后再公开收款。[现行法规](https://xzfg.moj.gov.cn/front/law/detail?LawID=1756&Query=%E4%BA%92%E8%81%94%E7%BD%91+1+2)

核对边界：未登录用户的 Apple、微信、支付宝账号；未提交入驻、签约、证书或公证申请，未付款；没有据公开页面推断任何审批已通过。身份证件、营业执照图、银行卡、私钥、APIv3 密钥、App 专用密码、验证码等只能在相应官方平台或受控密钥环境处理。
