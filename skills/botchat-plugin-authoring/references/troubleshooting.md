# 排障：诊断码怎么修 + 真实踩坑清单

## 一、三步定位法（别跳步）

1. `python3 scripts/check_plugin.py <包目录>` —— 清单 / 包形态 / 原生面板门禁（离线，零副作用）。
2. 本地跑载荷校验（纯函数，不需要宿主）：
   - IR：`app.extensions.ui_ir.validate(tree)`
   - 原生：`app.extensions.ui_panel_payload.validate_panel_data(data)`
   片段见 `view-ir.md` §七。
3. 装好之后看 `GET /api/extensions`（该行的诊断列表）与 `GET /api/extensions/views`。
   客户端侧问题在设置页的插件详情里有诊断行。

`doctor` 通过只代表「静态可加载」：entry 文件存在且可读。**它不证明子进程能起来**，
报告里也这么写。

## 二、诊断码 → 该改哪一行

### 清单协议（多半不拒整包，只降级该项）

| 码 | 含义 | 改哪里 |
|---|---|---|
| `invalidJSON` | 清单不是合法 JSON / 结构类型错 | 逐字修 `manifest.json`；注意 `capabilities` 的值必须是对象 |
| `unknownSchemaVersion` | `schemaVersion` 不是 1/2 | 写 `2` |
| `minAppVersionTooHigh` | 要求高于当前 app | 降 `minAppVersion`（预发布后缀比同号正式版旧） |
| `missingPrefix` | capability 键没有 `client.` / `server.` 前缀 | 改键名 |
| `unknownCapabilityKind` | 拼错的 kind | 对照 `manifest.md` §二 |
| `unimplementedCapabilityKind` | `server.masking.rules` / `server.provider` | 删掉，本期不生效 |
| `unknownKey` | 下级键不认识（如 `server.tool.timeout_ms`） | 删掉该键；`server.tool` 只认 `entry` + `tools` |
| `trustMismatch` | `trust: data` 却声明代码能力 / `builtin.` 声明 `in-process` | 改 `trust` 为 `sandboxed` |

### 包形态（这些是硬伤，插件会直接不出现）

| 码 | 含义 | 改哪里 |
|---|---|---|
| `packageDirNameMismatch` | 目录名 ≠ 清单 `id` | 改目录名（或改 id），两者逐字一致 |
| `entryFileMissing` / `entryOutsidePackage` | entry 指向的文件不存在 / 逃出包根 | 用包内相对路径（`tools.py`、`Panels/Main.swift`），不许 `../` 或绝对路径 |
| `packageEntrySuffix` | `server.*` 不是 `.py` / `client.theme` 不是 `.json` / `client.panel` 不是 `.swift` | 改后缀 |
| `packageSymlink` / `packageExecutableBit` | 包内有符号链接 / 文件带可执行位 | 去掉（`chmod -x`，别用 `ln -s`） |
| `packageForbiddenFile` | 有 `.sh/.command/.dylib/.so/.node/.jar/.app` 等 | 删掉；插件不能自带可执行二进制 |
| `packageNotRegularFile` / `packageNotDirectory` / `packageUnreadable` | 非常规文件 / 权限问题 | 修权限，别放管道、设备文件 |
| `manifestMissing` | 缺 `manifest.json` | 补 |
| `extensionIdConflict` | 同 id 在两个 root 都存在 | 内置 root 优先；改用户包的 id |
| `userRootDisabled` | 用户 root 被关（`EXTENSIONS_USER_ROOT_ENABLED=false`） | 打开设置里的「扫描用户目录」 |
| `userRootInsideServerRoot` / `rootUnavailable` | 路径配置非法 | 检查 `BOTCHAT_HOME` / `BOTCHAT_EXTENSIONS_ROOT` |

### 宿主 / 调用期

| 码 | 含义 | 改哪里 |
|---|---|---|
| `pluginCrashed` | `register(ctx)` 或 handler 抛异常 | 看宿主日志；扫描期不执行代码，所以语法错只在这里暴露 |
| `pluginActivationTimeout` | 激活超 10s | 别在 `register` 里做重活（读大盘、起网络） |
| `pluginBlacklisted` | 连续 2 次崩溃被拉黑 | 修好后 `POST /api/extensions/{id}/unblock` 再启用 |
| `hostUnavailable` | 宿主不可达 / 调了未实现的 `llm.invoke` | 重启宿主；`llm.invoke` 本期就是会失败 |
| `capabilityEntryMissing` | 声明了 view/工具但没注册，或 `client.view` 的 view 不在 `server.ui.views` | 让「清单 ↔ `register(ctx)`」逐字对上 |
| `toolNameConflict` | 对外名撞车（插件内重名或与其他插件同 id 前缀） | 改工具名 |
| `permissionDenied` | 未授权 / 渲染期写盘 / 路径越界 / 清单没请求的键 | 补 `permissions` + 授权端点；把写操作移出渲染路径 |
| `irInvalid` | 树非法（禁用键、未知 kind、坏取值、tone 越界） | 用 `ui_ir.validate` 拿到 `code + path`，按 `view-ir.md` 改 |
| `irBudgetExceeded` | 超 2000 节点 / 512 KB / 深度 64 | 分页（`List` 限条数）或裁剪 |
| `viewNotDeclared` | 该 view 没有任何已启用插件声明 | 检查 `client.view` 与启用态 |
| `actionRejected` | 视图与实例不匹配、节点非法 | 交互只回整棵树；`nodeId` 用声明过的那个 |
| `extensionDisabled` | 渲染时插件已停用 | 回占位树是预期行为；重新启用 + 重启宿主 |

### Hook 事件专属诊断

| 码 | 含义 | 改哪里 |
|---|---|---|
| `hookEventWithoutDispatch` | 声明了已知事件（`post_model` / `pre_tool` / `post_tool` / `idle`）但本期无派发点，该事件不会执行 | 无需改清单；等派发点实现后自动生效 |
| `unknownKey` | 事件名不是已知的六个取值之一（拼错 / 新事件） | 检查拼写，取值为 `{pre_model, post_model, pre_tool, post_tool, idle, run_finished}` |
| `hookAbortInvalidEvent` | `onError: abort` 未声明在 `pre_model` 上 | 移到 `pre_model` 事件，其他事件会自动降级为 `continue` |

### 原生面板（客户端侧，doctor 看不到）

| 码 | 含义 | 改哪里 |
|---|---|---|
| `nativeSourceRejected` | 源码门禁命中 | 按 `native-panel.md` §六 逐条改；**注释里出现禁用词也算**；入口挂固定类名也归这里（文案「入口类名固定（已废弃写法）」） |
| `nativeEntryMissing` | 找不到入口（没导出 `@_cdecl("botchat_panel_entry")` / 导出两次 / entry 指向的文件不在包里 / 客户端用了自己拼的根路径） | 改入口导出与 `client.panel.entry`；包根只认服务端下发的 `roots` |
| `nativeToolchainMissing` | 本机没有 `swiftc` | 装 Xcode Command Line Tools；同插件 IR 视图仍可用 |
| `nativeCompileFailed` | 编译失败（只回含 `error:` 的行） | 看那几行；常见是没有 `import SwiftUI`／用了 `@State` 却每次重建视图 |
| `nativeLoadFailed` | bundle 加载失败 | 多半是模块名/类名冲突：入口 MUST 是 `@_cdecl("botchat_panel_entry")` 导出一次、入口类型不得挂固定 ObjC 类名 |
| `nativeConsentDeclined` | 用户没同意编译运行该面板 | 是人的选择，不是 bug |

## 三、真实踩坑（每条都对应一次实际问题）

1. **注释里出现禁用词也会被门禁拒**。`// 再 dlopen 出实例` 直接命中 `dlopen`。写面板时连注释也绕开
   那些符号名。
2. **`${workspace}` 只在清单侧展开**。插件代码里 `ctx.host.fs.write("${workspace}/x")` 必被判越界
   （不是绝对路径）。两侧都用 `~` 才是能对齐的形态。
3. **`server.ui.entry` 与 `server.tool.entry` 不同文件 ⇒ `server.ui` 被静默撤下**（只有一条 error
   诊断）。现象是「工具好用、面板打不开」。
4. **`server.tool` 的额外键被忽略**。想加 `timeout_ms` 之类不会生效（`unknownKey`），工具预算固定 30s。
5. **改完包不重启宿主等于没改**。走 `POST /api/extensions/host/restart`（停 → 重扫 → 按库内 enabled 重激活）。
6. **写了工具但主 Agent 直接看不见**：插件工具缺省 `extended`，要先 `tool_search`；停用插件会立刻把它
   从工具表摘掉。
7. **点了按钮界面不变**：交互分支回了和上次逐字相同的树。本通道没有 patch，回一样的树 = 什么都不发生。
   给返回值带一个会变的东西（计数、时间戳、状态）当活体探针。
8. **声明了挂载点却看不到**：五个槽位都已接线，所以先查三处——`client.view.view` 不在
   `server.ui.views`（解码期 `capabilityEntryMissing` 剔除）、`slot` 拼错（跳过该条不拒包）、插件未启用
   （`GET /api/extensions/views` 只回已启用插件的槽位）。
9. **渲染期写盘被拒**（`permissionDenied`）：读盘可以放渲染首帧，写只能放动作与工具。
10. **`home_root()` 不是 `~/.botchat`**：运行 app 时是 `~/Library/Application Support/botChat/server`
    （受 `BOTCHAT_HOME` 影响）。手拼路径的后果是「服务端能列、客户端找不到源码」，只坏一个 slot。
11. **包目录名以点开头会被跳过**（扫描器把点开头当隐藏/回收站），`acme.demo` 这种点**必须**在中间。
12. **连续崩溃 2 次即拉黑**：改完不发 `unblock`，怎么重装都不激活。
13. **doctor 通过 ≠ 能激活**：它只做静态判定（entry 存在且可读），不启子进程、不读 DB。

## 四、拿不准的时候

- 契约正文：`docs/extension-plugin-contract.md`（清单 / 接口 / 诊断码 / 未实现清单）。
- 三个官方样例（可直接跑）：`serverSide/examples/extensions/`
  （`examples.hello-tool` 纯工具、`examples.hello-panel` IR + 窗口 + 原生面板并排、`examples.todo-list` 持久化 + 工具 + 原生面板）。
- 行为真相：`serverSide/tests/extensions/**`。读测试比读文档快，且测试锁的就是当前行为。
