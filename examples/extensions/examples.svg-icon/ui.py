"""SVG Icon 样例插件 —— 只用来证明「图标两形态」的链路，不用来证明任何真实功能。

三条刻意的约束（与 `examples.hello-panel` 同一套立场）：

1. **零权限**：清单 `permissions` 是空的，本文件也不碰文件、网络、子进程。
2. **零出网**：不存在任何 URL 请求；失败一定出在链路，而不是环境。
3. **只用预制节点**：`Column` / `Heading` / `Text` / `Divider`，不出现字面色值、字体族或像素值。

三个 view 各演示一种 SVG 图标形态（清单侧 `client.view.icon`，本文件只管产出 IR）：

- `main`：`Icons/mark.svg`，**省略 `tint`** ⇒ 缺省 `template`，由宿主按面着色；
- `badge`：`Icons/gradient.svg` + `tint: original` ⇒ 保留自带渐变，是本变更唯一受控的
  「插件自带颜色」入口（深色主题下可能不可见，客户端只给一条 info，不拦）；
- `about`：`Icons/wide.svg`，非方 `viewBox="0 0 48 20"` ⇒ 证明等比缩放 + 居中留白，
  尺寸仍只由宿主给的方框决定。

图标**不进 IR 树**：本文件里没有任何图标相关代码，SVG 只出现在清单的 `client.view.icon`。
"""

from __future__ import annotations

from typing import Any


def render_main(payload: dict[str, Any]) -> dict[str, Any]:
    """`panel` 视图：标题 + 一句说明 + 分隔线（最小可判定形态）。"""
    return {
        "kind": "Column",
        "spacing": 2,
        "children": [
            {"kind": "Heading", "text": "SVG 图标样例", "level": 1},
            {
                "kind": "Text",
                "text": "列头这个图标来自包内 Icons/mark.svg（tint 缺省 template）",
                "tone": "fg.secondary",
                "style": "caption",
            },
            {"kind": "Divider"},
            {
                "kind": "Text",
                "text": "同一份清单在侧栏 / 设置区各挂了一个图标，三者都不经过 IR。",
                "tone": "fg.tertiary",
                "style": "caption",
            },
        ],
    }


def render_badge(payload: dict[str, Any]) -> dict[str, Any]:
    """`sidebar.section` 视图：内联在侧栏分区头下方，必须极小。"""
    return {
        "kind": "Text",
        "text": "分区头图标保留 SVG 自带渐变（tint: original）",
        "tone": "fg.secondary",
        "style": "caption",
    }


def render_about(payload: dict[str, Any]) -> dict[str, Any]:
    """`settings.section` 视图：内嵌在插件详情页。"""
    return {
        "kind": "Column",
        "spacing": 1,
        "children": [
            {
                "kind": "Text",
                "text": "设置区图标是 48×20 的非方 viewBox，按 1:1 等比缩放进方形框并居中留白。",
                "tone": "fg.secondary",
                "style": "caption",
            },
        ],
    }


def register(ctx: Any) -> None:
    """插件唯一入口（`server.ui.entry` 指向本文件）。"""
    ctx.view("main", render_main)
    ctx.view("badge", render_badge)
    ctx.view("about", render_about)
