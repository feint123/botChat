---
name: botchat-plugin-authoring
description: 为 botChat 编写、修改、调试插件（扩展）的完整 SOP —— 清单 v2 字段、register(ctx) 工具、IR 面板树（botchat.ui/1）、原生 Swift 面板（botchat.panel/1）、doctor 静态对账、安装/启用/授权/重启与诊断码排障。Use when 用户要写一个 botChat 插件或扩展、给 botChat 加一个侧栏面板/设置页/工具、把已有脚本包成插件、插件装了不生效/面板空白/按钮没反应/工具调不到、或问清单字段、IR 节点、面板编译、扩展放在哪个目录。
---

# botChat 插件开发（扩展）

写插件的唯一原则：**先跑通最小闭环，再往里塞功能**。一个零权限的 `hello` 包能在真实宿主里
被启用、被点击、被 Agent 调用之后，剩下的都是往同一个形状里填内容。

契约正文（唯一事实源，本文只给操作路径）：
`docs/extension-plugin-contract.md`（清单/接口/诊断码）、`docs/extension-plugin-ui.md`（IR 节点）、
`docs/extension-panel-native.md`（原生面板）。**与代码冲突时以代码为准**，冲突处本文标注了对应实现文件。

## 第 0 步 — 形态问诊（MUST NOT 跳过）

写任何一行代码之前先问出「要的是哪一档」。**MUST NOT 沉默假设**：不问就动手，返工成本是重写整包。
宿主是 botChat 时用 `ask_user_question` 工具**一次提交一张表单**（Q1 类型单选 + 3~5 个追问）；
非 botChat 宿主则打印下面编号选项让用户回编号或字母。全文见 `references/intake.md` §一 / §二。

### 六个类型选项（ID 与名称逐字固定，MUST NOT 另造别名）

| ID | 名称 | 什么时候选它 |
|---|---|---|
| T1 | `tool` 纯工具 | 只要 Agent「做得到」、不需要人看见界面：查数据、记账、调本机工具 |
| T2 | `ui` IR 面板 | 要面板/设置页/侧栏段，内容能用文字、列表、按钮、开关、表单表达 |
| T3 | `native` 原生 SwiftUI 面板 | IR 表达不了：Chart、热力图、拖拽、动画、非标准布局 |
| T4 | `theme` 主题包 | 只换观感（46 角色配色；字体/度量 MUST NOT 进主题数据），没有任何代码与能力 |
| T5 | `combo` 工具+面板+命令组合 | 一个包同时要「Agent 能调」+「人能看到能点」，并带 QuickBar 可检索命令 |
| T6 | `modify` 修改或调试已有插件 | 包已存在，要改行为、加能力、修「不生效/空白/点不动」 |

### 能力叠加：`server.hook` 生命周期钩子

hook 不是第 7 种包型而是能力（capability），可叠在 T1/T2/T3/T5 这类有代码入口的包上，也可单独成包（只有 hook、没有工具与界面）。同一插件的 `server.tool` / `server.ui` / `server.hook` 必须指向同一入口文件；细节见 `references/hook.md`。

### 不支持清单（问到就直说做不到，MUST NOT 变通实现）

`server.masking.rules`（只登记）、`server.provider`（永不外置）、
dylib / `.app` / 符号链接（§四 铁律 2 直接拒收）。
原生热键注册：`client.command.shortcut` 只是提示文本，客户端不注册任何热键。
用户目录安装主题包：`client.theme` 唯一 root 是 `Bundle.main.resourceURL/Extensions`，第三方主题必须随 app 分发。

### 追问集（Q1~Q7 同一张表单一次提交）

| 编号 | 问什么 | 选项 / 记法 |
|---|---|---|
| Q1 | 插件类型 | T1~T6 单选 |
| Q2 | 要解决的痛点与使用者 | 人 / Agent / 两者 |
| Q3 | 界面出现在哪 | `panel` / `window` / `composer.accessory` / `sidebar.section` / `settings.section` / 无界面（`window` 经 QuickBar 命令打开为独立 NSPanel，尺寸取清单 `minWidth`/`minHeight` 与 320×240 取大者） |
| Q4 | 数据从哪来 | 纯内存常量 / 本机文件 / 网络 / 宿主 `state` |
| Q5 | 是否需要原生渲染 | 需要（Chart、拖拽、动画、非标准布局）/ 不需要 |
| Q6 | 分发与安装形态 | 自用直装（`Extensions/` 或 install API）/ 随 app 分发 / 主题包 |
| Q7 | 要不要挂生命周期钩子 | pre_model（改模型输入）/ run_finished（run 收尾）/ 都不要 |

### 需求卡（问诊后 MUST 先回写这张卡，再写代码）

8 个字段固定、缺项不许进下一步；**权限清单写「空」是合法答案**（MUST NOT 用留白表达）。

```yaml
id: acme.hello          # 包目录名 MUST 等于它，且 MUST NOT 以 builtin. 开头
展示名: 我的面板
类型: T2                 # 第 0 步表里的 ID
槽位: panel              # 五槽位之一，或「无界面」
视图名列表: [main, settings]
工具名列表: []           # 不提供工具就写 []
权限清单: 空             # fs.read / fs.write / net，缺省空
安装/分发方式: 自用直装
```

### 类型 → 下一步（脚手架 + 先读哪份 reference）

| 类型 | `scaffold_plugin.py` | 先读 |
|---|---|---|
| T1 | `--mode tool --tool <name>` | `references/manifest.md`、`references/plugin-api.md` |
| T2 | `--mode ui --slot <slot>` | `references/manifest.md`、`references/view-ir.md` |
| T3 | `--mode native --slot <slot>` | `references/native-panel.md`（外壳与槽位仍走 view-ir） |
| T4 | `--mode theme` | `references/intake.md` §一 T4 条 |
| T5 | `--mode ui --with-tool` | `references/view-ir.md` + `references/plugin-api.md` |
| T6 | 不生成骨架，直接跳 §三 | `references/intake.md` §五 |
| `server.hook` 能力 | `--with-hook` 叠到已有档，或 `--mode hook` 生成纯 hook 包 | `references/hook.md`；对账 `check_plugin.py` |

## 一、问诊后的档位速查：四档，别一上来就写原生面板

| 档 | 用什么 | 判据 | 能表达什么 |
|---|---|---|---|
| `tool` | `server.tool` + `tools.py` | Agent 要「做事」：查数据、记账、调本机工具 | 只有能力，没有界面 |
| `ui`（默认档） | `server.ui` + `client.view` + IR 树 | 要一个面板/设置页，内容是文字、列表、按钮、开关、表单 | 17 个预制节点，宿主负责排版与取色；挂哪个槽位由 `client.view[].slot` 决定 |
| `native` | 上面 + `client.panel` + 包内 `.swift` | 需要 Chart / 热力图 / 拖拽 / 动画 / 非标准布局 | 编译版 SwiftUI，**在宿主进程内同权运行** |
| `theme` | `client.theme` + 包内 `.json` | 只换观感，无任何代码与能力 | 无代码、只 JSON；**必须随 app 分发**（`clientSide/botChat/Extensions/<id>/`，构建后生效） |

判据来自 `docs/extension-panel-native.md` §一：**能用 IR 表达就别写原生面板**。原生面板的代价是
编译链（首次挂载 `swiftc` 约 0.8s）、主进程同权执行、以及出错时用户只看到占位。

## 二、五步工作流（把第 0 步的需求卡填进代码）

### 第 1 步：生成骨架（不要手搓清单）

```bash
SKILL=~/.agents/skills/botchat-plugin-authoring
python3 $SKILL/scripts/scaffold_plugin.py --id acme.hello --name "我的面板" --dir ~/dev/plugins --mode ui --slot panel
#   --mode ui（缺省）| tool | native | theme
#   --slot panel | window | composer.accessory | sidebar.section | settings.section（ui / native）
#   --with-tool 在 ui 骨架里同时生工具入口（T5）
#   生成 <dir>/<id>/ 并自动跑一次静态对账；--no-check 可跳过
```

脚本会替你守住两条硬规则：**包目录名 MUST 等于清单 `id`**、`id` MUST NOT 以 `builtin.` 开头
（内置包确实要该前缀时显式加 `--allow-builtin-prefix`，脚本会提示「随 app 分发」）。

### 第 2 步：填逻辑

- 工具：`templates/tool/tools.py.tpl` 的形状 —— `register(ctx)` 里 `ctx.tool(name, handler, description=, input_schema=)`。
- IR 面板：`register(ctx)` 里 `ctx.view(name, handler)` / `ctx.command(id, handler)`，handler 收 `payload` 回**整棵树**。
- 原生面板：视图函数回**数据对象**（不是树），界面写包内 `Panels/*.swift`，入口类名逐字 `@objc(BotChatPanelEntry)`。

**声明与注册必须逐字对得上**（这是最高频的翻车点）：

| 清单里 | 代码里 | 不一致的后果 |
|---|---|---|
| `server.ui.views: ["main","settings"]` | `ctx.view("main", …)` / `ctx.view("settings", …)` | 声明了没注册 ⇒ 渲染时 `capabilityEntryMissing`；注册了没声明 ⇒ 该 view 永远挂不上 |
| `server.tool.tools: ["todo_add"]` | `ctx.tool("todo_add", …)` | doctor 判硬伤（声明与登记不一致） |
| `client.command.id: "acme.hello.open"` | `ctx.command("acme.hello.open", …)` | 命令点不动 |
| `client.panel.views[].view` | 同上 AND 该 view 的 `client.view[].render` 为 `"native"` | `render: native` 无同名 `client.panel` ⇒ 撤下该条 |

### 第 3 步：静态对账（**每次改完清单都跑**）

```bash
python3 ~/.agents/skills/botchat-plugin-authoring/scripts/check_plugin.py ~/dev/plugins/acme.hello
# 等价于：cd serverSide && BOTCHAT_EXTENSIONS_ROOT=<父目录> .venv/bin/python -m app.extensions.doctor
```

退出码 `0` 通过 / `1` 有硬伤 / `2` 环境问题（找不到 `serverSide`，用 `--server-root` 指定）。
输出里 `[info] userRootDisabled` 是**预期的**——包装器刻意关掉本机已装包，避免别人的坏包混进你的报告。

这个包装器比裸 doctor 多做一件事：**原生面板源码门禁预检**（`client.panel` 的 `.swift` 按
`PanelSourceGate` 同一份规则查 import 白名单 / 禁用符号 / 写死颜色 / 体积），因为 doctor 只看
Python 与包形态，Swift 侧的问题要到客户端编译时才暴露。

doctor 的口径必须看懂：它只做**静态**判定（entry 文件存在且可读），**通过 ≠ 能激活**。
真实激活要有数据库、子进程与启用状态。

### 第 4 步：安装 → 启用 → 授权 → 重启宿主

插件目录**不在仓库里**，落在运行时根：

```
<home_root>/Extensions/<id>/          # 用户插件
# home_root 缺省 = serverRoot()，实际运行 app 时为
# ~/Library/Application Support/botChat/server（受 BOTCHAT_HOME 影响）
```

三条路，任选一条：

1. **设置页安装（推荐）**：把包目录喂给 `POST /api/extensions/install`，body `{"source_path": "<本机绝对路径>"}`
   （只收本机目录，`~/` 可展开；MUST NOT 传 URL）。装完是「未启用、空授权」，再 `POST /api/extensions/{id}/enable`
   body `{"enabled": true}`，要权限则 `POST /api/extensions/{id}/permissions`。
2. 直接把包目录拷进上面那个 `Extensions/`（目录名 = id），重启宿主后在设置里启用。
3. 内置包（随 app 分发）走 `clientSide/botChat/Extensions/`，构建时进 bundle。

**改完代码必须重启宿主**：`POST /api/extensions/host/restart`（停 → **重扫磁盘** → 按库内 `enabled`
重新激活）。本期没有热重载，停用只做到「工具不可调用」，宿主仍持有旧模块；
若改的是 `serverSide/` 源码，app 形态下必须重新构建 App（运行的是 bundle 里的 server 拷贝）。

### 第 5 步：活体验证（三个探针，缺一个都不算跑通）

| 探针 | 怎么做 | 不通说明什么 |
|---|---|---|
| 启用态 | 设置页能看到该插件且可启用；`GET /api/extensions` 里 `registered=true` / `enabled=true` | 包形态或清单被拒（看诊断码） |
| 视图 | 打开面板：先看到树，再**点一次按钮数字要变** | 链路断在渲染或动作回包 |
| 能力 | 让 Agent 做一次该工具要做的事；看不到工具就先 `tool_search` | 工具没进能力目录 / 未启用 / 仍是 `extended` |

**插件工具缺省是 `extended`**（`app/tools/spec.py` `PluginToolSpec.tier`）：它不会被注入模型的 `tools`
数组，只经 `tool_search` 被发现；当前清单**没有**声明 `core` 的入口（`tool_bridge.build_spec` 不传
`tier`），所以「写了工具但主 Agent 直接看不见」是预期行为，不是 bug。

## 三、修改与调试入口（T6 固定顺序，MUST NOT 跳步）

改已有插件按这五条走；**MUST NOT 在没跑完前五条时重写整包**，MUST NOT 顺手重构用户既有代码（只动最小面）。

1. **定位包目录**——只有两个 root：运行时 `<home_root>/Extensions/<id>/`（用户装，见 §二 第 4 步）与
   内置 `<repo>/clientSide/botChat/Extensions/<id>/`（随 app 分发）。两处同在时先确认宿主实际加载哪一个。
2. **read 清单** `<包>/manifest.json`，判断已声明的能力组合（`server.*` / `client.view` / `client.panel` /
   `client.command` / `client.theme`）。清单是事实源：代码有清单无 ⇒ 该能力不存在；清单有代码无 ⇒ `capabilityEntryMissing`。
3. **`check_plugin.py <包目录>`** 清静态硬伤（含原生面板源码门禁预检），口径见 §二 第 3 步。
4. **`POST /api/extensions/host/restart`**（停 → 重扫 → 按库内 `enabled` 重激活）；本期无热重载，不重启则改动不生效。
5. **三探针**：启用态 / 视图 / 能力，口径同 §二 第 5 步；缺一个都不算跑通。

先分清断在「没登记 / 没激活 / 没渲染 / 没权限」哪一层：判定树见 `references/intake.md` §五，现象对照见 §五。

## 四、铁律（违反即返工）

1. **包目录名 = 清单 `id`**；`id` 全局唯一，`builtin.` 前缀保留。
2. **禁符号链接**（任意层级）、禁可执行位、禁 `.sh/.command/.bat/.cmd/.ps1/.dylib/.so/.dll/.node/.jar/.app`。
3. 包内**只放清单声明过的代码**：有 `.py` 却没声明代码能力 ⇒ doctor 硬伤（来源不明的可执行代码）。
   同时**一个插件只有一个代码入口**：`server.ui.entry` 与 `server.tool.entry` MUST 指向同一文件，
   否则 `server.ui` 被撤下（工具保留）——现象就是「工具好用、面板打不开」。
4. 扫描期**零代码执行**：`.py` 有语法错误也照常登记，错误只在激活时以 `pluginCrashed` 暴露 ——
   所以「doctor 通过」不等于「代码没语法错」，激活后还要看诊断。
5. `entry` MUST 是包内相对路径、不逃出包根；`server.*` 只允许 `.py`，`client.theme` 只允许 `.json`，
   `client.panel` 只允许 `.swift` 且单文件 ≤ 256 KB。
6. 工具返回值 MUST 可 JSON 序列化（不可序列化即 `invalid_result`，宿主不会 `str()` 兜底）；
   业务失败用返回体表达，别靠抛异常。
7. IR 树里 **MUST NOT 出现字面色值 / 字体 / 像素**：`color`/`font`/`fontSize`/`width`/`padding`/`radius`
   这些键名本身非法；颜色只能走 `tone`，取值限于 `TONE_ROLES` 的 27 个角色。
8. **渲染 MUST 是纯函数**：渲染期的写型宿主调用（`fs.write` / `net.fetch`）会被直接拒（`permissionDenied`）。
9. 权限缺省全空；`fs.read` / `fs.write` 是**路径前缀数组**，写不隐含读；`net` 是**精确 host**，不许通配。
   `ctx.host.fs` 的实参**不做占位符替换**且要求绝对路径 —— 清单侧写 `${workspace}/x` 与插件侧传
   `${workspace}/x` 对不上（前者被 `expand_prefix` 展开、后者被判越界）。**两侧都用 `~` 前缀**是唯一能对齐的形态。
10. 插件之间互不可见（模块名 `botchat_ext_<sanitized_id>`），跨插件 `import` 必失败；`state` 只含白名单键
    （`workspaceName`、有会话时的 `conversationTitle`），MUST NOT 期待凭据或消息正文。
11. `activationEvents` 本期**不驱动激活**：装配层在启动 / 启用 / `host/restart` 时按库内 `enabled`
    直接激活，`dispatch_event`（按事件懒激活）当前没有调用方。所以漏写不会导致「激活不了」，
    写了也还没生效 —— 别把它当成排障线索。

## 五、排障：现象 → 先去哪看

| 现象 | 最可能原因 | 改哪里 |
|---|---|---|
| 设置页根本没有这个插件 | 目录名 ≠ `id` / 清单 JSON 坏 / `minAppVersion` 高于当前 app | 跑 `check_plugin.py` 看 error 级诊断 |
| 插件在、启用后没反应 | 宿主没重扫/没激活（装配层只在启动、启用、`host/restart` 时激活） | `POST /api/extensions/host/restart`，再看该行诊断 |
| 面板空白 / 显示占位 | 树非法（`irInvalid`）或超预算（`irBudgetExceeded`） | 用服务端 `ui_ir.validate(tree)` 本地复现，看 `code` + `path` |
| 点了按钮界面不变 | 交互分支回了和上次**逐字相同**的树（本通道无 patch） | 让返回值带上变化量（计数、时间、状态） |
| 面板一片报错 / `nativeEntryMissing` | `@objc(BotChatPanelEntry)` 写错、entry 路径不在包内、`apiVersion` ≠ 1 | 包内 `.swift` 入口类名与清单 `client.panel.entry` |
| 原生面板编译失败 | 用了门禁 API（出网/文件/子进程/dylib 相关）或不是 bundle 友好代码 | 只经 `data` 取数、只经 `host.dispatch` 动作 |
| 工具「存在但模型看不到」 | 插件工具缺省 `extended` | 让 Agent 先 `tool_search`；或把能力目录里该工具启用 |
| 工具调用报 `permissionDenied` | 清单请求了但没授权 / 渲染期写盘 / 路径越界 | `extension_state.permissions_json` 与路径前缀 |
| 改完代码行为没变 | 无热重载，宿主还持有旧模块 | 重启宿主（app 形态要重启整个 app） |

## 六、参考文件

- `references/intake.md` —— 七类型目录、问诊脚本、需求卡→清单映射、修改与调试决策树（§一 类型目录 /
  §二 问诊脚本 / §三 判据表 / §四 需求卡到清单映射 / §五 修改与调试 / §六 反模式）
- `references/hook.md` —— `server.hook` 扩展包能力：清单声明、`hooks` 字典入口、payload 白名单、回传体与预算、失败处置、对账与常见坑
- `references/manifest.md` —— 清单 v2 逐字段 + 三种完整清单
- `references/plugin-api.md` —— `register(ctx)` / `ctx.host.*` 全签名与错误形态
- `references/view-ir.md` —— 17 个节点、`tone` 白名单、预算、交互与幂等
- `references/native-panel.md` —— `client.panel` Swift 面板：SDK 全 API、编译链、门禁、纪律
- `references/lifecycle.md` —— 安装/启用/授权/停用/进程态的全部边界
- `references/troubleshooting.md` —— 诊断码逐条对应「改哪一行」+ 真实踩坑
- `scripts/scaffold_plugin.py` / `scripts/check_plugin.py` —— 生成与对账
- `templates/{tool,ui,native,theme}/` + `templates/fragments/` —— 四档骨架与共用片段（窄槽位用 `plugin.compact.py.tpl` 的 `Row` 根紧凑树；`--with-tool` 用 fragments 往同一 entry 插工具代码）。占位符 `{{id}}` `{{name}}` `{{tool}}` `{{view}}`
  `{{command}}` `{{slot}}` `{{toolFull}}` 由脚手架替换；`*.tpl` 落盘时剥后缀
