# 命令索引

## 0.5.2 微信文章浏览器修复（2026-09-30，当前本机版）

当前安装 `/Applications/AppSwitcher.app`，0.5.2 Release/local，保留个人设置。`--verify-app-activation` 现为 10 项，新增同可执行文件 accessory 共存及内核启动标识回归。Debug 与候选 Release 10/10，CoreTests 112/112；精确窗口探针在新旧版本均有焦点断言失败，真实文章页最终复测待 owner。构建、安装、摘要、回退和验证边界见[0.5.2 交付](../features/FEAT-001-app-switcher/wechat-browser-fix-0.5.2.md)。下列 0.5.1 及更早记录为历史。

## 当前：0.5.1 本机测试版已安装运行（2026-09-28）

唯一活动安装位于 `/Applications/AppSwitcher.app`，从 `~/Downloads/AppSwitcher-0.5.1-local-test-20260928.dmg` 实际提取并启动；旧的系统与个人 Applications 副本均已移入备份。启动：`open /Applications/AppSwitcher.app`。面板使用现有保存的唤出键（本机安装时为 ⌘E），顶部有「设置」，面板内 `⌘,` 打开同一设置窗；应用模式鼠标移到卡片上会显示独立退出叉。当前不含显示桌面按钮。本机包为 Release/local/arm64、ad-hoc 签名、未公证，不能当作官网正式分发包。安装、验证与回退见[0.5.1 本机交付](../features/FEAT-001-app-switcher/local-utility-release-0.5.1.md)。以下为历史命令和记录，不代替当前安装核对。

## 0.5.0 图标拖拽与唤醒引导（2026-09-27，历史）

已从本地 DMG 安装 `~/Applications/AppSwitcher.app` 并启动。安装时读取的当前组合为 ⌘J、F→J 开启，主题石墨；本轮安装不改这些设置。应用模式中拖到空键移动、拖到已有图标的键交换，落位后自动保存；“不再提示”跨重启保留，顶部手形菜单可重播/重新开启及恢复默认键位。键位独立存于 `~/Library/Application Support/AppSwitcher/key-mapping.json`，窗口模式不保存临时窗口键位。

- 构建：`APPSWITCHER_OUTPUT="$HOME/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.5.0-preview.app" ./scripts/build_app.sh`
- 隔离交互：`"$HOME/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.5.0-preview.app/Contents/MacOS/AppSwitcher" --preview-key-drag build/previews/0.5.0-drag-fixture`。只用合成目标，独立偏好，不激活真实应用；夹具忽略取消，以该测试进程的 SIGTERM 结束，不用于正常启动。
- 原生布局：`--verify-appearance` 27 项；`--render-preview build/previews/0.5.0-final` 三主题各 19 个场景，共 57 张。
- 安装包：`~/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.5.0-local-preview.dmg`。自签名、未公证、未发布官网；命令与验证明细见[交付记录](../features/FEAT-001-app-switcher/key-drag-2026-09-27.md)。

## 0.4.3 满版黑底图标（2026-09-27，历史）

当前安装 `~/Applications/AppSwitcher.app`，版本 0.4.3 local，启动：`open "$HOME/Applications/AppSwitcher.app"`。黑色背景覆盖整个图标，Finder 简介与列表已目视确认没有原先浅色外框；三主题及快捷键配置保持。新 DMG：`~/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.3-local-preview.dmg`，使用 `bash scripts/package_local_preview.sh <local.app> <new-output.dmg>` 生成，自签名、未公证。实际检查、摘要与回退见[图标记录](../features/FEAT-001-app-switcher/icon-full-bleed-2026-09-27.md)。

## 0.4.2 三套原生主题（2026-09-26，历史）

当时安装 `~/Applications/AppSwitcher.app`（0.4.2 local、自签名），现已更新为上方 0.4.3。按已保存的 ⌘E 唤出，面板顶部点击「石墨 / 银瓷 / 烟晶」，或面板内按 ⌘1 / ⌘2 / ⌘3 即时切换并保存；换主题无需重启。外观独立存于 `~/Library/Application Support/AppSwitcher/appearance.json`，快捷键文件不改。原 0.4.0 预览副本已退出但保留可回退。

`--verify-appearance`：25 项隔离偏好与布局检查。`--verify-overlay-drag`：本轮单屏 33 项含主题回归。`--render-preview build/previews/0.4.2-themes-final`：三主题子目录各 16 张共 48 张。安装制品、实际唤起、失败首证与未测范围见[主题交付记录](../features/FEAT-001-app-switcher/appearance-themes-2026-09-26.md)。本地 DMG 在 BuildCandidates 的 `AppSwitcher-0.4.2-local-preview.dmg`，未公证，未上传官网。

以下 0.4.0 及更早记录为历史，不代表当前运行版本。

## 2026-09-26 本机运行状态

最新预览包已加入鼠标拖动：按住标题、空白背景、空键位或底部说明可移动并跨屏，松手时适配目标屏，本轮切模式不复位。已原路径更新并重启；最终制品与双屏实测见 [TKT-015](../features/FEAT-001-app-switcher/panel-drag-2026-09-26.md)。

当前本机运行 0.4.0 local 预览包：`open "$HOME/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.0-preview.app"`。录制反馈修复包已签名、替换并重启，唤出快捷键已通过设置保存为 `⌘E`，重启后的实际录制、保存与全局唤起验证通过；F→J 开关保留 true，完整手势未复验。更改入口是菜单栏 →「快捷键设置…」→ 点击组合键录制 → 保存。制品、备份及验证边界见 [TKT-014](../features/FEAT-001-app-switcher/shortcut-recovery-2026-09-26.md)。

下表 `~/Applications/AppSwitcher.app` / 0.3.2 为历史安装记录，本机目前没有该安装副本，不应按这些记录推断当前版本或快捷键。

## 项目与历史命令

工具链：Swift 6.3.3、macOS 26.6.2、Apple Silicon；SwiftPM，最低目标 macOS 15。所有命令从项目根执行。实际检查结果见 [QA-001](../features/FEAT-001-app-switcher/test-plan.md)。

| 操作 | 命令 | 说明 |
| --- | --- | --- |
| 文档检查 | `python3 .framework/scripts/check_framework.py --root .` | 不代替业务测试 |
| Debug 构建 | `swift build` | Core、Kit、原生 App 和测试运行器 |
| 规则回归 | `swift run CoreTests` | 纯合成数据，不操作用户应用 |
| 合成 UI 渲染 | `.build/debug/AppSwitcherApp --render-preview build/previews/0.3.1` | 应用/窗口/空/失败/加载/窄屏/38键/短屏，以及笔记本/大屏/超宽屏/窄短屏38窗，以及中宽短屏38窗/大屏应用/缺图标，共十六场景；不启动热键、统计或读取用户窗口 |
| 快捷键设置预览 | `.build/debug/AppSwitcherApp --render-settings-preview build/previews/0.3.0/settings` | 默认、录制、冲突、草稿四种合成状态；不注册热键或监听按键 |
| 隔离快捷键注册验证 | `.build/debug/AppSwitcherApp --verify-shortcuts` | 注册四修饰 F17–F19，真实跨进程排他冲突、写入失败回滚、暂停恢复及释放；不生成键盘事件。非排他注册检测边界以 NOTE 单独记录 |
| 面板拖动验证 | `.build/debug/AppSwitcherApp --verify-overlay-drag` | 显式生成鼠标/定向键盘事件，只操作合成面板；验证拖动、双屏适配、更新保持与按钮/键盘回归。需系统事件发送权限，未授权 exit 2；单屏会说明未执行实际跨屏；Release 包支持同入口 |
| 隔离 AX 集成 | `.build/debug/AppSwitcherApp --verify-window-switching` | 父子进程仅控制本工具创建的合成窗口；0=通过、1=失败、2=权限不足跳过，跳过不是通过；不自动申请权限 |
| 隔离应用唤起回归 | `.build/debug/AppSwitcherApp --verify-app-activation` | 在临时目录创建独立合成 App，验证同包 helper 下四种窗口状态及同 exe 真多实例拒绝；不操作用户应用 |
| 隔离应用退出回归 | `.build/debug/AppSwitcherApp --verify-app-quit` | 在临时目录创建普通合成 App；验证进程身份拒绝、目标取消正常退出、随后实际结束以及提示不抢焦点；不操作用户应用 |
| 本地 release 打包 | `./scripts/build_app.sh` | 临时目录组装签名后复制到 `build/AppSwitcher.app` 并严格验签，优先 `AppSwitcher Dev` 自签名，否则 ad-hoc；不是对外发布/公证 |
| 本机非同步目录打包（构建记录） | `APPSWITCHER_OUTPUT="$HOME/Applications/AppSwitcher-0.3.1.app" ./scripts/build_app.sh` | TKT-012 实际执行的历史候选构建命令；该包随后改名安装到 `~/Applications/AppSwitcher.app`。避开 Documents 后续附加 FinderInfo 的问题 |
| 制品 App 唤起验证 | `"$HOME/Applications/AppSwitcher.app/Contents/MacOS/AppSwitcher" --verify-app-activation` | 验证最终安装的 Release；四种合成窗口状态加真多实例，共五场景，不代表第三方现场验收 |
| 制品 AX 验证 | `build/AppSwitcher.app/Contents/MacOS/AppSwitcher --verify-window-switching` | 验证打包后的 Release；测试范围和退出码与 Debug 相同 |
| 最终候选 AX 验证（历史记录） | `"$HOME/Applications/AppSwitcher-0.2.0.app/Contents/MacOS/AppSwitcher" --verify-window-switching` | 已执行通过；保留当时命令路径，当前安装位置见启动行 |
| 启动 | `open "$HOME/Applications/AppSwitcher.app"` | 当前正式安装位置，0.3.2；先退出已有实例。按已保存组合唤出，也可菜单「显示切换器」；快捷键设置可开关 F→J |
| 直接打开切换器 | `open "$HOME/Applications/AppSwitcher.app" --args --show-switcher` | 对新启动实例生效；复用菜单显示入口，与 `--show-settings` 同时传入时设置优先 |
| 直接打开设置 | `open "$HOME/Applications/AppSwitcher.app" --args --show-settings` | 对新启动实例生效；已运行时使用菜单栏「快捷键设置…」或面板齿轮 |
| 制品快捷键验证 | `"$HOME/Applications/AppSwitcher.app/Contents/MacOS/AppSwitcher" --verify-shortcuts` | 实际隔离注册与回滚验证，范围同 Debug |
| 退出 | 菜单栏 → 退出 AppSwitcher | 不使用模糊进程名批量终止 |
| 缓存路径迁移恢复 | `swift package clean`，再 `swift build` | 仅在预编译缓存引用旧仓库绝对路径等情况下使用，删除可重建构建缓存 |

框架、纯函数与合成原生窗口测试分别验证不同层次；不能据此声明 ClassIn/微信/Chrome、跨 Space、全屏或 150ms 延迟已验证。窗口标题与屏幕内容不进入日志/测试产物，合成预览除外。

2026-09-24 首次替换历史：旧 PID 8959 正常退出，重复构建包及 `build/AppSwitcher 2.app`（0.1.0）移入废纸篓；保留 `build/backups` 和 `usage.json`。正式路径签名有效、版本 0.2.0，启动后的单一 PID 63063 已进入 AppKit 事件循环并执行统计回调。未修改登录项、启动项或系统权限；菜单栏 UI 工具定位超时，未宣称安装后面板已目视验收。详情见 [REL-001](../features/FEAT-001-app-switcher/release.md)。

同日 TKT-010 修复后已更新为 0.2.1，正式安装路径不变，当时单一 PID 71639。新 Debug / Release App 四状态及 AX 测试通过；旧 0.2.0 已备份到 `~/Library/Application Support/AppSwitcher/backups/AppSwitcher-0.2.0-20260924.app`。启动日志确认备用热键注册成功；新版面板自动化定位超时，Spotify 现场 S 验证待用户重试，不记为通过。

同日 TKT-011 将面板调整为屏幕可用宽92% / 高82%，删除应用卡片重复副标题。0.2.2 当时已安装并重启，单一 PID 75949；13种合成视觉、Debug/Release构建及严格验签通过。0.2.1备份位于 `~/Library/Application Support/AppSwitcher/backups/AppSwitcher-0.2.1-20260924.app`，使用数据保留。

同日 TKT-006 自定义快捷键已升级为 0.3.0，正式路径保持不变，最终 PID 82431。菜单栏或面板齿轮打开设置，录制、保存后生效。真实窗口观察到用户保存 ⌘E 并关闭 F→J，重启保持配置且组合注册成功。默认 ⌃⌥Space 与本机启用的系统快捷键冲突，因此保留用户的新组合；未改系统设置。旧 0.2.2 保留在 AppSwitcher/backups；实际范围见 REL-001。

格式/静态工具尚未接入 swift-format / SwiftLint；目前使用编译器检查与 `git diff --check`。现有 `CoreTests` 是最小 Swift 可执行测试运行器；未迁移 XCTest/Swift Testing。0.3.x 阶段未配置正式分发与 CI；0.4.0 已增加脚本和工作流，真实 Developer ID / 公证及远端 CI 结果仍未取得。秘密值不入库。

2026-09-25 TKT-012 图标放大与多分辨率准备已升级至0.3.1，最终PID17459；16种合成视觉、Debug/Release构建及严格验签通过。用户⌘E/FJ关闭配置逐字节保留，旧0.3.0备份与SHA见REL-001。

2026-09-25 TKT-013 将同包不同可执行文件 helper 排除于主实例歧义计数，0.3.2 已安装，最终 PID98688。实际构建命令 `APPSWITCHER_OUTPUT="$HOME/Applications/AppSwitcher-0.3.2.app" ./scripts/build_app.sh`；Debug/Release应用探针5/5、CoreTests75项、签名及实际鼠标选择微信验证通过。⌘E配置保持，0.3.1备份与制品身份见REL-001。临时诊断包已退出并移至废纸篓。

## 0.4.0 商业闭环开发与验收

实际范围及结果见 [QA-002](../features/FEAT-002-commercialization/verification.md)。Python 3.12.14、Django 5.2.17、PostgreSQL 17.11；Python 依赖以 `web/uv.lock` 冻结。当前用户安装版仍为 0.3.2，开发候选不替换它。

| 操作 | 命令 | 说明 |
| --- | --- | --- |
| 冻结依赖 | `uv sync --frozen --project web` | uv 0.12.5；不把开发环境目录入库 |
| 本地初始化 | `uv run --frozen --project web python web/manage.py migrate`；`uv run --frozen --project web python web/manage.py init_development` | 仅本地配置；开发密钥/文件邮件在被忽略的 `.runtime` |
| 官网预览 | `SIMULATED_PAYMENTS=1 uv run --frozen --project web python web/manage.py runserver 127.0.0.1:8000 --noreload` | 演示支付明确标识；不发送真实验证码邮件、不收款 |
| 一般本地检查 | `./scripts/check_commerce.sh` | SQLite 会跳过 PG 并发测试；单独 PG 结果不可省略 |
| 真实PG事务测试 | `uv run --frozen --project web python web/manage.py test commerce --noinput` | 先在隔离环境配置 `APPSWITCHER_ENV=test`、`DATABASE_URL`；含并发测试，不对生产数据库执行 |
| 商业签名/状态探针 | `.build/debug/AppSwitcherApp --verify-commerce` | 合成测试，不操作用户应用；Release 同入口 |
| Python到Swift签名联调 | `uv run --directory web python manage.py license_fixture .runtime/license-fixture.json`；`.build/debug/AppSwitcherApp --verify-commerce-fixture web/.runtime/license-fixture.json` | 本地临时夹具；不打印令牌 |
| 实际本地API联调 | `uv run --directory web python manage.py desktop_api_fixture .runtime/desktop-api-fixture.json`；`.build/debug/AppSwitcherApp --verify-commerce-api web/.runtime/desktop-api-fixture.json` | localhost服务需运行；一次性夹具；Release拒绝开发API探针 |
| 账号状态预览 | `.build/debug/AppSwitcherApp --render-commerce-preview build/previews/0.4.0/account` | 8 个合成原生场景，不启动热键或使用统计 |
| 发布边界测试 | `python3 scripts/test_app_bundle.py` | 10项；缺配置/示例或非公网源/解析绕过/非法端口/输出保护/源码漂移拒绝 |
| 隔离本地Release包 | `APPSWITCHER_OUTPUT="$HOME/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.0-local.app" ./scripts/build_app.sh` | 非同步目录；local模式、自签或ad-hoc，不能对外发布 |
| 正式分发 | `./scripts/release_macos.sh` | 必需变量和独立Mac验收见运行手册；实际身份就绪前拒绝执行 |
| 本地备份恢复演练 | `uv run --frozen --project web python scripts/verify_postgres_restore.py --pg-bin <PG工具目录>` | 仅test+loopback；自建/清理随机临时数据库，不接受远程或生产地址 |
| 生产配置检查 | `uv run --frozen --project web python web/manage.py check --deploy --fail-level WARNING` | 须使用真实production配置，不能拿development检查充数 |
| 支付补偿与清理 | `uv run --frozen --project web python web/manage.py reconcile_payments`；`uv run --frozen --project web python web/manage.py purge_expired_auth` | 渠道确认后幂等处理；生产调度模板见deploy目录 |

正式域名/公钥、支付/邮件与部署细节见 [商业运行手册](../runbooks/commercial-release.md) 和 [web README](../../web/README.md)。
