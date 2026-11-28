"""Hello Panel 样例插件 —— 只用来证明 UI 链路，不用来证明任何真实功能。

三条刻意的约束（`tasks.md` 7.2）：

1. **零权限**：清单 `permissions` 是空的，本文件也不碰文件、网络、子进程。
2. **零出网**：不存在任何 URL 请求；失败一定出在链路，而不是环境。
3. **只产数据**：四个 view 全部 `render: native`，返回 `botchat.panel/1` 的 `data` 对象；
   界面由包内 `Panels/*.swift` 用 BotChatKit 画（`native` 是原生面板的第一个样例）。

四个 view 的分工对应四种挂载点：`main`（面板，信息最全）、`compact`（窗口，只留标题与
一个动作）、`settings`（设置区内嵌，最小）、`native`（同样的面板形态，用来对照
「同一份入口里多个 view 各有一份面板源码」）。命令返回 `{"text": …}`，客户端据此填入
输入条 —— 这是「命令类 slot 没有视图」的表达方式。
"""

from __future__ import annotations

from typing import Any

#: 每个实例的点击次数（**进程内存**，不是持久化状态）。
#:
#: 为什么样例要有状态：交互链路（按钮 → 服务端 → 插件 → 新数据 → 客户端推给面板）如果
#: 返回值与上一次**逐字相同**，界面上就什么都不会变 —— 用户会以为「点了没反应」。
#: 一个会变的计数是这条链路最直接的活体探针；重载快照后计数仍在，说明确实走了往返。
_COUNTS: dict[str, int] = {}


def _bump(instance_key: str) -> int:
    """把该实例的计数 +1 并返回新值（纯内存，进程重启归零）。"""
    key = instance_key or "-"
    _COUNTS[key] = _COUNTS.get(key, 0) + 1
    return _COUNTS[key]


def _hits(instance_key: str) -> int:
    """该实例当前的点击次数（未点过即 0）。"""
    return _COUNTS.get(instance_key or "-", 0)


def _flag(payload: dict[str, Any], name: str) -> bool:
    """从交互载荷读一个布尔开关值。

    `values` 是表单通道、`arguments` 是面板 `host.dispatch` 的实参通道，两者都要认：
    改写自 IR 的 `Toggle` 时，面板用哪条通道取决于它自己怎么 dispatch。
    """
    for key in ("values", "arguments"):
        source = payload.get(key)
        if isinstance(source, dict) and name in source:
            return bool(source[name])
    return False


def _instance_key(payload: dict[str, Any]) -> str:
    return str(payload.get("instanceKey", "") or "")


def render_main(payload: dict[str, Any]) -> dict[str, Any]:
    """`panel` 挂载点的 view：标题 + 计数 + 一个动作 + 一个开关。

    `hits` 是「这个实例被点了几次」——它是**动作真的跑到了插件**的证据：点一次 → `hits +1`
    → 新数据 → 面板按新值重画，屏幕上的数字才会变。

    开关值**不落盘**（与 IR 版同一口径）：它只随本次交互回传，回传什么就显示什么。
    """
    instance_key = _instance_key(payload)
    if payload.get("nodeId") == "press":
        _bump(instance_key)
    return {
        "title": "Hello 面板",
        "instance": instance_key or "（未提供实例键）",
        "hits": _hits(instance_key),
        "verbose": _flag(payload, "verbose"),
    }


def render_compact(payload: dict[str, Any]) -> dict[str, Any]:
    """`window` 挂载点的 view：窗口更小，只留标题、计数与一个动作。

    计数进数据是刻意的：IR 版的窗口视图不显示计数，于是「点了没反应」在界面上无从判定；
    原生的这一版把 `hits` 摆在标题旁，动作是否接通一眼可见。
    """
    instance_key = _instance_key(payload)
    if payload.get("nodeId") == "press":
        _bump(instance_key)
    return {
        "title": "Hello 窗口",
        "note": "窗口实例独立于面板实例",
        "hits": _hits(instance_key),
    }


def render_settings(payload: dict[str, Any]) -> dict[str, Any]:
    """`settings.section` 挂载点的 view：内嵌在插件详情页，必须明显更小。"""
    return {
        "text": "这是插件自己的设置区",
        "verbose": _flag(payload, "verbose"),
    }


def render_native(payload: dict[str, Any]) -> dict[str, Any]:
    """`native` 挂载点的 view：与 `main` 同为面板形态，但只有标题与计数。

    这两条并排存在是有意的：同一个插件、同一份 `server.ui` 入口，两个 view 各有一份
    包内面板源码（`Panels/HelloMain.swift` / `Panels/Hello.swift`），用来演示
    「一个视图一份面板产物」——一个编译产物只暴露一个入口符号。
    """
    instance_key = _instance_key(payload)
    if payload.get("nodeId") == "press":
        _bump(instance_key)
    return {
        "title": "Hello 原生面板",
        "hits": _hits(instance_key),
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
