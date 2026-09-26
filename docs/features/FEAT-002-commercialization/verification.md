---
id: QA-002
status: draft
owner: "Codex 集成；生产运营 owner 待落实"
upstream: [SPEC-002, CONTRACT-002, TASKS-002]
---

# 商业化测试、发布与交付记录

风险 high：账号隔离、资金、授权与对外制品。2026-09-25已完成主要实现、本地业务与协议验证、真实浏览器/Mac联调及独立审阅。总体目标经连续第三个回合的同一外部依赖审计转为blocked；没有生产真实交易、正式公证包或真实公网部署证据，不标记商业闭环已上线或总体目标complete。

## 验证计划

- 后端：真实 ORM/事务下验证码限流/重放、CSRF、跨账号、PKCE绑定、token轮换、试用唯一性、日历/月底/闰年、并发与幂等、退款不误伤其他订单。
- 支付适配：使用自建隔离密钥与合成订单验证签名/加密/金额/商户/重放；外部成功不得由客户端声明。生产小额支付、查单、退款必须单独验收。
- Swift：JWS合法与篡改/错误aud/iss/sub/sid/时间、离线截止/回拨、登录状态、门禁和原有规则；API真实本地联调。
- UI：桌面与手机宽度、键盘焦点、错误/空/加载状态，实际浏览器完成登录/账号/试用/模拟购买/订单/退款/工单。开发模拟明确标识，邮件只用隔离测试地址不发送外部消息。
- 分发：缺配置失败、隔离本地包、Info.plist固定来源/公钥/URLscheme；正式签名/公证/Gatekeeper/独立Mac实际下载安装升级需真实身份，缺失时明确未通过。
- 运行：冻结依赖安装、静态/安全检查、空库迁移、备份恢复、生产不安全配置拒绝、独立审阅。无生产系统时不能声称生产恢复/告警已验证。
- 原 App：swift build、CoreTests、合成应用唤起必要回归；不批量操作用户真实窗口。

## 当前外部条件

2026-09-26恢复推进：本地8000官网仍正常响应；公开配置仍为development、微信/支付宝禁用、模拟支付开启、正式下载不可用。未发现新的项目环境配置或有效代码签名身份。新增[本人账号开通与交接指引](../../runbooks/owner-account-setup.md)及被忽略的一次性向导 `build/onboarding/AppSwitcher-开通向导.command`：5阶段、8项状态、4项可选公开标识。`/bin/bash -n`与独立静态审阅通过，模板库未修改；ShellCheck未安装。未运行交互式端到端，未提交账户申请或将本人填报状态当作生产验证。正式服务入口询问等待用户补充；实际部署/交易/分发仍未完成。

同日按用户要求提交前，对128个拟提交文件运行detect-secrets 1.5.0（`scan --no-verify --all-files`，显式传入文件列表，不向外部服务验证候选秘密）。8处命中经逐项检查均为隔离CI凭据、RFC 7636公开测试向量或明确的合成配置/拒绝用例；未发现真实秘密，不通过加入宽泛白名单隐藏命中。独立范围检查确认无数据库、运行日志、安装包或私钥，`.workbuddy/`与被忽略的运行/构建产物不提交。框架检查110个Markdown、0错误0警告，暂存差异空白检查通过；本次未修改业务行为，复用上列已完成的业务验收记录。

域名、服务器/云平台、SMTP、Apple Developer会员/Developer ID、公证凭据、微信Native与支付宝电脑网站支付权限尚未确认。已向用户询问名称和开通状态，不要求在聊天发送秘密。没有进行生产收费、发邮件给外部用户或公网发布。

2026-09-25第三回合阻塞复核：实时 `/api/v1/config` 为development、wechat/alipay=false、simulated=true、download.available=false，经营/客服身份未配置；`security find-identity -v -p codesigning` 仍为0个有效身份。独立只读审阅逐项对照COMM-01至13，未发现已明确且无需外部条件可继续的FEAT-002实施缺口；这不是对全部代码无缺陷的保证。上一回合属于实际进展（修复正式包地址校验并完成价格/条款UI故障注入），本回合没有通过重复测试或新增非必要功能替代真实上线。

恢复推进需要三组真实条件：①域名/HTTPS、云/PostgreSQL、SMTP及经营/客服负责人；②微信Native、支付宝电脑网站支付的实际权限与受控配置；③Developer ID、公证身份及独立Mac安装升级验收条件。已有自主授权继续有效，无需重复产品方案审批。资料只通过受控环境/凭据管理配置，不在聊天粘贴秘密；条件提供后继续真实购买、续费、退款、对账与正式下载安装升级验收，提供账号本身不算验收完成。

## 实际结果（2026-09-25）

环境：macOS 26.6.2 / Apple Silicon，Swift 6.3.3，uv 0.12.5，Python 3.12.14，Django 5.2.17，cryptography 50.0.1。依赖冻结在 `web/uv.lock`。PostgreSQL 17.11 来自官方源码包及官方 SHA256 校验，本地构建后仅监听127.0.0.1:55432；密码只存在被忽略且权限600的测试文件，不入文档。演练结束已停止该隔离数据库。

| 层次 | 实际命令/操作 | 结果与边界 |
| --- | --- | --- |
| 后端 | `uv run --frozen --project web python web/manage.py test commerce --noinput` | 最终SQLite 52通过/4个PG专属跳过；实际PG17.11最终56/56全通过，7.677s，无跳过；真实事务并发含试用、支付、刷新和补偿边界 |
| 配置与质量 | `ruff check`、`ruff format --check web`、Django `check`、`makemigrations --check --dry-run`、`collectstatic --noinput` | 通过；0001–0003可从空库迁移；生产缺秘密/SMTP/主体/HTTPS/正式密钥或混入模拟功能时拒绝启动，测试包含可信代理伪造边界 |
| 依赖 | `uv run --frozen --project web pip-audit` | 查询时0已知漏洞；最初cryptography47命中问题后已升级到50.0.1重新验证，不声称未来无漏洞 |
| 支付与售后 | 自建隔离RSA/AES密钥的协议测试及本地演示订单 | 微信APIv3公钥模式、支付宝RSA2支付/查单/退款验签和商户/金额/流水核对、重复通知、补偿、退款保留其他订单通过；没有实际商户收付款 |
| Web实际UI | Chrome/IAB，1600×900桌面与390 CSS像素手机宽度 | 首页/导航/价格无横向溢出；文件验证码登录、月度/年度模拟支付、查单、退款申请、关联订单工单与回复、退出；条款/隐私同意记录与订单价格/条款版本真实入库；JS语法、模板解析、Prettier检查通过 |
| 购买条件变化 | 实际Chrome，独立8017服务/数据库/合成账号，保留旧页面后变更服务配置 | 旧¥9页面提交到已改¥10服务返回409 price_changed，订单0；旧2026-09-25条款页面提交到2026-09-26服务返回409 terms_updated，该账号订单0。两者刷新后均展示最新条件并清空同意框；未重新勾选时浏览器阻止提交且无新增请求，主动重新同意后各仅一笔1000分pending订单，新条款订单版本正确。没有模拟付款、真实收款或主站价格/条款变更 |
| Swift现有规则 | `swift run CoreTests` | 75/75通过；未对用户应用批量操作 |
| Swift商业边界 | Debug及Release `AppSwitcherApp --verify-commerce` | 最终44/44；含JWS签名、身份/来源/时限/回拨、PKCE、冷启动所需状态、错误回跳、Keychain租户namespace、授权网页路径等合成测试 |
| Python→Swift | `license_fixture` + `--verify-commerce-fixture` | 后端实际签发的Ed25519 JWS在Debug/Release通过；错误密钥与声明拒绝 |
| 实际localhost API | `desktop_api_fixture` + Debug `--verify-commerce-api` | 最终7/7：start/authorizeUrl、实际URLSession授权交换、me、14天试用/7天签名许可、refresh、退出与旧凭证拒绝通过；Release拒绝开发API探针 |
| Mac实际浏览器 | 隔离0.4.0 Debug商业候选，Chrome验证码→确认授权→系统打开App | 热回跳成功，原生显示账号/未试用；主动开始试用后期限正确；退出候选进程后冷回跳从零启动成功，同签名重启后Keychain登录和试用保持；重复回跳状态和会话数不变；检查更新正确说明尚无正式版本；退出后账号活跃会话0 |
| 原切换回归 | Release `AppSwitcherApp --verify-app-activation` | 5/5：正常、最小化、关闭窗口、隐藏、真多实例拒绝；仅合成App，准确前台PID和窗口结果，不代表第三方全场景 |
| 原生视觉 | `--render-commerce-preview build/previews/0.4.0/account` | 8个合成状态：未登录、试用、付费、过期、离线待验证、不可用、窄宽/长邮箱等；未读取用户屏幕内容 |
| 发布边界 | `python3 scripts/test_app_bundle.py`、`bash -n` | 10/10；非法服务源/公钥/模式、覆盖其他App、失败恢复、构建期源码漂移拒绝。包含示例域、非公网/旧式数字IP、编码主机和非法端口；macOS Bash3空数组缺陷经实际打包发现并修复 |
| 本地实际构建 | `APPSWITCHER_OUTPUT="$HOME/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.0-local.app" scripts/build_app.sh` | arm64 Release0.4.0、图标/URLscheme/冻结源码记录齐全；ad-hoc签名，本地构建后隔时严格复验通过。local模式无生产服务/公钥，不能官网分发 |
| 商业Release组合 | 隔离local构建，`APPSWITCHER_CONFIGURATION=release`、`APPSWITCHER_COMMERCE_MODE=commercial` | 实际0.4.0包固定reserved HTTPS与一次性测试公钥、严格验签通过、无DEBUG专用Info键、拒绝开发API探针，Python签发fixture在包内Swift校验通过。仅验证打包组合与签名消费，没有启动GUI、访问该测试域、写真实Keychain或进行公证 |
| 数据恢复 | `scripts/verify_postgres_restore.py`，隔离PG17.11 | 2个随机新库，合成2账号/4购买/1退款/试用/续费/工单/条款；23张表全部行与14序列一致，均清理。初次恢复校验0.565s；安全边界修复后复验0.096s。是小数据逻辑恢复，不能推导生产RTO/RPO |
| 部署/CI | systemd、nginx、补偿timer与GitHub Actions代码 | 完成独立静态审阅；未在真实Linux/云部署，远端CI未执行，生产SMTP送达/日志告警/PITR未验证 |
| 仓库交付 | `python3 .framework/scripts/check_framework.py --root .`、`git diff --check` | 108个Markdown、0错误0警告，diff无空白错误；不以文档检查替代业务测试 |

恢复证据保存在忽略目录 `build/restore-rehearsals/0b4c0c9ca754/report.json` 与 `build/restore-rehearsals/2d5448681764/report.json`；后者注入PGHOSTADDR/PGSERVICE覆盖项后依然只执行本地。远程/带查询参数/非法临时库名的seed入口在写入前拒绝。客户端联调夹具、开发邮件、访问/刷新令牌及数据库不入库。

最终临时原生测试进程均已退出，网页测试账号已登出，仅清理本次localhost issuer SHA256命名空间的测试Keychain项；生产命名空间和用户其他Keychain未修改。Debug专用 `AppSwitcherUITestSupportDirectory` 隔离测试快捷键/使用统计并停用测试实例的全局热键注册，商业鉴权仍完整运行；Release忽略该入口。原安装0.3.2进程仍在运行，快捷键文件SHA256始终为 `ccfefee726015a78ca84604ae24fdfed10f44642593592b019820879b9d68a86`。官网本地预览保留在 `http://127.0.0.1:8000/`，明确演示付款不产生真实扣款。

## 独立审阅发现与整改

- 安全/业务审阅：大量旧待付款订单会饿死后续补偿；已改为持久化 next_check_at、5分钟处理租约、失败退避、PG skip_locked，101条队列回归通过。拒绝退款可能覆盖并发成功状态；已改账号锁+仅requested条件更新，退款成功终态保留；独立复验通过。
- PostgreSQL实际测试：SQLite不能暴露的nullable join `FOR UPDATE`失败；已限定锁主体并复验56/56。
- 发布审阅：实际编译架构和文件名可能不一致、长时间公证期间活动源码可能漂移；已强制arm64并读取Mach-O、构建前冻结/编译后核对、只使用签入包内的记录。签前摘要明确命名，不冒充最终二进制摘要。
- 真实打包：Bash3在set-u下空数组失败，改为非空参数数组；Documents/File Provider异步附FinderInfo致验签失败，正式裸App改在私有临时目录封装，包装前再次验签。同步目录内的本地失败候选不作为交付制品。
- 真实Mac UI：Foundation `URL.path`吞掉尾斜杠，误拒绝合法授权页；改为percentEncodedPath严格校验，补2项回归并实际热/冷回跳。ad-hoc重签后旧测试Keychain条目可能弹系统许可提示，测试仅清理自身localhost命名空间，不降低ACL；正式Developer ID升级路径另验。
- 恢复工具审阅：隐藏seed分支也必须校验loopback及严格随机库名，libpq环境默认值可能覆盖目标；已共用校验并清除覆盖项，负向mock和带污染环境实际恢复复验通过。
- 正式包服务地址续审：原先仍接受 `example.com` 子域、其他127/8地址和内网地址；已拒绝示例域和非公网IP，补齐Foundation与urllib对编码主机的解释差异、缩写/八进制/十六进制数字IP、非法DNS标签和端口。独立审阅给出的11个反例均已拒绝，正常HTTPS443与本地reserved HTTPS仍接受。规则不联网、不证明域名所有权或服务已部署。

商业Release组合的脱敏记录位于 `build/commercial-release-configuration/report.json`，候选为 `~/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.0-commercial-release-check.app`；这是local/ad-hoc测试包，不是正式发布候选。当前运行服务仍明确为development、微信/支付宝均禁用、模拟开启、正式下载不可用；签名身份复查仍为0个有效身份。

真实浏览器价格/条款故障注入证据位于 `build/browser-fault-injection-3c8023e904/report.md` 及同目录响应状态、数据库计数、前端源码SHA记录。隔离副本的模板/JS/CSS与主源码逐字节相同；主站仍为900/2400/7800分、条款2026-09-25。两个测试账号均已退出，临时session计数0、8017监听停止，测试标签关闭；含密钥/邮件/数据库的临时代码/runtime已删除，仅保留脱敏证据，无需修改产品前端源码。

## 交付与未完成项

已实现官网与账号、手动月季年购买及续费领域、双渠道适配、签名离线授权、订单/退款/工单与运营后台、Mac账号体验、正式分发脚本、部署与恢复入口。用户现有 `~/Applications/AppSwitcher.app` 0.3.2及快捷键/使用数据保持；新商业候选隔离，不把没有生产服务的版本强行替换到日常使用路径。

尚需实际域名/HTTPS与云PostgreSQL、SMTP和客服/主体公开信息；Apple Developer/Developer ID及公证凭据；微信Native/支付宝电脑网站支付产品权限与受控配置。条件具备后执行每个开放渠道真实小额购买→权益同步→续费→退款→对账，以及独立Mac从正式下载入口安装/升级/权限/首次切换验收。正式域名变化需重新生成并固定客户端服务源/授权公钥。

现有WorkBuddy原始失败未复现、第三方App/多屏/Space/全屏/性能完整矩阵沿用FEAT-001遗留。Windows、海外、自动扣款仍后置；20–30名首批用户及真实续费意愿属于上线后验证，未发生。
