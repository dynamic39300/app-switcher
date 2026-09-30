# 0.5.1 设置与正常退出本机测试交付

2026-09-28。用户要求先将已完成的两个功能打新包，卸载旧包并安装启动。本次仅做本机 local 预览交付；“显示桌面”仍未实现，未声明三项功能全部完成。

## 制品与安装事实

- 源版本：`VERSION=0.5.1`；HEAD `efa255da9681f58be7d73a06a58a4685cf492ece` 加未提交工作区变更，构建内记录 `workingTreeModified=true`、`sourceSHA256=45e3342da34308efed2498fca4d32dd091104367272724c8e4187c94f0a6298a`。
- DMG：`/Users/eeo/Downloads/AppSwitcher-0.5.1-local-test-20260928.dmg`，3,582,595 字节，SHA-256 `916a58016ce04196c07eef284fdae79dba83b8cc7e9fd661225727e6e870a51a`。Release/local/arm64、ad-hoc 签名，未公证；仅本机测试，不是可公开分发的正式版。
- 从 DMG 只读挂载并提取应用后验签、核对版本与 `local` 模式；包内与提取后可执行文件 SHA-256 均为 `6b7b949bda828d185ededde06976f8aea37ec3b686ab506586902442e2e08ac7`。安装使用这份提取的应用，最终 `/Applications/AppSwitcher.app` 的摘要一致。
- 正常请求退出旧 PID 27087，并确认进程结束；原 `/Applications/AppSwitcher.app` 与 `~/Applications/AppSwitcher.app` 都是 0.5.0 且可执行文件摘要相同，已分别移至 `~/Library/Application Support/AppSwitcher/InstallBackups/20260928-0.5.1/Previous-system-AppSwitcher-0.5.0.app` 与 `Previous-personal-AppSwitcher-0.5.0.app`。目前两个 Applications 目录合计只保留系统目录的一份 AppSwitcher；没有删除用户设置和键位偏好。
- 安装后严格验签成功，`open /Applications/AppSwitcher.app` 启动；工作区回读 PID 55322、路径 `/Applications/AppSwitcher.app`、未终止。为了打开正常面板做现场界面核对，又正常退出并以 `--show-switcher` 重启，最终运行实例可能有新 PID，实际路径仍为 `/Applications/AppSwitcher.app`。

## 验证与边界

- `swift run -c release CoreTests`：112/112；项目框架检查：125 个 Markdown、0 错误/警告。
- 构建后的 Release `--verify-appearance` 27 项通过；`--verify-app-quit` 的过期身份、错误 bundle、取消退出、提示焦点及精确实例退出均通过；`--verify-app-activation` 5/5；`--verify-overlay-drag` 的设置按钮、`⌘,`、应用叉不冒泡与三主题/跨屏回归均通过。验证使用隔离合成应用，没有退出任何用户应用。
- 最终安装的 0.5.1 正常面板通过原生 UI 可访问性树和截图读到顶部「设置」、应用模式卡片「退出…」控件及键盘布局；界面已可供用户现场操作。未在用户真实第三方应用上点击退出叉，目标应用的保存/放弃/取消提示仍待用户体验验收。因面板关闭后 UI 绑定超时，未把设置窗口现场打开视为已验收；自动化回调检查已通过。
- 打包、安装及进程启动不等于长期稳定性或正式发布验收。当前 local 包不要求登录、未设置授权到期；Apple Developer ID 签名、公证、另一台 Mac 的首次安装、正式支付仍未完成。

## 使用与回退

打开 `/Applications/AppSwitcher.app`；本机保存的唤出组合为 `⌘E`，唤出后点顶部「设置」或按 `⌘,`。应用模式下鼠标悬停目标卡片，点击右上角叉请求该应用正常退出；若目标弹出保存提示，由目标应用负责。没有“显示桌面”按钮。

若需回退，先从菜单栏正常退出 0.5.1，再把当前应用移出 `/Applications`，将上述 `Previous-system-AppSwitcher-0.5.0.app` 复制回 `/Applications/AppSwitcher.app` 并启动。个人配置仍保留，不需清除 `~/Library/Application Support/AppSwitcher/`。本次没有执行回退演练。
