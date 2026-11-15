"""样例插件：`server.hook` 的最小可用形态（**纯逻辑、零权限、零出网**）。

它存在的目的是给「声明 → 解码 → 启用注册 → 派发 → 跨界执行 → 回传校验 → 应用」这条链路一个
真身。刻意与 `examples.hello-tool` 保持同形：

- 同一个 `hooks.py` 同时提供 `register(ctx)`（工具）与模块级 `hooks` 字典（钩子）——
  这正是「一个插件只有一个代码入口」的现实形态（`server.tool.entry` 与 `server.hook.entry`
  都指向本文件，入口一致性校验因此通过）。
- **纯 hook 包也能激活**：`activation_params` 的候选集含 `server.hook`，所以即使去掉
  `server.tool` 这一项，本包照样能起来（这正是 `hooks` 与 `tool` 共用入口的意义）。

三条约定（对写 hook 的人都成立）：

- `hooks` 必须是**模块级字典** `{名字: 可调用}`，可调用**只收一个参数**（投影后的 payload）；
  它不是通过 `ctx.hook(...)` 注册的 —— 宿主在 `ext.activate` 时只读这个字典的**键名**，
  真正调用发生在 `ext.hook.run`。
- 返回值是「回传体」：本样例只返回 `{messages: [{position, role, content}]}`，即**追加**一条
  消息。改写既有消息、`extra` 用别的命名空间、`role` 写 `assistant`/`tool` 都会被宿主整次拒绝。
- `content` MUST NOT 出现超长连续 `[A-Za-z0-9+.-]` 段（> 2048 字符）：掩码前的结构守卫会拒掉
  这种回传（掩码规则的长串回溯会让主进程阻塞数秒）。自然语言与代码都不会触发。
"""


def register(ctx):
    """注册 `hello` 工具（由 extension-host 在激活时调用一次）。"""

    def hello(arguments):
        """回一句问候，并说明本包还挂了一个 `pre_model` 钩子。"""
        name = arguments.get("name")
        target = name.strip() if isinstance(name, str) and name.strip() else "世界"
        return {"message": f"你好，{target}！这是 examples.hello-hook 的工具面。"}

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
    """`pre_model` 钩子：往系统提示里补一段可识别的样例说明。

    `position` 用 `after-system-prefix`（插在所有前导 system 消息之后）—— 这是最安全的默认：
    既不碰索引 0/1 的内置注入位（`[ProjectDoc]` / `[MemoryDoc]` 的幂等判据只看那里），
    也不会跑到用户消息之后（那是 `end` 的语义）。

    payload 里能拿到什么：`conversationId` / `userContent` / `messages[{role, content}]` /
    `extra`（白名单键）/ `omittedMessageCount`。**拿不到** `bot`、`attachments`、`tool_calls`
    与任何图片字节（跨界投影是白名单，不是黑名单）。
    """
    seen = len(payload.get("messages") or [])
    return {
        "messages": [
            {
                "position": "after-system-prefix",
                "role": "system",
                "content": (
                    "[HelloHook] 这条注入来自样例插件 examples.hello-hook 的 pre_model 钩子；"
                    f"它看到的可见消息数是 {seen}。样例用途，可在设置里停用。"
                ),
            }
        ]
    }


hooks = {"pre_model": pre_model}
