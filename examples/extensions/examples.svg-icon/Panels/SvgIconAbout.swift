//  SvgIconAbout.swift — `examples.svg-icon` 的 `settings.section` 视图面板（tasks 3.1）
//
//  设置区里的一小段说明：非方 `viewBox` 的图标按等比缩放放进方形框并居中留白。
//  这里把「viewBox 是多少」当成数据展示（标签），后面跟一个等宽的图标文件行 ——
//  面板自己不做缩放、也不读 SVG 文件，像素一律由宿主注入的图标视图负责。

import AppKit
import BotChatKit
import SwiftUI

// MARK: - 入口

struct SvgIconAboutEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        MainActor.assumeIsolated { SvgIconAboutPanel(host: host) }
    }
}

@_cdecl("botchat_panel_entry")
public func svgIconAboutEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(SvgIconAboutEntry.self, hostRaw)
}

// MARK: - 实例

final class SvgIconAboutPanel: NSObject, PanelInstance {
    private let host: PanelHost
    private let hosting: NSHostingView<AnyView>

    init(host: PanelHost) {
        self.host = host
        self.hosting = NSHostingView(
            rootView: AnyView(
                SvgIconAboutView(host: host, row: SvgIconAboutModel(payload: PanelData([:])))
                    .panelKitRoot(host)
            )
        )
        super.init()
        host.log("SVG 图标面板（about）已创建")
    }

    var rootView: NSView { hosting }

    func update(data: NSDictionary) {
        hosting.rootView = AnyView(
            SvgIconAboutView(host: host, row: SvgIconAboutModel(payload: PanelData(data)))
                .panelKitRoot(host)
        )
    }
}

// MARK: - 数据

struct SvgIconAboutModel: Equatable {
    let text: String
    let iconFile: String
    /// `viewBox` 的宽高；缺字段时为 0，视图据此不画那条标签（不编造比例）。
    let viewBoxWidth: Int
    let viewBoxHeight: Int

    init(payload: PanelData) {
        text = payload.string("text", SvgIconAboutCopy.text)
        iconFile = payload.object("icon")?.string("file", SvgIconAboutCopy.unknownIcon)
            ?? SvgIconAboutCopy.unknownIcon
        let box = payload.object("viewBox")
        viewBoxWidth = box?.int("width") ?? 0
        viewBoxHeight = box?.int("height") ?? 0
    }

    /// 「48×20」这种形态；宽高任一缺失就不显示。
    var viewBoxLabel: String? {
        guard viewBoxWidth > 0, viewBoxHeight > 0 else { return nil }
        return "\(viewBoxWidth)×\(viewBoxHeight)"
    }
}

private enum SvgIconAboutCopy {
    static let text = "设置区图标是非方 viewBox，按 1:1 等比缩放进方形框并居中留白。"
    static let unknownIcon = "（data 里没给图标文件）"
    static let viewBoxSymbol = "aspectratio"
}

// MARK: - 视图

struct SvgIconAboutView: View {
    let host: PanelHost
    let row: SvgIconAboutModel

    var body: some View {
        VStack(alignment: .leading, spacing: host.metric("spacing.s")) {
            Text(row.text)
                .kitText(.caption, tone: .fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: host.metric("spacing.s")) {
                if let viewBox = row.viewBoxLabel {
                    KitTag(viewBox, role: .neutral, glyph: .symbol(SvgIconAboutCopy.viewBoxSymbol))
                }
                Text(row.iconFile)
                    .kitText(.monoSmall, tone: .fgTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
        }
        .padding(host.metric("spacing.s"))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
