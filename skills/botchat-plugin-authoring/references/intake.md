# 问诊 / 选型 / 修改 —— 唯一参考页

**这页什么时候用**：用户只说「我想要个 botChat 插件」而没说形态时（§一 / §二）、要判定「他这句原话该落哪一档」时（§三）、问诊完要把需求卡翻成清单字段时（§四）、包已存在要改或修不生效时（§五）、想把做法沉淀成「别这么干」时（§六）。
口径三源：`docs/extension-plugin-contract.md`（清单 / 接口 / 诊断码）、`docs/extension-plugin-ui.md`（IR）、`docs/extension-panel-native.md`（原生面板）。**与代码冲突以代码为准**，冲突处标注「本页口径 → 代码位置」。下列片段里公共清单字段一律省略：`schemaVersion:2` / `id` / `name` / `version` / `minAppVersion` / `trust` / `permissions`。

## 一、七类插件目录

**这节什么时候用**：回答「能做几种插件、每种长什么样、起步命令是什么」。六个 ID 与名称逐字固定，MUST NOT 另造别名。

### T1 `tool` 纯工具

| 项 | 内容 |
|---|---|
| 定位 · 适用 | 只有能力、没有界面：Agent 能「做事」，人看不到任何东西。「让 Agent 能查我的待办」「把这笔账记下来」。 |
| 不适用 | 想看数 / 想点按钮 / 想配置；或「Agent 说完还要人确认」。 |
| 起步 · 闭环 | `python3 $SKILL/scripts/scaffold_plugin.py --mode tool --tool <name> --dir ~/dev/plugins --id <id>`；闭环 = `check_plugin.py` 退出 0 → install/enable → Agent 先 `tool_search` 再调用一次并拿到业务结果。 |
| 代价与坑 | **缺省 `extended`**：不进模型 `tools` 数组，只经 `tool_search` 被发现；清单**没有**声明 core 的入口（`tool_bridge.build_spec` 不传 `tier` → `serverSide/app/extensions/tool_bridge.py:71`、`serverSide/app/tools/spec.py:102`）。因此「写了工具、主 Agent 直接看不见」是预期行为。 |

```json
// <id>/manifest.json + <id>/tools.py（register(ctx) → ctx.tool(...)）
"capabilities": { "server.tool": { "entry": "tools.py", "tools": ["<name>"] } },
"activationEvents": ["onTool:<id 归一>__<name>"]
```

### T2 `ui` IR 面板

| 项 | 内容 |
|---|---|
| 定位 · 适用 | 17 个预制节点拼树，宿主负责排版与取色（默认档，能表达就别升 T3）。「想要个面板看数据」「加个设置页」。 |
| 不适用 | Chart / 热力图 / 拖拽 / 动画 / 非标准布局 —— IR 表达不了，升级 T3。 |
| 起步 · 闭环 | `python3 $SKILL/scripts/scaffold_plugin.py --mode ui --slot <slot> --dir ~/dev/plugins --id <id>`；闭环 = 打开面板先看到树，**点一次按钮数字要变**。 |
| 代价与坑 | 渲染 MUST 纯函数（渲染期 `fs.write` / `net.fetch` 直接 `permissionDenied`）；`tone` 只有 27 个角色；`nodeId` / `name` 不许绑定。 |

五槽位选择表（`slot` 是封闭集合，集合外取值**跳过该条、不拒包**）：

| slot | 用户会怎么说 | 预算 / 节点白名单 | 输入 | 尺寸与落点 |
|---|---|---|---|---|
| `panel` | 「给我开一栏看板」 | 2000 / 全部 | 允许 | 随列宽（宽 ≥300pt），列带 `ExtensionPanelColumn` |
| `window` | 「想要个独立小窗」 | 2000 / 全部 | 允许 | 下限 320×240（`size.minWidth/minHeight` 可抬高），见下 |
| `composer.accessory` | 「输入条上加个开关」 | 40 / `Row` `Text` `Button` `Toggle` | 只许 `Toggle` | 高 ≤44pt；单占位选举 + ✕ 冷却 30 分钟 |
| `sidebar.section` | 「侧栏加个分区」 | 200 / `Row` `Text` `Button` `Progress` `List` | 禁止 | 高 ≤240pt 超出滚动；全部占用者都渲染 |
| `settings.section` | 「加个设置页」 | 300 / 全部（禁 `List`） | 允许 | 宽度随页，插件详情页 `ExtensionDetailPanelSection` |

**`window` 的降级事实**：经 QuickBar 插件命令打开时按「面板列 + 一条提示」呈现（降级必须可见，MUST NOT 静默换呈现）——`ExtensionPluginCommandRunner.swift:17`、`ExtensionSlotCatalog.swift:64`。**本页口径 → 代码现状**：HEAD 的 `QuickBarHostBridge.swift:134` 已把 `slot == "window"` 交给 `ExtensionPanelWindowController`（`NSPanel`，`ExtensionPanelWindow.swift:72`）打开，上述两处注释尚未同步；仅 `requestOpen(extensionPanel:)` 路径走面板列。

```json
// <id>/manifest.json + <id>/plugin.py（register(ctx) → ctx.view(...) / ctx.command(...)）
"capabilities": {
  "server.ui": { "entry": "plugin.py", "views": ["main", "settings"] },
  "client.view": [{ "slot": "panel", "view": "main", "title": "看板", "icon": "square.grid.2x2", "priority": 50 },
                  { "slot": "settings.section", "view": "settings", "title": "看板设置" }],
  "client.command": { "id": "<id>.open", "title": "打开看板" } }
```
`client.view.view` MUST 在 `server.ui.views` 里（否则解码期剔除 `capabilityEntryMissing`）；`client.command` 只认**单对象**。

### T3 `native` 原生 SwiftUI 面板

| 项 | 内容 |
|---|---|
| 定位 · 适用 | 包内自带 `.swift`，客户端首次挂载时 `swiftc` 编成 bundle，在**宿主主进程内同权运行**。要图表 / 热力图 / 拖拽 / 动画。 |
| 不适用 | 文字、列表、表单、按钮、进度 —— 用 IR，写原生是过度设计。 |
| 起步 · 闭环 | `python3 $SKILL/scripts/scaffold_plugin.py --mode native --slot <slot> --dir ~/dev/plugins --id <id>`；闭环 = 门禁预检 → `validate_panel_data(...)` → 装/启用/重启 → 点按钮数字变且滚动与输入状态留住。 |
| 代价与坑 | 编译链代价：首次挂载 `swiftc -Onone` 约 0.83s、**不是沙箱**（门禁只挡误用与主题腐烂）、编译失败用户只见占位、无工具链报 `nativeToolchainMissing`（同包 IR 视图照常工作）。 |

三处声明必须同时成立，缺一条即撤下：`client.view.render = "native"`、`client.panel.views[].view` 同名、`server.ui.views` 含该 view。`apiVersion` 只认 `1`；`entry` 是包内相对路径、`.swift`、**单文件 ≤256 KB**（≤4000 行）；入口类名逐字 `@objc(BotChatPanelEntry)`。`PanelSourceGate` 门禁：import 只许 `SwiftUI` / `AppKit` / `Foundation` / `Observation` / `CoreGraphics`；禁用符号子串匹配（`FileManager` `URLSession` `Process(` `NSTask` `dlopen` `NSWindow(` …，**注释里出现也算**）；写死颜色一律拒。

```json
// <id>/manifest.json + <id>/plugin.py（视图回「数据对象」）+ <id>/Panels/Main.swift（写界面）
"client.view": [{ "slot": "panel", "view": "hits", "title": "命中", "render": "native" }],
"client.panel": { "views": [{ "view": "hits", "entry": "Panels/Main.swift", "apiVersion": 1 }] }
```

### T4 `theme` 主题包

| 项 | 内容 |
|---|---|
| 定位 · 适用 | 纯数据包，只给颜色角色，没有任何代码与能力。「界面太素，想换套配色」。 |
| 不适用 | 想改字体 / 圆角 / 尺寸 / 布局 / 动效 —— `ThemeMetrics` / `ThemeFont` MUST NOT 进 `theme.json`。 |
| 起步 · 闭环 | `python3 $SKILL/scripts/scaffold_plugin.py --mode theme --dir <父目录> --id <id>`（生成 `manifest.json` + `theme.json`，41 角色取自 `builtin.paper-warm` 真实取值，MUST 逐个改成自己的配色）；脚本自带客户端判据自检（41 角色完整 / 派生禁写 / `schemaVersion==1` / `#RRGGBB` / `{light,dark}` 成对）；`check_plugin.py` **只覆盖清单、不校验 theme.json 语义**；闭环 = 源目录落盘 → 构建 App → 设置页主题列表出现该套并可切换。 |
| 代价与坑 | **只能随 app 分发**：唯一 root 是 `Bundle.main.resourceURL/Extensions`（`ThemeCatalog.swift:54`），本期不支持用户目录安装 / 文件导入 / `.bctheme` 关联；源目录是 folder reference（`project.pbxproj:40`），构建后才生效。清单 `schemaVersion` 是 **`1`**（插件包是 `2`，别混）。 |

`theme.json` 要给 **41 个可写角色**（46 角色中 5 个派生，派生角色出现即校验失败），取值 `{light, dark}` 成对 `#RRGGBB`，**唯一豁免 `brand.emphasis`** 允许 light/dark 同值；禁字体 / 脚本 / 图片 / 外链 URL / `data:`；包内文件白名单只有 `manifest.json` / `theme.json` / `preview.png`（≤64KB）。

```json
// <id>/manifest.json（schemaVersion: 1）+ <id>/theme.json + <id>/preview.png（可选，≤64KB）
{ "schemaVersion": 1, "id": "acme.ink", "name": "墨", "version": "1.0.0", "minAppVersion": "1.2.0",
  "capabilities": { "client.theme": { "entry": "theme.json" } } }   // 无 permission / trust，纯数据包
```
`builtin.` 前缀保留给内置包（`ThemeValidationRules.swift:50`），第三方用自家前缀（如 `acme.ink`）。

### T5 `combo` 组合（工具 + 面板 + 命令）

| 项 | 内容 |
|---|---|
| 定位 · 适用 | 一个包里 Agent 能调、人能看到能点、QuickBar 能搜到它声明的命令。「Agent 帮我记待办，我也想在侧栏看着划掉」。 |
| 不适用 | 两件事其实互不相关 —— 拆两个包（插件之间互不可见，跨包 `import` 必失败）。 |
| 起步 · 闭环 | `python3 $SKILL/scripts/scaffold_plugin.py --mode ui --with-tool --dir ~/dev/plugins --id <id>`；闭环 = 三探针全绿（启用态 + 视图点得动 + `tool_search` 后能调），且命令能在 QuickBar 搜到。 |
| 代价与坑 | **一个 `register(ctx)`、一份 entry**：`server.ui.entry` 与 `server.tool.entry` MUST 指向同一文件，否则 `server.ui` 被撤下（工具保留）—— 现象是「工具好用、面板打不开」。声明与注册 MUST 逐字对齐：`server.ui.views` ↔ `ctx.view()`、`server.tool.tools` ↔ `ctx.tool()`、`client.command.id` ↔ `ctx.command()`。 |

```json
// <id>/manifest.json + <id>/plugin.py（同一个 register(ctx) 里注册 view / command / tool）
"capabilities": {
  "server.ui":   { "entry": "plugin.py", "views": ["main"] },
  "server.tool": { "entry": "plugin.py", "tools": ["todo_add"] },
  "client.view": [{ "slot": "sidebar.section", "view": "main", "title": "我的待办" }],
  "client.command": { "id": "<id>.open", "title": "打开待办" } }
```

### T6 `modify` 修改 / 调试已有插件

包已存在，要改行为、加能力，或修「不生效 / 空白 / 点不动」。**不适用**：其实想「另做一个」—— 先按 §二 重新问一遍（同 `id` 冲突会 `extensionIdConflict`）。**起步**：不生成骨架，按 **§五** 固定决策树走。**代价**：改包必须重启宿主（本期无热重载）；改 `serverSide/` 源码在 app 形态下要**重新构建 App**。

### 能力叠加：`server.hook`（不是第 7 种类型）

| 项 | 内容 |
|---|---|
| 定位 · 适用 | 挂到 Agent 生命周期：`pre_model` 改模型输入、`run_finished` 做收尾；可叠在 T1/T2/T3/T5 上，也可单独成纯 hook 包。 |
| 不适用 | 只认识但无派发点的四个事件 `post_model` / `pre_tool` / `post_tool` / `idle`，声明了也不执行、只记 warning。 |
| 起步 · 闭环 | `--mode hook` 或 `--with-hook` → 填 `capabilities.server.hook` 四字段 → 写模块级 `hooks` 字典 → `check_plugin.py` 对账 → 安装启用 → `host/restart`。 |
| 代价与坑 | `trust` 不能写 `data`；三个代码类 kind 必须同入口；回传体多写键会被整次拒；priority 缺省 100 恒在内置块之后。 |

> 参数互斥口径：`--slot` / `--with-tool` 只对 `ui` / `native` 有意义（`tool` / `theme` 给非 `panel` 槽位或 `--with-tool` 会被拒，退出码 2）；`--view` 与 `--tool` 同名、`--view settings`（与模板固定注册的第二视图撞名）、非 `^[a-z][a-z0-9_]*$` 的标识符同样被拒。窄槽位（`sidebar.section` / `composer.accessory`）会自动换成 `Row` 根紧凑树——面板那棵 `Column` 树会被整树拒渲染（`slotNotAllowed`）。

## 二、问诊脚本

**这节什么时候用**：写第一行代码之前。**MUST NOT 沉默假设**，也别把七个类型直接倒给用户 —— 先问痛点，再落类型。

| 编号 | 问什么 | 选项 | 跳过规则 |
|---|---|---|---|
| Q1 | 你要的是哪一类 | T1~T6（判据见下） | 恒问 |
| Q2 | 解决谁的什么问题 | 人 / Agent / 两者 + 痛点一句话 | 恒问 |
| Q3 | 界面出现在哪 | `panel` / `window` / `composer.accessory` / `sidebar.section` / `settings.section` / 无界面 | T1、T4 跳过（都无界面） |
| Q4 | 数据从哪来 | 内存常量 / 本机文件 / 网络 / 宿主 `state` 白名单 | T4 跳过（纯数据包） |
| Q5 | 是否需要原生渲染 | 需要（Chart / 拖拽 / 动画 / 非标准布局）/ 不需要 | T1、T4 跳过 |
| Q6 | 怎么装、给谁用 | 自用直装（`Extensions/` 或 install API）/ 随 app 分发 / 主题包 | 恒问（T4 只有「随 app 分发」） |

Q1 判据一句话：T1 只要 Agent「做得到」、人不需要看见界面 · T2 要一块界面且内容能用文字/列表/按钮/开关/表单说完 · T3 要 Chart / 热力图 / 拖拽 / 动画 / 非标准布局、IR 表达不了 · T4 只换观感（配色）、不要任何代码与能力 · T5 同一件事既要 Agent 能调、又要人能看到能点 · T6 包已经有了，要改 / 要修。

「用户这样答 ⇒ 就这么定」：

| 用户答 | 就这么定 |
|---|---|
| Q1=T1 且 Q2 说「Agent 帮我做」 | T1；不填槽位、不写 `client.*`，`permissions: {}` 起步 |
| Q1=T2 且 Q3=`settings.section` | T2；该 view 禁 `List`、上限 300 节点 |
| Q1=T2 且 Q3=`composer.accessory` | T2；只许 `Row`/`Text`/`Button`/`Toggle`、最多一个 `Toggle`、40 节点 |
| Q1=T2 且 Q5=需要 | 改判 T3；`render` 写 `native` 并补 `client.panel` |
| Q1=T4 | T4；`schemaVersion: 1`，交付形态只能是「随 app 分发」 |
| Q2 说「Agent 调 + 我也想点」 | T5；一个 `plugin.py` 同时挂 `server.tool` 与 `server.ui` |
| 说要「模型看到之前加点东西」 | 在 T1/T2/T5 上叠加 `server.hook`，`events: ["pre_model"]`，回传体按 `after-system-prefix` 插 system 消息 |
| 说要「每轮结束自动做事」 | `events: ["run_finished"]`；`idle` 无派发点，声明了也不执行 |
| Q4=网络 或 Q4=本机文件 | 追加 `permissions.net`（精确 host）或 `fs.read` / `fs.write`（`~` 前缀路径数组） |
| Q4=宿主 `state` | 只可依赖 `workspaceName`（恒有）与 `conversationTitle`（有会话才有）；**凭据 MUST NOT 走 state** |
| Q6=随 app 分发且是 T2/T3 | 放 `clientSide/botChat/Extensions/<id>/`；`id` MUST NOT 以 `builtin.` 开头 |

提问模板（可直接抄给用户；允许回「我不确定」，此时按推荐缺省）：

```
为了不返工，先确认 6 件事（回编号即可；不确定就写「不确定」，我按推荐缺省往下走）：
1. 你要哪一类？ 1) 纯工具（Agent 能查能记，界面看不到） 2) 普通面板（文字/列表/按钮/开关/表单） 3) 原生面板（图表/拖拽/动画） 4) 主题包（只换配色） 5) 组合包（Agent 能调 + 我能点 + 命令可搜） 6) 改已有插件
   另问（不算类型选择）：要不要挂生命周期钩子？`pre_model`（改模型输入）/ `run_finished`（run 收尾）/ 都不要 —— 这是能力叠加，选完类型再加。
2. 它替你解决什么？主要给谁用：人 / Agent / 两者？
3. 界面放哪？ 1) 列带面板 2) 独立小窗 3) 输入条上 4) 侧栏分区 5) 设置页 6) 不要界面
4. 数据从哪来？ 1) 写死在代码里 2) 读本机文件 3) 联网 4) 只读宿主给的 workspaceName / 会话标题
5. 需要图表/拖拽/动画这类原生渲染吗？ 要 / 不要      6. 怎么装？ 1) 自己用本地目录装 2) 随 app 一起发 3) 主题包
推荐缺省：1→2)、3→1)、4→1)、5→不要、6→1)。
```

**不支持清单（问到就直说做不到，MUST NOT 变通实现）**：`server.masking.rules`（登记未实现）、`server.provider`（永不外置）、dylib / `.app` / 符号链接 / 可执行位；原生热键注册（`client.command.shortcut` 只是提示文本，客户端不注册热键 → `serverSide/app/extensions/capability_shortcut.py`）；用户目录安装主题包。

## 三、判据表（用户原话 → 类型）

**这节什么时候用**：用户不按问卷答、只丢一句口语时快速定档；也当「这不该是什么」的对照表。

| 用户原话 | 类型与落点 |
|---|---|
| 想让 Agent 能查我的待办 | T1 `tool`；`server.tool` + `tools.py`，零权限起步 |
| 想要个面板看数据 | T2 `ui`；`panel` + IR 树 |
| 想要图表热力图拖拽 | T3 `native`；`render: "native"` + 包内 `Panels/*.swift` |
| 界面太素想换配色 | T4 `theme`；`schemaVersion: 1` + 41 角色 `theme.json`，随 app 分发 |
| 插件装了不生效 | T6；先查启用态与 `host/restart`（§五 第 4 步） |
| 工具模型看不见 | T6；插件工具缺省 `extended`，让 Agent 先 `tool_search`（不是 bug） |
| 面板点按钮没反应 | T6；交互回了逐字相同的树（本通道无 patch），给返回值加变化量 |
| 想加个输入条按钮 | T2；`composer.accessory`（只许一个 `Toggle`、40 节点、✕ 冷却 30 分钟） |
| 想在侧栏加分区 | T2；`sidebar.section`（200 节点、禁输入、240pt 上限、全部渲染） |
| 想加设置页 | T2；`settings.section`（300 节点、禁 `List`） |
| 想加个独立小窗 | T2；`window`（`size.minWidth/minHeight` 抬高 320×240 下限） |
| 想加个 Agent 能调、我也能点的东西 | T5 `combo`；一份 `plugin.py` 同时注册 tool + view + command |
| 想在模型调用前注入一段规范 / 上下文 | `server.hook` + `pre_model`：回传体按 `after-system-prefix` 插 system 消息 |
| 想在每轮结束自动归档 / 统计 | `server.hook` + `run_finished`：回传体写 `metrics` / `logs` |

## 四、需求卡 → 清单映射

**这节什么时候用**：问诊结束后、写代码之前。8 个字段固定，缺项 MUST NOT 进下一步；「权限清单写空」是**合法答案**，不许留白。

| 需求卡字段 | 落到清单哪 | 不填的合法形态 |
|---|---|---|
| `id` | `id`（MUST 等于包目录名） | 不能省；小写字母开头 + `a-z0-9._-`，MUST NOT 以 `builtin.` 开头 |
| 展示名 | `name` | 不能省；照抄 `id` 是最差做法，至少写成用户能懂的名字 |
| 类型 | 由 `capabilities` 组合体现（无 `type` 键） | 不能省（决定后面五行） |
| 槽位 | `client.view[].slot` | T1 / T4 时整个 `client.view` 都不出现 |
| 视图名列表 | `server.ui.views`（每条 `client.view.view` 必在其内） | `[]` → 不写 `server.ui`，也不写 `client.view` / `client.command` |
| 工具名列表 | `server.tool.tools` | `[]` → 不写 `server.tool`（空数组会被拒该能力） |
| 权限清单 | `permissions` | 写 `{}`；只写要用的键，`fs.*` 用 `~` 前缀路径数组、`net` 用精确 host |
| 安装 / 分发方式 | 不落清单字段，落**落盘位置** | 自用直装 → `<home_root>/Extensions/<id>/`（运行 app 时即 `~/Library/Application Support/botChat/server/Extensions/<id>/`）；随 app 分发 → `clientSide/botChat/Extensions/<id>/` |

完整可抄的 8 字段需求卡（T5 示例）：

```yaml
id: acme.todo            # 包目录名 MUST 等于它，MUST NOT 以 builtin. 开头
展示名: 我的待办
类型: T5                 # 工具 + 面板 + 命令
槽位: sidebar.section    # 五槽位之一；T5 也常选 panel / settings.section
视图名列表: [main]       # → server.ui.views 与 client.view[].view
工具名列表: [todo_add]   # → server.tool.tools（对外名 acme_todo__todo_add）
权限清单: { fs.read: ["~/.botchat/todos"], fs.write: ["~/.botchat/todos"] }   # → permissions
安装/分发方式: 自用直装  # 拷进 <home_root>/Extensions/acme.todo/ 或 POST /api/extensions/install
```

对应清单骨架（三个能力块都要齐；少一个就回 §二 重问，别靠代码「兜一下」）：

```json
{ "schemaVersion": 2, "id": "acme.todo", "name": "我的待办", "version": "0.1.0", "minAppVersion": "0.1.0", "trust": "sandboxed",
  "activationEvents": ["onStartup", "onSlot:sidebar.section:main"],
  "permissions": { "fs.read": ["~/.botchat/todos"], "fs.write": ["~/.botchat/todos"] },
  "capabilities": { "server.ui": { "entry": "plugin.py", "views": ["main"] },
                    "server.tool": { "entry": "plugin.py", "tools": ["todo_add"] },
                    "client.view": [{ "slot": "sidebar.section", "view": "main", "title": "我的待办" }] } }
```

## 五、修改与调试

**这节什么时候用**：包已存在（T6）、或「装了不生效 / 空白 / 点不动」。五步固定顺序，MUST NOT 跳步。

1. **定位包目录**（只有两个 root）：运行时 `<home_root>/Extensions/<id>/`（运行 app 时即 `~/Library/Application Support/botChat/server/Extensions/<id>/`，受 `BOTCHAT_HOME` 影响）与内置 `clientSide/botChat/Extensions/<id>/`；两处同 id 先确认宿主实际加载哪一个（内置 root 优先）。
2. **read 清单判能力组合**：清单是事实源 —— 代码有清单无 ⇒ 该能力不存在；清单有代码无 ⇒ `capabilityEntryMissing`；顺带看 `server.ui.entry` 与 `server.tool.entry` 是否同一文件（不同 ⇒ `server.ui` 被撤下）。
3. **`python3 $SKILL/scripts/check_plugin.py <包目录>`**：退出码 `0` 通过 / `1` 有硬伤 / `2` 环境问题；比裸 doctor 多一层原生面板源码门禁预检，`[info] userRootDisabled` 是预期项。
4. **`POST /api/extensions/host/restart`**：停 → 重扫磁盘 → 按库内 `enabled` 重激活。本期无热重载，不重启等于没改。
5. **三探针**：启用态（`GET /api/extensions` 的 `registered` / `enabled`）、视图（打开面板点一次按钮要有变化）、能力（让 Agent 做一次该工具做的事；看不到先 `tool_search`）—— 缺一个都不算跑通。

断在哪一层：**没登记**（包形态 / 清单被拒，看诊断码）→ **没激活**（启用态 + `host/restart`）→**没渲染**（`irInvalid` / `irBudgetExceeded` / `slotNotAllowed` / `nativeEntryMissing`）→ **没权限**（`permissionDenied`）。

| 改了什么 | 要重启什么 |
|---|---|
| 插件 Python 代码（`.py`） | `POST /api/extensions/host/restart`（宿主仍持旧模块，停用不够） |
| 清单 `manifest.json` | `host/restart`；slot / 视图声明变了还要让客户端重拉 `GET /api/extensions/views` |
| 包内 Swift 面板 | `host/restart`；编译缓存键含源码 + SDK 源 + 参数 + `swiftc --version`，源码变了自动重编 |
| 内置包（`clientSide/botChat/Extensions/`） | 重新构建 App 后启动（资源进 bundle，改源目录不影响已构建产物） |
| `serverSide/` 源码 | 重启服务进程；**app 形态下必须重新构建 App**（运行的是 `…/botChat.app/Contents/Resources/server` 拷贝） |
| 主题包（`theme.json`） | 重新构建 App（唯一 root 在 bundle 内，本期无用户目录安装） |
| hook 包（`Extensions/<id>/`） | 改完 `POST /api/extensions/host/restart`；清单改动后跑 `check_plugin.py` 对账 |

修改前 MUST NOT 做：**未定位就重写整包**（先按 1–3 步证伪；多数「不生效」是没重启或仍是 `extended` 档）·**顺手重构用户既有结构**（只动最小面，否则用户没法从 diff 看出真正修了什么）· **把 `doctor 通过` 当 `能激活`**（它只做静态判定：entry 存在且可读，不启子进程、不读 DB、不查语法）。

## 六、反模式

**这节什么时候用**：写下第一版方案后自检；或评审别人的包时逐条对照。

| 反模式 | 为什么会坏 | 正确做法 |
|---|---|---|
| 为小改上原生面板 | 编译链 + 主进程同权执行 + 编译失败只留占位，成本全落用户侧 | 能用 17 个节点表达就用 IR；Chart / 拖拽 / 动画才升 T3 |
| `trust: "data"` 却声明工具 | 代码能力被拒（warning），工具永远不出现 | 有代码就写 `sandboxed`（外部插件缺省档） |
| 两套 entry（`server.ui.entry` ≠ `server.tool.entry`） | `server.ui` 被静默撤下：工具好用、面板打不开 | 一个 `register(ctx)`、一份 entry，两条能力指向同一文件 |
| 声明与注册不一致（`views` / `tools` / 命令 id） | 声明了没注册 ⇒ `capabilityEntryMissing`；注册了没声明 ⇒ 永远挂不上 | 清单字符串与 `ctx.view/tool/command` 逐字对齐，改完跑 `check_plugin.py` |
| 渲染期写盘或出网 | `fs.write` / `net.fetch` 在渲染路径被直接拒（`permissionDenied`），且渲染 MUST 纯函数 | 读可放渲染首帧，写只放交互分支与工具里 |
| 在 IR 里写色值 / 像素 | `color` / `font` / `width` / `padding` 这些键名本身非法，整树 `irInvalid` | 颜色只走 `tone`（27 角色），字号走 `style` 档，尺寸交给 slot |
| 指望 `shortcut` 注册热键 | 客户端不注册任何热键，它只是提示文本；写错只丢这条提示 | 要入口就写 `client.command`（进 QuickBar 检索），别承诺键位 |
| 用 `${workspace}` 传 `ctx.host.fs` 实参 | 清单侧被 `expand_prefix` 展开、插件侧只 `expanduser` ⇒ 判越界 fail-closed | 两侧都用 `~` 前缀路径 |
| 把凭据塞进 `state` | `state` 只有 `workspaceName` / `conversationTitle` 白名单键，凭据拿不到也不该给 | 需要凭据就做成用户显式授权后由宿主代发，别写进面板上下文 |
| 把 hook 写进服务端源码（宿主内置路径） | 那是宿主内置实现的路径，你的包不在那里，改了也不算插件 | 写成 `Extensions/<id>/` 包，清单声明 `server.hook` |
| 声明了 `post_model` / `pre_tool` / `post_tool` / `idle` | 这四个事件本期没有派发点，注册成功但永不执行，只记 warning | 换 `pre_model` / `run_finished`，或确认需求后走能力提案 |

**交叉核对入口**：`references/manifest.md`（清单字段）、`plugin-api.md`（`register(ctx)` / `ctx.host.*`）、`view-ir.md`（17 节点 / tone / 预算）、
`native-panel.md`（SDK / 编译链 / 门禁）、`lifecycle.md`（装 / 启用 / 授权 / 重启）、`troubleshooting.md`（诊断码逐条）。
