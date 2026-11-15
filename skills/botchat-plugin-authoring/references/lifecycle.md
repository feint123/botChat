# 生命周期：装、启用、授权、重启、停用、删除

实现：`serverSide/app/extensions/`（`package_install.py` / `package_staging.py` / `package_remove.py` /
`assembly.py` / `activation.py`）、路由 `app/routers/extensions*.py`。契约见
`docs/extension-plugin-contract.md` §七/§八/§九。

## 一、磁盘落点（只有两个 root）

| root | 路径 | 扫描 |
|---|---|---|
| 内置 | `serverRoot()/Extensions`（打包后 = `botChat.app/Contents/Resources/Extensions`），可被 `BOTCHAT_EXTENSIONS_ROOT` 覆盖 | 恒扫；不存在 = 零内置插件（正常形态） |
| 用户 | `home_root()/Extensions`，实际运行 app 时 = `~/Library/Application Support/botChat/server/Extensions`（`BOTCHAT_HOME` 可改） | 由 `EXTENSIONS_USER_ROOT_ENABLED`（缺省开）决定；关掉时**连一次 scandir 都不做**，安装端点回 409 |

扫描器跳过点开头的目录（所以回收站 `.trash` 不会出现在列表里）。

## 二、安装

```
POST /api/extensions/install
{ "source_path": "/abs/path/to/<id>" }      # 只收本机目录，~/ 可展开，MUST NOT 传 URL
```

流程：**判定（零写入）→ staging 落位 → 登记为「未启用、空授权」**。

- 目录名 MUST 等于清单 `id`；符号链接 / 可执行位 / 禁用后缀 / 逃出包根都会被拒。
- 规模上限：文件数 2000、总字节 32 MiB（先算后拷，超限 400 并给出实际规模）。
- 用户 root 关闭 ⇒ 409；同 id 冲突、staging 失败等按 `InstallRejection.status_code` 返回。
- 装完 `enabled` **恒为 false**：装 ≠ 启用。

也可以直接把包目录拷进 `<home_root>/Extensions/<id>`（目录名 = id），重启宿主后在设置里启用。

## 三、启用 / 停用

```
POST /api/extensions/{extension_id}/enable
{ "enabled": true, "version": "0.1.0", "requested_permissions": {...} }
```

- `enabled: true` MUST 来自人的动作，MUST NOT 由扫描自动触发。
- `version` 缺省沿用已登记版本；变了就按版本策略**收敛授权**（升版本新增权限不自动授予）。
- 停用**不清空已有授权**，只把该插件的工具从工具表摘除（能力目录条目保留）。
- 响应带 `pending_keys`（请求了但未授权的键）与 `converged_keys`（被裁掉的键）。

## 四、授权

```
POST /api/extensions/{extension_id}/permissions
{ "permissions": { "fs.read": ["~/.botchat/todos"] } }
```

出现过的键**整体替换**，没出现的键保持原样；给空数组即撤销。清单没请求过的键会被拒并记
`permissionDenied`（不是静默丢弃）。实际授权落 `extension_state.permissions_json`。

## 五、改代码后怎么让它生效

| 场景 | 做法 |
|---|---|
| 只改插件包内容（`.py` / `.swift` / `manifest.json`） | `POST /api/extensions/host/restart` —— 停宿主 → **重扫磁盘** → 按库内 `enabled` 重新激活并同步工具与能力目录。黑名单不清 |
| 改了服务端 `serverSide/` 源码 | 重启服务进程；**app 形态下必须重新构建 App 再启动**（运行的是 bundle 里的 server 拷贝，只重启进程不会带新代码） |
| 插件被拉黑（连续 2 次崩溃） | `POST /api/extensions/{id}/unblock`（幂等；未拉黑回 `removed=false`），再启用/重启 |
| 改了清单的 slot / 视图声明 | 重扫 + 客户端重新拉 `GET /api/extensions/views` |

**本期无热重载**：宿主仍持旧模块，别指望改文件就变。

## 六、删除

`DELETE /api/extensions/{extension_id}` —— 包目录被**移动**进 `<user root>/.trash/<id>-<时间戳>`，
不直接销毁；回收站不自动清理（等到人处置）。登记行转为 `orphaned=true`，授权原值保留。

## 七、进程态与已知边界（会直接影响你判断「为什么没生效」）

- 插件工具表是**进程态**：多 worker / 多副本时只有持有装配层的进程有插件工具。
- **`activationEvents` 不驱动激活**：装配层在启动 / 启用 / `host/restart` 时按库内 `enabled` 直接
  激活（`assembly._activate_enabled`）；按事件懒激活的 `dispatch_event` / `activate_and_register`
  已实现但当前无调用方。排查「为什么没生效」时先看启用态与宿主重启，不要看激活事件。
- 插件工具缺省 `extended`（`PluginToolSpec.tier`），只经 `tool_search` 被发现；清单目前没有
  声明 `core` 的入口（`tool_bridge.build_spec` 不传 `tier`）。
- 停用只做到「不可调用」：宿主仍持有模块，改包仍需重启宿主。
- 插件 UI 五个挂载点**均已接线**：`panel`（面板列）/ `window`（独立 `NSPanel`，经 QuickBar 命令打开）/ `composer.accessory`（输入条）/ `sidebar.section`（侧栏分区）/ `settings.section`（设置页）。
  客户端唯一取数入口是 `ExtensionSlotCatalog`（宿主只读投影，MUST NOT 自扫清单）。
- 插件 UI 的跨块选取 / 时间线内联卡片未实现（受 Markdown 语区不变量约束）。
- `server.masking.rules` / `server.provider` / `ctx.host.llm.invoke` / `keychain` / `tools` /
  `clipboard` 均为「登记未实现」或「预留」。
- **`server.hook` 已接线**：启用时注册到 HookManager（按 `priority` 升序），停用时逐项 `unregister` 且不清空事件，注册路径不激活子进程（首次派发时才 `activate`）。
- 插件互依赖、市场、远程安装、`.bcext` 打包都不做：只支持本地目录。

## 八、诊断面（排查时先看这几个）

| 端点 | 用途 |
|---|---|
| `GET /api/extensions` | 列表：`registered` / `enabled` / `available_version` / `pending_keys` / 诊断 |
| `GET /api/extensions/views` | 已启用插件的槽位与命令投影，含 `roots.user` / `roots.builtin`（原生面板定位唯一依据） |
| `GET /api/extensions/views/{ext}/{view}` | 取视图快照（渲染一帧） |
| `POST /api/extensions/actions` | 交互（客户端用；插件侧只关心返回载荷形状） |
| `POST /api/extensions/commands/{command_id}` | 执行插件命令 |
| `POST /api/extensions/host/restart` | 整宿主重启 |
| `POST /api/extensions/{id}/unblock` | 解除拉黑 |

命令行离线对账（不需要 DB / 不起 HTTP）：`app.extensions.doctor`，见 SKILL 第 3 步。
