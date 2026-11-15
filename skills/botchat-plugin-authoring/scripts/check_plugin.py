#!/usr/bin/env python3
"""对任意一个 botChat 插件包目录跑静态对账（`app.extensions.doctor` 的薄包装）。

为什么需要包装：`python -m app.extensions.doctor` 扫的是**已配置的两个 root**
（`serverRoot()/Extensions` 与 `home_root()/Extensions`），而作者在开发期手上的包通常还躺在
自己目录里、没安装。doctor 支持用 `BOTCHAT_EXTENSIONS_ROOT` 改内置 root，本脚本就靠这一点
把「任意父目录」临时当成 root 扫，并顺手关掉用户 root（否则本机已装包的坏诊断会混进你的报告）。

用法：
    python3 check_plugin.py ~/dev/plugins/acme.demo          # 传包目录
    python3 check_plugin.py ~/dev/plugins                    # 传父目录（扫里面所有包）
    python3 check_plugin.py ~/dev/plugins --json             # 机读
    python3 check_plugin.py ~/dev/plugins --server-root /path/to/serverSide

退出码：0 = 通过；1 = 有硬伤；2 = 环境问题（找不到 serverSide / 找不到 python）。

只读：本脚本不写插件包、不装插件、不碰数据库。`wroteFiles` 非空即说明有别的东西在往包里写
（典型是 `__pycache__`），doctor 会把它单独列出来。
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

#: 作者常见布局：源码仓库里的 serverSide 与打包 app 里的 server 都行，两者模块名一致。
_DEFAULT_SERVER_CANDIDATES: tuple[str, ...] = (
    "serverSide",
    "../serverSide",
    "../../serverSide",
    "server",
    "../server",
)


def _pkg_parent(target: Path) -> Path:
    """把用户给的路径归一成「root 目录」（装着若干插件包的父目录）。"""
    if (target / "manifest.json").is_file():
        return target.parent
    return target


def _looks_like_server(path: Path) -> bool:
    return (path / "app" / "extensions" / "doctor.py").is_file()


def _resolve_server_root(explicit: str | None) -> Path | None:
    """定位 serverSide：显式参数 → 环境变量 → 从 cwd 与包目录向上找。"""
    if explicit:
        candidate = Path(explicit).expanduser().resolve()
        return candidate if _looks_like_server(candidate) else None

    from_env = os.environ.get("BOTCHAT_SERVER_ROOT", "").strip()
    if from_env:
        candidate = Path(from_env).expanduser().resolve()
        if _looks_like_server(candidate):
            return candidate

    seeds = [Path.cwd(), Path(__file__).resolve().parent]
    for seed in seeds:
        for base in (seed, *seed.parents):
            for rel in _DEFAULT_SERVER_CANDIDATES:
                candidate = (base / rel).resolve()
                if _looks_like_server(candidate):
                    return candidate
    return None



#: 面板源码门禁（逐项对齐 `clientSide/.../Native/PanelSourceGate.swift`；改了那边要同步这里）。
_PANEL_MAX_BYTES = 256 * 1024
_PANEL_MAX_LINES = 4_000
_PANEL_ALLOWED_IMPORTS = frozenset(
    {"SwiftUI", "AppKit", "Foundation", "Observation", "CoreGraphics", "AVKit", "AVFoundation"}
)
_PANEL_BANNED_SYMBOLS = (
    "FileManager",
    "URLSession",
    "URLRequest",
    "Process(",
    "NSTask",
    "NSAppleScript",
    "NSWorkspace",
    "dlopen",
    "dlsym",
    "SecItem",
    "CGEvent",
    "AXUIElement",
    "NSWindow(",
    "NSPanel(",
)
_PANEL_COLOR_HINTS = ("Color(", "NSColor(", "cgColor")
_HEX_PATTERN = re.compile(r"[#0]x?[0-9A-Fa-f]{6}(?![0-9A-Fa-f])")


def _package_dirs(target: Path) -> list[Path]:
    """本次要检查的包目录（传父目录时逐个列出，避免只查第一个）。"""
    if (target / "manifest.json").is_file():
        return [target]
    return sorted(p for p in target.iterdir() if p.is_dir() and (p / "manifest.json").is_file())


def _panel_entries(manifest_path: Path) -> list[tuple[str, str]]:
    """从清单里取 `client.panel` 的 (view, entry)；清单坏掉时安静跳过（doctor 会报）。"""
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []
    capabilities = manifest.get("capabilities")
    if not isinstance(capabilities, dict):
        return []
    panel = capabilities.get("client.panel")
    if not isinstance(panel, dict):
        return []
    views = panel.get("views")
    if isinstance(views, dict):
        views = [views]
    if not isinstance(views, list):
        return []
    entries: list[tuple[str, str]] = []
    for item in views:
        if not isinstance(item, dict):
            continue
        view, entry = item.get("view"), item.get("entry")
        if isinstance(view, str) and isinstance(entry, str):
            entries.append((view, entry))
    return entries


def _gate_panel_source(source: str) -> list[str]:
    """单文件门禁：与 Swift 侧同规则（含「注释里出现禁用词也算」这条实测口径）。"""
    problems: list[str] = []
    raw = source.encode("utf-8")
    if len(raw) > _PANEL_MAX_BYTES:
        problems.append(f"{len(raw)} 字节 > {_PANEL_MAX_BYTES}")
    lines = source.splitlines()
    if len(lines) > _PANEL_MAX_LINES:
        problems.append(f"{len(lines)} 行 > {_PANEL_MAX_LINES}")
    for number, line in enumerate(lines, start=1):
        trimmed = line.strip()
        if trimmed.startswith("import "):
            name = trimmed[len("import ") :].strip()
            for delimiter in (" ", ";"):
                if delimiter in name:
                    name = name.split(delimiter, 1)[0]
            if name not in _PANEL_ALLOWED_IMPORTS:
                problems.append(
                    f"第 {number} 行：import {name} 不在白名单"
                    f"（只允许 {'/'.join(sorted(_PANEL_ALLOWED_IMPORTS))}）"
                )
            continue
        for symbol in _PANEL_BANNED_SYMBOLS:
            if symbol in line:
                problems.append(f"第 {number} 行：使用了禁用符号 {symbol}")
        if "Color(red:" in line or "Color( red:" in line or "NSColor(calibrated" in line:
            problems.append(f"第 {number} 行：写死了颜色（{trimmed[:40]}）")
        elif any(hint in line for hint in _PANEL_COLOR_HINTS) and _HEX_PATTERN.search(line):
            problems.append(f"第 {number} 行：写死了十六进制色值")
        if "@objc(BotChatPanelEntry)" in line:
            problems.append(
                f"第 {number} 行：入口类名固定（已废弃写法）"
                "（固定类名会让同进程第二个面板拿不到自己的类；"
                "删掉该注解，改用 @_cdecl(\"botchat_panel_entry\") 导出入口）"
            )
    return problems


def _panel_gate_report(packages: list[Path]) -> list[str]:
    """对所有包的面板源文件跑门禁，返回逐条问题（空 = 通过）。"""
    findings: list[str] = []
    for package in packages:
        for view, entry in _panel_entries(package / "manifest.json"):
            source_path = package / entry
            if not source_path.is_file():
                continue
            problems = _gate_panel_source(source_path.read_text(encoding="utf-8", errors="replace"))
            for problem in problems:
                findings.append(f"{package.name}/{entry}（view={view}）：{problem}")
    return findings


def _python_for(server_root: Path) -> str:
    """优先用服务端自己的 venv：依赖版本与宿主一致，才有可比性。"""
    for rel in (".venv/bin/python", "venv/bin/python"):
        candidate = server_root / rel
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return sys.executable


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="对任意插件包目录跑 botChat 扩展静态对账")
    parser.add_argument("target", help="插件包目录，或装着包的父目录")
    parser.add_argument("--server-root", default=None, help="serverSide 目录（缺省自动探测）")
    parser.add_argument("--json", action="store_true", help="输出 doctor 的机读 JSON")
    parser.add_argument(
        "--with-user-root",
        action="store_true",
        help="同时扫本机已安装的用户插件（缺省关掉，避免别人的坏包混进报告）",
    )
    args = parser.parse_args(argv)

    target = Path(args.target).expanduser().resolve()
    if not target.exists():
        print(f"路径不存在：{target}", file=sys.stderr)
        return 2

    server_root = _resolve_server_root(args.server_root)
    if server_root is None:
        print(
            "找不到 serverSide（含 app/extensions/doctor.py 的目录）。\n"
            "用 --server-root 指定，或设 BOTCHAT_SERVER_ROOT。\n"
            "已打包的 app 里对应 botChat.app/Contents/Resources/server。",
            file=sys.stderr,
        )
        return 2

    env = dict(os.environ)
    env["BOTCHAT_EXTENSIONS_ROOT"] = str(_pkg_parent(target))
    if not args.with_user_root:
        env["EXTENSIONS_USER_ROOT_ENABLED"] = "false"
    env.setdefault("PYTHONDONTWRITEBYTECODE", "1")

    cmd = [_python_for(server_root), "-m", "app.extensions.doctor"]
    if args.json:
        cmd.append("--json")
    completed = subprocess.run(cmd, cwd=server_root, env=env, check=False)

    packages = _package_dirs(target)  # 传包目录就只查这个包；传父目录才查全部
    gate_findings = _panel_gate_report(packages)
    if gate_findings:
        print("\n—— 原生面板源码门禁（不进 doctor，失败在客户端侧）——")
        for finding in gate_findings:
            print(f"  [禁止] {finding}")
        print(
            "  说明：面板代码在主进程内同权运行，门禁只挡误用与主题腐烂；"
            "注释里出现禁用词同样会命中。"
        )
    elif packages:
        print("\n原生面板源码门禁：通过（未声明 client.panel 或源码合规）")

    if completed.returncode != 0:
        return completed.returncode
    return 1 if gate_findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
