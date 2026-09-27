# TKT-017：三套原生外观主题

状态：done（实现、本机验证与本地安装）；风险 medium；2026-09-26 owner 接受三套方案并要求在软件界面切换。范围为原生覆盖层，不是官网主题或再次交付浏览器原型。依赖 TKT-015 / TKT-016；AC-10 / AC-14 / 新 AC-15。

## 契约 / AC-15

面板顶部提供石墨机械、银瓷工作台、烟晶控制台三个直接按钮；即时切换，当前主题具有选中语义。面板内 ⌘1 / ⌘2 / ⌘3 提供同等入口，不注册额外全局快捷键。主题不影响键位映射、目标、模式、加载代次或面板外框，不改变 ⌘E 等已有用户唤出设置。

首次为石墨。偏好仅存 `~/Library/Application Support/AppSwitcher/appearance.json`，schema `{version:1, style:"graphite"|"porcelain"|"smoke"}`。保存后生效，失败保留旧主题并显示错误。缺失使用默认；未知版本、未知样式、损坏文件只提示且不覆盖，用户明确选主题才修复。重开和重启恢复，回退旧版忽略该文件。无窗口标题、按键日志或网络数据。

三套采用已确认原型六个材质色（石墨 #171B22、钛灰 #343B46、银瓷 #ECEEF0、墨色 #26313D、冰蓝 #9CCFFF、烟晶 #213F48）；正文 SF / 苹方，键标 SF Mono。原生系统字体代替网页展示标题字体；主界面不增加宣传文案。布局：A 完整键盘 + 底部目标；B 宽高足够时增加顶部目标；C 宽屏左侧目标 + 右侧键盘。窄短屏自动省略额外目标区，底部目标保留。数字行出现时提高侧栏所需宽度，保持 38 键能力与键盘区滚动。

按压按钮顶面与内容一起移动，A/B/C 键程分别 3/4/2pt，60ms 按下 / 150ms 回位；阴影随侧壁收拢。减少动效不位移，仅静态边界反馈；增强对比度强化边框。物理键即刻提交目标，不为了显示动画而延迟切换。无模拟触觉或声音。键帽、模式、主题、设置和关闭按钮不触发窗口拖动；标题、底部、空键和非操作背景继续可拖动。

## 实现与验证计划 / TEST-018

`OverlayAppearanceStore` 管理 UI 专属原子偏好；`OverlayStyle` 定义稳定标识及布局阈值；`OverlayPalette` 与 `MaterialKeycapStyle` 定义材质。保持既有 Core ← Kit ← App 依赖，不新增包或服务。其他窗口继续使用已有 OverlayTheme，避免无关页面一起换色。

需验证：三种保存与重新读取、损坏/未知/写失败保护；三主题合成应用/窗口/38键/窄短/加载/空/失败预览；真实合成面板点击换色、键盘换色、框架不移动、选择不变化、拖动和激活回归；Debug/Release、CoreTests、签名包和实际安装状态。未完成不得写已安装。原型作为设计历史保留，不进入 App 的构建资源。

## 已执行检查

- Debug 构建通过，无警告；`swift run CoreTests` 75/75。
- `--verify-appearance`：Debug / 0.4.2 签名 Release 各 25/25，使用独立临时目录；`--verify-shortcuts` 签名 Release 20/20，不写用户配置。
- Debug `--verify-overlay-drag`：33/33，包括单屏拖动、主题鼠标按钮、⌘1–3、映射/选择/框架保持、模式/设置/关闭。当前只有一个显示器，明确跳过实际双屏拖动；保留纯几何夹具覆盖。不能把历史双屏结果当本轮复测。
- `--render-preview build/previews/0.4.2-themes-final` 输出三主题 × 16 场景 = 48 PNG。目视检查三款正常应用、浅色窄短窗口、烟晶 38 键、石墨加载等代表场景；并非逐张完整验收。首轮发现键帽阴影作用到文字，加入 compositingGroup 后重新生成，确认浅色文字恢复清晰。
- `python3 scripts/test_app_bundle.py` 11/11；文档检查 117 Markdown、0 错误、0 警告；`git diff --check` 通过。
- 0.4.2 Release 构建与 `AppSwitcher Dev` 自签名成功，候选位于 `~/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.2-preview.app`；复制到此前不存在的 `~/Applications/AppSwitcher.app`，最终路径严格验签与 `--verify-branding` 通过。可执行文件 SHA256：`e2cf2dee67817d215ec4d6a0c55b08f456bd2800da142d69911ab9283be2f195`。

首次失败保留：签名包交互探针第一次报告 synthetic panel missing，第二次在标题拖动前报告 lost focus，均停止发送后续事件，不判产品通过。当时仍有旧版/合成渲染及另一签名检查进程；之后退出旧版、结束渲染，改为最终安装路径单独串行验证，结果另记。未据这些失败推定确切因果。

本轮为同一 Agent 自审，无独立审阅。未测完整 VoiceOver、200% 放大、所有系统减少动效/增强对比度组合、真实第三方激活、跨 Space 与延迟目标；实现了相关语义/动效分支但不据此宣称系统验收完成。

## 最终本机交付

最终安装路径的签名 Release `--verify-overlay-drag` 串行运行 33/33 通过。旧 0.4.0 PID 39174 正常退出，未删除旧包；当前运行 `~/Applications/AppSwitcher.app` 0.4.2，PID 52518，启动输出辅助功能=true、组合快捷键注册=true，F→J 按原配置开启。

实际启动后第一次短时采样未见面板，按 diagnosing-bugs 建立有隐藏前置条件的唤起检查，而不是盲目反复切换同一热键。进程采样显示正常 AppKit 事件循环，无启动阻塞；原配置未改，后续实际唤起已经成功。最终 `swift build/diagnostics/installed-appearance-smoke.swift` 明确先用定向 Esc 收起自身面板，再发送用户已保存的全局 ⌘E，两轮均观察到安装进程的可见面板并通过。该诊断不读取窗口标题、不激活真实候选；没有据此虚构代码缺陷或修复。检查结束保留面板供 owner 预览。

用户 `shortcuts.json` 更新前后 SHA256 均为 `117e3fb6f27536e27519cae6224652f0eb4d3f5474dee66b0b65783ceb8d2054`。主题探针仅写自己的临时目录，未预设用户偏好；首次主题为石墨，后续由界面选择保存。

DMG：`~/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.2-local-preview.dmg`，hdiutil verify 通过；SHA256 `6abb4ddabe7d0af51495eebb39ae91bc54ad0e2523df7b3b3077829c54c4fea2`。包含最新版应用、Applications 链接、三主题操作说明；本地自签名，未公证，不是官网分发包。打包暂存保留于 `/var/folders/6_/ydsn99l150v407cbf2l9927c0000gn/T/AppSwitcher-local-dmg.V75hB4`，未删除用户文件。

回退：从菜单栏退出新版，打开仍保留的 `~/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.4.0-preview.app`；不要同时运行两个版本，不删除快捷键、使用数据或新的 appearance.json。0.4.1 品牌候选仍保留；品牌安装与 DMG 交付由本 0.4.2 合并完成。
