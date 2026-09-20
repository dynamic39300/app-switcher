# app-switcher 领域语言

这里只记录领域词义和关系，不存技术方案、临时任务或聊天记录。

## Language

**候选 app（candidate app）**：正在运行、`activationPolicy` 为 regular、且非本应用自身的 App；是覆盖层键位的分配对象。
_Avoid_：把菜单栏/后台进程也算作候选，或把「已安装但未运行」的 App 混为候选。

**键位（key / keycap）**：覆盖层键盘上的一个物理位置，V1 为字母 `A–Z`（26）加数字行 `1–0 - +`（12），共 38。
_Avoid_：把「键位」与「快捷键」混用——键位是覆盖层内的位置，快捷键是唤起覆盖层的全局组合键。

**键位映射（key mapping）**：键位到候选 app 的确定性对应关系，由 rank 与首字母规则决定。
_Avoid_：把某一时刻的映射当作永久固定；运行集合变化会重算。

**rank**：候选 app 的使用排序（激活次数降序 → 最近激活降序 → 名称升序兜底）。
_Avoid_：把 rank 等同于风险等级或产品优先级。

**覆盖层（overlay）**：唤出键触发的键盘形状面板，展示键位映射。
_Avoid_：把覆盖层称作「弹出菜单」或「Dock 替代」。

**唤出键（trigger hotkey）**：唤起覆盖层的全局快捷键，默认 `⌥+Space`，可配置。
_Avoid_：与「键位映射中的按键」混淆。

**就近让位（collision fallback）**：多个候选首字母相同时，rank 低者落到最近空闲字母键的分配策略。
_Avoid_：把「就近让位」说成随机或用户手动分配（V1 为自动）。

方法论中的 PRD/spec/ticket 含义见 [框架原则](.framework/docs/handbook/overview.md)与[交付链路](.framework/docs/handbook/lifecycle.md)。
