# 当前架构与技术选型

状态：2026-09-24 TKT-009 已完成本地实现与隔离验证；TKT-010 的 App 正常窗口呈现修复通过受控 Debug / Release 验证，TKT-011 自适应面板已随 0.2.2 本机更新。TKT-006 自定义唤出组合键已随 0.3.0 完成本地实现、注册回滚验证及本机安装，真实保存与重启注册已观察。新版 Spotify 现场和完整第三方 App 兼容矩阵仍待验收。采用 [架构规范](../../.framework/docs/standards/architecture.md)。

## 输入约束

- 用户任务：唤出键盘面板 → 选择 App；需要具体窗口时按 Tab 切换窗口模式。
- 业务不变量：候选是 `.regular` 且非自身的运行进程；App 默认一进程一键；窗口展开必须同时满足可控制和可辨认条件。
- 范围：macOS 15+、Apple Silicon；单机单用户、最多 38 个映射目标；无账号、无网络。
- 延迟：App 覆盖层显示目标 ≤ 150ms，尚未完成本轮实测；跨进程 AX 查询异步执行并限制超时，不阻塞初次 App 面板。
- 隐私：统计持久化 app 身份和计数，快捷键配置单独保存组合与 F→J 开关；窗口标题只在内存快照使用，AX 对象只保留短期引用。设置录制限本窗，日志、统计与配置不包含标题或逐键输入记录；不取屏幕内容。

## 选择记录

| 能力 | 当前选择 | 理由与边界 |
| --- | --- | --- |
| 工程与 UI | SwiftPM + CLT；SwiftUI 内容、AppKit 菜单栏 agent / NSPanel | 现有 `Package.swift` 与 `Sources/` 是实际工程；本地打包用仓库脚本，分发签名与公证仍单独验收 |
| 模块 | `AppSwitcherCore` → `AppSwitcherKit` → `AppSwitcherApp` | Core 的候选与分配是纯值规则；Kit 封装系统访问；App 编排 UI 和激活 |
| 触发 / 设置 | 可配置 Carbon 组合键（默认 `⌃⌥Space`）+ 可开关的既有 F→J；独立原生设置窗 | TKT-006 实现中：局部录制、注册与写入失败回滚；检测已知保留 / 已启用系统组合和 Carbon 排他冲突，不保证发现第三方非排他注册 / 事件监听 / 局部快捷键。F→J 依赖输入监控，覆盖层和录制使用独立暂停原因，不自定义无修饰双字母 |
| App 激活 | 唯一目标安装路径的 `NSWorkspace.openApplication` reopen → PID / 启动时间核对 → yield / 原进程 activate | 修复单纯前台 PID 正确却无可见窗口的问题；窗口由 App 正常打开行为决定，多实例不猜测重开，不批量 AX 恢复，见 TKT-010 |
| 窗口能力与控制 | 公开 AX 枚举 + 短期对象注册表 + 不透明 token | 标题负责辨认，token 回到同一 AX 对象负责控制；不按标题或 CG ID 猜测连接，不用私有 API |
| 聚焦确认 | 读回 frontmost PID 与 AX focused window | 窗口动作返回成功不能替代实际焦点相等；读回失败明确反馈 |
| 生命周期 | 覆盖层会话快照 + 异步探测 + 会话代次 | 查询超时/取消/迟到不能改变另一轮面板、替换已展示按键或触发隐式切换 |
| 数据 | 现有 `usage.json` 统计；TKT-006 新增独立 `shortcuts.json` 配置 | `ShortcutController` 协调、`ShortcutStore` 原子保存；保存前校验并协调 Carbon 注册，失败保留旧值。缺失 / 损坏 / 无效值提供默认降级与恢复入口，合法保存键占用时提示且不静默改键；不改统计，无窗口 token / 标题入 schema |

详细契约见 [DESIGN-001](../features/FEAT-001-app-switcher/design.md)，关键取舍见 [ADR-0001](../adr/0001-capability-based-window-switching.md)，兼容边界和旧判断修正见 [RES-002](../features/FEAT-001-app-switcher/multi-window-research-2026-09-24.md)。实际命令和版本证据由[命令索引](commands.md)与 [QA-001](../features/FEAT-001-app-switcher/test-plan.md)维护。

## FEAT-002 商业服务扩展（2026-09-25）

早期无账号/无网络描述保留为 0.3.2 本地基线。用户授权后新增 Django 单体服务、PostgreSQL生产存储、原生网站，以及 Mac 账号/Keychain/固定公钥离线验证模块。窗口控制仍本机执行，窗口标题、按键、使用统计不上网。商业制品须通过授权门禁，开发本地版与正式分发配置隔离。结构、威胁和接口见 [DESIGN-002](../features/FEAT-002-commercialization/design.md)、[CONTRACT-002](../features/FEAT-002-commercialization/contract.md) 和 [ADR-0002](../adr/0002-commercial-service-and-local-license.md)。实际完成范围以 QA-002 为准。
