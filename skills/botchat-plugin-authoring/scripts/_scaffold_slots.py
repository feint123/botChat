"""五个挂载点的脚手架口径（唯一事实源在服务端 `app/extensions/ui_contract.py`）。

为什么单独成文件：槽位不只是清单里的一个字符串 —— `SLOT_ALLOWED_KINDS` 对窄槽位是**白名单**，
`sidebar.section` 与 `composer.accessory` 都不收 `Column`。所以「改了 slot 字符串」并不等于
「包能渲染」：主视图的树根形状也得跟着换（见 `variant_for`）。这条事实写在这里，
脚手架主流程只做搬运。
"""

from __future__ import annotations

#: 五挂载点封闭集合（顺序即 `--slot` 帮助文本里的顺序）。
SLOTS: tuple[str, ...] = (
    "panel",
    "settings.section",
    "sidebar.section",
    "composer.accessory",
    "window",
)

#: 节点白名单不是全集的槽位：模板主视图 MUST 换成 Row 根的紧凑树。
#: 取值依据 `ui_contract.SLOT_ALLOWED_KINDS`：
#: `sidebar.section` = Row/Text/Button/Progress/List；`composer.accessory` = Row/Text/Button/Toggle。
#: 两者都**不收** `Column` / `Heading` / `Divider` / `Field` —— 拿面板树挂上去会被整树拒渲染
#: （`slotNotAllowed`，见 `ui_ir.validate`）。
NARROW_SLOTS: frozenset[str] = frozenset({"sidebar.section", "composer.accessory"})

#: 每个槽位一句口径说明（生成后打印，避免作者拿面板的尺寸预期去写侧栏）。
SLOT_NOTES: dict[str, str] = {
    "panel": "panel：工具栏面板列，2,000 节点预算、17 个 kind 全集。",
    "settings.section": "settings.section：嵌在插件详情页，300 节点预算；禁 List（会与设置页自身滚动打架）。",
    "sidebar.section": "sidebar.section：会话侧栏分区，200 节点；只收 Row/Text/Button/Progress/List，不接受任何输入控件。",
    "composer.accessory": "composer.accessory：输入条配件条，40 节点、44pt 高；只收 Row/Text/Button/Toggle，输入只许 Toggle。",
    "window": "window：独立 NSPanel 窗口，单实例键 (extensionId, viewId)，关闭即停流、插件停用不自动关窗。",
}

#: `window` 的额外提示（要求：`--slot window` 时 MUST 打一行说明）。
#: 口径以代码为准：HEAD 的 `QuickBarHostBridge.quickBarRunPluginCommand` 对 `slot == "window"`
#: 调 `ExtensionPanelWindowController.open` 开真窗口；只有旧版本宿主才降级为「面板列 + 一条提示」。
SLOT_QUICKBAR_NOTE: str = (
    "提示：`window` 与 `panel` 是两个挂载点。HEAD 的宿主经 QuickBar 命令打开时按声明开独立窗口"
    "（`ExtensionPanelWindowController`），旧版本宿主才会降级为「面板列 + 一条可见提示」；"
    "两个挂载点请勿混用同一 view。"
)


def is_narrow(slot: str) -> bool:
    """该槽位的节点白名单是否非全集（决定要不要换紧凑树）。"""
    return slot in NARROW_SLOTS


def variant_for(*, mode: str, slot: str) -> str:
    """选模板变体：`compact` = Row 根紧凑树；`default` = 原面板树。

    只有 `ui` 档备了紧凑模板：`native` 的载荷是 `botchat.panel/1` 数据对象，不套 IR 节点
    白名单，换槽位只用改清单里的 `slot`。返回 `default` 而模板缺失变体文件时，
    渲染阶段会按「只认已声明变体」跳过，不会静默产出半个包。
    """
    if mode == "ui" and is_narrow(slot):
        return "compact"
    return "default"
