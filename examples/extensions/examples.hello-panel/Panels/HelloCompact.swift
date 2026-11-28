//  HelloCompact.swift — `examples.hello-panel` 的 `window` 视图面板（tasks 3.2）
//
//  独立窗口里的紧凑形态：标题 + 计数 + 一句说明 + 一个动作。窗口实例与面板实例各自独立
//  （宿主按 slot 各建一份实例），所以这里的计数与 `main` 不共享。
//
//  数据、视图两层与 `HelloMain.swift` 同一套口径；差别只有信息密度（窗口可以顶对齐铺满）。

import AppKit
import BotChatKit
import SwiftUI

// MARK: - 入口

struct HelloCompactEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        MainActor.assumeIsolated { HelloCompactPanel(host: host) }
    }
}

@_cdecl("botchat_panel_entry")
public func helloCompactEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(HelloCompactEntry.self, hostRaw)
}

// MARK: - 实例

final class HelloCompactPanel: NSObject, PanelInstance {
    private let host: PanelHost
    private let hosting: NSHostingView<AnyView>

    init(host: PanelHost) {
        self.host = host
        self.hosting = NSHostingView(
            rootView: AnyView(
                HelloCompactView(host: host, row: HelloCompactModel(payload: PanelData([:])))
                    .panelKitRoot(host)
            )
        )
        super.init()
        host.log("Hello 面板（compact）已创建")
    }

    var rootView: NSView { hosting }

    func update(data: NSDictionary) {
        hosting.rootView = AnyView(
            HelloCompactView(host: host, row: HelloCompactModel(payload: PanelData(data)))
                .panelKitRoot(host)
        )
    }
}

// MARK: - 数据

struct HelloCompactModel: Equatable {
    let title: String
    let note: String
    let hits: Int

    init(payload: PanelData) {
        title = payload.string("title", HelloCompactCopy.title)
        note = payload.string("note", HelloCompactCopy.note)
        hits = payload.int("hits")
    }
}

private enum HelloCompactCopy {
    static let title = "Hello 窗口"
    static let note = "窗口实例独立于面板实例"
    static let symbol = "macwindow.on.rectangle"
    static let pressTitle = "点我"
    static let pressSymbol = "hand.tap"
    /// 交互节点 id：与 `ui.py` 的 `payload.get("nodeId")` 判定逐字一致。
    static let pressNode = "press"
}

// MARK: - 视图

struct HelloCompactView: View {
    let host: PanelHost
    let row: HelloCompactModel

    var body: some View {
        VStack(alignment: .leading, spacing: host.metric("spacing.m")) {
            header
            Text(row.note)
                .kitText(.annotation, tone: .fgTertiary)
                .fixedSize(horizontal: false, vertical: true)
            KitButton(
                HelloCompactCopy.pressTitle,
                tone: .brand,
                leadingIcon: HelloCompactCopy.pressSymbol
            ) {
                host.dispatch(HelloCompactCopy.pressNode, [:])
            }
            .kitButtonEmphasis(.tinted)
            .kitButtonSize(.small)
            Spacer(minLength: 0)
        }
        .padding(host.metric("spacing.l"))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: host.metric("spacing.s")) {
            Image(systemName: HelloCompactCopy.symbol)
                .kitText(.title, tone: .fgSecondary)
            Text(row.title)
                .kitText(.title, weight: .semibold)
                .lineLimit(1)
            Spacer(minLength: 0)
            // 计数是「动作真的跑到了插件」的证据：窗口这一面也把它摆出来。
            KitTag(row.hits, role: .info)
        }
    }
}
