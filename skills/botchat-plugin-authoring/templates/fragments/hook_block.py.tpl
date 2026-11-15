
# --- server.hook fragment appended by scaffold ---
def pre_model(payload):
    """`pre_model` 钩子：往系统提示里补一段说明。

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
                    f"[{{name}}] 这条注入来自插件 {{id}} 的 pre_model 钩子；"
                    f"它看到的可见消息数是 {seen}。样例用途，可在设置里停用。"
                ),
            }
        ]
    }


hooks = {"pre_model": pre_model}
# --- end server.hook fragment ---
