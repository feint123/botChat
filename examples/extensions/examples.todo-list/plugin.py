"""待办清单插件 —— 面板视图 + Agent 工具，共用同一份 JSON。

## 为什么数据落在 `~/.botchat/todos/`，而不是 `${workspace}`

这是契约现状逼出来的结论，不是偏好：

1. `${workspace}` 只在**清单侧**被展开（`sandbox_build.expand_prefix`）。插件调用
   `ctx.host.fs.write` 时传进去的字符串会进入 `sandbox_policy.path_allowed`，那里只做
   `expanduser()` + `resolve(strict=False)`，**不做占位符替换**；带 `${workspace}` 的路径
   不是绝对路径，`canonical_path` 直接返回 None ⇒ 判为越界（fail-closed）。
2. 插件能看到的路径类事实只有 `state.workspaceName`，而它是 `home_root()` 的**目录名**
   （不含任何层级，见 `ui_state.build_state`），拼不出绝对路径。
3. 生产装配用 `ExtensionAssembly()` 无参构造，`workspace` 回落 `Path.cwd()`（服务端进程
   cwd），所以清单里写 `${workspace}/...` 展开出来的位置与「用户正在编辑的项目」无关。

两条合起来的结论：能让**清单侧前缀**与**插件侧实参**对齐的形态只剩 `~` 展开（两侧都过
`expanduser`）。`~/.botchat/` 也正是本仓跨会话记忆（`~/.botchat/memory/`）的既定位置，
个人待办放在同一棵树下不额外制造约定。

## 渲染期与写入期的分工

`ui.render` 期宿主禁止一切写型调用（`host_plugin_api._reject_write_during_render` 会直接抛
`permissionDenied`），所以：**读**盘发生在首次渲染（`_ensure_loaded`），**写**盘只发生在
`ui.action` 与工具调用里。渲染函数因此是纯函数（同一输入同一份 data），副作用只在 handler 层。

## 渲染体：两个视图都是原生面板

`panel` 槽的 `main`（`Panels/Todo.swift`）与 `settings.section` 槽的 `settings`
（`Panels/Settings.swift`）都声明为 `render: "native"`，因此 `view_main` / `view_settings`
返回的都是 **data**（`botchat.panel/1`）而不是 IR 树。两件事 MUST 同时成立，否则服务端会把
data 当 IR 校验并降级：

1. 两个视图函数的返回值满足 `panel_data` / `settings_data` 的形状（顶层对象、键名 ASCII、
   数组有上限）；
2. 服务端动作链按清单的 `render` 选校验器（`ui_action._dispatch_action_impl`）。

`settings` 不是「顺带改的」：样例清单是 IR 下线的**随仓样板**，留一条 IR 视图就等于给读者
示范已废弃写法。

动作参数从 `arguments` 进：原生面板的 `host.dispatch("add", ["title": …])` 在插件侧
落到 `payload["arguments"]`；`values` 是 IR 时代的上行形态，`_handle_node` 两个都读，
因为动作载荷的两种形状由服务端路由决定，插件不该因为自己换了渲染体就少认一种。
"""

from __future__ import annotations

import json
from collections.abc import Callable
from datetime import UTC, datetime
from typing import Final, NotRequired, Protocol, TypedDict, cast
from uuid import uuid4

#: 数据文件（清单 `permissions.fs.read` / `permissions.fs.write` 必须与此同前缀）。
DATA_PATH: Final[str] = "~/.botchat/todos/todos.json"

#: 设置区面板的标题（标题是插件资产，不是通用 UI 文案，故随 data 下发）。
SETTINGS_TITLE: Final[str] = "待办清单"

#: 授权说明。内容是**本插件的**权限事实（清单请求了哪两个前缀、没授权时会怎样），
#: 因此归服务端而不是面板源码。
PERMISSION_HINT: Final[str] = (
    "本插件需要 fs.read 与 fs.write 授权到 ~/.botchat/todos；"
    "未授权时改动只活在进程内存里，宿主重启即丢。"
)

#: 单次返回最多多少条（data 序列化上限 256 KB；一条约 120 字节，200 条约 24 KB）。
MAX_ROWS: Final[int] = 200

#: 标题长度上限：一条待办是「一行字」，超长说明该拆成多条。
TITLE_LIMIT: Final[int] = 200

#: 数据文件 schema 版本（结构变化时递增，读侧据此判断是否兼容）。
SCHEMA_VERSION: Final[int] = 1


class TodoItem(TypedDict):
    """一条待办。`doneAt` 只在完成后出现（未完成时键缺席，不是空串）。"""

    id: str
    title: str
    done: bool
    createdAt: str
    doneAt: NotRequired[str]


class Storage(Protocol):
    """数据落盘协议：宿主 fs 与测试内存实现共用，把 IO 从纯逻辑里隔离出来。"""

    def read(self) -> str | None:
        """文件文本；不存在 / 未授权 / 宿主不可达一律返回 None（不抛）。"""

    def write(self, text: str) -> str | None:
        """整体覆盖写入；成功返回 None，失败返回可直接展示给用户的中文原因。"""


class HostFs(Protocol):
    """`ctx.host.fs` 的形状（只声明本插件用到的两个方法）。"""

    def read(self, path: str) -> str:
        """读文本；未授权或不存在时抛。"""
        ...

    def write(self, path: str, text: str) -> None:
        """写文本；未授权时抛，父目录由宿主创建。"""
        ...


class HostLike(Protocol):
    """`ctx.host` 的形状。"""

    fs: HostFs


ViewHandler = Callable[[dict[str, object]], dict[str, object]]
ToolHandler = Callable[[dict[str, object]], dict[str, object]]


class ContextLike(Protocol):
    """`register(ctx)` 收到的上下文（只声明本插件用到的注册动作）。"""

    host: HostLike

    def view(self, name: str, handler: ViewHandler) -> None:
        """注册一个视图渲染器（交互也走它）。"""

    def command(self, command_id: str, handler: ViewHandler) -> None:
        """注册一条命令。"""

    def tool(
        self,
        name: str,
        handler: ToolHandler,
        *,
        description: str,
        input_schema: dict[str, object],
    ) -> None:
        """注册一个 Agent 工具。"""


# —— 进程内状态（宿主回收子进程即归零，下次渲染重新读盘） ——

_storage: Storage | None = None
_todos: list[TodoItem] = []
_loaded: bool = False
_notice: str | None = None


def use_storage(storage: Storage | None) -> None:
    """替换数据源并丢弃进程内缓存（`register` 与测试共用这一入口）。"""
    global _storage, _loaded, _notice
    _storage = storage
    _loaded = False
    _notice = None


def reset_state() -> None:
    """清空进程内待办（测试用；正常运行时不该有人调它）。"""
    global _todos, _loaded, _notice
    _todos = []
    _loaded = False
    _notice = None


def _now() -> str:
    """UTC 时间戳（秒级即可：待办不需要亚秒精度）。"""
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


# —— 纯逻辑：解析 / 序列化 / 增删改 ——


def parse_payload(text: str) -> tuple[list[TodoItem], str | None]:
    """把文件文本解析成待办列表；结构不对时返回空列表 + 原因（MUST NOT 抛给渲染层）。"""
    try:
        raw = cast(object, json.loads(text))
    except json.JSONDecodeError:
        return [], "数据文件不是合法 JSON，已按空清单显示（下次改动会覆盖它）"
    if not isinstance(raw, dict):
        return [], "数据文件结构不对，已按空清单显示"
    mapping = cast(dict[str, object], raw)
    items = mapping.get("todos")
    if not isinstance(items, list):
        return [], "数据文件缺少 todos 数组，已按空清单显示"
    parsed: list[TodoItem] = []
    for entry in cast(list[object], items):
        item = _decode_item(entry)
        if item is not None:
            parsed.append(item)
    return parsed, None


def _decode_item(entry: object) -> TodoItem | None:
    """解码单条：任何一个必需字段不合格就整条丢弃（不猜、不补默认值）。"""
    if not isinstance(entry, dict):
        return None
    mapping = cast(dict[str, object], entry)
    todo_id = mapping.get("id")
    title = mapping.get("title")
    if not isinstance(todo_id, str) or todo_id == "":
        return None
    if not isinstance(title, str) or title.strip() == "":
        return None
    created = mapping.get("createdAt")
    done = mapping.get("done")
    item = TodoItem(
        id=todo_id,
        title=title,
        done=done is True,
        createdAt=created if isinstance(created, str) else "",
    )
    done_at = mapping.get("doneAt")
    if isinstance(done_at, str):
        item["doneAt"] = done_at
    return item


def serialize(todos: list[TodoItem]) -> str:
    """整份序列化（JSON 可解析 + 结尾换行，便于 diff 与手工编辑）。"""
    return (
        json.dumps(
            {"version": SCHEMA_VERSION, "todos": todos},
            ensure_ascii=False,
            indent=2,
            sort_keys=False,
        )
        + "\n"
    )


def find_todo(todos: list[TodoItem], todo_id: str) -> TodoItem | None:
    """按 id 取一条（id 在文件里是唯一身份，重复出现时取第一条）。"""
    for item in todos:
        if item["id"] == todo_id:
            return item
    return None


def add_todo(todos: list[TodoItem], title: str) -> str | None:
    """追加一条；返回错误文案或 None（不抛）。"""
    cleaned = title.strip()
    if cleaned == "":
        return "标题不能为空"
    if len(cleaned) > TITLE_LIMIT:
        return f"标题超过 {TITLE_LIMIT} 字，请拆成多条"
    todos.append(TodoItem(id=uuid4().hex[:12], title=cleaned, done=False, createdAt=_now()))
    return None


def set_done(todos: list[TodoItem], todo_id: str, done: bool) -> bool:
    """把一条设为完成 / 未完成；返回是否命中（幂等：重复设置同一状态也返回 True）。"""
    item = find_todo(todos, todo_id)
    if item is None:
        return False
    item["done"] = done
    if done:
        item["doneAt"] = _now()
    else:
        item.pop("doneAt", None)
    return True


def toggle_todo(todos: list[TodoItem], todo_id: str) -> bool:
    """翻转一条的完成态；返回是否命中。"""
    item = find_todo(todos, todo_id)
    if item is None:
        return False
    return set_done(todos, todo_id, not item["done"])


def remove_todo(todos: list[TodoItem], todo_id: str) -> bool:
    """删除一条；返回是否命中。"""
    for index, item in enumerate(todos):
        if item["id"] == todo_id:
            del todos[index]
            return True
    return False


def clear_done(todos: list[TodoItem]) -> int:
    """删掉所有已完成；返回删除条数。"""
    kept = [item for item in todos if not item["done"]]
    removed = len(todos) - len(kept)
    todos[:] = kept
    return removed


def counts(todos: list[TodoItem]) -> tuple[int, int]:
    """（未完成数，已完成数）。"""
    done = sum(1 for item in todos if item["done"])
    return len(todos) - done, done


# —— 渲染（纯函数：同一输入必得同一棵树） ——


def _brief(item: TodoItem) -> dict[str, object]:
    """工具返回用的精简形态（只给 id / 标题 / 时间，避免把整份文件吐进上下文）。"""
    return {
        "id": item["id"],
        "title": item["title"],
        "createdAt": item["createdAt"],
        "doneAt": item.get("doneAt"),
    }


def _panel_row(item: TodoItem) -> dict[str, object]:
    """面板行数据：只给渲染必需字段。

    `doneAt` 统一成字符串（未完成时为空串）：面板侧 `PanelData` 只有 `string` / `int` /
    `double` / `bool` / `rows` / `object` 六个读数，把「缺键」与「空值」收敛成同一形状，
    面板就不必写两套分支。
    """
    return {
        "id": item["id"],
        "title": item["title"],
        "createdAt": item["createdAt"],
        "doneAt": item.get("doneAt") or "",
    }


def panel_data(todos: list[TodoItem], *, notice: str | None = None) -> dict[str, object]:
    """面板主视图的 data（`botchat.panel/1`）：统计 + 两段列表 + 提示。

    形状固定：`counts` 给头部计数，`open` / `done` 给两段列表，`notice` 给一行提示
    （空串 = 无提示），`truncatedOpen` / `truncatedDone` 给出被截掉的条数 —— 静默截断
    会让用户以为「待办没了」，所以这个计数 MUST 进 data 而不是只写日志。

    列表上限 `MAX_ROWS` 是**载荷预算**不是交互预算：原生面板自己滚动，不存在 IR 的
    节点总数约束；真正的硬顶是 `validate_panel_data` 的 256 KB。
    """
    open_items = [item for item in todos if not item["done"]]
    done_items = [item for item in todos if item["done"]]
    shown_open = open_items[:MAX_ROWS]
    shown_done = done_items[:MAX_ROWS]
    return {
        "counts": {"open": len(open_items), "done": len(done_items)},
        "open": [_panel_row(item) for item in shown_open],
        "done": [_panel_row(item) for item in shown_done],
        "truncatedOpen": len(open_items) - len(shown_open),
        "truncatedDone": len(done_items) - len(shown_done),
        "notice": notice or "",
    }


def settings_data(todos: list[TodoItem], *, notice: str | None = None) -> dict[str, object]:
    """设置区面板的 data（`botchat.panel/1`）：文件位置 + 计数 + 授权说明 + 提示。

    与 `panel_data` 同口径 —— **只给事实，文案归面板**：`title` / `dataPath` 是插件资产，
    `counts` 给计数，`permissionHint` 是权限事实；按钮标题这类通用 UI 文案留在
    `Panels/Settings.swift`。`notice` 空串 = 无提示（`PanelData` 只有一个读数，缺键与空值
    收敛成同一形状，面板就不必写两套分支）。
    """
    open_count, done_count = counts(todos)
    return {
        "title": SETTINGS_TITLE,
        "dataPath": DATA_PATH,
        "counts": {"open": open_count, "done": done_count},
        "notice": notice or "",
        "permissionHint": PERMISSION_HINT,
    }


# —— IO 层：读一次缓存，写整份覆盖 ——


class _HostStorage:
    """走 `ctx.host.fs` 的存储实现；异常一律转成「没有数据 / 保存失败」。"""

    def __init__(self, host: HostLike) -> None:
        self._host = host

    def read(self) -> str | None:
        # 未授权 / 文件不存在 / 宿主不可达，对插件是同一件事：当作「没有数据」，不改内存态。
        try:
            return self._host.fs.read(DATA_PATH)
        except Exception:
            return None

    def write(self, text: str) -> str | None:
        # 写失败必须回到界面上（MUST NOT 静默），否则用户会以为已保存。
        try:
            self._host.fs.write(DATA_PATH, text)
        except Exception as exc:
            return f"保存失败：{exc}"
        return None


def _ensure_loaded() -> None:
    """首次需要数据时读盘（渲染期允许读、禁止写）。"""
    global _todos, _loaded, _notice
    if _loaded:
        return
    _loaded = True
    if _storage is None:
        return
    text = _storage.read()
    if text is None:
        return
    _todos, _notice = parse_payload(text)


def _reload() -> None:
    """丢掉缓存并重新读盘（用于「重新读取」按钮）。"""
    global _loaded
    _loaded = False
    _ensure_loaded()


def _persist() -> str | None:
    """把当前内存态整份写回；返回错误文案或 None。"""
    if _storage is None:
        return "插件尚未激活，改动只在这个进程里"
    return _storage.write(serialize(_todos))


# —— payload 取值助手（值一律是 `object`，逐个收窄，不用 Any） ——


def _as_text(value: object) -> str:
    """取字符串字段；非字符串一律当空串。"""
    return value if isinstance(value, str) else ""


def _as_dict(value: object) -> dict[str, object]:
    """取对象字段；非对象一律当空 dict。"""
    if not isinstance(value, dict):
        return {}
    mapping = cast(dict[str, object], value)
    return dict(mapping)


# —— 交互（`ui.action`） ——


def _handle_node(
    node_id: str,
    values: dict[str, object],
    arguments: dict[str, object],
) -> str | None:
    """执行一次节点动作，返回要展示的提示或 None。

    标题优先取 `arguments["title"]`（原生面板通过 `host.dispatch("add", ["title": …])`
    上行），其次取 `values["newTitle"]`（IR 的 `Field` 上行）。两个入口共用同一份动作语义，
    MUST NOT 给原生面板再写一套 `addNative` —— 那会让「同一件事」在两种渲染体下行为漂移。
    """
    if node_id == "add":
        title = _as_text(arguments.get("title")) or _as_text(values.get("newTitle"))
        error = add_todo(_todos, title)
        return error if error is not None else _persist()
    if node_id == "clearDone":
        removed = clear_done(_todos)
        if removed == 0:
            return "没有已完成的待办"
        return _persist()
    verb, _, target = node_id.partition(":")
    if verb == "toggle" and target != "":
        if not toggle_todo(_todos, target):
            return "这条待办已不存在"
        return _persist()
    if verb == "remove" and target != "":
        if not remove_todo(_todos, target):
            return "这条待办已不存在"
        return _persist()
    return None


def view_main(payload: dict[str, object]) -> dict[str, object]:
    """`panel` 视图（`render: native`）：交互先执行动作，再回整份新 data。

    `refresh` 是面板唯一一个**不改数据只重读盘**的动作：丢掉内存缓存重新解析文件。
    没有它，面板一旦拿着旧快照就只能等插件重启（原生面板不自己能取数）。
    """
    _ensure_loaded()
    notice = _notice
    node_id = _as_text(payload.get("nodeId"))
    if node_id == "refresh":
        _reload()
        notice = _notice
    elif node_id != "":
        notice = _handle_node(
            node_id,
            _as_dict(payload.get("values")),
            _as_dict(payload.get("arguments")),
        )
    return panel_data(_todos, notice=notice)


def view_settings(payload: dict[str, object]) -> dict[str, object]:
    """`settings.section` 视图（`render: native`）：只读一屏，交互仅支持手动重读。

    唯一动作 `refresh` 与 `main` 那个同义：丢掉内存缓存重新读盘（面板自己不取数）。
    """
    _ensure_loaded()
    if _as_text(payload.get("nodeId")) == "refresh":
        _reload()
    return settings_data(_todos, notice=_notice)


def command_open(_payload: dict[str, object]) -> dict[str, object]:
    """命令：让客户端打开面板（`{"view": "<view id>"}` 是客户端认的打开形态）。"""
    return {"view": "main"}


# —— Agent 工具 ——


def tool_list(_arguments: dict[str, object]) -> dict[str, object]:
    """列出全部待办（未完成在前），不回文件路径与内部字段。"""
    _ensure_loaded()
    open_items = [item for item in _todos if not item["done"]]
    done_items = [item for item in _todos if item["done"]]
    return {
        "counts": {"open": len(open_items), "done": len(done_items)},
        "open": [_brief(item) for item in open_items],
        "done": [_brief(item) for item in done_items],
    }


def tool_add(arguments: dict[str, object]) -> dict[str, object]:
    """新增一条待办并落盘。"""
    _ensure_loaded()
    error = add_todo(_todos, _as_text(arguments.get("title")))
    if error is not None:
        return {"ok": False, "error": error}
    warning = _persist()
    return {"ok": warning is None, "added": _brief(_todos[-1]), "warning": warning}


def tool_done(arguments: dict[str, object]) -> dict[str, object]:
    """把一条标记为完成：优先按 id，其次按标题精确匹配（多条命中就报错不强改）。"""
    _ensure_loaded()
    todo_id = _as_text(arguments.get("id"))
    if todo_id == "":
        title = _as_text(arguments.get("title"))
        if title == "":
            return {"ok": False, "error": "需要 id 或 title 之一"}
        matches = [item for item in _todos if item["title"] == title]
        if not matches:
            return {"ok": False, "error": f"没有标题为「{title}」的待办"}
        if len(matches) > 1:
            return {
                "ok": False,
                "error": "标题命中多条，请改用 id",
                "candidates": [_brief(item) for item in matches],
            }
        todo_id = matches[0]["id"]
    if not set_done(_todos, todo_id, True):
        return {"ok": False, "error": f"没有 id 为「{todo_id}」的待办"}
    item = find_todo(_todos, todo_id)
    warning = _persist()
    return {
        "ok": warning is None,
        "done": _brief(item) if item is not None else None,
        "warning": warning,
    }


def tool_remove(arguments: dict[str, object]) -> dict[str, object]:
    """删除一条待办。"""
    _ensure_loaded()
    todo_id = _as_text(arguments.get("id"))
    if todo_id == "":
        return {"ok": False, "error": "需要 id"}
    item = find_todo(_todos, todo_id)
    if item is None or not remove_todo(_todos, todo_id):
        return {"ok": False, "error": f"没有 id 为「{todo_id}」的待办"}
    warning = _persist()
    return {"ok": warning is None, "removed": _brief(item), "warning": warning}


# —— 注册（宿主唯一入口） ——


def register(ctx: ContextLike) -> None:
    """注册两个视图、一条命令、四个工具（清单声明与此 MUST 一一对应）。"""
    use_storage(_HostStorage(ctx.host))
    ctx.view("main", view_main)
    ctx.view("settings", view_settings)
    ctx.command("examples.todo-list.open", command_open)
    ctx.tool(
        "todo_list",
        tool_list,
        description="列出当前待办清单（未完成在前），返回 id / 标题 / 时间",
        input_schema={"type": "object", "properties": {}},
    )
    ctx.tool(
        "todo_add",
        tool_add,
        description="新增一条待办（用户说「帮我记一条…」时用）",
        input_schema={
            "type": "object",
            "properties": {"title": {"type": "string", "description": "待办标题"}},
            "required": ["title"],
        },
    )
    ctx.tool(
        "todo_done",
        tool_done,
        description="把一条待办标记为完成：优先传 id，只有唯一标题时可用 title",
        input_schema={
            "type": "object",
            "properties": {
                "id": {"type": "string", "description": "待办 id（todo_list 返回）"},
                "title": {"type": "string", "description": "标题精确匹配（仅在没 id 时用）"},
            },
        },
    )
    ctx.tool(
        "todo_remove",
        tool_remove,
        description="删除一条待办（按 id）",
        input_schema={
            "type": "object",
            "properties": {"id": {"type": "string", "description": "待办 id（todo_list 返回）"}},
            "required": ["id"],
        },
    )
