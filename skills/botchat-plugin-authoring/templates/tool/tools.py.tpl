"""{{name}} — 最小工具插件（botChat 扩展，change `add-extension-plugin-system`）。

宿主只会调用 `register(ctx)` 一次（首次匹配 `activationEvents` 时），所以：
模块顶层 MUST 保持无副作用（import 放函数里更稳），一切注册都在 `register` 内完成。

四条纪律（踩过才写的）：
1. `ctx.tool(name, ...)` 的 `name` 是**插件内名**；对外名由宿主编成 `<id>__<name>`
   （点号与连字符归一下划线），清单 `activationEvents` 里写的是**对外名**。
2. handler 收一个 `dict`、回一个**可 JSON 序列化**的值。回不可序列化对象即 `invalid_result`，
   宿主不会 `str()` 兜底。
3. 业务失败用返回体表达（`{"ok": false, "error": "..."}`）；抛异常只会给用户一个插件崩溃诊断。
4. 插件之间互不可见（模块名 `botchat_ext_<sanitized_id>`），跨插件 `import` 必失败。
"""

from __future__ import annotations


def {{tool}}(arguments: dict[str, object]) -> dict[str, object]:
    """{{tool}}：一句话说清「做什么」和「什么时候该被调用」。"""
    raw = arguments.get("text")
    text = raw.strip() if isinstance(raw, str) else ""
    if text == "":
        return {"ok": False, "error": "text 不能为空"}
    return {"ok": True, "echo": text}


def register(ctx):
    """注册工具。工具名 MUST 与清单 `capabilities["server.tool"].tools` 逐字一致。"""
    ctx.tool(
        "{{tool}}",
        {{tool}},
        description="{{name}}：把输入原样回显（零权限样例）",
        input_schema={
            "type": "object",
            "properties": {
                "text": {"type": "string", "description": "要回显的文本"},
            },
            "required": ["text"],
        },
    )
