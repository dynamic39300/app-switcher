---
id: REL-001
status: ready
owner: "AppSwitcher 项目 owner（待填姓名）"
upstream: [SPEC-001]
---

# REL-001：App 切换器发布记录

上游：[TRACE-001](traceability.md)、[QA-001](test-plan.md)；规则：[运行规范](../../../.framework/docs/standards/operations.md)。

## 版本与范围

- 源 commit：见 git 历史（TKT-001 `c9e8053` → TKT-002 `9e2f893` → TKT-003 `072407d` → TKT-004/005/007 本次提交）。
- 制品：`build/AppSwitcher.app`（SwiftPM release 构建 + 自签名 `AppSwitcher Dev`）。
- 版本：0.1.0；bundle id `com.appswitcher.app`；macOS 15+；Apple Silicon。
- 对应 Tickets 与 AC：TKT-001~007；AC-01~AC-10（AC-09 热键配置 UI 部分未完成）。
- 用户可见变化：全新本地工具。不包含：窗口真实标题（需屏幕录制 + Developer ID 签名）、热键配置 UI、中文名首字母映射。

## 发布条件与授权

- 环境：本机（个人使用）。操作人：owner 本人。无对外分发授权。
- 必要审阅/证据：`swift run CoreTests` 29 项通过；`.app` 启动成功、热键注册=true。
- 权限：辅助功能（已授权）；屏幕录制（可选，用于窗口真实标题，当前自签名不可得 → 降级「窗口 N」）。

## 操作与恢复

- 启动：`open build/AppSwitcher.app`（菜单栏 agent，无 Dock 图标）；菜单栏图标菜单可退出。
- 打包：`./scripts/build_app.sh`。
- 单测：`swift run CoreTests`。
- 恢复：菜单栏「退出 AppSwitcher」或 `pkill -f AppSwitcher`；删除 `build/AppSwitcher.app` 即移除，无数据/外部副作用。

## 验收证据

| 阶段 | 版本/环境/操作者/时间 | 真实结果 | 证据/问题 |
| --- | --- | --- | --- |
| 候选验证 | macOS 26.6.2 / CLT Swift 6.3.3 / 2026-09-20 | `swift run CoreTests` 29 项全通过 | 输出「✅ 全部通过：29 项」 |
| 构建 | 同上 | `swift build` + `build_app.sh` 成功，自签名成功 | `build/AppSwitcher.app` 生成 |
| 启动 | 同上 | `open` 启动成功，`[main] AppSwitcher 0.1.0 启动，热键 ⌃⌥+Space 注册=true` | 日志 `/tmp/appswitcher.log` |
| 上线后关键旅程 | 待 owner 验收 | 待执行：热键唤出覆盖层、按键切换、Esc 取消、跨桌面 | 待产生 |

状态链：`planned → ready → released → verified`。当前 `ready`，owner 端到端验收后置 `released/verified`。
