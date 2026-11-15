"""{{name}} — 原生面板插件（`botchat.panel/1`）。

清单里该 view 声明了 `"render": "native"`，因此视图函数 MUST 返回**数据对象**，
不是 IR 节点树：服务端按清单的 `render` 选校验器（`ui_action` / `ui_panel_payload`），
返回树会被当 data 校验并整帧降级。

判据（docs/extension-panel-native.md §一）：需要 Chart / 热力图 / 拖拽 / 动画 / 非标准布局
才用 native；其余情况用 IR —— 原生面板是逃生舱，不是默认档。

data 的约束（服务端强制，失败只降级该 slot）：
- 顶层 MUST 是 JSON 对象；≤256 KB；深度 ≤8；单数组 ≤2000 项。
- 键名 `[A-Za-z_][A-Za-z0-9_]*`，且 MUST NOT 以 `_` 开头（保留给宿主）。
- 图片只允许裸 `assetId` 或 `/api/media/{id}`，外链 / `data:` / 本地路径一律拒。
"""

from __future__ import annotations

#: 进程内状态：原生面板要看到变化，必须让 data 变（同 data 连推两次界面不动）。
_HITS: dict[str, int] = {}{{toolBlock}}


def render_main(payload: dict[str, object]) -> dict[str, object]:
    """`{{slot}}` 挂载点的视图：渲染与交互共用。

    交互参数来自 `payload["arguments"]`（原生面板 `host.dispatch("press", [...])` 落在这里），
    而 IR 的 `Field` 走 `payload["values"]` —— 两种渲染体共用同一份动作语义时两个都要读。
    """
    instance_key = str(payload.get("instanceKey") or "")
    key = instance_key or "-"
    if payload.get("nodeId") == "press":
        _HITS[key] = _HITS.get(key, 0) + 1
    return {
        "title": "{{name}}",
        "hint": "这段界面由包内 Panels/Main.swift 编译而来；数据来自服务端子进程。",
        "hits": _HITS.get(key, 0),
    }


def on_command(payload: dict[str, object]) -> dict[str, object]:
    """命令处理器：只回 `{"view": …}` 或 `{"text": …}`。"""
    return {"view": "{{view}}"}


def register(ctx):
    """唯一入口：视图名 MUST 在清单 `server.ui.views` 里。"""
    ctx.view("{{view}}", render_main)
    ctx.command("{{command}}", on_command){{toolRegister}}
