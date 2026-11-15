"""{{name}} — IR 面板插件（botChat 扩展，`botchat.ui/1`）。

这是「默认档」：用预制节点拼树，宿主负责排版与取色。能用 IR 表达就别写原生面板
（判据见 `docs/extension-panel-native.md` §一：Chart / 热力图 / 拖拽 / 动画 / 非标准布局 → native）。

挂载点：`{{slot}}`。预算与节点白名单按 slot 分档（服务端 `ui_contract.SLOT_PROFILES`）。

五条硬约束（服务端 `ui_contract.py` / `ui_ir.py` 校验，违规即 `irInvalid` 并降级成占位树）：
1. **不许出现字面色值 / 字体 / 像素**：`color` `font` `fontSize` `width` `padding` `radius` …
   这些键名本身非法；颜色只能走 `tone`，且只能取 `ui_contract.TONE_ROLES` 的 27 个角色。
2. `kind` 只能是 17 个之一：Text / Heading / Markdown / Image / Divider / Spacer / Progress /
   Row / Column / Grid / List / Field / Button / Toggle / Link / Empty / Error。
3. 交互节点（Button / Toggle / Field）的 `nodeId` 是动作路由键，MUST 在渲染树里唯一。
4. 渲染 MUST 是纯函数：**渲染期一切写型宿主调用都会被拒**（`fs.write` / `net.fetch` 直接抛
   `permissionDenied`）。要写盘就放到交互分支或工具里，别放在渲染路径上。
5. 预算：≤2000 节点 / ≤512 KB / 深度 ≤64，超了记 `irBudgetExceeded`。
"""

from __future__ import annotations

#: 进程内状态（不是持久化）。交互链路要有可见变化，否则用户会以为「点了没反应」。
_COUNTS: dict[str, int] = {}{{toolBlock}}


def _bump(instance_key: str) -> int:
    key = instance_key or "-"
    _COUNTS[key] = _COUNTS.get(key, 0) + 1
    return _COUNTS[key]


def _tree(*, instance_key: str, count: int) -> dict[str, object]:
    """面板主视图：只回预制节点，颜色只用 tone 角色。"""
    return {
        "kind": "Column",
        "spacing": 2,
        "children": [
            {"kind": "Heading", "text": "{{name}}", "level": 1},
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
                        "text": f"已点击 {count} 次",
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
        ],
    }


def render_view(payload: dict[str, object]) -> dict[str, object]:
    """`{{slot}}` 挂载点的视图：渲染与交互**共用同一个函数**。

    交互时宿主带 `nodeId`（被点的节点）与 `values`（表单当前值）。命中就改状态，
    然后回**整棵树** —— 本通道没有 patch / diff 语义，回一模一样的树界面上什么都不会变。
    """
    instance_key = str(payload.get("instanceKey") or "")
    if payload.get("nodeId") == "press":
        _bump(instance_key)
    return _tree(instance_key=instance_key, count=_COUNTS.get(instance_key or "-", 0))


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
    """唯一入口。视图名 MUST 与清单 `server.ui.views` 逐字一致（声明与注册要对得上）。"""
    ctx.view("{{view}}", render_view)
    ctx.view("settings", render_settings)
    ctx.command("{{command}}", on_command){{toolRegister}}
