"""样例插件：`server.tool` 的最小可用形态（纯逻辑、零权限、无 UI）。

它存在的目的是给「启用 → 激活 → 注册 → 调用 → 返回」这条链路一个真身：不依赖任何权限、
不读文件、不出网，因此它失败时一定是链路本身出了问题，而不是环境。

三条约定（对写插件的人都成立）：

- 只有 `register(ctx)` 会被宿主调用，模块顶层 MUST 保持无副作用（import 一律放函数内更好）；
- `ctx.tool(name, handler, ...)` 的 `name` 是**插件内名**，对外名由宿主编成
  `<插件 id>__<工具名>`（本包即 `examples_hello_tool__hello`：点号与连字符归一为下划线）；
- handler 收一个 `dict`、回一个**可 JSON 序列化**的值；抛异常即一次工具错误（不会中断 run）。
"""


def register(ctx):
    """注册 `hello` 工具（由 extension-host 在激活时调用一次）。"""

    def hello(arguments):
        """回一句问候：`name` 缺省为「世界」。"""
        name = arguments.get("name")
        target = name.strip() if isinstance(name, str) and name.strip() else "世界"
        return {"message": f"你好，{target}！这句来自样例插件的工具。"}

    ctx.tool(
        "hello",
        hello,
        description="向指定名字打招呼（样例插件的示例工具，零权限）",
        input_schema={
            "type": "object",
            "properties": {"name": {"type": "string", "description": "要问候的名字"}},
        },
    )
