"""{{name}} — 面板插件（botChat 扩展，`botchat.panel/1`）。

插件 UI 只有一种渲染体：**编译版 SwiftUI 面板**。视图函数返回**数据对象**（不是节点树），
界面在包内 `Panels/*.swift` 里写，由宿主编译后加载。`botchat.ui/1`（预制节点 IR）已全量下线：
节点集、`tone` 白名单、节点预算与 slot 节点白名单一并作废，写节点树会被当 data 校验并整帧降级。

清单里这两个 view 都声明了 `"render": "native"`，并且 `client.panel.views[]` 各有一条同名条目 ——
**三向一致是硬约束**：`render: native` ↔ `client.panel` 同名条目 ↔ `server.ui.views`。
少任何一向，该 `client.view` 会在解码期被撤下（打开它只剩占位）。

data 的约束（服务端强制，失败只降级该 slot，不截断继续渲染）：
- 顶层 MUST 是 JSON 对象；序列化后 ≤256 KB；嵌套深度 ≤8；单数组 ≤2000 项。
- 键名 MUST 匹配 `[A-Za-z_][A-Za-z0-9_]*`，且 MUST NOT 以 `_` 开头（保留给宿主）。
- 图片只允许裸 `assetId` 或 `/api/media/{id}`；`data:` / `file:` / 外链 / 本地路径一律拒。
"""

from __future__ import annotations

#: 进程内状态：面板要看到变化，必须让 data 变（同一份 data 连推两次界面不动）。
_HITS: dict[str, int] = {}{{toolBlock}}


def render_main(payload: dict[str, object]) -> dict[str, object]:
    """`{{slot}}` 挂载点的视图：渲染与交互共用。

    交互参数来自 `payload["arguments"]`（原生面板 `host.dispatch("press", [...])` 落在这里）。
    渲染 MUST 是纯函数：渲染期一切写型宿主调用都会被拒（`fs.write` / `net.fetch` 抛
    `permissionDenied`）。要写盘就放到交互分支或工具里。
    """
    instance_key = str(payload.get("instanceKey") or "")
    key = instance_key or "-"
    if payload.get("nodeId") == "press":
        _HITS[key] = _HITS.get(key, 0) + 1
    return {
        "title": "{{name}}",
        "hint": "界面在包内 Panels/Main.swift；数据来自服务端子进程。",
        "hits": _HITS.get(key, 0),
    }


def render_settings(payload: dict[str, object]) -> dict[str, object]:
    """`settings.section` 挂载点：嵌在插件详情页，尺寸由宿主钳制，必须明显更小。"""
    return {
        "endpoint": "https://example.invalid",
        "note": "这里是插件自己的设置区",
    }


def on_command(payload: dict[str, object]) -> dict[str, object]:
    """命令处理器：只准回 `{"view": …}`（开面板）或 `{"text": …}`（填进输入条）。"""
    return {"view": "{{view}}"}


def register(ctx):
    """唯一入口。视图名 MUST 与清单 `server.ui.views` 逐字一致。"""
    ctx.view("{{view}}", render_main)
    ctx.view("settings", render_settings)
    ctx.command("{{command}}", on_command){{toolRegister}}
