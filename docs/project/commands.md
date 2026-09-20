# 命令索引

本文件记录命令来源和验证状态。业务工具尚未配置，不执行猜测的安装、测试或部署命令。

| 操作 | 实际命令/来源 | 验证状态 |
| --- | --- | --- |
| 文档与快照检查 | `python3 .framework/scripts/check_framework.py --root .` | 生成器提供；本项目已执行，0 错误 |
| 安装 | Xcode 工程依赖（无第三方包，待 TKT-002 建立） | 未配置 |
| 本地开发 | `xcodebuild` / Xcode Run（待 TKT-002 建立工程） | 未配置 |
| 格式/静态分析/类型 | SwiftFormat / SwiftLint / `swift build`（待选型落地） | 未配置 |
| 单元/集成/合同测试 | `xcodebuild test` 或 Swift Testing（待 TKT-002） | 未配置 |
| E2E/无障碍/性能/eval | 手动端到端用例见 [QA-001](../features/FEAT-001-app-switcher/test-plan.md) | 未配置 |
| 构建/发行包 | `xcodebuild archive`（ad-hoc 签名，TKT-007） | 未配置 |
| 发布/迁移/回退 | 个人使用，无服务端；发布记录见 feature 目录 | 未配置 |

选型完成后，每项填写执行目录、工具/版本来源、必要变量名称、预期结果与最近核验。秘密值不入库。CI 必需检查在仓库平台设置中实际启用；此模板不会启用分支保护。
