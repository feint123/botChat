"""主题包（`client.theme`）脚手架：角色表镜像、载荷自检、生成后提示。

## 为什么脚手架要自带一份角色表

主题包**没有服务端语义校验**：`doctor` 只认清单（`client.theme.entry` 指向的文件存在即可），
`theme.json` 的内容由客户端 `ThemeValidator` 在**装载期**判。也就是说「把 41 个角色写成 3 个、
色值写 `zzz`」照样能过 doctor、装得上、启用得了，只有用户切到那个主题时整包降级。
故这里把判据镜像到生成期，让错误在自己的终端里就暴露。

镜像范围（逐项对齐 `clientSide/botChat/Services/Extensions/ThemeValidationRules.swift`）：
角色完整 / 派生禁写 / 顶层键 / 色值形态 / 成对。
**不镜像**对比度基线、亮度阶梯与派生回归 —— 那是 3 张会随内置主题调整的表（`contrastBaselines`
/ `derivedExpectations`），抄一份进来一定会漂移；那三项以客户端装载期结论为准。
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

#: 41 个可写角色（`ThemeValidationRules.writableRoles` 的逐行镜像；少一个即整包无效）。
WRITABLE_ROLES: tuple[str, ...] = (
    "bg.canvas",
    "bg.surface",
    "bg.surfaceRaised",
    "bg.surfaceSunken",
    "bg.fillSubtle",
    "bg.selection",
    "bg.selectionEmphasis",
    "bg.selectionBorder",
    "fg.primary",
    "fg.secondary",
    "fg.tertiary",
    "border.default",
    "border.muted",
    "border.strong",
    "border.focus",
    "brand.base",
    "brand.pressed",
    "brand.emphasis",
    "brand.text",
    "status.pending.fg",
    "status.pending.subtle",
    "status.running.fg",
    "status.running.subtle",
    "status.done.fg",
    "status.done.subtle",
    "status.failed.fg",
    "status.failed.subtle",
    "status.warning.fg",
    "status.muted.fg",
    "categorical.1",
    "categorical.2",
    "categorical.3",
    "categorical.4",
    "categorical.5",
    "syntax.keyword",
    "syntax.type",
    "syntax.function",
    "syntax.string",
    "syntax.number",
    "syntax.comment",
    "syntax.property",
)

#: 5 个派生角色：由引擎按公式算，MUST NOT 出现在数据里（出现即整包无效）。
DERIVED_ROLES: frozenset[str] = frozenset(
    {"fg.disabled", "brand.subtle", "status.warning.subtle", "status.muted.subtle", "syntax.punctuation"}
)

#: `theme.json` 顶层允许的键（之外记未知键诊断，不失败）。
TOP_LEVEL_KEYS: frozenset[str] = frozenset({"schemaVersion", "extends", "colors"})

#: 载荷 schema 版本：**是 1 不是 2**（清单另有版本，两者独立）。
THEME_SCHEMA_VERSION = 1

_HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")


def validate_theme_json(path: Path) -> list[str]:
    """按客户端装载期判据自检 `theme.json`，返回问题清单（空 = 通过）。"""
    try:
        raw: Any = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return [f"theme.json 不是合法 JSON：{error.msg}（第 {error.lineno} 行）"]
    if not isinstance(raw, dict):
        return ["theme.json 顶层 MUST 是 JSON 对象"]

    problems: list[str] = []
    if raw.get("schemaVersion") != THEME_SCHEMA_VERSION:
        problems.append(
            f"theme.json 的 schemaVersion MUST 是 {THEME_SCHEMA_VERSION}（当前 {raw.get('schemaVersion')!r}）；"
            "主题载荷版本与清单版本是两个独立字段"
        )
    unknown_top = sorted(set(raw) - TOP_LEVEL_KEYS)
    if unknown_top:
        problems.append(f"theme.json 顶层出现契约外的键（客户端记未知键诊断）：{unknown_top}")

    colors = raw.get("colors")
    if not isinstance(colors, dict):
        problems.append("theme.json 缺少 colors 对象")
        return problems

    provided = set(colors)
    missing = [role for role in WRITABLE_ROLES if role not in provided]
    if missing:
        problems.append(f"缺少 {len(missing)} 个必需角色（缺一即整包无效，不做单键回落）：{missing}")
    derived = sorted(provided & DERIVED_ROLES)
    if derived:
        problems.append(f"派生角色 MUST NOT 出现在数据里（由引擎按公式计算）：{derived}")

    for role in sorted(provided):
        pair = colors[role]
        if not isinstance(pair, dict):
            problems.append(f"角色 {role} 的取值 MUST 是 {{light, dark}} 对象")
            continue
        extra = sorted(set(pair) - {"light", "dark"})
        if extra:
            problems.append(f"角色 {role} 出现契约外的子键：{extra}")
        for mode in ("light", "dark"):
            value = pair.get(mode)
            if not isinstance(value, str) or not _HEX.match(value):
                problems.append(f"角色 {role}.{mode} 的值 {value!r} 不是 #RRGGBB 形态")
    return problems


def build_notes(*, extension_id: str, allow_builtin: bool) -> list[str]:
    """`theme` 模式生成后 MUST 说的话（分发路径 + 校验口径 + 未覆盖项）。"""
    notes = [
        "主题包只能随 app 分发：客户端主题加载器唯一的 root 是 bundle 内的 `Extensions/`，"
        "没有「用户目录主题」这条路。",
        "落盘目标父目录建议 `clientSide/botChat/Extensions/`（构建时进 app 的 resource bundle）。",
        "校验口径：`check_plugin.py` 只覆盖**清单**（entry 存在性等）；`theme.json` 的语义"
        "（41 角色完整 / 派生禁写 / 色值形态）由本脚本按客户端判据自检，"
        "对比度基线与派生回归只在客户端装载期判 —— 服务端 doctor **不覆盖** theme.json 内容。",
        "骨架里的 41 个色值是从 `builtin.paper-warm` 抄来的真实取值，MUST 逐个改成自己的配色；"
        "原样发布等于一个 paper-warm 的副本。",
    ]
    if allow_builtin:
        notes.insert(
            0,
            f"`{extension_id}` 带 `builtin.` 前缀 —— 只给**随 app 分发**的内置包用；"
            "第三方包用这个前缀会被客户端以 `reservedIdPrefix` 拒绝。",
        )
    return notes
