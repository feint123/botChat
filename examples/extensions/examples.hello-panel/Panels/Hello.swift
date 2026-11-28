// Hello.swift — 原生面板样例（change `add-native-extension-panels` 5.8）。
//
// 这个文件**不编进 app**：它随插件包分发，由客户端在首次挂载时用 swiftc 编译成 bundle，
// 再把入口类实例化出来。契约见 `docs/extension-panel-native.md`。
//
// 三件事刻意保留在样例里，因为它们是作者最容易写错的地方：
//   1. 入口 MUST 用 `@_cdecl("botchat_panel_entry")` 导出一次，MUST NOT 给入口类挂固定 ObjC 类名
//      （`@objc(固定名)` 已废弃：类名是进程级全局命名空间，同进程第二个面板会拿不到自己的类）；
//   2. 实例**持有** `NSHostingView`，`update(data:)` 只换 `rootView`（这样 @State 才留得住）；
//   3. 视觉只经 `BotChatKit`：字号 `.kitText`、分隔 `KitDivider`、标签 `KitTag`、按钮 `KitButton`，
//      根上挂 `.panelKitRoot(host)` 注入宿主调色板；MUST NOT 写字面色值 / 字号 / 像素。

import AppKit
import BotChatKit
import SwiftUI

// MARK: - 入口

struct HelloPanelEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        // Kit 组件与 `NSHostingView` 都是 `@MainActor`，而本方法默认 nonisolated；
        // 宿主本来就在主线程取实例，故这是把已知事实告诉编译器，不是挪线程。
        MainActor.assumeIsolated { HelloPanelInstance(host: host) }
    }
}

/// 入口导出：宿主按符号 `botchat_panel_entry` 取它（符号按镜像解析，不按类名查表）。
@_cdecl("botchat_panel_entry")
public func helloPanelEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(HelloPanelEntry.self, hostRaw)
}

// MARK: - 实例

final class HelloPanelInstance: NSObject, PanelInstance {
    private let host: PanelHost
    private let hosting: NSHostingView<AnyView>

    init(host: PanelHost) {
        self.host = host
        self.hosting = NSHostingView(
            rootView: AnyView(
                HelloView(host: host, row: HelloModel(payload: PanelData([:])))
                    .panelKitRoot(host)
            )
        )
        super.init()
        host.log("Hello 原生面板已创建")
    }

    var rootView: NSView { hosting }

    /// 幂等：解码是纯函数，同一份 data 连调两次结果一致。
    func update(data: NSDictionary) {
        hosting.rootView = AnyView(
            HelloView(host: host, row: HelloModel(payload: PanelData(data)))
                .panelKitRoot(host)
        )
    }
}

// MARK: - 数据

struct HelloModel: Equatable {
    let title: String
    let hits: Int

    init(payload: PanelData) {
        title = payload.string("title", HelloCopy.title)
        hits = payload.int("hits")
    }
}

private enum HelloCopy {
    static let title = "Hello 原生面板"
    static let note = "这段界面由插件里的 SwiftUI 源码编译而来；数据来自服务端子进程。"
    static let symbol = "square.stack.3d.up"
    static let hitsPrefix = "已点击"
    static let hitsSuffix = "次"
    static let pressTitle = "点我"
    static let pressSymbol = "hand.tap"
    /// 交互节点 id：与 `ui.py` 的 `payload.get("nodeId") == "press"` 判定逐字一致。
    static let pressNode = "press"
}

// MARK: - 视图

struct HelloView: View {
    let host: PanelHost
    let row: HelloModel

    var body: some View {
        VStack(alignment: .leading, spacing: host.metric("spacing.s")) {
            header
            Text(HelloCopy.note)
                .kitText(.caption, tone: .fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
            KitDivider(.hairline)
            actionRow
        }
        .padding(host.metric("spacing.m"))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: host.metric("spacing.s")) {
            Image(systemName: HelloCopy.symbol)
                .kitText(.title, tone: .fgSecondary)
            Text(row.title)
                .kitText(.sectionTitle, weight: .semibold)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    /// 计数用 `info` 语义（`status.running.*`，与按钮那条链路同源），动作用 `brand` 实底。
    private var actionRow: some View {
        HStack(spacing: host.metric("spacing.s")) {
            KitTag("\(HelloCopy.hitsPrefix) \(row.hits) \(HelloCopy.hitsSuffix)", role: .info, glyph: .dot)
            Spacer(minLength: 0)
            KitButton(HelloCopy.pressTitle, tone: .brand, leadingIcon: HelloCopy.pressSymbol) {
                // 上行交互：宿主生成幂等 action_id、串行发给服务端插件。
                host.dispatch(HelloCopy.pressNode, [:])
            }
            .kitButtonEmphasis(.prominent)
        }
    }
}
