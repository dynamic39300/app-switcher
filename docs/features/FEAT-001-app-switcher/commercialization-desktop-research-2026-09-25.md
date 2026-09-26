---
id: RES-COMM-DESKTOP
status: draft
owner: "AppSwitcher 项目 owner（待填姓名）"
upstream: [SPEC-001, DESIGN-001]
---

# 商业化桌面端研究：浏览器登录、macOS 分发与 Windows 边界

核验日期：2026-09-25。本文为商业化里程碑的研究输入，区分已核验事实、建议与待验证事项；不代表已修改当前产品范围、联网行为或发布授权。本次未修改业务代码，未注册账号、安装工具或发布软件。

## 范围与当前基线

用户描述的是笔记本、台式机上的 **macOS 和 Windows** 两个平台；这里将原话中的「iOS 版」理解为当前 Mac 版。当前工程仅声明 macOS 15+，UI 和系统层依赖 SwiftUI、AppKit、Carbon 与 Accessibility，现阶段验证环境为 Apple Silicon。[Package.swift](../../../Package.swift)、[当前架构](../../project/architecture.md)

范围更新：用户最新决定先面向中国大陆个人用户，海外后置；同一账号不限制设备数量、类型或同时在线数量。经营主体为中国大陆公司或个体，首期按月／季／年主动购买，自动扣款后置。下文跨地域与多语言研究保留作未来参考，不作为首发验收要求；最新规则见[商业化里程碑](../../project/commercialization-roadmap-2026-09-25.md)及[首发商业规则](../../project/commercialization-rules-2026-09-25.md)。支付渠道、主体资格和税务不在本文的核验范围。

## 已核验事实与产品含义

| 已核验事实 | 对 AppSwitcher 的含义 | 一手来源 |
| --- | --- | --- |
| 原生客户端通过外部浏览器发起授权、用授权码回到 App，是标准支持的方式；公共原生客户端需要 PKCE。重定向可采用平台声明的 HTTPS、自定义 scheme 或桌面 loopback；实际可用性与体验需按平台验证。 | 用户提出的「下载 → 浏览器登录 → 返回 App」可实现。回跳本身不能直接视作登录成功。 | [RFC 8252 §§4–8](https://www.rfc-editor.org/rfc/rfc8252) |
| OAuth 安全最佳实践要求精确校验重定向地址（loopback 端口有规定例外）、防 CSRF、授权码首次兑换后失效；不把 access token 放进 URL 查询参数。公共客户端的 refresh token 需要轮换或发送方约束。 | 建议采用短期一次性 code + PKCE，并用随机 state 绑定当前登录请求；访问／刷新凭证通过安全后端交换，避免进入浏览器历史和回跳 URL。 | [RFC 9700 §§2.1、2.2.2、4.2–4.3、4.7、4.14](https://www.rfc-editor.org/rfc/rfc9700) |
| macOS Keychain 提供加密存储小型秘密数据的系统能力。 | 建议将桌面长期登录凭证放入 Keychain；不写进现有 usage.json、shortcuts.json 或诊断日志。Windows 后续使用对应平台安全存储，具体实现尚未核验。 | [Apple：Keychain services](https://developer.apple.com/documentation/security/keychain-services) |
| Apple 的现代官网分发流程使用 Developer ID 签名、公证；公证要求包括 Hardened Runtime 和安全时间戳，自签名／ad-hoc 不属于所需 Developer ID 证书。公证不是 App Store 的 App Review。 | 当前本地包验证通过，不等于已经适合官网面向普通用户分发。商业发布需另建并验收正式制品流程。 | [Apple：Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) |
| Apple 官方包装流程支持 ZIP、磁盘映像、安装包等分发容器，建议附加公证票据并在未使用过该产品的 Mac 上测试最终下载制品。 | 首期可选择简单 DMG／ZIP；验收对象必须是官网真实下载得到的包，覆盖首次安装与旧版升级。 | [Apple：Packaging Mac software for distribution](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution) |
| Windows 的 SetForegroundWindow 受前台进程、最近输入、菜单状态等条件限制，即便条件满足也可能被拒绝。 | Windows 版不能承诺「枚举到窗口就一定切得过去」；应从用户实际按键或点击开始，验证最终焦点和可见状态。 | [Microsoft：SetForegroundWindow](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setforegroundwindow) |

上述来源均为官方规范或官方文档；网页和搜索内容仅作为研究材料。Apple 动态文档正文通过官方页面的搜索索引核验，未将页面成功打开但没有正文视作已读。

## 建议的首期登录与权益体验

以下为设计建议，尚未成为已接受的规格。OAuth 是授权框架；账号注册、身份认证和订阅权益还需由选定的账号服务提供，不应把「拿到一个 OAuth token」直接等同于已经购买。

1. 官网明确支持的 macOS 版本与芯片，提供下载、价格、帮助和账号入口。App 首次打开时展示简短价值说明和「登录／注册」；试用是否免注册由 owner 决定。
2. App 创建当前登录请求，用系统浏览器打开官网。建议优先考虑同时适合国内与海外的邮箱账号，避免仅依赖中国手机号；首发中文优先，多语言结构保留扩展空间。
3. 用户在网页完成注册或登录，网页提示返回 App。App 接收短期一次性 code，核对当前请求后由自身持有的 PKCE verifier 完成交换。密码、access token、refresh token 不放进回跳 URL。取消、超时、重复回跳、旧请求回跳都应有明确结果。
4. App 获得账号身份后，另行取得服务端确认的权益：试用／有效／到期／撤销等。购买月、季、年时，应落到同一账号的统一权益；用户已确认不限设备数量、类型与同时在线数量，未来 Windows 接入同一账号权益，不新增设备额度。
5. 日常切换仍在本机完成。建议缓存有到期边界的授权结果、设置明确离线宽限，不逐次按键联网；服务端不可用时如何提示、何时限制使用，需要先形成产品规则和验收用例。

回跳方案不在本研究定案：先用选定账号服务实际支持的方式做最小验证，再比较浏览器提示、冷启动回跳、多个 App 实例、scheme 被抢占或 loopback 端口异常。PKCE 不意味着可以忽略回跳身份和会话核对。[RFC 8252](https://www.rfc-editor.org/rfc/rfc8252)

建议的登录验收至少覆盖：未安装时的网页提示、App 已启动／未启动、用户拒绝浏览器打开 App、过期／重复／伪造回跳、断网、刷新凭证撤销、退出账号、设备解绑、购买成功后权益刷新，以及首发中文环境下从官网到 App 的完整路径；英文路径随后续地域扩展验收。以上是建议的测试范围，本次没有运行认证集成实验。

## macOS 官网发布需要补齐的工作

当前 [build_app.sh](../../../scripts/build_app.sh) 尝试 `AppSwitcher Dev` 本地自签名，失败时回退 ad-hoc；[命令索引](../../project/commands.md) 也明确 Developer ID、公证、分发与 CI 尚未配置。需要补充：

- **身份和制品：** 确定商业主体对应的开发者身份、稳定 Bundle ID 和签名证书，完成正式签名、公证、票据附加；保管发布密钥，记录构建版本与校验信息。
- **安装和权限：** 用最终下载包在独立 Mac 验证 Gatekeeper、首次启动、辅助功能／输入监控的说明与跳转，确认用户拒绝权限时仍能理解可用范围。首次安装不应要求用户关闭系统安全保护。
- **更新与恢复：** 建议把更新纳入商业闭环。首期至少提供版本检查、发行说明、官网下载升级和数据保留；内置自动更新另做选型，验证更新包身份、版本兼容、失败恢复与撤回有问题的版本。不要把「官网换个下载链接」当作已经具备更新机制。
- **支持范围：** 当前仅有 Apple Silicon 环境记录。是否增加 Intel、最低系统版本以及哪些第三方 App 属于正式支持，应以真实测试决定，官网如实展示。

前两项中的签名、公证和最终分发包验证来自 Apple 官方要求／指引；更新策略、支持矩阵和验收拆分是结合本项目的建议，不是 Apple 已替本项目验证过的能力。[公证文档](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)、[包装文档](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)

## Windows：先验证系统能力，再决定产品与实现

**代码事实：** 当前 `Package.swift` 和实际 imports 表明界面与系统适配绑定 macOS；不存在已实现的 Windows 目标。因此不能把当前 SwiftUI／AppKit 应用直接作为已完成的 Windows 移植，也没有依据此时锁定 Windows 技术栈。[Package.swift](../../../Package.swift)、[OverlayView.swift](../../../Sources/AppSwitcherApp/OverlayView.swift)、[RunningAppsProvider.swift](../../../Sources/AppSwitcherKit/RunningAppsProvider.swift)

**建议的复用边界：** 官网、账号、订单／权益协议、产品视觉语言和切换规则的意图可以共用；全局快捷键、窗口枚举、焦点、权限、托盘、多屏、安装和更新需 Windows 平台适配。Core 的源码是否直接复用应由小验证决定，不能仅凭其「纯规则」就承诺跨平台零成本。

建议把 Windows 前置研究限定为一个可丢弃的原型，回答以下问题后再排完整版本：

| 小验证 | 验收观察 |
| --- | --- |
| 全局组合键唤出面板 → 字母选择 → 实际目标前台 | 快捷键冲突可反馈，按键结束后真实前台窗口正确，失败不误报成功。 |
| 同应用多窗口、多个进程、托盘和辅助进程 | 能定义稳定的候选身份与去重规则；不把不可切换后台组件作为普通目标。 |
| 正常、最小化、隐藏、主窗口已关闭；常用原生与网页技术桌面应用 | 各状态记录可见窗口和键盘焦点；不照搬 macOS 的 reopen 结论。 |
| 多显示器、高 DPI、全屏、虚拟桌面、权限级别不同的目标 | 明确哪些可支持、哪些需要提示或回退；本次未验证这些场景。 |

Windows 的前台限制已有官方证据，其余列表是待验证问题，不能解读为已确认的能力或缺陷。[Microsoft：SetForegroundWindow](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setforegroundwindow)

## 对下一阶段里程碑的建议

建议将「非开发者能从官网下载，经浏览器登录并购买权益，在 Mac 上可靠使用和升级」作为首个商业闭环。账号和分发可以与当前可靠性、UI、首次引导并行完善；公开收费前仍需真实兼容性验收，已有规则测试通过不能代替第三方应用现场验证。

Windows 后续可安排上述小验证，输出支持边界和粗估，不与首个 macOS 商业闭环捆绑上线。设备规则已确认不限；试用、离线、月／季／年日历算法已有[建议规则稿](../../project/commercialization-rules-2026-09-25.md)，仍需评审。待定实施事项包括账号服务、回跳方式、Intel 支持、更新方案及 Windows 首期范围。正式签名与申请材料见[前置清单](../../project/commercialization-prerequisites-2026-09-25.md)。本次只完成来源核验和文档，没有认证、签名公证或 Windows 实验结果。
