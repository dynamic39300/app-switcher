---
id: RES-COMM-PREREQUISITES
status: draft
owner: "AppSwitcher 项目 owner（待填姓名）"
upstream: [RES-COMM-DESKTOP]
---

# 商业化前置准备：开发者身份、分发与国内服务

核验日期：**2026-09-25**。本稿按最新方向：首发中国大陆个人用户、macOS 先行，Windows / 海外 / 自动扣款后置；月、季、年主动付款，同一账号不限设备数量和类型。不限设备不代表尚未开发的平台已可使用。本文只整理前置材料和工程依赖；未申请账号、提交证件、购买服务、签名公证或部署。

同日实施更新：用户已授权 Codex 自主全面实施；官网、账号、国内支付适配、Mac授权、DMG发布脚本与部署模板已实现，本地联调和独立审阅结果见 [QA-002](../features/FEAT-002-commercialization/verification.md)。本页保留官方申请材料依据，以下“工程可做”不再表示代码尚未开始。当前仍没有域名/云/SMTP/商户权限已就绪的证据；本机 `security find-identity -v -p codesigning` 未发现有效正式签名身份。身份申请、审核和真实生产验收不能由本地模拟代替。

**现在最先确定实际经营主体与 Apple 注册身份，并准备本人可控制的 Apple Account。工程可以同时建设商业闭环和分发脚本，正式对外制品则要等会员、签名身份与公证验证。** 用户已表示愿意申请所需开发者账号，但尚无会员获批或正式证书就绪的证据。旧[桌面研究](../features/FEAT-001-app-switcher/commercialization-desktop-research-2026-09-25.md)与[支付研究](../features/FEAT-001-app-switcher/commercialization-payments-research-2026-09-25.md)涉及海外的范围不作为本次首发要求。

## Apple 申请身份与材料

| 申请情况 | 官方要求 / 区别 | 本项目现在准备 |
| --- | --- | --- |
| 个人 | 法定姓名、联系方式、真实地址，Apple Account 开启双重认证；达到所在地区成年年龄。个人身份不要求 D‑U‑N‑S。 | 确认账号信息与本人身份一致，受信任号码 / 设备可用；不要把产品名填成个人姓名。[注册入口](https://developer.apple.com/programs/enroll/)、[D‑U‑N‑S 说明](https://developer.apple.com/help/account/membership/D-U-N-S/) |
| 组织 / 公司 | 必须是能与 Apple 签约的法律实体；需要实体名称、D‑U‑N‑S、具有签约授权的 Account Holder、组织域名邮箱及有效公开官网。商号、品牌名或分支机构不能替代实体。 | 准备营业 / 注册材料、对应名称与地址、组织电话；非创始人申请时准备授权及可核实联系人。Apple 可能要求经认证的材料副本，以实际要求为准。[组织注册要求](https://developer.apple.com/help/account/membership/program-enrollment/)、[身份验证](https://developer.apple.com/help/account/membership/identity-verification/) |
| 大陆个体工商户、独资经营等待确认形式 | Apple 明确把其认定为 sole proprietor / single-person business 的申请归到个人；有 D‑U‑N‑S 本身不能证明具备组织资格。 | 先按实际登记形式向 Apple / D&B 核实，**不预设“个体一定能组织注册”，也不凭只有一名股东就替 Apple 判断公司资格**。材料不匹配时核实记录，不用品牌名绕过。[D‑U‑N‑S 的法律实体判断](https://developer.apple.com/help/account/membership/D-U-N-S/) |

中国大陆 Apple Developer App 的个人流程列出身份证号、电话、自拍身份核验，以及英文姓名 / 地址；还需兼容设备、最新 App、iCloud 登录，并在同一设备完成流程。申请人仅在 Apple 官方流程提交这些资料，本文不收集证件、密码、验证码或付款资料。其他验证方式由本人联系 Apple 支持。[大陆专用注册说明](https://developer.apple.com/cn/help/account/membership/enrolling-in-the-app)

组织应先查询已有 D‑U‑N‑S，再按 Apple 入口申请，避免重复。准备实体名称、总部 / 通信地址、工作联系方式及注册文件；官方列出 D&B 处理和向 Apple 同步需要时间，不应把当天取得号码当成当天获批承诺。[D‑U‑N‑S 查询与申请](https://developer.apple.com/help/account/membership/D-U-N-S/)

适用路线是普通 **Apple Developer Program**，个人和组织均可成为会员并取得 Developer ID；不是因为面向消费者收费就要改选企业内部应用计划。官方基础年费为 99 美元，实际地区币种与价格以申请时展示为准。通过 Developer App 购买会员是自动续期会员，这属于开发者会费，与本产品后置的自动扣款功能分开。[会员能力与费用](https://developer.apple.com/programs/whats-included/)、[会员购买方式](https://developer.apple.com/help/account/membership/program-enrollment/)

## 用户准备与工程工作分界

P0：现在开始，影响外部开通周期；P1：公开收费 / 分发前具备；P2：后置或候选。以下“工程可做”是下一阶段工作建议，不代表本稿已经实施。

| 优先级 / 事项 | 用户现在准备或确认 | 工程可并行完成 | 当前状态 / 通过条件 |
| --- | --- | --- | --- |
| P0 主体与账号 | 确认实际经营主体；决定申请个人还是经核实的组织身份；准备上表材料、本人 Apple Account 与 2FA | 给出材料清单、检查官网信息是否一致 | 用户愿意申请，资格 / 会员尚未核验；以 Apple 实际审核为准 |
| P0 品牌与域名 | 确认产品名、域名归属和申请组织使用的官网 / 域名邮箱 | 官网页面、下载说明、支持入口；校准正式 Bundle ID 与发布身份 | 域名 / 邮箱未确认。组织官网不能只是占位页；该要求来自组织注册说明 |
| P1 发布证书 | 会员获批后，由 Account Holder 在本人管理的账户创建 Developer ID Application；确定发布密钥保管人 | 本地生成 CSR 的步骤、证书配置入口、签名身份校验；不把私钥或账号密码写入仓库 | Application 用于 App；只有选择 `.pkg` 安装包才增加 Developer ID Installer，DMG 不因此要求 Installer 证书。[证书类型与角色](https://developer.apple.com/help/account/certificates/create-developer-id-certificates) |
| P1 公证认证 | 在受控钥匙串 / 密钥管理中完成提交身份配置；工程只引用配置名 | Hardened Runtime、时间戳、提交 / 等待 / 日志检查、staple、最终包验收流水线 | 当前没有正式公证完成证据；不通过聊天传递密码或公证凭据。[自动化公证](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow) |
| P1 官网正式包 | 确认发布名称、版本、支持范围，提供独立 Mac 的验收条件 | 从真实下载入口验首次安装、升级、权限、配置保留；签名变化后的旧版升级需实测 | 本地严格验签不等于官网下载 / Gatekeeper 验收；不要求用户关闭系统安全保护。[包装与分发测试](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution) |
| P1 更新与恢复 | 明确更新支持责任、发布说明和问题版本处理方式 | 稳定下载地址、版本信息、更新包身份校验与失败恢复设计；每版走正式签名 / 公证 | 已实现App检查新版并转到可信官网下载/替换指导，未引入静默安装；真实普通用户安装/升级仍待验证 |
| P2 内置自动更新 | 无需现在额外申请更新服务账号 | 评估 Sparkle 2 与官网手动升级的成本；若采用，验证框架 / helper 打包、HTTPS appcast、EdDSA 更新签名和密钥保管 | **Sparkle 仅候选，未引入依赖或锁定版本**；其签名不替代 Apple Developer ID / 公证。[Sparkle 官方接入与安全说明](https://sparkle-project.org/documentation/) |

证书创建和后续更新存在持续维护责任：Apple 说明 Developer ID 证书到期后，符合条件的既有签名 App 不因此自动停止运行，但签署新版本需要有效证书；取新证书需要有效计划会员。应把会员 / 证书到期和密钥恢复纳入发布运维，不将首包签名当成一次性手续。[证书到期与更新](https://developer.apple.com/help/account/certificates/create-developer-id-certificates)

## 实施前打包差距与当前依赖

实施前0.3.2只支持本地自签名/ad-hoc。现 [build_app.sh](../../scripts/build_app.sh) 与 [release_macos.sh](../../scripts/release_macos.sh) 已支持0.4.0正式配置、Developer ID、Hardened Runtime/时间戳、DMG、公证、附票据、架构与源码记录；缺正式身份会停止，不回退自签名冒充发布。裸App在私有临时目录封装，避开Documents同步元数据。非同步目录本地包严格验签通过；正式证书、公证提交、Gatekeeper及独立Mac真实下载安装升级尚未验收。

Apple 对现代官网分发的公证流程要求有效 Developer ID、Hardened Runtime 和安全时间戳，自签名 / ad‑hoc 不能作为其替代。公证是软件安全检查流程，不能代替第三方 App 兼容性和实际功能验收。[公证要求](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

建议依赖顺序为：**身份核验 / 会员 → Developer ID Application 与受控提交身份 → 正式签名 → 包装与公证 → 附加票据 → 最终下载包安装 / 升级验收 → 发布**。脚本、官网和验收夹具可在会员审核期间准备；没有证书时只能完成流程设计和本地部分，不能宣称正式链路已通。若选 ZIP，票据附在 App 后重新打 ZIP；若选 DMG，可附在 DMG。Apple 明确不能直接给 ZIP staple。[自定义公证流程](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)

本机只读检查 `xcrun --find notarytool` 与 `xcrun --find stapler` 均成功，路径在 `/Library/Developer/CommandLineTools/usr/bin/`。因此当前不是“没有这些命令”；会员身份、证书、认证及提交结果仍未配置或验证。没有读取用户钥匙串秘密，也没有用这些命令向 Apple 提交制品。

## 国内域名、云、邮件与支付的准备状态

本节复用既有[支付研究](../features/FEAT-001-app-switcher/commercialization-payments-research-2026-09-25.md)、[桌面研究](../features/FEAT-001-app-switcher/commercialization-desktop-research-2026-09-25.md)及 [CLOUD.md](../../CLOUD.md)，不扩大为新的法律或商户资格结论。

| 优先级 / 前置 | 目前可确认 | 用户需准备 | 工程可并行做 / 外部完成条件 |
| --- | --- | --- | --- |
| P0 域名 / 官网 | 域名与归属尚未确认 | 产品域名、真实经营主体、管理联系人 | 页面与下载设计；部署地域明确后，由负责人 / 服务商核验备案及平台所需资质的适用性，不预判“全部需要 / 不需要” |
| P0 云与部署地域 | `CLOUD.md` 尚无已配置云环境 | 选择拟用地域、云账号归属及预算 | staging / production、订单与权益服务、备份恢复、日志与告警方案；本稿不创建或购买资源 |
| P1 事务邮件 | 邮箱登录是已有候选方案，服务 / 发件域名 / 送达未确认 | 确认邮箱路线、发件域名和客服收件人 | 接入前准备验证码、限流和模板；在真实服务验证域名认证与大陆邮件送达后才宣称可用，不把组织工作邮箱等同于事务发信服务 |
| P0 微信支付 | 用户申请中；未核验已获 Native 权限 | 最终主体、商户产品权限、AppID 与商户号绑定状态 | 订单 / 通知幂等 / 查单 / 退款设计；上线条件包含实际权限和服务端配置，不仅是“有商户号”。[微信官方接入准备](https://pay.wechatpay.cn/doc/v3/merchant/4015614538) |
| P0 支付宝 | 用户申请中；电脑网站支付仅候选产品，详细准入尚待后台核验 | 产品签约、网页应用上线和实际收款能力 | 支付适配接口可先隔离；按商户后台当前契约验证回调 / 查单 / 退款，不能用个人收钱码替代产品接入资格。[支付宝官方产品入口](https://b.alipay.com/signing/home.htm) |
| P1 收费支持 | 退款 / 票据 / 条款 / 客服责任尚待确认 | 确定负责人和可执行流程；实际法律 / 税务适用另行核验 | 订单查询、退款入口、权益恢复、支持与隐私页面；不由本稿认定特定主体已满足全部要求 |

Windows 签名、海外收款、自动扣款权限不进入当前 P0。首发不限设备的授权规则属于产品 / 权益系统设计，与 Apple 的测试设备登记额度不是同一个概念；不能用 Apple 开发测试限制替代付费账号规则。

## 尚未验证与后续更新触发

尚未确认实际主体类型、Apple 会员 / D‑U‑N‑S 状态、正式证书、公证提交、域名 / 云 / 邮件与商户后台权限；未运行真实支付、退款或正式下载包验收。申请身份确定、账号获批、正式包完成或平台要求变化时更新本稿。Apple 动态文档正文已通过官方文档 JSON 核对；网页资料仅为依据，不授予申请、付款或发布权限。
