

    # 工具名是**插件内名**；对外名 = `<id>__<name>`（点号/连字符归一为下划线），
    # 清单 activationEvents 里写的是对外名 `onTool:{{toolFull}}`。
    ctx.tool(
        "{{tool}}",
        {{tool}},
        description="{{name}}：把输入原样回显（零权限样例）",
        input_schema={
            "type": "object",
            "properties": {
                "text": {"type": "string", "description": "要回显的文本"},
            },
            "required": ["text"],
        },
    )
