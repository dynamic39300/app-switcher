# 0.5.2 微信文章浏览器切换修复

日期：2026-09-30。对应 TKT-020 / AC-05、AC-07 / TEST-022。实现及本机安装完成，真实文章页最终显示待 owner 复测。不是正式公证分发。

## 问题与定位

用户在应用模式点击 5 号微信浏览器，键盘面板闪回，未切到公众号文章页。现场只读进程元数据确认：`com.tencent.flue.WeChatAppEx` 同一个 bundle 与 executable 下同时存在 accessory 和 regular 进程，二者均无 LaunchServices launchDate。未记录文章标题或内容。

诊断采用现有 `AppActivationProbe` 的跨进程合成窗口，增加同可执行文件 accessory 进程，调用真实 `RunningAppsProvider.activate`。原逻辑结果：

```text
swift build --product AppSwitcherApp && .build/debug/AppSwitcherApp --verify-app-activation
FAIL same-executable-accessory: result=failure("这个应用有多个运行实例，无法确认要恢复哪一个。请直接选择目标窗口。"), selectedUIFrontmost=false, noAmbiguousReopen=true
RESULT failures=1/6
```

普通、最小化、关闭、隐藏四场景及真正多界面实例保护仍通过。最小复现的必要条件是同 bundle/executable 的 regular 界面进程与 accessory 进程共存；去掉辅助进程后原普通场景通过。代码中的面板失败处理会重新显示，解释用户的“闪一下”。该证据是合成复现与现场进程结构相符，非捕获用户点击时的原始日志。

## 修复及界限

只在目标有可核验的内核启动时间、同可执行文件下唯一 regular 进程、其他进程身份完整时，直接按选定 PID 激活，跳过不能准确指向某个进程的 bundle reopen。核对前台 PID，并用公开 CG 窗口所有者、层级、透明度、尺寸确认该进程存在正常可见窗口。没有读取窗口标题、截图、录屏授权或私有 API，也没有按微信名称硬编码。

真实多个 regular 实例、未知 executable 仍保守拒绝重开。该分支不会批量恢复最小化窗口或重建已关闭窗口；无法显示现有窗口时给出明确失败。普通单实例仍沿用原来的 reopen 恢复逻辑。本次处理应用入口，不承诺切到浏览器某个特定标签页。

## 验证与自审

- Debug `--verify-app-activation`：10/10。
- 最终签名 Release/local 候选包 `--verify-app-activation`：10/10。新增核验 launchDate 缺失、内核身份过期、现有可见窗、隐藏、最小化及关闭状态；无可见窗口时不以 PID 前台冒充成功。
- `swift run CoreTests`：112/112。
- 构建、品牌探针、安装前后 `codesign --verify --deep --strict` 通过。
- 精确窗口探针 `.build/debug/AppSwitcherApp --verify-window-switching` 首次在“后台目标窗口获得真实键盘焦点”失败；随后旧安装版 0.5.1 相同命令同位置失败。未修改该路径掩盖失败，未将其记为通过，后续另查焦点事件/环境问题。
- 单 Agent 自审：核对保留多 regular 保护、内核身份校验、取消条件、可见窗口验证、隐私边界及原未提交改动。没有声称独立审阅。
- 新版真实面板能读取 17 个应用及 `5，微信，应用入口`。通过 CUA 点击该项后 AppSwitcher 窗口不再可读，后续只读采样面板可见窗口数为 0；微信浏览器 CUA 读取持续超时，未取得文章页最终画面或稳定前台证据。故现场结果仍需用户复测，不能只凭面板消失结案。

## 安装与回退

- 安装：`/Applications/AppSwitcher.app`，0.5.2，Release/local，ad-hoc 签名、未公证。候选包在 `/Users/eeo/Library/Application Support/AppSwitcher/BuildCandidates/AppSwitcher-0.5.2-wechat-browser.app`。
- 可执行文件 SHA-256：`9e7ac2aebe4348397ec16f70f885b71afb14358b8e8b45e4dedcfb8101bcefab`。
- 旧版备份：`/Users/eeo/Library/Application Support/AppSwitcher/InstallBackups/20260930-0.5.2/Previous-AppSwitcher-0.5.1.app`；实际原安装目录也保存在同目录的 `Previous-installed-original.app`。
- 替换前核对旧 PID 55759 的精确路径，发送 SIGTERM 并确认结束，再替换安装；未终止微信或浏览器。新 PID 38474 已启动（PID 是本次记录，不作未来操作依据），启动日志确认 0.5.2、快捷键注册成功、辅助功能可用。
- 安装前后本地目录顶层 4 个 JSON 配置逐字节摘要一致，未清空快捷键、键位、外观或使用统计。验证真实切换本身可能正常增加使用统计。
- 回退：先退出当前 AppSwitcher，将当前包移至备份位置，再将上述 0.5.1 备份复制回 `/Applications/AppSwitcher.app` 并启动。不要删除用户配置。本轮未执行回退演练。

复测：保持微信文章浏览器窗口打开，唤起键盘面板，点击 5 号微信浏览器图标主体（非右上角退出叉）；预期面板收起且文章窗口前置。若文章窗口已关闭或全部最小化，先恢复窗口后测试本次修复的场景。
