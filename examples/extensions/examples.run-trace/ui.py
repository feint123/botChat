"""`examples.run-trace` 的展示层：宿主轨迹读口 → `botchat.panel/1` data 的唯一投影点。

**纯函数**：零 IO、零写、渲染期无副作用（同一份输入必得同一份 data）—— 于是「打开一次」与
「点一次刷新」在服务端是同一段代码（`design.md` D7：重渲染即刷新，不建定时器、不做轮内推送）。
data 形状与两条必须与面板侧逐字对齐的口径（`runs` 缺席 ≠ 空数组；进行中的 `endedAt` 缺席）
见同目录 `README.md` §「data 契约」；裁剪条数一律如实回传，MUST NOT 静默少给。
"""

from __future__ import annotations

import json
from collections.abc import Mapping
from typing import Final, Protocol, cast

#: 视图 id：与清单三处声明同值；`TITLE` 与 `client.view.title` 同值，便于两侧对照。
VIEW_ID: Final[str] = "run-trace"
TITLE: Final[str] = "运行轨迹"
#: 一页多少轮（spec「默认页大小 MUST 为 20 轮」）。插件 MUST NOT 擅自抬高。
MAX_TURNS: Final[int] = 20
#: 单个工具列表 / 单轮子代理最多进 data 多少条（可读性与载荷预算的双重上限）。
MAX_TOOLS_PER_LIST: Final[int] = 40
MAX_SUBAGENTS_PER_TURN: Final[int] = 20

#: 整份 data 的字节预算：硬顶 256 KB，留出信封（`schema` / `rev` / `diagnostics`）与固定键余量。
BUDGET_BYTES: Final[int] = 192 * 1024

#: 取不到数据时的说明文案（键是内部原因码；面板对未知取值原样回显，故这里是中文句子）。
REASON_TEXTS: Final[dict[str, str]] = {
    "no_trace_api": "宿主版本不支持轨迹读口（缺少 ext.host.trace），拿不到运行轨迹",
    "permission_denied": "本插件没有会话读权限（清单需声明 permissions.conversation: [read]）",
    "method_missing": "宿主不认轨迹读口方法（宿主版本过旧），拿不到运行轨迹",
    "host_unavailable": "宿主当前不可用，取不到运行轨迹",
    "malformed": "宿主返回的轨迹形状不可读（缺 turns 列表）",
    "read_failed": "读取运行轨迹失败，稍后点刷新重试",
}

#: 跨界错误码 → 原因码。**只读 `code`**：跨进程后异常类身份不传递（`host_faults` 的硬约束）。
CODE_REASONS: Final[dict[int, str]] = {
    -32001: "permission_denied",  # PERMISSION_DENIED
    -32004: "permission_denied",  # SANDBOX_DENIED
    -32601: "method_missing",  # METHOD_NOT_FOUND
    -32002: "host_unavailable",  # HOST_UNAVAILABLE
    -32008: "host_unavailable",  # TRANSPORT_CLOSED
}


class TraceTurnsApi(Protocol):
    """`ctx.host.trace` 的形状（只声明本插件用到的方法）。"""

    def turns(self, limit: int = MAX_TURNS) -> object:
        """一页轨迹事实：`{turns: [...], hasMore: bool}`。"""


class ViewContext(Protocol):
    """`register(ctx)` 需要的注册面。"""

    host: object

    def view(self, name: str, handler: object) -> None:
        """注册一个视图渲染器。"""


def register(ctx: ViewContext) -> None:
    """插件唯一入口：注册面板视图（本插件没有工具、没有 hook）。

    读口在注册期取一次并闭包捕获：重渲染是同一段纯函数，不在渲染期探测宿主属性。
    """
    api = trace_api(ctx.host)

    def render_view(payload: Mapping[str, object]) -> dict[str, object]:
        """视图处理器：宿主每次渲染 / 交互都会调它一次。"""
        del payload  # 面板没有参数面：轨迹永远是「当前会话最近若干轮」。
        raw, reason = fetch(api)
        return panel_data(raw, reason=reason)

    ctx.view(VIEW_ID, render_view)


def trace_api(host: object) -> TraceTurnsApi | None:
    """从宿主取 `trace` 命名空间；宿主版本不支持时 `None`（不猜、不抛）。

    用 `getattr` 而不是 `isinstance(host, TraceHost)`：带数据成员的协议要 `@runtime_checkable`
    才能 `isinstance`，而把「宿主版本旧」变成一次异常是更坏的结果。
    """
    namespace = cast("object", getattr(host, "trace", None))
    if namespace is None or not callable(cast("object", getattr(namespace, "turns", None))):
        return None
    return cast("TraceTurnsApi", namespace)


def fetch(api: TraceTurnsApi | None) -> tuple[dict[str, object] | None, str]:
    """调用读口；返回 `(原始载荷, 取不到的原因码)`。成功时原因码是空串。"""
    if api is None:
        return None, "no_trace_api"
    try:
        result = api.turns(limit=MAX_TURNS)
    except Exception as exc:  # 读口失败 MUST NOT 让面板整张崩：降级成可读占位
        return None, reason_of(exc)
    if not isinstance(result, dict):
        return None, "malformed"
    return cast("dict[str, object]", result), ""


def reason_of(exc: BaseException) -> str:
    """异常 → 原因码：先读 `code`，再读 `details["code"]`，都没有即 `read_failed`。"""
    details = getattr(exc, "details", None)
    nested = (
        cast("dict[object, object]", details).get("code") if isinstance(details, dict) else None
    )
    for code in (getattr(exc, "code", None), nested):
        if isinstance(code, int) and not isinstance(code, bool):
            return CODE_REASONS.get(code, "read_failed")
    return "read_failed"


def panel_data(raw: Mapping[str, object] | None, *, reason: str = "") -> dict[str, object]:
    """一份合法 data：**任何情况**都返回共享键集；`runs` 只在取到数据时出现（缺席 ≠ 空数组）。"""
    reason_text = "" if raw is not None else REASON_TEXTS.get(reason, REASON_TEXTS["read_failed"])
    head: dict[str, object] = {
        "available": raw is not None,
        "reason": reason_text,
        "title": TITLE,
        "limit": MAX_TURNS,
        "turnCount": 0,
        "hiddenRuns": 0,
        "hasMore": False,
        "truncatedTools": 0,
        "hiddenSubagents": 0,
        # 取不到数据时 MUST NOT 声称「一轮都没跑过」——那是把「没数据」当成「没跑过」。
        "summary": "取不到运行轨迹" if raw is None else "",
        "notice": reason_text,
    }
    if raw is None:
        return head

    turns = [turn for item in _items(raw.get("turns")) if (turn := decode_turn(item)) is not None]
    turns.sort(key=_sort_key)
    kept, dropped = fit(turns, overhead=_json_size(head))
    # 宿主侧的字节裁剪（`truncatedTurns`）与本地裁剪合并计数：两者都是「这一页不完整」。
    hidden = dropped + _int(raw.get("truncatedTurns"))
    has_more = raw.get("hasMore") is True or hidden > 0
    truncated = sum(_int(turn.get("truncatedTools")) for turn in kept)
    subagents = sum(_int(turn.get("hiddenSubagents")) for turn in kept)
    summary, notice = headline(
        kept, hidden=hidden, has_more=has_more, truncated=truncated, subagents=subagents
    )
    return {
        **head,
        "turnCount": len(kept),
        "hiddenRuns": hidden,
        "hasMore": has_more,
        "truncatedTools": truncated,
        "hiddenSubagents": subagents,
        "summary": summary,
        "notice": notice,
        "runs": kept,
    }


def decode_turn(item: Mapping[str, object]) -> dict[str, object] | None:
    """解一条轮；`turnId` 缺失即整条丢弃（不猜、不补）。"""
    turn_id = _text(item, "turnId")
    if turn_id == "":
        return None
    turn: dict[str, object] = {
        "turnId": turn_id,
        "label": _text(item, "label"),
        "status": _text(item, "status"),
    }
    _put_int(turn, item, "index")
    _put_times(turn, item)
    turn["tools"], hidden_tools = _decode_tools(item.get("tools"))
    turn["subagents"], hidden_subagents = _decode_subagents(item.get("subagents"))
    turn["truncatedTools"] = _int(item.get("truncatedTools")) + hidden_tools
    turn["hiddenSubagents"] = hidden_subagents
    return turn


def _decode_subagents(value: object) -> tuple[list[dict[str, object]], int]:
    """子代理列表：按 `MAX_SUBAGENTS_PER_TURN` 裁，返回 `(保留项, 被裁条数)`。

    身份读 `runId`（宿主读口的字段名）并同时容忍 `taskId`：两个名字指的是同一件事，
    面板统一按 `taskId` 消费。
    """
    rows: list[dict[str, object]] = []
    for item in _items(value):
        task_id = _text(item, "runId") or _text(item, "taskId")
        name = _text(item, "name")
        if task_id == "" and name == "":
            continue
        row: dict[str, object] = {"taskId": task_id, "name": name, "status": _text(item, "status")}
        _put_times(row, item)
        row["tools"], hidden = _decode_tools(item.get("tools"))
        row["truncatedTools"] = _int(item.get("truncatedTools")) + hidden
        rows.append(row)
    return _capped(rows, MAX_SUBAGENTS_PER_TURN)


def _decode_tools(value: object) -> tuple[list[dict[str, object]], int]:
    """工具列表：按 `MAX_TOOLS_PER_LIST` 裁，返回 `(保留项, 被裁条数)`。"""
    rows: list[dict[str, object]] = []
    for item in _items(value):
        name = _text(item, "name")
        if name == "":
            continue
        row: dict[str, object] = {"name": name, "status": _text(item, "status")}
        row["label"] = _text(item, "label")
        _put_times(row, item)
        rows.append(row)
    return _capped(rows, MAX_TOOLS_PER_LIST)


def _capped(rows: list[dict[str, object]], limit: int) -> tuple[list[dict[str, object]], int]:
    """同层排序 + 按上限裁剪；返回 `(保留项, 被裁条数)`。"""
    rows.sort(key=_sort_key)
    return rows[:limit], max(0, len(rows) - limit)


def fit(turns: list[dict[str, object]], *, overhead: int) -> tuple[list[dict[str, object]], int]:
    """按字节预算贪心装轮（顺序不变）：返回 `(保留项, 未显示轮数)`。"""
    total: int = overhead
    kept: list[dict[str, object]] = []
    for turn in turns:
        size = _json_size(turn) + 1
        if kept and total + size > BUDGET_BYTES:
            break
        kept.append(turn)
        total += size
    return kept, len(turns) - len(kept)


def headline(
    turns: list[dict[str, object]], *, hidden: int, has_more: bool, truncated: int, subagents: int
) -> tuple[str, str]:
    """头部两句话：`(一句话摘要, 提示)`。提示为空串表示无需提示。"""
    # 「装不下的轮」与「更早的轮次」两条尾巴，摘要与提示共用同一份口径。
    tail = [f"还有 {hidden} 轮未显示（超出载荷预算）"] if hidden > 0 else []
    if has_more:
        tail.append("更早的轮次不在本页")
    summary = " · ".join(
        [f"{len(turns)} 轮", f"{sum(_tool_count(turn) for turn in turns)} 次工具", *tail]
    )
    notice: list[str] = []
    if truncated > 0:
        notice.append(f"还有 {truncated} 项工具未显示（超出单轮显示上限）")
    if subagents > 0:
        notice.append(f"还有 {subagents} 个子代理未显示")
    return summary, "；".join([*notice, *tail])


def _tool_count(turn: Mapping[str, object]) -> int:
    """一轮里 data 中真实存在的工具条数（含各子代理下的）。"""
    subs = sum(len(_items(sub.get("tools"))) for sub in _items(turn.get("subagents")))
    return len(_items(turn.get("tools"))) + subs


def _sort_key(item: Mapping[str, object]) -> tuple[str, str]:
    """同层排序键：起始时刻（ISO-8601 字典序即时序）+ 身份。缺席者排最前，MUST NOT 冒充「最晚」。"""
    identity = _text(item, "turnId") or _text(item, "taskId") or _text(item, "name")
    return (_text(item, "startedAt"), identity)


def _put_times(target: dict[str, object], source: Mapping[str, object]) -> None:
    """时刻键与 `durationMs`：缺席就是事实（进行中 / 未配对），MUST NOT 用 `0` 或当前时刻补齐。"""
    for key in ("startedAt", "endedAt"):
        value = _text(source, key)
        if value != "":
            target[key] = value
    _put_int(target, source, "durationMs")


def _put_int(target: dict[str, object], source: Mapping[str, object], key: str) -> None:
    """整数字段：缺 / 布尔 / 负数一律不出现（「算不出来」不冒充 `0`）。"""
    value = source.get(key)
    if isinstance(value, int) and not isinstance(value, bool) and value >= 0:
        target[key] = value


def _text(source: Mapping[str, object], key: str) -> str:
    """取字符串字段；缺 / 非字符串即空串（面板只需判空，不用管 JSON 类型）。"""
    value = source.get(key)
    return value if isinstance(value, str) else ""


def _int(value: object) -> int:
    """取非负整数；其余一律 `0`（只用于**派生合计**，不用于透传事实）。"""
    return value if isinstance(value, int) and not isinstance(value, bool) and value >= 0 else 0


def _items(value: object) -> list[Mapping[str, object]]:
    """数组取值：非数组给空列表，数组里的非对象项逐项丢弃（不猜、不崩）。"""
    if not isinstance(value, list):
        return []
    items: list[object] = cast("list[object]", value)
    return [cast("dict[str, object]", item) for item in items if isinstance(item, dict)]


def _json_size(value: object) -> int:
    """一份 JSON 值的序列化字节数（载荷预算的唯一度量口径）。"""
    return len(json.dumps(value, ensure_ascii=False).encode("utf-8"))
