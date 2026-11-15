# 清单 v2（`manifest.json`）速查

事实源：`docs/extension-plugin-contract.md` §一/§二/§三/§四；实现 `app/extensions/manifest.py`、
`capabilities.py`、`fields.py`、`package.py`。文档与代码冲突以代码为准。

## 一、顶层字段

| 字段 | 必需 | 缺省 | 取值与校验后果 |
|---|---|---|---|
| `schemaVersion` | 是 | — | 只认 `1` / `2`；未知值**拒整包**（`unknownSchemaVersion`）。v1 归一成 v2 内存模型，下游不再判版本 |
| `id` | 是 | — | 全局唯一；MUST 等于包目录名（否则 `packageDirNameMismatch` 硬伤）；`builtin.` 前缀保留 |
| `name` | 是 | — | 展示名 |
| `version` | 是 | — | 点分版本；升/降级影响授权收敛（升版本新增权限不自动授予，收缩自动收敛） |
| `minAppVersion` | 是 | — | 高于当前 app 版本即**拒整包**（`minAppVersionTooHigh`）。预发布后缀比同号正式版**旧**（`1.0.0-beta < 1.0.0`） |
| `trust` | 否 | `data` | `data` / `sandboxed` / `in-process`；非法值（含 `dylib`/`.app`）**拒整包** |
| `activationEvents` | 否 | `[]` | `onStartup` / `onCommand:<id>` / `onTool:<对外名>` / `onSlot:<slot>:<view>`；前缀外的项记 warning 并跳过。**本期只做声明与校验**：装配层在启动 / 启用 / `host/restart` 时按库内 `enabled` 直接激活（`host_activation.dispatch_event` 目前无调用方），事件不影响是否被激活 |
| `permissions` | 否 | 全空 | 见 §四；未知键按**未授权**处理（不猜测放行） |
| `capabilities` | 是 | — | 键带端前缀的开放集合，值是**嵌套 JSON 对象**（`client.view` 也可是对象数组） |

顶层未知键记 `unknownKey` warning，**不拒包**。

## 二、能力 kind

| kind | 必需下级键 | 可选 | 状态 |
|---|---|---|---|
| `server.tool` | `entry`（`.py`）、`tools`（非空字符串数组） | — | 已实现 |
| `server.ui` | `entry`（`.py`）、`views`（非空字符串数组） | — | 已实现 |
| `client.view` | `slot`、`view`、`title` | `icon` `priority`(int，缺省 0) `size` `lazy` `render` | 已实现 |
| `client.panel` | `views: [{view, entry}]` | `apiVersion`（只认 `1`） | 已实现 |
| `client.command` | `id`、`title` | `shortcut` | 已实现 |
| `client.theme` | `entry`（`.json`） | — | 已实现（8 个内置主题包即此形态） |
| `server.hook` | `entry`（必需，与 `server.tool` / `server.ui` 同文件）、`events`（放行集 `{pre_model, run_finished}`）、`onError?`（可选，`continue` 缺省 / `abort` 仅 `pre_model` 有效）、`priority?`（可选，整数，缺省 `100`） | — | 已实现 |
| `server.masking.rules` / `server.provider` | — | — | **登记但未实现**：写了只得到一条诊断，不会生效 |

硬约束：

- `slot` 是封闭集合：`panel` / `window` / `composer.accessory` / `sidebar.section` / `settings.section`。
  集合外的取值**跳过该条**，不拒整包。五个挂载点**均已接线**：`panel` 进面板列、`window` 开独立
  `NSPanel`（经 QuickBar 命令打开，尺寸取 `minWidth`/`minHeight` 与 320×240 的较大者）、
  `composer.accessory` 进输入条、`sidebar.section` 进侧栏分区、`settings.section` 进设置页。
- `render` 只认 `"ir"`（缺省）/ `"native"`；其它取值撤下该条（不回落）。
- `client.view.view` MUST 出现在同包 `server.ui.views` 里，否则解码期剔除（`capabilityEntryMissing`）。
- **`server.ui.entry` 与 `server.tool.entry` MUST 指向同一文件**：一个插件只有一个 `register(ctx)`。
  不同文件时记 error 并**撤下 `server.ui`**（工具能力保留）——这就是「工具能用、面板打不开」的常见成因。
- `server.tool` 只认 `entry` + `tools` 两个下级键；`timeout_ms` 之类的额外键会被 `unknownKey` 忽略。
- 声明了 `server.ui.views` 却既无 `client.view` 也无 `client.command` ⇒ doctor 记 warning（用户无从打开）。

## 三、信任档位

| 档位 | 执行位置 | 适用 |
|---|---|---|
| `data` | 不执行代码 | 主题包、纯数据包。声明代码能力 ⇒ 拒绝该能力（warning），不拒包 |
| `sandboxed`（代码缺省） | extension-host 子进程 | 外部插件 |
| `in-process` | 主进程内导入 | 仅用户 root **且**设置里开了「信任本地插件」（`EXTENSIONS_TRUST_LOCAL`）；`builtin.` 一律降级 |

## 四、权限

缺省全空：零出网、零 keychain、零 workspace 写、零宿主工具、零模型调用。

| 键 | 形态 | 生效点 |
|---|---|---|
| `fs.read` / `fs.write` | 路径前缀数组（`${workspace}` 会被**清单侧**展开） | 宿主代发 + `realpath` 前缀比对；写不隐含读 |
| `net` | host 数组（精确匹配，不许通配） | `ctx.host.net.fetch` 由宿主代发 |
| `keychain` | 键名数组 | 预留（本期无实现路径） |
| `tools` | 宿主工具名数组 | 预留 |
| `llm` | 角色数组 | `ctx.host.llm.invoke`（协议齐备但**显式失败** `hostUnavailable`） |
| `clipboard` | 布尔 | 预留 |

授权是**人的显式动作**：清单只写「请求」，实际授权落 `extension_state.permissions_json`。
升版本新增权限不自动授予；权限收缩自动收敛；给清单没请求的键会被拒并记 `permissionDenied`。

## 五、四个可直接抄的片段

### 5.1 纯工具（零权限、零界面）

```json
{
  "schemaVersion": 2,
  "id": "acme.echo",
  "name": "回声",
  "version": "0.1.0",
  "minAppVersion": "0.1.0",
  "trust": "sandboxed",
  "activationEvents": ["onTool:acme_echo__echo"],
  "permissions": {},
  "capabilities": {
    "server.tool": { "entry": "tools.py", "tools": ["echo"] }
  }
}
```

`activationEvents` 里的 `onTool:` 写的是**对外名**（`<id 归一>__<工具名>`，点号与连字符变下划线），
不是插件内名。口径写对是为了将来接上事件驱动时不用返工 —— 本期它不参与激活判定。

### 5.2 IR 面板 + 设置区 + 命令

```json
{
  "schemaVersion": 2,
  "id": "acme.board",
  "name": "看板",
  "version": "0.1.0",
  "minAppVersion": "0.1.0",
  "trust": "sandboxed",
  "activationEvents": ["onStartup", "onSlot:panel:main", "onCommand:acme.board.open"],
  "permissions": {},
  "capabilities": {
    "server.ui": { "entry": "plugin.py", "views": ["main", "settings"] },
    "client.view": [
      { "slot": "panel", "view": "main", "title": "看板", "icon": "square.grid.2x2", "priority": 50 },
      { "slot": "settings.section", "view": "settings", "title": "看板设置" }
    ],
    "client.command": { "id": "acme.board.open", "title": "打开看板" }
  }
}
```

### 5.3 原生面板（`render: native` + 包内 Swift）

```json
{
  "schemaVersion": 2,
  "id": "acme.chart",
  "name": "图表",
  "version": "0.1.0",
  "minAppVersion": "0.1.0",
  "trust": "sandboxed",
  "activationEvents": ["onStartup", "onSlot:panel:hits"],
  "permissions": {},
  "capabilities": {
    "server.ui": { "entry": "plugin.py", "views": ["hits"] },
    "client.view": [
      { "slot": "panel", "view": "hits", "title": "命中", "render": "native" }
    ],
    "client.panel": { "views": [{ "view": "hits", "entry": "Panels/Hits.swift", "apiVersion": 1 }] }
  }
}
```

### 5.4 server.hook 声明片段

```json
{
  "schemaVersion": 2,
  "id": "acme.logger",
  "name": "日志钩子",
  "version": "0.1.0",
  "minAppVersion": "0.1.0",
  "trust": "sandboxed",
  "activationEvents": ["onStartup"],
  "permissions": {},
  "capabilities": {
    "server.tool": { "entry": "plugin.py", "tools": ["echo"] },
    "server.hook": {
      "entry": "plugin.py",
      "events": ["pre_model", "run_finished"],
      "onError": "continue",
      "priority": 100
    }
  }
}
```

`entry` 与同包的 `server.tool` / `server.ui` **必须指向同一文件**；`events` 只认 `{pre_model, run_finished}`，其余四个已知事件无派发点；`onError: abort` 仅允许落在 `pre_model`；`priority` 缺省 `100`，内置注入块最大卡位 44，故插件恒在其后。

### 5.5 文件读写权限（注意 `~` 前缀）

```json
"permissions": {
  "fs.read":  ["~/.botchat/todos"],
  "fs.write": ["~/.botchat/todos"]
}
```

清单侧与插件侧都用 `~`：`expand_prefix` 只展开清单，而 `ctx.host.fs.*` 的实参只做 `expanduser()`，
带 `${workspace}` 的实参不是绝对路径 ⇒ 判越界（fail-closed）。真实踩坑记录见
`serverSide/examples/extensions/examples.todo-list/plugin.py` 顶部注释。

## 六、清单层最容易犯的六个错

| 错 | 症状 |
|---|---|
| 目录名与 `id` 不一致 | 硬伤 `packageDirNameMismatch`，插件直接不出现 |
| `trust: "data"` 却声明 `server.tool` | 能力被拒（warning），工具永远不出现 |
| `server.ui.entry` ≠ `server.tool.entry` | `server.ui` 被撤下：面板打不开但工具正常 |
| `render: "native"` 没有同名 `client.panel` | 该 `client.view` 被撤下，槽位里没有它 |
| `client.view.view` 不在 `server.ui.views` | 解码期剔除（`capabilityEntryMissing`） |
| `slot` 写成 `settings` / `sidebar` 等自造名 | 该条被跳过，界面上什么都没有 |
