"""Hello Panel 样例插件 —— 只用来证明 UI 链路，不用来证明任何真实功能。

三条刻意的约束（`tasks.md` 7.2）：

1. **零权限**：清单 `permissions` 是空的，本文件也不碰文件、网络、子进程。
2. **零出网**：不存在任何 URL 请求；失败一定出在链路，而不是环境。
3. **只用预制节点**：`Text` / `Row` / `Button` / `Toggle` / `Divider`，不出现字面色值、
   字体族或像素值（`docs/extension-plugin-ui.md` §二 硬约束 1）。

三个 view 的分工对应三种挂载点：`main`（面板，信息最全）、`compact`（窗口，只留标题与
一个动作）、`settings`（设置区内嵌，最小）。命令返回 `{"text": …}`，客户端据此填入
输入条 —— 这是「命令类 slot 没有视图」的表达方式。
"""

from __future__ import annotations

from typing import Any

#: 每个实例的点击次数（**进程内存**，不是持久化状态）。
#:
#: 为什么样例要有状态：交互链路（按钮 → 服务端 → 插件 → 新整树 → 客户端应用）如果
#: 返回值与上一次**逐字相同**，界面上就什么都不会变 —— 用户会以为「点了没反应」。
#: 一个会变的计数是这条链路最直接的活体探针；重载快照后计数仍在，说明确实走了往返。
_COUNTS: dict[str, int] = {}


def _bump(instance_key: str) -> int:
    """把该实例的计数 +1 并返回新值（纯内存，进程重启归零）。"""
    key = instance_key or "-"
    _COUNTS[key] = _COUNTS.get(key, 0) + 1
    return _COUNTS[key]


def _panel_tree(*, instance_key: str, pressed: bool, count: int = 0) -> dict[str, Any]:
    """面板主视图：标题 + 状态 + 按钮 + 开关。

    `count` 是「这个实例被点了几次」——它是**动作真的跑到了插件**的证据：
    点一次 → `count +1` → 新整树 → 客户端按 `rev` 应用，屏幕上的数字才会变。
    """
    return {
        "kind": "Column",
        "spacing": 2,
        "children": [
            {"kind": "Heading", "text": "Hello 面板", "level": 1},
            {
                "kind": "Text",
                "text": f"实例：{instance_key}",
                "tone": "fg.secondary",
                "style": "caption",
            },
            {"kind": "Divider"},
            {
                "kind": "Row",
                "align": "between",
                "children": [
                    {
                        "kind": "Text",
                        "text": f"已点击 {count} 次（开关：{'开' if pressed else '关'}）",
                        "tone": "status.running.fg",
                    },
                    {
                        "kind": "Button",
                        "nodeId": "press",
                        "label": "点我",
                        "style": "primary",
                    },
                ],
            },
            {
                "kind": "Toggle",
                "nodeId": "verbose",
                "label": "详细模式",
                "value": pressed,
            },
        ],
    }


def render_main(payload: dict[str, Any]) -> dict[str, Any]:
    """`panel` 挂载点的 view（渲染与交互共用）。

    交互时宿主会带上 `nodeId` 与 `values`（表单值）。命中 `press` 就记一次点击 ——
    这一步是「按钮真的接通了」的唯一证据，故 MUST NOT 让交互分支返回与渲染完全相同的树。
    """
    instance_key = str(payload.get("instanceKey", "") or "")
    if payload.get("nodeId") == "press":
        _bump(instance_key)
    values = payload.get("values") or {}
    verbose = bool(values.get("verbose")) if isinstance(values, dict) else False
    return _panel_tree(
        instance_key=instance_key,
        pressed=verbose,
        count=_COUNTS.get(instance_key or "-", 0),
    )


def render_compact(payload: dict[str, Any]) -> dict[str, Any]:
    """`window` 挂载点的 view：窗口更小，只留标题与一个动作。"""
    return {
        "kind": "Column",
        "spacing": 2,
        "children": [
            {"kind": "Text", "text": "Hello 窗口", "style": "title"},
            {
                "kind": "Text",
                "text": "窗口实例独立于面板实例",
                "tone": "fg.tertiary",
                "style": "caption",
            },
            {"kind": "Button", "nodeId": "press", "label": "点我"},
        ],
    }


def render_settings(payload: dict[str, Any]) -> dict[str, Any]:
    """`settings.section` 挂载点的 view：内嵌在插件详情页，必须明显更小。"""
    return {
        "kind": "Column",
        "spacing": 1,
        "children": [
            {"kind": "Text", "text": "这是插件自己的设置区", "tone": "fg.secondary"},
            {"kind": "Toggle", "nodeId": "verbose", "label": "详细模式", "value": False},
        ],
    }


def render_native(payload: dict[str, Any]) -> dict[str, Any]:
    """`render: native` 的 view：返回**数据**，不是节点树（`botchat.panel/1`）。

    这条样例刻意与 `render_main` 并排存在：同一个插件、同一份 `server.ui` 入口，
    一个 view 产 IR 树、另一个产 data —— 客户端按清单的 `render` 选渲染器。
    """
    instance_key = str(payload.get("instanceKey", "") or "")
    if payload.get("nodeId") == "press":
        _bump(instance_key)
    return {
        "title": "Hello 原生面板",
        "hits": _COUNTS.get(instance_key or "-", 0),
    }


def on_open(payload: dict[str, Any]) -> dict[str, Any]:
    """命令：只回 `{"text": …}`（客户端把它填进输入条，不打开任何视图）。"""
    return {"text": "Hello：这条文本来自插件命令"}


def register(ctx: Any) -> None:
    """插件唯一入口（`server.ui.entry` 指向本文件）。"""
    ctx.view("main", render_main)
    ctx.view("compact", render_compact)
    ctx.view("settings", render_settings)
    ctx.view("native", render_native)
    ctx.command("examples.hello-panel.open", on_open)
