//  SvgIconMain.swift — `examples.svg-icon` 的 `panel` 视图面板（change `make-plugin-ui-native-kit` tasks 3.1）
//
//  **这个文件不编进 app**：它随插件包分发，由宿主编译（源码形态）或直接加载（预编形态）成 bundle。
//  契约见 `docs/extension-panel-native.md`。
//
//  两件事刻意分开：
//  1. `SvgIconMainModel` 纯函数解码 `botchat.panel/1` 的 `data`（缺键给缺省，不崩）；
//  2. `SvgIconMainView` 只用 BotChatKit 组件与语义角色；间距走 `host.metric(...)`，
//     不写字面色值、字号或像素。
//
//  用了 Kit 组件就必须挂 `.panelKitRoot(host)`：面板是独立编译的 bundle，读不到宿主的
//  SwiftUI environment，调色板由宿主经 `PanelHost` 下发、再由该修饰器注入。

import AppKit
import BotChatKit
import SwiftUI

// MARK: - 入口

struct SvgIconMainEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        // Kit 组件与 NSHostingView 都是 @MainActor，宿主本就在主线程取实例。
        MainActor.assumeIsolated { SvgIconMainPanel(host: host) }
    }
}

@_cdecl("botchat_panel_entry")
public func svgIconMainEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(SvgIconMainEntry.self, hostRaw)
}

// MARK: - 实例

final class SvgIconMainPanel: NSObject, PanelInstance {
    private let host: PanelHost
    /// 实例持有宿主视图：推数据只换 `rootView`，`NSView` 与 `@State` 都留着。
    private let hosting: NSHostingView<AnyView>

    init(host: PanelHost) {
        self.host = host
        self.hosting = NSHostingView(
            rootView: AnyView(
                SvgIconMainView(host: host, row: SvgIconMainModel(payload: PanelData([:])))
                    .panelKitRoot(host)
            )
        )
        super.init()
        host.log("SVG 图标面板（main）已创建")
    }

    var rootView: NSView { hosting }

    /// 幂等：解码是纯函数，同一份 data 连调两次结果一致。
    func update(data: NSDictionary) {
        hosting.rootView = AnyView(
            SvgIconMainView(host: host, row: SvgIconMainModel(payload: PanelData(data)))
                .panelKitRoot(host)
        )
    }
}

// MARK: - 数据

struct SvgIconMainModel: Equatable {
    let title: String
    let summary: String
    let footnote: String
    let iconFile: String
    let tint: String

    init(payload: PanelData) {
        title = payload.string("title", SvgIconMainCopy.title)
        summary = payload.string("summary", SvgIconMainCopy.summary)
        footnote = payload.string("footnote", SvgIconMainCopy.footnote)
        // 图标事实在 `data.icon` 子对象里；缺一层就退回「未知」，不编造路径。
        let icon = payload.object("icon")
        iconFile = icon?.string("file", SvgIconMainCopy.unknownIcon) ?? SvgIconMainCopy.unknownIcon
        tint = icon?.string("tint") ?? ""
    }
}

private enum SvgIconMainCopy {
    static let title = "SVG 图标样例"
    static let summary = "列头这个图标来自包内 SVG，由宿主按面着色"
    static let footnote = "图标只出现在清单的 client.view.icon，不进面板载荷。"
    static let unknownIcon = "（data 里没给图标文件）"
    static let eyebrow = "client.view.icon"
    static let originalTint = "original"
    static let symbol = "photo"
    static let tintSymbol = "circle.lefthalf.filled"
}

// MARK: - 视图

struct SvgIconMainView: View {
    let host: PanelHost
    let row: SvgIconMainModel

    var body: some View {
        VStack(alignment: .leading, spacing: host.metric("spacing.s")) {
            header
            Text(row.summary)
                .kitText(.caption, tone: .fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
            KitDivider(.hairline)
            Text(row.footnote)
                .kitText(.caption, tone: .fgTertiary)
                .fixedSize(horizontal: false, vertical: true)
            iconPath
        }
        .padding(host.metric("spacing.m"))
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: host.metric("spacing.s")) {
            Image(systemName: SvgIconMainCopy.symbol)
                .kitText(.meta, tone: .fgSecondary)
            Text(row.title)
                .kitText(.sectionTitle, weight: .semibold)
                .lineLimit(1)
            Spacer(minLength: 0)
            if !row.tint.isEmpty {
                // 语义档从 tint 事实映射：`original` 保留插件自带色（深色主题下可能不可见），
                // `template` 由宿主按面着色，是安全的缺省。
                KitTag(
                    row.tint,
                    role: row.tint == SvgIconMainCopy.originalTint ? .info : .neutral,
                    glyph: .symbol(SvgIconMainCopy.tintSymbol)
                )
            }
        }
    }

    /// 图标文件路径：面板只展示「用了哪个包内文件」这一条事实，不自己读盘。
    private var iconPath: some View {
        HStack(spacing: host.metric("spacing.s")) {
            Text(SvgIconMainCopy.eyebrow)
                .kitText(.annotation, tone: .fgTertiary)
            Text(row.iconFile)
                .kitText(.mono, tone: .fgSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(host.metric("spacing.s"))
        .kitSurface(.inset)
    }
}
