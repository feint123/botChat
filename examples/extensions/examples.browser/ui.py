"""浏览器样例插件 —— 演示「面板内嵌 `WKWebView`」的完整形态。

## 它演示什么

`WebKit` 已加入面板 import 白名单（`docs/extension-panel-native.md` §四「内嵌网页」），
所以面板可以自己内嵌一个 `WKWebView`。本样例把那条边界**当成代码写出来**，而不是靠作者自觉：

1. **可出网、可执行远程 JS**：`Panels/Browser.swift` 不关 `allowsContentJavaScript`，也不注入脚本。
2. **MUST NOT 读本地文件**：非 `http`/`https`/`about` 的 scheme 在 `decidePolicyFor` 里一律取消，
   并回一条中文提示。面板侧也**不碰** `loadFileURL` / `allowingReadAccessTo`（禁用符号）。
3. **零权限**：清单 `permissions` 是空的 —— 面板的网络访问是 `WKWebView` 自己的网络栈，
   与插件子进程的 `ctx.host.net` 授权是两件事，不要混淆。

## 为什么服务端还要有 `ui.py`

`client.panel.views[]` 里的 view MUST 在同包 `server.ui.views` 里有数据来源（三向对账，见
`app/extensions/capability_panel.py`）。服务端**只产数据**（主页地址、访问计数），不做任何
网页抓取：抓取会让「页面到底是谁加载的」变得不可归因，而本样例要示范的正是「面板自己加载」。

## 那个会变的计数

`visited` 是**进程内存**里「这个实例完成了几次页面加载」。它的用途与 `examples.hello-panel`
的计数一致：如果回包与上次逐字相同，界面上什么都不会变，用户会以为「没接上」。一个会变的数
是「面板 → 服务端 → 插件 → 新 data → 面板」这条往返最直接的活体探针。
"""

from __future__ import annotations

from typing import Any

#: 每个实例的页面加载次数（进程内存，重启归零）。
_VISITS: dict[str, int] = {}

#: 每个实例最近一次的页面地址与标题（同上，进程内存）。
_LAST: dict[str, tuple[str, str]] = {}

#: 缺省主页。刻意选一个静态、无登录、无追踪的地址，便于确认「渲染通了」而不是「被拦了」。
DEFAULT_HOME = "https://example.com/"


def _instance_key(payload: dict[str, Any]) -> str:
    return str(payload.get("instanceKey", "") or "")


def _argument(payload: dict[str, Any], name: str) -> str:
    """从交互回包里取一个字符串实参。

    `arguments` 是面板 `host.dispatch` 的实参通道；`values` 是表单通道。两者都认，
    是为了让面板换通道时样例不需要跟着改。
    """
    for key in ("arguments", "values"):
        source = payload.get(key)
        if isinstance(source, dict):
            value = source.get(name)
            if isinstance(value, str):
                return value
    return ""


def render_main(payload: dict[str, Any]) -> dict[str, Any]:
    """`panel` 挂载点的 view 数据。

    面板在**每次导航完成**时 dispatch 一次 `commit`（带 `url` / `title`）。这里把它记下来并
    把新计数回给面板 —— 屏幕上的「已加载 N 页」变了，就说明这条往返真的走通了。
    """
    instance_key = _instance_key(payload)
    if payload.get("nodeId") == "commit":
        url = _argument(payload, "url")
        title = _argument(payload, "title")
        if url:
            _VISITS[instance_key] = _VISITS.get(instance_key, 0) + 1
            _LAST[instance_key] = (url, title)
    last_url, last_title = _LAST.get(instance_key, ("", ""))
    return {
        "title": "浏览器",
        "home": DEFAULT_HOME,
        "visited": _VISITS.get(instance_key, 0),
        "lastUrl": last_url,
        "lastTitle": last_title,
        "boundary": "只允许 http / https；本地文件与其它协议会被面板拒绝",
    }


def register(ctx: Any) -> None:
    """插件唯一入口（`server.ui.entry` 指向本文件）。"""
    ctx.view("main", render_main)
