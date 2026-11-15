

# ---- 工具能力（`--with-tool`）：与视图同文件、同一次 `register(ctx)` 注册 ----
# 为什么不留到第二个模块：两条能力各自 import 一个 entry 就是两个 `register`，
# 互相看不到对方注册过什么；同文件才能让「声明几个、注册几个」一眼对齐。


def {{tool}}(arguments: dict[str, object]) -> dict[str, object]:
    """{{tool}}：一句话说清「做什么」和「什么时候该被调用」。"""
    raw = arguments.get("text")
    text = raw.strip() if isinstance(raw, str) else ""
    if text == "":
        return {"ok": False, "error": "text 不能为空"}
    return {"ok": True, "echo": text, "view": "{{view}}"}
