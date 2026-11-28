//  SvgIconBadge.swift — `examples.svg-icon` 的 `sidebar.section` 视图面板（tasks 3.1）
//
//  侧栏分区里的内联小面板：宿主钳制高度（≤240pt），所以这里只画一行事实 —— 一句说明 +
//  一个 tint 语义标签。数据、视图两层与 `SvgIconMain.swift` 同一套口径，不重复解释。
//
//  `tint: original` 是本样例唯一「插件自带颜色」的入口，故这一行刻意把 tint 档显式标出来：
//  读的人要能一眼看出「这里有插件自己的颜色」。

import AppKit
import BotChatKit
import SwiftUI

// MARK: - 入口

struct SvgIconBadgeEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        MainActor.assumeIsolated { SvgIconBadgePanel(host: host) }
    }
}

@_cdecl("botchat_panel_entry")
public func svgIconBadgeEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(SvgIconBadgeEntry.self, hostRaw)
}

// MARK: - 实例

final class SvgIconBadgePanel: NSObject, PanelInstance {
    private let host: PanelHost
    private let hosting: NSHostingView<AnyView>

    init(host: PanelHost) {
        self.host = host
        self.hosting = NSHostingView(
            rootView: AnyView(
                SvgIconBadgeView(host: host, row: SvgIconBadgeModel(payload: PanelData([:])))
                    .panelKitRoot(host)
            )
        )
        super.init()
        host.log("SVG 图标面板（badge）已创建")
    }

    var rootView: NSView { hosting }

    func update(data: NSDictionary) {
        hosting.rootView = AnyView(
            SvgIconBadgeView(host: host, row: SvgIconBadgeModel(payload: PanelData(data)))
                .panelKitRoot(host)
        )
    }
}

// MARK: - 数据

struct SvgIconBadgeModel: Equatable {
    let text: String
    let tint: String

    init(payload: PanelData) {
        text = payload.string("text", SvgIconBadgeCopy.text)
        tint = payload.string("tint")
    }
}

private enum SvgIconBadgeCopy {
    static let text = "分区头图标保留 SVG 自带渐变（tint: original）"
    static let originalTint = "original"
    static let symbol = "paintpalette"
}

// MARK: - 视图

struct SvgIconBadgeView: View {
    let host: PanelHost
    let row: SvgIconBadgeModel

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: host.metric("spacing.s")) {
            Image(systemName: SvgIconBadgeCopy.symbol)
                .kitText(.meta, tone: .fgTertiary)
            // 侧栏窄：允许两行，且必须能压 —— 否则固有宽度会把分区顶宽。
            Text(row.text)
                .kitText(.caption, tone: .fgSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !row.tint.isEmpty {
                KitTag(
                    row.tint,
                    role: row.tint == SvgIconBadgeCopy.originalTint ? .info : .neutral,
                    glyph: .dot
                )
            }
        }
        .padding(host.metric("spacing.s"))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
