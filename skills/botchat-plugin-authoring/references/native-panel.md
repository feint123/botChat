# 原生面板（`botchat.panel/1`，包内 Swift）

事实源：`docs/extension-panel-native.md`（SDK 面 / 载荷契约 / 编译链 / 信任口径）；
SDK 真身 `clientSide/botChat/botChat/Services/Extensions/Native/PanelKitSource.swift`；
门禁 `PanelSourceGate.swift`；编译 `PanelCompiler.swift` / `SwiftcRunner.swift`。

## 一、先问一句：真的需要吗

| 需求 | 用 IR | 用 native |
|---|---|---|
| 文字、列表、表单、按钮、进度 | ✓ | 过度设计 |
| Chart / 热力图 / 拖拽 / 动画 / 非标准布局 | 表达不了 | ✓ |

原生的代价：首次挂载 `swiftc` 编译（`-Onone` 约 0.83s）、代码在**宿主主进程内同权运行**
（不是沙箱，门禁只挡误用与主题腐烂）、编译失败时用户只看到占位。

## 二、三处声明必须同时成立

```json
{
  "trust": "sandboxed",
  "capabilities": {
    "server.ui": { "entry": "plugin.py", "views": ["hits"] },
    "client.view": [{ "slot": "panel", "view": "hits", "title": "命中", "render": "native" }],
    "client.panel": { "views": [{ "view": "hits", "entry": "Panels/Hits.swift", "apiVersion": 1 }] }
  }
}
```

1. `client.view[].render` MUST 是 `"native"`（缺省 `"ir"`；其它取值撤下该条，**不回落**）。
2. `client.panel.views[].view` MUST 与该条 `client.view` 的 `view` 同名，且在 `server.ui.views` 里 ——
   **没有「纯客户端面板」**，原生面板仍由服务端产数据。
3. `entry` MUST 是包内相对路径、`.swift`、不逃包根、单文件 ≤ 256 KB；`apiVersion` 只认 `1`
   （更高版本跳过该条，不猜着加载）。

`trust` 与原生面板无关：`trust` 管服务端 Python 在哪跑。

## 三、服务端视图函数回「数据」，不是树

```python
def render_main(payload: dict) -> dict:
    return {"title": "命中", "hits": 3}
```

`data` 约束（服务端强制，失败只降级该 slot）：顶层 MUST 是对象；≤256 KB；深度 ≤8；单数组 ≤2000 项；
键名 `[A-Za-z_][A-Za-z0-9_]*` 且 MUST NOT 以 `_` 开头（保留给宿主）；图片只允许裸 `assetId` 或
`/api/media/{id}`（外链 / `data:` / 本地路径一律拒）。

信封：`schema` 为 `botchat.panel/1` 时载荷键是 `data`；降级帧恒为 `botchat.ui/1` + 占位树 +
`degraded: true`（此时客户端跳过 schema 校验，只看 `diagnostics[0].code`）。

## 四、SDK：作者能用的全部 API

编译时宿主把下面这份源码与你的文件同批交给 `swiftc`（`MUST NOT` 自己再声明）：
（节选自 `PanelKitSource.swift`，`apiVersion` = 1）

```swift
protocol PanelHost: AnyObject {
    var apiVersion: Int { get }
    var extensionId: String { get }
    var viewId: String { get }
    var locale: String { get }
    func color(_ role: String) -> NSColor        // 46 角色之一，动态色
    func metric(_ key: String) -> CGFloat        // 语义尺寸档
    func dispatch(_ nodeId: String, _ arguments: NSDictionary)
    func media(_ assetId: String, _ completion: @escaping (NSImage?) -> Void)
    func log(_ message: String)
}

protocol PanelInstance: AnyObject { var rootView: NSView { get }; func update(data: NSDictionary) }
protocol PanelEntry { static func makeInstance(host: PanelHost) -> PanelInstance }   // 入口类型可为 struct / enum

extension PanelHost { func panelColor(_ role: String) -> Color }   // 取色捷径

// 入口装配助手：入口函数里只需把「自己的入口类型 + 宿主指针」交给它
func botchatPanelInstance<E: PanelEntry>(_ entry: E.Type, _ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?

struct PanelData {                     // 容错取值，缺字段给缺省
    init(_ raw: NSDictionary)
    func string(_ key: String, _ fallback: String = "") -> String
    func int(_ key: String, _ fallback: Int = 0) -> Int
    func double(_ key: String, _ fallback: Double = 0) -> Double
    func bool(_ key: String, _ fallback: Bool = false) -> Bool
    func rows(_ key: String) -> [PanelData]
    func object(_ key: String) -> PanelData?
}
```

**入口：一次 `@_cdecl` 导出，不挂固定类名**（一个面板源文件只能导出一次）：

```swift
struct MainPanelEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance { MainPanelInstance(host: host) }
}

/// 宿主按符号 `botchat_panel_entry` 取它（按镜像解析，不按类名查表）。
@_cdecl("botchat_panel_entry")
public func mainPanelEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(MainPanelEntry.self, hostRaw)
}
```

宿主只认这个 **C 符号**（`dlsym`），MUST NOT 给入口类型挂固定 ObjC 类名 —— `@objc(BotChatPanelEntry)`
这类写法已被门禁拒（`nativeSourceRejected`，文案「入口类名固定（已废弃写法）」）：类名是**进程级全局
命名空间**，ObjC runtime 对同名类只注册先到者，同进程第二个面板必然拿不到自己的类（入口直接返 nil）。
符号按镜像解析、类名完全由你自选，因此多面板共存与同一插件多版本共存都不撞。缺符号或入口返空 ⇒
`nativeEntryMissing`（不是白屏）；导出两次是链接期重复符号 ⇒ `nativeCompileFailed`。

## 五、五条纪律

1. **实例持有视图，宿主只推数据**：`update(data:)` 里只换 `hosting.rootView`，
   `MUST NOT` 重建 `NSView`／`NSHostingView` —— 实测同类型 `rootView` 赋值能保住 `@State`
   （滚动、焦点、输入框内容），重建会全丢。
2. `update` 幂等：同一份 data 连推两次结果一致。
3. 取色只经 `host.panelColor(role)`（或 `host.color(role)`）；返回动态色，`MUST NOT` 转成固定 RGB 缓存 ——
   否则主题切换后不跟随。
4. **面板不许自己取数**：数据一律来自 `data`，动作一律 `host.dispatch`。
5. 尺寸由宿主钳制（`composer.accessory` ≤44pt、`sidebar.section` ≤240pt、`panel` 随列宽）。

## 六、源码门禁（`PanelSourceGate.swift`，注释文本同样命中）

| 规则 | 取值 |
|---|---|
| 允许的 import | `SwiftUI` `AppKit` `Foundation` `Observation` `CoreGraphics` `AVKit` `AVFoundation` |
| 禁用符号（子串匹配，**注释里出现也算**） | `FileManager` `URLSession` `URLRequest` `Process(` `NSTask` `NSAppleScript` `NSWorkspace` `dlopen` `dlsym` `SecItem` `CGEvent` `AXUIElement` `NSWindow(` `NSPanel(` |
| 写死颜色 | `Color(red:` / `Color( red:` / `NSColor(calibrated` / `NSColor(srgb`；或同行含 `Color(`／`NSColor(`／`cgColor` 且出现六位十六进制 |
| 入口写法 | 入口挂固定 ObjC 类名（`@objc(固定名)`）⇒ 命中「入口类名固定（已废弃写法）」，改用 `@_cdecl("botchat_panel_entry")` |
| 体积 / 行数 | ≤256 KB / ≤4000 行 |

误报口径（实测）：`"#hashtag"`、`ticket 0x1F`、`Color(nsColor: host.color(...))` **都不命中**。

本 skill 的 `scripts/check_plugin.py` 内置同一份规则的预检（doctor 不检查 Swift），
所以「写面板 → 跑一次对账」能在装之前抓到这类错误。

## 七、编译链与缓存（客户端侧，作者只需知道结论）

```
包内 Panels/X.swift ──门禁──► swiftc（SDK 源 + 面板源同批）──► Panel.bundle ──► 实例
```

- 参数固定：`-emit-library -Xlinker -bundle -module-name P_<hash8> -swift-version 5 -Onone`。
  **模块名必带哈希**：同名 module 二次加载会让 ObjC runtime 撞类并静默跑旧实现。
- 缓存键 = 面板源码 + SDK 源 + 参数 + `swiftc --version`；落
  `~/Library/Application Support/botChat/PanelBuilds/<hash>/`，全局 200 MB LRU。
- 无工具链 ⇒ `nativeToolchainMissing` 占位 + 安装指引；同插件的 IR 视图照常工作。
- 编译失败 ⇒ 只留含 `error:` 的行（≤20 行 / ≤4000 字符），提供「让 Agent 修」回填。
- **包根只认服务端下发**：`GET /api/extensions/views` 的 `roots.user` / `roots.builtin` 是定位面板源码的
  唯一依据（`home_root()` 可被 `BOTCHAT_HOME` 改到任意位置）。手拼 `~/.botchat/Extensions` 拼错的后果
  是「服务端能列视图、客户端找不到源码」，只坏一个 slot（`nativeEntryMissing`）。

## 八、验证顺序（省时间）

1. `check_plugin.py <包>` —— 清单 + 包形态 + 源码门禁。
2. `validate_panel_data(render_xxx({...}))` —— 载荷形状（纯函数，不需要宿主）。
3. 装 + 启用 + 重启宿主，打开面板。
4. 点一下按钮：宿主生成幂等 `action_id` 串行发给服务端，插件回新 data，`update(data:)` 只换
   `rootView` —— 数字要变，且滚动/输入状态要留住。
