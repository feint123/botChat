# server.hook 扩展包能力

> 目标：照着文档能一次写出可启用、能被派发、能被对账的 hook 包。

## 一、这是什么

`server.hook` 是**扩展包声明的能力**，让插件在模型调用前或 run 结束后注入消息片段。它由清单声明与模块导出两半组成：

| 层面 | 形态 | 作用 |
|------|------|------|
| 清单 | `capabilities.server.hook` | 声明事件、优先级、失败策略 |
| 代码 | 模块级 `hooks` 字典 | 导出 `{事件名：函数}`，函数只收一个参数 |
| 运行期 | 跨界投影 + 守卫校验 | 白名单 payload → 执行 → 回传体整次拒绝/应用 |

核心纪律：**纯逻辑、零出网、不碰图片字节**。插件看到的只是结构化事实，没有 ORM 对象与凭据。

## 二、清单怎么声明

`capabilities.server.hook` 必须含四字段：

| 字段 | 类型 | 必需性 | 缺省 | 拒绝条件 |
|------|------|--------|------|----------|
| `entry` | `str` | **必需** | — | 缺失/非字符串 ⇒ `error`，能力不可用 |
| `events` | `tuple[str, ...]` | **必需** | — | 缺失/非字符串数组 ⇒ `error` |
| `onError` | `"continue"` \| `"abort"` | 可选 | `"continue"` | 非法取值 ⇒ `error` |
| `priority` | `int` | 可选 | `100` | 布尔值 ⇒ `warning`+ 回落；非整数同 |

**事件放行集** = `{pre_model, run_finished}`。**已知集六项** = `{pre_model, post_model, pre_tool, post_tool, idle, run_finished}`。其余四事件声明后会记 `hookEventWithoutDispatch`（认识但无派发点），不会拒清单。

`onError: abort` **只在 `pre_model` 有效**；其它事件声明了也降级为 `continue` 并记 warning `hookAbortInvalidEvent`。

`priority` 缺省 `100`；内置注入块最大卡位是 44，故插件恒在其后。**不建议设更小值**（会打破约定且可能干扰幂等）。

**`trust` 不能写 `data`**：`CODE_KINDS` 含 `server.hook`，当 `trust=data` 时记 `TRUST_MISMATCH` 并跳过该能力。合法取值：`sandboxed` / `in-process`。

**入口一致性**：同一插件的所有代码类 kind（`server.tool` / `server.ui` / `server.hook`）**MUST 指向同一文件**，否则整包被拒并记 `ENTRY_MISMATCH`。

## 三、代码入口写什么

**`hooks` 必须是模块级字典**：`{事件名：可调用}`，可调用**只收一个参数**（投影后的 payload）。它不是通过 `ctx.hook(...)` 注册的 —— 宿主在 `ext.activate` 时只读这个字典的键名，真正调用发生在 `ext.hook.run`。

同一个 `.py` 文件可同时提供 `register(ctx)`（工具）与模块级 `hooks` 字典，这正是「一个插件只有一个代码入口」的现实形态。

纯 hook 包也能激活：`activation_params` 候选集含 `server.hook`，即使去掉 `server.tool` 也能启动。

导出面缺实现（文件有但 `hooks` 字典缺键）⇒ 该事件上的注册跳过并记 `CAPABILITY_ENTRY_MISSING` warning。

## 四、payload 能看到什么

投影是**白名单**，五项顶层键（自行 grep `project_hook_context` 确认）：

```json
{
  "conversationId": "uuid",
  "userContent": "用户原始输入文本",
  "messages": [{"role": "system"|"user", "content": "文本"}],
  "extra": {"is_supervisor": true, "mode": "chat", ...},
  "omittedMessageCount": 0
}
```

- `messages` 每项**只有** `role` / `content`；拿不到 `bot` / `attachments` / `tool_calls` / `reasoning_content` / 图片字节。
- **不可投影项是整条省略**并用 `omittedMessageCount` 表达，不是置空。
- `extra` 白名单七键：`is_supervisor` / `mode` / `design_system` / `design_ref` / `deliverable` / `delegate_from` / `task_id`。

## 五、回传体能改什么

回传体只认两键：`messages` / `extra`。消息项只认三键：`position` / `role` / `content`。

**`position` 四枚举**：

| 字面值 | 插入语义 |
|--------|----------|
| `after-system-prefix` | 插在所有前导 system 消息之后（最安全默认） |
| `end` | 追加到可见消息末尾 |
| `user-before` | 插在**最后一个** user 消息之前；没有 user 消息时追加到末尾 |
| `index:N` | 插在第 N 个可见项之前（越界 ⇒ `index_out_of_range` / `index_in_prefix`） |

**`role` 只允许** `system` / `user`；写 `assistant`/`tool` 整次拒绝。

**预算上限表**（grep 常量确认）：

| 限制项 | 数值 |
|--------|------|
| 新增条数 | `MAX_NEW_MESSAGES = 8` |
| 单条 content 字节 | `MAX_CONTENT_BYTES = 65_536` |
| 新增内容总字节 | `MAX_TOTAL_BYTES = 262_144` |
| extra 序列化字节 | `MAX_EXTRA_BYTES = 8_192` |
| 事件累计字节 | `MAX_EVENT_TOTAL_BYTES = 524_288` |
| 超长连续字母数字串 | `MAX_ALNUM_RUN = 2048`（整次拒绝） |

任一项不合规则**整次拒绝、不部分生效**，记 `hookRejected`。

## 六、失败与处置

**预算与超时**：`server.hook` 执行预算 `HOOK_TIMEOUT_SECONDS = 2.0` 秒，超时即跳过该钩子并把失败类别记为 `timeout`（常量 `CATEGORY_TIMEOUT`）。

**异常隔离**：插件异常不影响 run，只把失败类别记为 `crashed`（常量 `CATEGORY_CRASHED`）并继续。连续崩溃达 `CONSECUTIVE_CRASH_LIMIT = 2` 次拉黑宿主；连续失败（超时/RPC 错）达 `CONSECUTIVE_FAILURE_LIMIT = 3` 次强制重建。

**`continue` vs `abort`**：`continue` 是正常返回（未注入或注入失败都算）；`abort` 以记号传递而非抛异常，记号键 `ABORT_KEY = "__hook_abort__"` 写入 `ctx.extra`。`run_finished` 上 `abort` 无效（结果已落库）。

## 七、注册、命名与排序

**注册名格式**三段冒号：`<extension_id>:<event>:<hook_name>`（如 `examples.hello-hook:pre_model:pre_model`）。每段内部不含冒号，按冒号切三段即可还原归属；扩展 id 原样保留（不把点号转下划线），所以诊断里的 `pluginId` 与注册名首段逐字一致。内置注册项不带这种三段形态，故不会撞名。

启用时注册、停用时逐项摘除（**MUST NOT 清事件**）；注册路径不激活子进程。

`priority` 与内置最大卡位 44 的关系：插件缺省 100 恒在其后，不建议设更小值。

## 八、对账与验证

**`check_plugin.py` 与 doctor 的关系**：doctor 是静态对账工具，检查清单解析与代码导出面是否匹配。

**诊断码**（grep `doctor_hook.py` / `capability_hook.py` 取得）：

| 码名 | 触发场景 |
|------|----------|
| `trustMismatch` | `trust=data` 承载 `server.hook` |
| `entryMismatch` | 多代码类 kind 指向不同 entry |
| `capabilityEntryMissing` | 清单声明了但磁盘没文件 / hooks 字典缺键 |
| `hookEventWithoutDispatch` | 声明了认识但无派发点的事件 |
| `hookAbortInvalidEvent` | `onError: abort` 落在非 `pre_model` 事件 |
| `hookRejected` | 运行期回传体不合契约 |

**验证序列**（第 1 步每次改清单都跑；2~4 步只在你改到宿主侧代码时需要）：

1. **对账**：`python3 ~/.agents/skills/botchat-plugin-authoring/scripts/check_plugin.py <包目录>`（`app.extensions.doctor` 的包装器，会做 `server.hook.events` 对账；退出码 0 通过）
2. **能力解码回归**：`cd serverSide && .venv/bin/python -m pytest tests/extensions/test_hook_capability.py tests/extensions/test_hook_names_wiring.py -q`
3. **投影与派发回归**：`cd serverSide && .venv/bin/python -m pytest tests/extensions/test_hook_projection.py tests/extensions/test_hook_bridge_e2e.py -q`
4. **静态门禁**：`cd serverSide && .venv/bin/ruff check app/extensions/hook_*.py`

**装完还要闭环**：`POST /api/extensions/{id}/enable` → `POST /api/extensions/host/restart`，再在对话里触发一次看注入是否出现。

**doctor 只做静态对账，通过 ≠ 子进程真的导出了该 hook**（运行期事实）。

## 九、常见坑

| 症状 | 原因 | 修法 |
|------|------|------|
| 能力不可用，诊断 `trustMismatch` | `trust: data` 写了 | 改为 `trust: sandboxed` |
| hooks 字典找不到 | 用 `ctx.hook()` 注册 | 改成模块级 `hooks = {...}` |
| 事件声明了但不派发 | 声明了 `post_model` 等无派发点事件 | 只保留 `pre_model` / `run_finished` |
| 整包被拒，诊断 `entryMismatch` | `server.tool.entry` 与 `server.hook.entry` 不一致 | 指向同一文件 |
| 回传被拒，诊断 `hookRejected` | 回传体多了 `tool_calls` 等键 | 只留 `position`/`role`/`content` |
| 回传被拒，诊断 `hookRejected` | `role` 写了 `assistant` / `tool` | 只允许 `system` / `user` |
| 回传被拒，诊断 `hookRejected` | `content` 有 >2048 连续字母数字串 | 拆成长度≤2048 的段 |
| 插件永远在后 | `priority` 设得比 44 小 | 保持缺省 100 或更大 |
| 停用后以为清空了内置注入 | 以为停用会清事件 | 停用只摘除插件注册，不清事件 |
| 改完不重启宿主 | 改完源码直接跑 | 重新构建 App 并重启进程 |
| doctor 过了但激活失败 | 以为 doctor 能验证真实导出 | 需实际启用看运行期日志 |
| `abort` 用错事件 | 在 `run_finished` 上用 `abort` | `abort` 只允许 `pre_model` |

## 十、可抄最小样例

**`manifest.json`**（逐字段对齐 `examples.hello-hook`）：

```json
{
  "schemaVersion": 2,
  "id": "my.hook-sample",
  "name": "Hook 样例插件",
  "version": "0.1.0",
  "minAppVersion": "0.1.0",
  "trust": "sandboxed",
  "activationEvents": ["onTool:hello"],
  "permissions": {},
  "capabilities": {
    "server.tool": {
      "entry": "hooks.py",
      "tools": ["hello"]
    },
    "server.hook": {
      "entry": "hooks.py",
      "events": ["pre_model"],
      "priority": 100
    }
  }
}
```

**`hooks.py`**（完整可抄全文；要纯 hook 包就删掉 `server.tool` 声明与 `register`，只留 `hooks` 字典）：

```python
"""纯 hook 包的最小可用形态（零权限、零出网）。"""


def register(ctx):
    """注册 `hello` 工具（由 extension-host 在激活时调用一次）。"""

    def hello(arguments):
        name = arguments.get("name")
        target = name.strip() if isinstance(name, str) and name.strip() else "世界"
        return {"message": f"你好，{target}！这是 my.hook-sample 的工具面。"}

    ctx.tool(
        "hello",
        hello,
        description="向指定名字打招呼（样例插件的示例工具，零权限）",
        input_schema={
            "type": "object",
            "properties": {"name": {"type": "string", "description": "要问候的名字"}},
        },
    )


def pre_model(payload):
    """`pre_model` 钩子：往系统提示里补一段可识别的样例说明。"""
    seen = len(payload.get("messages") or [])
    return {
        "messages": [
            {
                "position": "after-system-prefix",
                "role": "system",
                "content": (
                    "[MyHook] 这条注入来自插件 my.hook-sample；"
                    f"它看到的可见消息数是 {seen}。样例用途，可在设置里停用。"
                ),
            }
        ]
    }


hooks = {"pre_model": pre_model}
```

**收尾**：把两个文件放进 `Extensions/<id>/`（目录名必须等于 `id`），`POST /api/extensions/install` body `{"source_path": "<本机绝对路径>"}` → `POST /api/extensions/{id}/enable` body `{"enabled": true}` → `POST /api/extensions/host/restart`，再发一条消息看注入块里是否出现 `[MyHook]`；没出现就先跑对账看诊断码，别直接改代码猜。
