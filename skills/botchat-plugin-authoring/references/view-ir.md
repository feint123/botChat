# 视图 IR（`botchat.ui/1`）

事实源：`docs/extension-plugin-ui.md`；实现常量 `serverSide/app/extensions/ui_contract.py`（节点表 /
tone 白名单 / 预算 / 禁用键），校验 `ui_ir.py` + `ui_ir_fields.py` + `ui_ir_values.py`。
**客户端 `ExtensionUIDecoder` 会二次校验同一份契约**，服务端放过不等于能渲染。

## 一、三条硬约束

1. **禁字面色值 / 字体 / 像素**：出现 `color` `colors` `background` `foreground` `font` `fontFamily`
   `fontSize` `width` `height` `padding` `margin` `radius` 任一键 ⇒ **整树非法**（不是忽略该键）。
   颜色走 `tone`，字号走 `style` 档，尺寸由 slot 决定。
2. `kind` 只能是下表 17 个之一；未知 kind 即整树非法。
3. `nodeId` / `name` 是**身份字段**，MUST 是常量字符串，MUST NOT 用 `{"$item": …}` 绑定。

## 二、17 个节点

| kind | 必需 | 可选 | 备注 |
|---|---|---|---|
| `Text` | `text` | `tone` `style` | `style` ∈ `body`/`caption`/`title`/`mono` |
| `Heading` | `text` | `level` `tone` | `level` ∈ 1/2/3 |
| `Markdown` | `text` | — | 内嵌图片与 `Image.ref` 同形态（只收素材引用） |
| `Image` | `ref` | `caption` `size` | `ref` 只收裸 `assetId` 或 `/api/media/{id}`；`size` ∈ `s`/`m`/`l` |
| `Divider` | — | — | |
| `Spacer` | — | `size` | `size` 0..4 |
| `Progress` | `value` | `label` `tone` | `value` 是 0..1 或 `null` |
| `Row` | `children` | `spacing` `align` | `spacing` 0..4；`align` ∈ `leading`/`center`/`trailing`/`between` |
| `Column` | `children` | `spacing` `align` | `align` ∈ `leading`/`center`/`trailing`/`stretch` |
| `Grid` | `columns` `children` | `spacing` | `columns` 1..6 |
| `List` | `items` `rowTemplate` | `empty` `spacing` | `items` 每项计入节点预算；行内用绑定取字段 |
| `Field` | `name` `label` `input` | `value` `options` `placeholder` `required` | `input` ∈ `text`/`number`/`select`；`select` 必须给非空 `options: [{value,label}]` |
| `Button` | `nodeId` `label` | `style` `arguments` `tone` | `style` ∈ `primary`/`secondary`/`plain` |
| `Toggle` | `nodeId` `label` `value` | `arguments` `tone` | `value` MUST 是布尔 |
| `Link` | `label` `url` | — | `url` scheme 只认 http(s) |
| `Empty` | — | `title` `hint` | 通常由宿主自造（插件没内容时也可回） |
| `Error` | `code` `message` | `retryNodeId` | 占位树的形状，宿主与插件共用 |

## 三、`tone` 白名单（27 个，逐字）

```
fg.primary  fg.secondary  fg.tertiary  fg.disabled
bg.surface  bg.surfaceRaised  bg.surfaceSunken  bg.fillSubtle  bg.selection
border.default  border.muted  border.strong  border.focus
brand.base  brand.text
status.{pending,running,done,failed,warning,muted}.{fg,subtle}   # 6 × 2 = 12
```

表外取值非法（`MUST NOT` 回落默认色）。这是 `docs/theme-tokens.md` 46 角色的**子集**。

## 四、绑定与列表

- 文本字段可以是字符串，也可以是 `{"$item": "dot.path"}`（唯一键：`$item`）。
- 仅限 `List` 的 `rowTemplate` 上下文使用；`nodeId` / `name` 不许绑定。
- `List.items` 每项各算一个节点进预算，`rowTemplate` 与 `empty` 按普通节点校验。

## 五、预算（超出记 `irBudgetExceeded`，不是 `irInvalid`）

| 项 | 上限 |
|---|---|
| 节点数 | 2000（`List.items` 每项 +1） |
| 序列化字节 | 512 KB（UTF-8） |
| 嵌套深度 | 64（根为 1；`children` / `rowTemplate` / `empty` 每层 +1） |

## 六、交互与幂等

- 交互恒返回**整棵树**（`botchat.ui/1`）或**整份数据**（`botchat.panel/1`），没有 patch / diff。
- 服务端按清单 `render` 选校验器，插件**不能**自己决定回什么；回错形状 ⇒ 该帧降级。
- 每次回包带连号 `rev`：客户端连号应用、**跳号必须重拉快照**；断流时保留最后一棵树并标「已离线」
  （MUST NOT 清空）；插件停用时切 `disabled` 占位树（MUST NOT 自动关列/关窗）。
- 交互 MUST 串行，重试复用**同一个** `action_id`（幂等只在服务端进程内生效）。
- 幂等回放 MUST 连 `schema` 与载荷一起回；降级帧（`diagnostics` 非空）恒为 `botchat.ui/1` + 占位树，
  且 `degraded: true` 时客户端跳过 schema 校验只按 `diagnostics[0].code` 渲染。

## 七、本地自测（不用起宿主）

```bash
cd serverSide && .venv/bin/python - <<'PY'
import importlib.util
from app.extensions.ui_ir import validate

spec = importlib.util.spec_from_file_location("p", "/path/to/plugin.py")
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
verdict = validate(mod.render_main({"instanceKey": "x"}))
print(verdict.ok, verdict.code, verdict.path, verdict.message)
PY
```

原生面板的 data 载荷用 `app.extensions.ui_panel_payload.validate_panel_data(data)` 单独校验。
两者都是**纯函数**，不需要数据库、不需要起服务、不需要装插件。
