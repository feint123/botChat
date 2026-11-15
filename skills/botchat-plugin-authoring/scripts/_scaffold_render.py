"""模板树渲染：占位符替换、变体选择、`*.tpl` 去后缀、渲染后残留检测。

两条规则值得单列，因为它们是「拿到的包看起来对、跑起来不对」的来源：

1. **变体只在文件名里表达**。一个模式对同一个落盘文件名可能有多份模板（`plugin.default.py.tpl`
   与 `plugin.compact.py.tpl` —— 面板树与窄槽位的紧凑树）。变体段 MUST 出现在扩展名之前、
   MUST 取自受控词表，否则 `foo.compact.json.tpl` 这种普通文件名会被误当变体吞掉。
2. **片段不落盘**。`templates/fragments/` 不在任何 `<mode>` 目录内（各模式的模板根是
   `templates/<mode>`），所以它天然不会被整树渲染扫到；片段只经 `render_fragment()` 取用，
   拼进宿主模板后随宿主一起过残留检测。
"""

from __future__ import annotations

import re
from pathlib import Path

#: 落盘时剥掉的后缀。
TPL_SUFFIX = ".tpl"

#: 受控变体标记。只有这几个词出现在 `<name>.<variant>.<ext>` 的倒数第二段时才视为变体。
VARIANT_MARKERS: tuple[str, ...] = ("default", "compact")

#: 残留占位符的形态。与既有脚本同口径（只认纯字母键），命中即说明模板与脚本对不上。
_PLACEHOLDER = re.compile(r"\{\{[a-zA-Z]+\}\}")


def substitute(text: str, values: dict[str, str]) -> str:
    """把 `{{key}}` 逐个替换；未在 `values` 里声明的键原样留下，留给残留检测报错。"""
    for key, value in values.items():
        text = text.replace("{{" + key + "}}", value)
    return text


def split_variant(filename: str) -> tuple[str, str | None]:
    """拆出「落盘文件名, 变体名」。无变体段时变体为 `None`（该文件恒渲染）。

    非 `*.tpl` 文件（将来若加二进制样例）原样返回：那时候没有「剥后缀」这回事。
    """
    if not filename.endswith(TPL_SUFFIX):
        return filename, None
    stem = filename[: -len(TPL_SUFFIX)]
    parts = stem.split(".")
    if len(parts) >= 3 and parts[-2] in VARIANT_MARKERS:
        return ".".join([*parts[:-2], parts[-1]]), parts[-2]
    return stem, None


def render_tree(
    template_dir: Path,
    target: Path,
    values: dict[str, str],
    *,
    variant: str,
) -> list[Path]:
    """复制模板树并替换占位符；`*.tpl` 落盘时剥后缀，非本变体的文件跳过。"""
    written: list[Path] = []
    for source in sorted(template_dir.rglob("*")):
        if not source.is_file():
            continue
        if any(part.startswith(".") for part in source.relative_to(template_dir).parts):
            # 点开头的一律不渲染：`.DS_Store` 之类的垃圾会被原样复制进插件包
            # （客户端装载期按包体白名单判，多余文件即整包拒）。
            continue
        relative = source.relative_to(template_dir)
        name, file_variant = split_variant(relative.name)
        if file_variant is not None and file_variant != variant:
            continue
        relative = relative.with_name(name)
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        text = substitute(source.read_text(encoding="utf-8"), values)
        destination.write_text(text, encoding="utf-8")
        written.append(destination)
    return written


def render_fragment(templates_root: Path, relative: str, values: dict[str, str]) -> str:
    """取一段共享片段并替换占位符（片段本身不落盘，只嵌进宿主模板）。"""
    source = templates_root / "fragments" / relative
    if not source.is_file():
        raise FileNotFoundError(f"模板片段缺失：{source}")
    return substitute(source.read_text(encoding="utf-8"), values)


def leftover_placeholders(paths: list[Path]) -> list[str]:
    """渲染后仍有 `{{…}}` 就是模板与脚本对不上：早点炸，别让用户拿到半个包。"""
    leftovers: list[str] = []
    for path in paths:
        match = _PLACEHOLDER.search(path.read_text(encoding="utf-8"))
        if match is not None:
            leftovers.append(f"{path.name}: {match.group(0)}")
    return leftovers
