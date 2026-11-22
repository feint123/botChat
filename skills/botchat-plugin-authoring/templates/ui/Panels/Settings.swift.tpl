// {{name}} — 设置区视图（botchat.panel/1）。
//
// 与 Panels/Main.swift 是**两个独立的镜像**：各自编译成一个 bundle、各自导出一次
// `@_cdecl("botchat_panel_entry")`。宿主按镜像解析符号，所以两者可以导出同名 C 符号；
// 但同一份源文件内 MUST 只导出一次，入口类型名也各自独立。
//
// 设置区嵌在插件详情页里，尺寸由宿主钳制，MUST 写得比主面板明显更小：
// 一行说明 + 少量控件，不铺大布局。

import AppKit
import SwiftUI

struct SettingsPanelEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        SettingsPanelInstance(host: host)
    }
}

@_cdecl("botchat_panel_entry")
public func settingsPanelEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(SettingsPanelEntry.self, hostRaw)
}

final class SettingsPanelInstance: NSObject, PanelInstance {
    private let host: PanelHost
    private let hosting: NSHostingView<AnyView>

    init(host: PanelHost) {
        self.host = host
        self.hosting = NSHostingView(
            rootView: AnyView(SettingsPanelView(host: host, data: PanelData([:])))
        )
        super.init()
    }

    var rootView: NSView { hosting }

    func update(data: NSDictionary) {
        hosting.rootView = AnyView(SettingsPanelView(host: host, data: PanelData(data)))
    }
}

struct SettingsPanelView: View {
    let host: PanelHost
    let data: PanelData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.string("note", "插件设置"))
                .font(.system(size: 11))
                .foregroundStyle(host.panelColor("fg.secondary"))
            Text(data.string("endpoint", "—"))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(host.panelColor("fg.tertiary"))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
