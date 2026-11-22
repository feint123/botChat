#!/usr/bin/env python3
"""按模板生成一个 botChat 插件包骨架，并顺手跑一次静态对账。

三种档位 ×（可选）五挂载点 ×（可选）工具能力：

    python3 scaffold_plugin.py --id acme.hello --dir ~/dev/plugins
    #   ↑ ui 档（缺省）：面板 + 设置区 + 一条命令，挂 `panel`；
    #     界面是包内 Panels/*.swift（`botchat.panel/1`），预制节点 IR 已下线
    python3 scaffold_plugin.py --id acme.echo --dir ~/dev/plugins --mode tool
    #   ↑ 纯工具档：只有 server.tool，没有界面
    python3 scaffold_plugin.py --id acme.chart --dir ~/dev/plugins --mode native
    #   ↑ 原生档：与 ui 档同一种渲染体，差别只在主视图的图标与 priority 缺省值

    # 五挂载点（缺省 panel）：panel / settings.section / sidebar.section /
    #                      composer.accessory / window
    python3 scaffold_plugin.py --id acme.side --dir ~/dev/plugins --slot sidebar.section
    python3 scaffold_plugin.py --id acme.win  --dir ~/dev/plugins --slot window
    python3 scaffold_plugin.py --id acme.bar  --dir ~/dev/plugins --slot composer.accessory

    # 组合包：界面 + 工具写在**同一份 entry** 里
    python3 scaffold_plugin.py --id acme.combo --dir ~/dev/plugins --with-tool --tool echo
    python3 scaffold_plugin.py --id acme.combo2 --dir ~/dev/plugins --mode native --with-tool

    # 主题包（只能随 app 分发；`builtin.` 前缀需显式开关）
    python3 scaffold_plugin.py --id acme.sunset --mode theme \\
        --dir ~/botChat/clientSide/botChat/Extensions
    python3 scaffold_plugin.py --id builtin.sunset --mode theme --allow-builtin-prefix \\
        --dir ~/botChat/clientSide/botChat/Extensions

    ... --no-check   只生成，不跑 doctor
    ... --force      目标目录已存在也覆盖

三条不可省的规则（脚本会替你守住前两条）：
1. 包目录名 MUST 等于清单 `id`（目录名是加载器的寻址键，不一致会被当两种包互相静默吞掉）；
2. `id` MUST NOT 以 `builtin.` 开头（该前缀保留给随应用分发的包；`--allow-builtin-prefix` 才放行，
   且只对 `--mode theme` 有意义 —— 服务端加载器的其它 kind 没有「内置」这条路）；
3. 生成后真正的生效时机是「安装 → 启用 → 重启宿主」，改包也要重启（本期无热重载）。

零依赖：只用标准库；对账那步交给同目录的 `check_plugin.py`。
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

from _scaffold_manifest import apply_with_hook, apply_with_tool, verify_json
from _scaffold_render import leftover_placeholders, render_fragment, render_tree
from _scaffold_slots import SLOT_NOTES, SLOT_QUICKBAR_NOTE, SLOTS, variant_for
from _scaffold_theme import build_notes, validate_theme_json

#: 模板根：`<skill>/templates/<mode>`；共享片段在 `<skill>/templates/fragments/`。
_TEMPLATES = Path(__file__).resolve().parent.parent / "templates"

#: 目录名与清单 id 的合法字符：文件系统与 SDK 模块名都要吃得住。
_ID_PATTERN = re.compile(r"^[a-z][a-z0-9._-]*$")

#: 视图名/工具名会进 Python 标识符（`def {{tool}}(...)`），故与 id 同口径收紧。
_NAME_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")

#: `settings` 是模板固定注册的第二个视图名；主视图撞名会让 `ctx.view` 抛 `HostFault`。
_RESERVED_VIEW = "settings"

#: 哪些模式带界面能力（`--slot` / `--with-tool` 只对它们有意义）。
_UI_MODES: tuple[str, ...] = ("ui", "native")

#: 哪些模式有 Python 代码入口（`--with-hook` 只对这些档有意义）。
_CODE_MODES: tuple[str, ...] = ("ui", "native", "tool", "hook")


def _sanitize_module(text: str) -> str:
    """与宿主同口径：点号与连字符归一为下划线（对外工具名 = `<id>__<tool>`）。"""
    return re.sub(r"[^a-z0-9_]", "_", text.lower())


def _check_id(extension_id: str, *, allow_builtin: bool) -> str | None:
    if extension_id.startswith("builtin.") and not allow_builtin:
        return "id 不能以 builtin. 开头（保留给随应用分发的内置包；确属内置包加 --allow-builtin-prefix）"
    if not _ID_PATTERN.match(extension_id):
        return "id 只允许小写字母开头，含 a-z 0-9 . _ -"
    return None


def _check_combination(args: argparse.Namespace, parser: argparse.ArgumentParser) -> str | None:
    """拒绝「无意义 / 会静默产出坏包」的参数组合。返回错误文本（None = 放行）。"""
    if args.mode not in _UI_MODES:
        # 显式给错才拒；缺省值（panel / False）不算用户的表达。
        if args.slot != parser.get_default("slot"):
            return f"--slot 只对 --mode ui / native 有意义（{args.mode} 档没有 client.view）"
        if args.with_tool and args.mode != "tool":
            return "--with-tool 只叠加在 --mode ui / native 上（tool 档本身就是工具，theme 档没有代码）"
    if args.with_hook and args.mode not in _CODE_MODES:
        return "--with-hook 只叠加在 ui / native / tool / hook 档上（theme 档没有 Python 代码入口）"
    if args.mode == "hook" and args.with_hook:
        return "--mode hook 的清单已含 server.hook；再给 --with-hook 会把 hooks 片段重复拼进 hooks.py，二选一"
    if args.with_tool and args.tool == args.view:
        return (
            f"--tool 与 --view 同名（都是 {args.view}）：两者写在同一个 entry 里，"
            "def 会互相覆盖（ctx.tool 收的是最后一个）"
        )
    if args.view == _RESERVED_VIEW:
        return (
            f"--view 不能是 {_RESERVED_VIEW}：模板固定注册第二个视图 {_RESERVED_VIEW}，"
            "同名会让 ctx.view 抛 HostFault（视图重复注册）"
        )
    for label, value in (("--view", args.view), ("--tool", args.tool)):
        if not _NAME_PATTERN.match(value):
            return f"{label} 只允许小写字母开头，含 a-z 0-9 _（它要进 Python 标识符）"
    return None


def _values(args: argparse.Namespace, *, tool_block: str = "", tool_register: str = "", hook_block: str = "") -> dict[str, str]:
    """模板占位符取值表。`toolBlock` / `toolRegister` / `hookBlock` 为空串时不留空行。"""
    return {
        "id": args.id,
        "name": args.name or args.id,
        "version": args.version,
        "minAppVersion": args.min_app_version,
        "tool": args.tool,
        "toolFull": f"{_sanitize_module(args.id)}__{_sanitize_module(args.tool)}",
        "view": args.view,
        "command": args.command or f"{args.id}.open",
        "slot": args.slot,
        "toolBlock": tool_block,
        "toolRegister": tool_register,
        "hookBlock": hook_block,
    }


def _server_root_args(raw: str | None) -> list[str]:
    """把 `--server-root` 透传给 `check_plugin.py`；未给时不留空参。"""
    if not raw:
        return []
    return ["--server-root", raw]


def _tool_fragments(templates: Path, values: dict[str, str], *, enabled: bool) -> tuple[str, str]:
    """取两段工具片段；未启用时回两个空串（占位符被替换掉，不会残留）。"""
    if not enabled:
        return "", ""
    block = render_fragment(templates, "tool_block.py.tpl", values)
    register = render_fragment(templates, "tool_register.py.tpl", values)
    return block, register


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="生成 botChat 插件包骨架（ui / tool / native / theme 四档）",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "五挂载点只对 ui / native 有意义：panel / settings.section / sidebar.section /\n"
            "composer.accessory / window。第六个渲染位置 `client.row`（轮级行）不是 slot，\n"
            "它是独立能力 kind，需要手写清单添加（每轮一行，单包条数上限 4）。"
        ),
    )
    parser.add_argument("--id", required=True, help="插件 id，同时是包目录名（如 acme.hello）")
    parser.add_argument("--name", default=None, help="展示名（缺省用 id）")
    parser.add_argument("--dir", default=".", help="父目录（包会建在 <dir>/<id>）")
    parser.add_argument(
        "--mode",
        choices=("ui", "tool", "native", "theme", "hook"),
        default="ui",
        help="ui=带界面的插件（原生面板，默认）/ tool=纯工具 / native=同 ui，但缺省图标与优先级不同 / theme=主题包",
    )
    parser.add_argument("--version", default="0.1.0")
    parser.add_argument("--min-app-version", default="0.1.0")
    parser.add_argument(
        "--tool", default="echo", help="工具名（插件内名；--mode tool 与 --with-tool 用）"
    )
    parser.add_argument("--view", default="main", help="主视图名")
    parser.add_argument("--command", default=None, help="命令 id（缺省 <id>.open）")
    parser.add_argument(
        "--slot",
        choices=SLOTS,
        default="panel",
        help="主视图挂载点（只对 ui / native 有意义；缺省 panel）",
    )
    parser.add_argument(
        "--with-tool", action="store_true", help="在 ui / native 档上叠加工具能力（同一份 entry）"
    )
    parser.add_argument(
        "--with-hook", action="store_true", help="在 ui / native / tool / hook 档上叠加 server.hook 能力到同一 entry 文件"
    )
    parser.add_argument(
        "--allow-builtin-prefix",
        action="store_true",
        help="允许 builtin. 前缀（只给随 app 分发的内置主题包；缺省关闭）",
    )
    parser.add_argument("--no-check", action="store_true", help="不跑静态对账")
    parser.add_argument(
        "--server-root",
        default=None,
        help="serverSide 目录（转给 check_plugin.py；缺省自动探测或读 BOTCHAT_SERVER_ROOT）",
    )
    parser.add_argument("--force", action="store_true", help="目标目录已存在时覆盖")
    args = parser.parse_args(argv)

    problem = _check_id(args.id, allow_builtin=args.allow_builtin_prefix)
    if problem is not None:
        print(f"id 不合法：{problem}", file=sys.stderr)
        return 2
    problem = _check_combination(args, parser)
    if problem is not None:
        print(f"参数组合不允许：{problem}", file=sys.stderr)
        return 2

    template_dir = _TEMPLATES / args.mode
    if not template_dir.is_dir():
        print(f"模板缺失：{template_dir}", file=sys.stderr)
        return 2

    parent = Path(args.dir).expanduser().resolve()
    target = parent / args.id
    if target.exists() and not args.force:
        print(f"目标已存在：{target}（要覆盖加 --force）", file=sys.stderr)
        return 2

    probe = _values(args, tool_block="", tool_register="")
    tool_block, tool_register = _tool_fragments(
        _TEMPLATES, probe, enabled=args.with_tool and args.mode in _UI_MODES
    )

    # Hook fragment for --with-hook
    if args.with_hook and args.mode in _CODE_MODES:
        hook_probe = _values(args)
        hook_block = render_fragment(_TEMPLATES, "hook_block.py.tpl", hook_probe)
        values = _values(args, tool_block=tool_block, tool_register=tool_register, hook_block=hook_block)
    else:
        values = _values(args, tool_block=tool_block, tool_register=tool_register, hook_block="")

    variant = variant_for(mode=args.mode, slot=args.slot)
    written = render_tree(template_dir, target, values, variant=variant)

    leftovers = leftover_placeholders(written)
    if leftovers:
        shutil.rmtree(target, ignore_errors=True)
        print("模板占位符没替换干净，已回滚：\n  " + "\n  ".join(leftovers), file=sys.stderr)
        return 2

    payload = target / "theme.json"
    if args.with_tool and args.mode in _UI_MODES:
        apply_with_tool(target / "manifest.json", tool=args.tool, tool_full=values["toolFull"])
    
    # Handle --with-hook
    if args.with_hook and args.mode in _CODE_MODES:
        # Determine the entry file based on mode
        if args.mode == "hook":
            entry_file = "hooks.py"
        elif args.mode == "tool":
            entry_file = "tools.py"
        else:  # ui or native
            entry_file = "plugin.py"
        
        # Append hooks fragment to entry file
        if values.get("hookBlock"):
            entry_path = target / entry_file
            existing = entry_path.read_text(encoding="utf-8")
            entry_path.write_text(existing + values["hookBlock"], encoding="utf-8")
        
        apply_with_hook(target / "manifest.json", entry=entry_file)

    problems = verify_json(target / "manifest.json", *([payload] if payload.is_file() else []))
    if not problems and payload.is_file():
        problems = validate_theme_json(payload)
    if problems:
        shutil.rmtree(target, ignore_errors=True)
        print("生成物没通过自检，已回滚：\n  " + "\n  ".join(problems), file=sys.stderr)
        return 2

    print(f"已生成 {args.mode} 档插件：{target}")
    print(f"  主视图挂载点：{args.slot} —— {SLOT_NOTES[args.slot]}")
    if args.mode == "ui" and variant == "compact":
        print("  窄槽位：主视图已换成 Row 根紧凑树（该 slot 的节点白名单不收 Column）。")
    if args.slot == "window":
        print(f"  {SLOT_QUICKBAR_NOTE}")
    if args.with_tool and args.mode in _UI_MODES:
        print(f"  组合包：server.tool 与 server.ui 共用同一份 entry，对外工具名 {values['toolFull']}")
    if args.with_hook and args.mode in _CODE_MODES:
        if args.with_tool and args.mode in _UI_MODES:
            print(f"  组合包：server.tool、server.ui 与 server.hook 共用同一份 entry")
        elif args.mode == "hook":
            print(f"  纯 hook 档：entry = hooks.py")
        else:
            print(f"  组合包：server.hook 叠加在现有能力上")
    for path in written:
        print(f"  {path.relative_to(target)}")
    if args.mode == "theme":
        for note in build_notes(extension_id=args.id, allow_builtin=args.allow_builtin_prefix):
            print(f"  · {note}")

    if args.no_check:
        print("\n跳过对账（--no-check）。手动跑：python3 check_plugin.py " + str(target))
        if args.mode == "theme":
            print("注意：theme 档还差**客户端装载期**校验（41 角色已由本脚本自检；对比度基线与派生回归未验证）。")
        return 0

    checker = Path(__file__).resolve().parent / "check_plugin.py"
    print("\n—— 静态对账 ——")
    if args.mode == "theme":
        print("口径：本次只对账**清单**。`client.theme` 的载荷（theme.json）不在服务端 doctor 的")
        print("      覆盖范围内 —— 上面那步 41 角色 / 派生禁写 / 色值形态是本脚本按客户端判据自检的；")
        print("      对比度基线与派生回归只在客户端装载期判。")
    completed = subprocess.run(
        [sys.executable, str(checker), str(target), *_server_root_args(args.server_root)],
        check=False,
    )
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
