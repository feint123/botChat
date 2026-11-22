"""五个挂载点的脚手架口径（唯一事实源在服务端 `app/extensions/capability_ui.py` 的 `VIEW_SLOTS`）。

为什么单独成文件：槽位是清单里的一个字符串，但**各槽位的可用宽度与高度不同**，
面板视图得按它调布局。`botchat.ui/1`（预制节点 IR）下线后，槽位不再有「节点白名单 /
节点预算」这层概念 —— 载荷上限对所有 slot 一致（`data` 256 KB / 深度 8 / 单数组 2,000 项，
见 `ui_panel_payload.py`），尺寸由宿主钳制。这条事实写在这里，脚手架主流程只做搬运。
"""

from __future__ import annotations

#: 五挂载点封闭集合（顺序即 `--slot` 帮助文本里的顺序）。
#: 第六个渲染位置 `client.row`（轮级行）**不是 slot**：它是独立能力 kind，无实例键、无 rev、
#: 不进快照 LRU，走行载荷（32 KiB），见 `capability_row.py`。
SLOTS: tuple[str, ...] = (
    "panel",
    "settings.section",
    "sidebar.section",
    "composer.accessory",
    "window",
)

#: 每个槽位一句口径说明（生成后打印，避免作者拿面板的尺寸预期去写侧栏）。
SLOT_NOTES: dict[str, str] = {
    "panel": "panel：工具栏面板列，随列宽伸缩；面板列头已有的动作不要重复造。",
    "settings.section": "settings.section：嵌在插件详情页，可用高度小；只放设置项，不铺大布局。",
    "sidebar.section": "sidebar.section：会话侧栏分区，高度上限 240pt；一行说明 + 少量动作，别放大表格。",
    "composer.accessory": "composer.accessory：输入条配件条，高度上限 44pt；只能塞一行，控件用 .small。",
    "window": "window：独立 NSPanel 窗口，单实例键 (extensionId, viewId)，关闭即停流、插件停用不自动关窗。",
}

#: `window` 的额外提示（要求：`--slot window` 时 MUST 打一行说明）。
#: 口径以代码为准：宿主经 QuickBar 命令打开时调 `ExtensionPanelWindowController.open` 开真窗口。
SLOT_QUICKBAR_NOTE: str = (
    "提示：`window` 与 `panel` 是两个挂载点。宿主按声明开独立 NSPanel（`ExtensionPanelWindowController`）；"
    "两个挂载点请勿混用同一 view。"
)


def is_narrow(slot: str) -> bool:
    """该槽位是否需要紧凑布局（只在帮助文本里用来提醒尺寸，不再影响模板选择）。"""
    return slot in {"sidebar.section", "composer.accessory"}


def variant_for(*, mode: str, slot: str) -> str:
    """选模板变体。

    `botchat.ui/1` 下线后不再需要「窄槽位换 Row 根紧凑树」这层：面板是一份 SwiftUI 视图，
    换槽位只需改清单里的 `slot`，视图自己按 `host` 给的尺寸调布局。保留本函数是为了
    模板树仍按 `*.default.tpl` / `*.compact.tpl` 命名分派时不会崩 —— 现在恒返回 `default`。
    """
    return "default"
