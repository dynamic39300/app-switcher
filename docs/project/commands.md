# 命令索引

本文件记录命令来源和验证状态。

| 操作 | 实际命令/来源 | 验证状态 |
| --- | --- | --- |
| 文档与快照检查 | `python3 .framework/scripts/check_framework.py --root .` | 已执行，0 错误 |
| 构建（Domain 库） | `swift build`（SwiftPM + CLT） | 已执行 |
| 单元测试 | `swift run CoreTests`（最小测试运行器） | 已执行，17 项通过 |
| 格式/静态分析/类型 | swift-format / SwiftLint（待接入） | 未配置 |
| spike 打包 .app | `spike/TKT-001/make_app.sh`（手工壳 + 自签名） | spike 验证通过 |
| 正式 .app 打包/签名/公证 | 待装 Xcode + Developer ID | 未配置 |
| 发布/分发 | 待装 Xcode + Apple 开发者账号 | 未配置 |

说明：无 Xcode 时 XCTest/Swift Testing 均不可用（XCTest 需 Xcode；Swift Testing 宏需编译器插件），单测走 `swift run CoreTests`。装 Xcode 后可将 `Sources/CoreTests/main.swift` 的测试逻辑平移为 Swift Testing。秘密值不入库。CI 检查需在仓库平台实际启用。
