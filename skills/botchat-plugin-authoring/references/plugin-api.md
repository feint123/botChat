# 插件代码接口（`register(ctx)` / `ctx.host`）

实现：`serverSide/app/extensions/host_plugin_api.py`（插件侧持有）、`host_child_dispatch.py`
（子进程分发）、`host_limits.py`（预算）。契约正文见 `docs/extension-plugin-contract.md` §五/§六。

## 一、入口

```python
def register(ctx):          # 宿主在首次匹配 activationEvents 时调用一次
    ...
```

- 只有 `register(ctx)` 会被调用；**模块顶层 MUST 无副作用**（扫描阶段零代码执行，只有激活才 import）。
- 一个插件只有一个代码入口：`server.tool.entry` 与 `server.ui.entry` MUST 指向同一文件。
- 两种 `trust`（`sandboxed` / `in-process`）复用**同一份**接口与错误语义，没有第二套 API。
- 插件之间互不可见：模块名 `botchat_ext_<sanitized_id>`，跨插件 import 必失败。
- 激活预算 10s，超时即该插件本期整体不可用（`pluginActivationTimeout`）。

## 二、`ctx` 上的方法

| 方法 | 说明 | 违反时 |
|---|---|---|
| `ctx.tool(name, handler, *, description="", input_schema=None)` | 注册工具；`name` 是**插件内名** | 空名 / 重名 ⇒ 抛 `HostFault`（不静默覆盖） |
| `ctx.view(name, handler)` | 注册视图渲染器；`name` MUST 在清单 `server.ui.views` 里 | 空名 / 不可调用 / 重名 ⇒ 抛 |
| `ctx.command(command_id, handler)` | 注册命令处理器；`id` MUST 与清单 `client.command.id` 一致 | 同上 |
| `ctx.log(message, **fields)` | 写宿主日志（落主进程诊断面） | MUST NOT 打明文/凭据 |
| `ctx.tools` / `ctx.views` / `ctx.commands` | 已注册项的只读快照（属性，不是方法） | — |

工具对外名 = `<sanitized_id>__<sanitized_tool_name>`（点号与连字符归一下划线，总长 ≤ 64）。
模型与能力目录只认对外名；`ext.tool.call` 只认插件内名。

## 三、`ctx.host` 的五个命名空间

```python
ctx.host.fs.read(path: str) -> str          # 越权/不存在即抛 permissionDenied
ctx.host.fs.write(path: str, text: str) -> None   # 写不隐含读；父目录由宿主创建
ctx.host.net.fetch(url, *, method="GET", headers=None, body=None) -> {status, body, headers}
ctx.host.llm.invoke(role: str, messages: list[dict[str, str]]) -> str

# 目标台账（需 permissions.goal；读=read，其余动作按档授予）
ctx.host.goal.list(...)  /  .get(goal_id)  /  .current()
ctx.host.goal.act(...)   /  .update(...)   /  .delete(goal_id, expected_round)
ctx.host.goal.create(...) /  .deliver(...)

# 工作区快照（需 permissions.workspace: ["read"]）
ctx.host.workspace.snapshot() -> {available, reason, truncated, total, files[]}
```

四条口径：

1. **路径**：实参 MUST 是绝对路径（`~` 会被 `expanduser`，`${workspace}` **不会**被替换）。
   宿主做 `realpath` + 前缀比对，越界 fail-closed。
2. **出网**：`net.fetch` 由宿主代发，插件侧永不持有 socket；`net` 权限是**精确 host**（不许通配）。
3. **渲染期禁写**：`fs.write` / `net.fetch` 在 `ui.render` 期间调用会被直接拒（`permissionDenied`），
   不发出任何请求。写只能发生在动作（`ui.action`）与工具调用里。
4. **`llm.invoke` 本期显式失败**（`hostUnavailable`）：协议齐备但宿主不代发模型请求。
   插件不会拿到伪造结果，也不会拿到 key。
5. **`workspace.snapshot()` 无参**：工作区由宿主按**当前 hook 的会话**派生。允许插件传路径
   等于允许它读任意目录的 git 事实，那就绕开了路径白名单 —— 所以这个接口 MUST NOT 有参数。
   不在 hook 上下文（例如在工具里直调）或缺 `permissions.workspace` ⇒ `permissionDenied`；
   工作区不是 git 仓库 ⇒ 正常返回 `available=false`（两者处置不同）。
6. **`goal` 写入只走既有状态机**：`execute` 档会让目标进入自动执行或重开已消耗的执行预算，
   执行轮以完全访问运行（路径黑名单仍生效）。这一档 MUST NOT 被 `act` / `create` 隐式推导。

## 四、三类 handler 的入参与返回

### 4.1 工具 handler

```python
def handler(arguments: dict) -> object:      # 返回值 MUST 可 JSON 序列化
    return {"ok": True, ...}
```

- 入参是模型给的参数对象（按 `input_schema` 校验后的形态）。
- 返回值不可序列化 ⇒ `invalid_result`（宿主不会 `str()` 兜底）。
- 抛异常 ⇒ 该次工具调用失败（不中断 run）；业务失败请用返回体表达，用户能读到原因。
- 工具预算 30s。

### 4.2 视图 handler（渲染与交互共用）

```python
def render(payload: dict) -> dict: ...
```

`payload` 的键：

| 键 | 何时有 | 含义 |
|---|---|---|
| `view` | 恒有 | view 名 |
| `instanceKey` | 恒有 | 实例键（同一 view 可多实例，状态要按它分区） |
| `state` | 恒有（可能空对象） | 白名单公开事实：`workspaceName`、有会话时的 `conversationTitle`；取不到就**没有这个键** |
| `nodeId` | 交互时 | 被操作的节点 id（Button/Toggle 的 `nodeId`、Field 的 `name`） |
| `values` | 交互时 | 表单当前值（保留键；IR 的 `Field` 已随 `botchat.ui/1` 下线，新插件用 `arguments`） |
| `arguments` | 交互时 | 节点的 `arguments`（原生面板 `host.dispatch(nodeId, args)` 落在这里） |

- 返回**数据对象**（`botchat.panel/1`）。`botchat.ui/1` 节点树已下线：写树会被当 data 校验并整帧降级。
- 没有 patch / diff：回一模一样的数据 ⇒ 界面不变（用户会以为「点了没反应」）；交互分支 MUST 产生可观察变化。
- 渲染预算 2s；渲染 MUST 纯函数（同输入同输出），副作用只能落在动作与工具里。

### 4.3 命令 handler

```python
def on_command(payload: dict) -> dict: ...
```

- 只准回 `{"view": "<view 名>"}`（打开面板）或 `{"text": "..."}`（填进输入条）。
- 其它形状：客户端只记日志，不打扰用户。

## 五、预算与生命周期（`host_limits.py`）

| 项 | 值 |
|---|---|
| 启动 / 目录 / 激活 | 15s / 10s / 10s |
| 工具调用 | 30s（`PLUGIN_TOOL_TIMEOUT_MS`，清单不可放大） |
| 渲染 / 钩子 | 2s / 2s |
| 空闲回收 | 5 分钟无调用即回收宿主，下次激活重新拉起 |
| 连续崩溃 | 2 次即拉黑该插件（`pluginBlacklisted`） |
| 连续失败（超时/RPC 错） | 达阈值强制重建宿主（照抄 MCP 池兜底） |

两条后果必须知道：插件工具表是**进程态**（多 worker 时只有装配层所在进程有），
停用只做到「不可调用」（宿主仍持有旧模块，改包要重启）。
