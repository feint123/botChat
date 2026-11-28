# 运行轨迹（`examples.run-trace`）

一个**纯读面板**样例：把当前会话最近若干轮的「轮 → 子代理 → 工具」三层轨迹画成账本
（纵向按层级，每行一条按时长归一的微条），状态用三色区分进行中 / 成功 / 失败。

本插件**没有工具、没有 hook、没有文件与网络权限**。它只做一件事：把宿主的轨迹读口投影成
面板能画的数据。

## 文件

| 文件 | 职责 |
|---|---|
| `manifest.json` | 唯一声明面：`server.ui`（产数据的 view）+ `client.view`（`panel` 槽位）+ `client.panel`（面板源码） |
| `ui.py` | `register(ctx)` 唯一入口 + 轨迹投影（除读口之外零逻辑，纯函数） |
| `Panels/RunTrace.swift` | 原生面板：会话总览轨 + 三层账本 + 折叠摘要行 + 顶部刷新按钮 |

## 取数口径：只有时长与状态，没有正文

数据全部来自宿主读口 `ctx.host.trace.turns(limit=20)`（`ext.host.trace` 是第六个 host
命名空间，只读）。面板**不自己取数**：门禁挡 `URLSession` / `FileManager` / `Process` /
`NSWorkspace`，面板代码里也拿不到宿主 store。

因此本面板能回答「哪一轮慢、哪个子代理最耗、哪次工具调用失败了」，**不能**回答：

- 消息正文（聊天流里照常完整落库，回看请走聊天区）；
- 工具参数原文（只给服务端成型的短标签 `label`，≤80 字符，且已过 `MaskingProvider`）；
- diff 内容、文件内容、模型名、token 用量。

这是刻意的裁剪，也是本插件唯一的能力边界：**过程审计，不给正文**。

## 刷新语义：打开一次 + 手动

- 打开面板 = 一次渲染（`ctx.view` handler 跑一次），得到的是**当时**的快照；进行中的工具标
  `进行中`，`endedAt` 缺席。
- 轮内**不自动更新**：没有定时器、没有 SSE 订阅、不做轮内推送。想看在跑的最新状态，点面板
  顶部的刷新按钮 —— 它经 `host.dispatch` 让服务端重渲染、推一个新的 `rev`，面板**原位更新**
  （不重建视图、不丢滚动位置与展开态）。

## 分页与「还有 N 项未显示」是什么意思

`botchat.panel/1` 的硬顶是 256 KB，**撞上限是整帧被拒、面板整张空白**，比「少显示几轮」
坏得多。故载荷分三级如实裁剪，被裁掉的条数一律回传并在面板上明说：

| data 键 | 含义 | 用户看到什么 |
|---|---|---|
| `hasMore` | 会话里还有更早的轮次（一页只有 20 轮） | `更早的轮次不在本页` |
| `hiddenRuns` | 因字节预算没装下的轮数 | `还有 N 轮未显示（超出载荷预算）` |
| `truncatedTools` | 某轮工具太多、超单轮显示上限未显示的条数 | `还有 N 项工具未显示` |
| `hiddenSubagents` | 某轮子代理太多、超单轮显示上限未显示的条数 | `还有 N 个子代理未显示` |

MUST NOT 把「少了」显示成「就这些」：这四个键就是面板说真话的地方。

## 依赖的宿主版本

本插件依赖 `ext.host.trace.turns` 与清单权限 `permissions.conversation: ["read"]`。宿主不
支持时的表现（都是**可读占位**，不是空白面板）：

| 情形 | 面板显示 |
|---|---|
| 宿主没有 `ext.host.trace` 命名空间（版本过旧） | `宿主版本不支持轨迹读口…` |
| 清单没声明 `permissions.conversation`（或元素被丢弃成空集） | `本插件没有会话读权限…` |
| 宿主不认该方法（`METHOD_NOT_FOUND`） | `宿主不认轨迹读口方法（宿主版本过旧）…` |
| 宿主当前不可用 / 传输已关闭 | `宿主当前不可用…` |
| 载荷形状不可读（缺 `turns`） | `宿主返回的轨迹形状不可读…` |

按码判定，不按异常类名：跨进程之后类身份不传递（`host_faults` 的硬约束）。

## data 契约（`botchat.panel/1`）

共享键：`available` / `reason` / `title` / `limit` / `turnCount` / `hiddenRuns` / `hasMore` /
`truncatedTools` / `hiddenSubagents` / `summary` / `notice`；**取到数据时**多一个 `runs[]`。

两条必须与面板侧逐字对齐的口径：

1. **取不到数据 ⇒ `runs` 键缺席**（不是空数组、也不是 `null`）：空数组的语义是「这个会话
   真的没跑过」，与「拿不到数据」是两件事。面板靠「`runs` 缺席 + `available=false`」区分，
   前者显示原因、后者显示「还没有跑过一轮」。
2. **进行中的条目 `endedAt` 缺席**：MUST NOT 用当前时刻冒充结束；`durationMs` 同理，缺了
   就缺席，不补 `0`（`0` 是「瞬间完成」这个假事实）。面板据此把条画到「本轮结束」而不是
   0 宽，并按 spec 保留最窄 2pt 的可点击命中区。

## 视觉纪律

只用 `BotChatKit`：字号走 `kitText`，容器走 `.kitSurface(.inset)` / `.kitSurface(.raised)`，
状态色只从 `ThemeColor` 既有角色取（经 `host.panelColor(...)`：`status.running.*` /
`status.done.*` / `status.failed.*` / `status.muted.*`）。不写字面色值、不写字号与像素、
不自建 palette、根上挂 `panelKitRoot(host)`。
