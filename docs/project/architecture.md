# 当前架构与技术选型

状态：已选型、待实现。采用 [架构规范](../../.framework/docs/standards/architecture.md)。

## 输入约束

- 核心用户任务：唤出键盘形状覆盖层 → 识别键位 → 按键切换 App / 取消。
- 业务不变量：键位映射确定性；候选 = `.regular` 且非自身；本地无网络、无账号。
- 并发/数据规模：单机单用户；候选 App 数目标 ≤ 38。
- 延迟目标：覆盖层显示 ≤ 150ms。
- 隐私：仅本地存储 app 身份 + 激活计数/时间戳，不采集窗口标题与屏幕内容。
- 团队能力：单人，Swift/SwiftUI 能力待核验；预算无云资源（本地工具）。

## 选择记录

| 能力 | 候选与替代 | 选择理由 | 版本/支持窗口/核验来源 | Owner/退出代价 |
| --- | --- | --- | --- | --- |
| 应用与部署 | Xcode 原生 App（菜单栏 agent + NSPanel 覆盖层）vs SPM 可执行 | 签名/公证/打包标准链路 | macOS 15+、Apple Silicon；Swift 6.3.3 | 待填姓名；改 SPM 代价小 |
| 数据与身份 | 本地 JSON + UserDefaults；无账号/无服务端 | 单机工具、隐私最简 | Foundation | 待填；引入服务端需重新设计信任边界 |
| 模型或工具 | 不适用（无 AI 能力） | — | — | — |
| 全局热键 | Carbon `RegisterEventHotKey` vs NSEvent 监视器 | 免辅助功能、可冲突检测 | macOS 26 实测待 spike | 待填；退回 NSEvent 需辅助功能 |
| 激活 app | `NSRunningApplication.activate` + AX `kAXRaiseAction` 兜底 | 跨桌面可靠置前 | macOS 26 实测待 spike | 待填；若仅 AX 可行则辅助功能为硬前置 |

版本以实际锁文件和配置为准。首个纵向切片（TKT-001 spike）的验证结果：待执行。

## 当前态

模块边界、依赖方向（Domain 纯函数 ← Adapter ← Controller ← UI）、数据流与信任边界详见 [DESIGN-001](../features/FEAT-001-app-switcher/design.md)。重要历史决策链接到 [ADR](../adr/README.md)，不在本文件复制全部历史讨论。

当前无代码；候选代码路径 `src/`（或 Xcode 工程）将在 TKT-002 建立。
