"""清单后处理：按槽位与 `--with-tool` 调整已渲染的清单。

为什么不用纯模板做：这几条都是**条件性**的（「slot 恰好是 settings.section 时不再重复声明
settings 视图」「组合包时 entry 指向同一个文件」）。若塞进模板，就要在 JSON 里维护逗号与
整块可选段，模板会立刻变成不可读的拼装代码，而残留检测只能证明「没有占位符」，
证明不了「JSON 合法」。这里改成渲染后按语义定点改，改完再统一 `json.loads` 校验一次。
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

def _load(manifest_path: Path) -> dict[str, Any]:
    raw: Any = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError(f"清单顶层不是 JSON 对象：{manifest_path}")
    return raw


def _dump(manifest_path: Path, manifest: dict[str, Any]) -> None:
    text = json.dumps(manifest, ensure_ascii=False, indent=2)
    manifest_path.write_text(text + "\n", encoding="utf-8")


def _capabilities(manifest: dict[str, Any]) -> dict[str, Any]:
    capabilities = manifest.get("capabilities")
    if not isinstance(capabilities, dict):
        raise ValueError("清单缺少 capabilities 对象")
    return capabilities


def apply_with_tool(manifest_path: Path, *, tool: str, tool_full: str) -> None:
    """组合包：`server.tool` 指向**同一份** entry，并补 `onTool:` 激活事件。

    为什么强调同一份 entry：两条能力各自起一个子进程、各自 import 一个模块，
    `register(ctx)` 会被调两次且两次拿不到对方的注册 —— 同文件才能让一次
    `register` 里同时 `ctx.view` / `ctx.tool`（`--view` 与 `--tool` 会撞名时由主流程先拒）。
    """
    manifest = _load(manifest_path)
    capabilities = _capabilities(manifest)
    ui = capabilities.get("server.ui")
    if not isinstance(ui, dict) or not isinstance(ui.get("entry"), str):
        raise ValueError("组合包要求清单已有 server.ui.entry（--with-tool 只叠加在 ui / native 上）")
    capabilities["server.tool"] = {"entry": ui["entry"], "tools": [tool]}
    events = manifest.get("activationEvents")
    if not isinstance(events, list):
        raise ValueError("清单缺少 activationEvents 数组")
    if f"onTool:{tool_full}" not in events:
        events.append(f"onTool:{tool_full}")
    _dump(manifest_path, manifest)


def verify_json(*paths: Path) -> list[str]:
    """渲染后统一校验：清单/主题载荷都 MUST 是合法 JSON。返回问题列表（空 = 通过）。"""
    problems: list[str] = []
    for path in paths:
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            problems.append(f"{path.name}: {error.msg}（第 {error.lineno} 行）")
    return problems


def apply_with_hook(manifest_path: Path, *, entry: str) -> None:
    """叠加 server.hook 能力到已有档的 manifest 上。

    要求：同一插件的多个代码类入口 MUST 指向同一文件（entryMismatch 校验在 package.py）。
    因此这里必须检查现有 server.tool/server.ui 的 entry，确保一致。
    """
    manifest = _load(manifest_path)
    capabilities = _capabilities(manifest)

    # 检查是否已有代码类能力，并获取其 entry
    code_entry = None
    for kind in ("server.ui", "server.tool"):
        cap = capabilities.get(kind)
        if isinstance(cap, dict) and isinstance(cap.get("entry"), str):
            if code_entry is not None and code_entry != cap["entry"]:
                raise ValueError(f"已有代码类能力 entry 不一致：{kind}={cap['entry']!r}")
            code_entry = cap["entry"]

    # 纯 hook 档时，code_entry 为 None，直接使用传入的 entry
    if code_entry is not None and code_entry != entry:
        raise ValueError(
            f"server.hook.entry ({entry!r}) 与已有代码类能力 entry ({code_entry!r}) 不一致；"
            f"一个插件只有一个 register(ctx) 入口，MUST 指向同一文件"
        )

    # 添加或更新 server.hook 能力
    capabilities["server.hook"] = {
        "entry": entry,
        "events": ["pre_model"],
        "priority": 100
    }

    # 如果还没有 activationEvents，初始化
    if "activationEvents" not in manifest:
        manifest["activationEvents"] = []

    _dump(manifest_path, manifest)
