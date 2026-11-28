//  HelloSettings.swift — `examples.hello-panel` 的 `settings.section` 视图面板（tasks 3.2）
//
//  设置区内嵌的最小形态：一句说明 + 一个开关。行高受限、左对齐贴齐设置页的其它分区，
//  所以这里不画标题行，也不铺满宽度。
//
//  Kit 没有开关组件，故用系统 `Toggle`；着色只经 `host.panelColor("brand.base")`，
//  MUST NOT 写字面色值（面板拿不到宿主主题的其它通道）。

import AppKit
import BotChatKit
import SwiftUI

// MARK: - 入口

struct HelloSettingsEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        MainActor.assumeIsolated { HelloSettingsPanel(host: host) }
    }
}

@_cdecl("botchat_panel_entry")
public func helloSettingsEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(HelloSettingsEntry.self, hostRaw)
}

// MARK: - 实例

final class HelloSettingsPanel: NSObject, PanelInstance {
    private let host: PanelHost
    private let hosting: NSHostingView<AnyView>

    init(host: PanelHost) {
        self.host = host
        self.hosting = NSHostingView(
            rootView: AnyView(
                HelloSettingsView(host: host, row: HelloSettingsModel(payload: PanelData([:])))
                    .panelKitRoot(host)
            )
        )
        super.init()
        host.log("Hello 面板（settings）已创建")
    }

    var rootView: NSView { hosting }

    func update(data: NSDictionary) {
        hosting.rootView = AnyView(
            HelloSettingsView(host: host, row: HelloSettingsModel(payload: PanelData(data)))
                .panelKitRoot(host)
        )
    }
}

// MARK: - 数据

struct HelloSettingsModel: Equatable {
    let text: String
    let verbose: Bool

    init(payload: PanelData) {
        text = payload.string("text", HelloSettingsCopy.text)
        verbose = payload.bool("verbose")
    }
}

private enum HelloSettingsCopy {
    static let text = "这是插件自己的设置区"
    static let verboseTitle = "详细模式"
    /// 交互节点 id 与实参键：与 `ui.py` 的判定 / `_flag` 读取逐字一致。
    static let verboseNode = "verbose"
    static let verboseKey = "verbose"
}

// MARK: - 视图

struct HelloSettingsView: View {
    let host: PanelHost
    let row: HelloSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: host.metric("spacing.s")) {
            Text(row.text)
                .kitText(.caption, tone: .fgSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle(
                isOn: Binding(
                    get: { row.verbose },
                    set: {
                        host.dispatch(
                            HelloSettingsCopy.verboseNode, [HelloSettingsCopy.verboseKey: $0]
                        )
                    }
                )
            ) {
                Text(HelloSettingsCopy.verboseTitle)
                    .kitText(.caption, tone: .fgPrimary)
            }
            .toggleStyle(.switch)
            .tint(host.panelColor("brand.base"))
        }
        .padding(host.metric("spacing.s"))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
