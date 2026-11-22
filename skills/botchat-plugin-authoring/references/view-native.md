# 视图 IR（`botchat.ui/1`）—— **已下线**

> 状态：`botchat.ui/1`（预制节点 IR）已**全量下线**，本文件仅作考古索引，不再是可照做的契约。
> 判据以代码为准，见文末「现存事实」。

## 一、下线的事实

change `make-plugin-ui-native-kit`（提交 `feat(extensions)!: 插件 UI 收敛为原生面板 + BotChatKit，下线 botchat.ui/1`）之后：

- **插件 UI 只有一种渲染体**：编译版 SwiftUI 面板（`botchat.panel/1`）。没有第二套渲染体，
  也没有「零工具链也能看」的降级渲染面 —— 本机没有 Swift 工具链时，插件 UI 显示宿主导航占位
  （安装指引），MUST NOT 回落到任何旁路渲染。
- **随 IR 一并作废的资产**：17 个节点集（`Text` / `Heading` / `Markdown` / … / `Error`）、
  `tone` 白名单、`List` 绑定语法、节点预算、slot 节点白名单（`SLOT_ALLOWED_KINDS` /
  `SLOT_PROFILES`）。服务端 `ui_ir.py` 与客户端 IR 渲染/解码簇已删除。
- `client.view.render` 的封闭值集收缩为单值 `native`（缺省即 `native`）。写 `ir` 或任何未知值，
  该声明在**解码期被撤下**（MUST NOT 猜成某个取值）。

## 二、现存事实（要写视图就照这些）

| 项 | 事实 | 代码位置 |
|---|---|---|
| 唯一载荷 schema | `botchat.panel/1` | `ui_panel_payload.py:SCHEMA_PANEL`、客户端 `ExtensionPayloadSchema.swift` |
| 视图函数返回 | **数据对象**（JSON 对象），不是节点树 | 同上 |
| 载荷上限（所有 slot 一致） | ≤256 KB、深度 ≤8、单数组 ≤2,000 项 | `ui_panel_payload.py:MAX_BYTES/MAX_DEPTH/MAX_ITEMS` |
| 键名 | `[A-Za-z_][A-Za-z0-9_]*`，MUST NOT 以 `_` 开头 | `ui_panel_payload.py:_KEY_RE` |
| 图片引用 | 只允许裸 `assetId` 或 `/api/media/{id}` | `ui_panel_payload.py` |
| 界面代码 | 包内 `Panels/*.swift`，声明在 `client.panel.views[]` | `capability_panel.py` |
| 视觉 | MUST 用 `BotChatKit` 组件与角色，禁字面色值/字体/像素 | `docs/ui-kit.md` |
| 三向一致 | `render: native` ↔ `client.panel` 同名条目 ↔ `server.ui.views` | `capability_panel.reconcile_native_panels` |

## 三、界面怎么写

- IR 面板 → 见 `native-panel.md`（入口符号、实例持有视图、取色、尺寸契约、编译链）。
- 插件 API（`register(ctx)`、`ctx.host.*`）→ 见 `plugin-api.md`。
- 清单字段 → 见 `manifest.md`。

## 四、考古

- IR 时代的完整契约原文随 change `add-extension-ui-slots` 归档，不在本仓现行文档内。
- 资产清单（哪些文件、多少行被删）见服务端仓 `docs/analysis/ir-retirement-inventory.md`。
