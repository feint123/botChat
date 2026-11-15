"""{{name}} — IR 紧凑树插件（botChat 扩展，`botchat.ui/1`）。

为什么不是面板那棵树：挂载点是 `{{slot}}`，它的节点准入是**白名单**而不是全集 ——
服务端 `ui_contract.SLOT_ALLOWED_KINDS` 里 `sidebar.section` 只收
Row / Text / Button / Progress / List，`composer.accessory` 只收 Row / Text / Button / Toggle。
拿面板树（`Column` 根 + `Heading` + `Divider`）挂上去会被**整树拒渲染**（`slotNotAllowed`），
界面上只剩占位 —— 而且这种错装得上、启用得了，只有点开那一格才看得见。

预算与准入（服务端强制，失败只坏该槽位）：
- `sidebar.section`：≤200 节点，禁输入控件（`Field` / `Toggle` 都不行），`List` 可用；
- `composer.accessory`：≤40 节点、高 44pt，输入只许 `Toggle`，禁 `List`。

渲染 MUST 是纯函数：渲染期一切写型宿主调用都会被拒（`fs.write` / `net.fetch` 抛
`permissionDenied`）。颜色只走 `tone`，取值限于 `TONE_ROLES` 的 27 个角色。
"""

from __future__ import annotations

#: 进程内状态（不是持久化）：同 data 连推两次界面不动，所以计数必须有变化。
_COUNTS: dict[str, int] = {}{{toolBlock}}

def render_view(payload: dict[str, object]) -> dict[str, object]:
    """`{{slot}}` 挂载点的视图：渲染与交互共用；根节点 MUST 是该槽位白名单内的 kind。"""
    instance_key = str(payload.get("instanceKey") or "")
    key = instance_key or "-"
    if payload.get("nodeId") == "press":
        _COUNTS[key] = _COUNTS.get(key, 0) + 1
    # 全树只有 Row / Text / Button 三种 —— 缩放窗口、换成窄槽位都不会被拒。
    return {
        "kind": "Row",
        "align": "between",
        "children": [
            {
                "kind": "Text",
                "text": f"{{name}}：已点击 {_COUNTS.get(key, 0)} 次",
                "tone": "status.running.fg",
                "style": "caption",
            },
            {"kind": "Button", "nodeId": "press", "label": "点我", "style": "primary"},
        ],
    }


def render_settings(payload: dict[str, object]) -> dict[str, object]:
    """`settings.section` 挂载点：嵌在插件详情页里，尺寸必须明显更小。"""
    return {
        "kind": "Column",
        "spacing": 1,
        "children": [
            {"kind": "Text", "text": "这是插件自己的设置区", "tone": "fg.secondary"},
            {
                "kind": "Field",
                "name": "endpoint",
                "label": "接口地址",
                "input": "text",
                "placeholder": "https://…",
            },
        ],
    }


def on_command(payload: dict[str, object]) -> dict[str, object]:
    """命令处理器：只准回 `{"view": …}`（开面板）或 `{"text": …}`（填进输入条）。"""
    return {"view": "{{view}}"}


def register(ctx):
    """唯一入口。视图名 MUST 与清单 `server.ui.views` 逐字一致。"""
    ctx.view("{{view}}", render_view)
    ctx.view("settings", render_settings)
    ctx.command("{{command}}", on_command){{toolRegister}}
