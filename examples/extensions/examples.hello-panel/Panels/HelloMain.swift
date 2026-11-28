//  HelloMain.swift — `examples.hello-panel` 的 `panel` 视图面板（tasks 3.2）
//
//  **这个文件不编进 app**：它随插件包分发，由宿主编译（源码形态）或直接加载（预编形态）成 bundle。
//  契约见 `docs/extension-panel-native.md`。
//
//  这一份样例的重点是**交互闭环**：点按钮 → `host.dispatch` → 服务端调 `ui.py` 的同一个 view
//  → 回一份新 `data` → 宿主 `update(data:)` 重画。所以界面上的计数不是本地状态，
//  它就是「动作真的跑到了插件」的活体探针。
//
//  Kit 没有开关组件（`KitTag` / `KitButton` / `KitNotice` 都是展示与动作位），故「详细模式」
//  用系统 `Toggle`，着色仍只经 `host.panelColor("brand.base")` —— 面板 MUST NOT 写字面色值。

import AppKit
import BotChatKit
import SwiftUI

// MARK: - 入口

struct HelloMainEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        MainActor.assumeIsolated { HelloMainPanel(host: host) }
    }
}

@_cdecl("botchat_panel_entry")
public func helloMainEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(HelloMainEntry.self, hostRaw)
}

// MARK: - 实例

final class HelloMainPanel: NSObject, PanelInstance {
    private let host: PanelHost
    private let hosting: NSHostingView<AnyView>

    init(host: PanelHost) {
        self.host = host
        self.hosting = NSHostingView(
            rootView: AnyView(
                HelloMainView(host: host, row: HelloMainModel(payload: PanelData([:])))
                    .panelKitRoot(host)
            )
        )
        super.init()
        host.log("Hello 面板（main）已创建")
    }

    var rootView: NSView { hosting }

    func update(data: NSDictionary) {
        hosting.rootView = AnyView(
            HelloMainView(host: host, row: HelloMainModel(payload: PanelData(data)))
                .panelKitRoot(host)
        )
    }
}

// MARK: - 数据

struct HelloMainModel: Equatable {
    let title: String
    let instance: String
    let hits: Int
    let verbose: Bool

    init(payload: PanelData) {
        title = payload.string("title", HelloMainCopy.title)
        instance = payload.string("instance", HelloMainCopy.unknownInstance)
        hits = payload.int("hits")
        verbose = payload.bool("verbose")
    }
}

private enum HelloMainCopy {
    static let title = "Hello 面板"
    static let unknownInstance = "（未提供实例键）"
    static let instancePrefix = "实例："
    static let hitsPrefix = "已点击"
    static let hitsSuffix = "次"
    static let verboseOn = "开关：开"
    static let verboseOff = "开关：关"
    static let symbol = "hand.wave"
    static let pressTitle = "点我"
    static let pressSymbol = "hand.tap"
    static let verboseTitle = "详细模式"
    /// 交互节点 id：与 `ui.py` 的 `payload.get("nodeId")` 判定逐字一致。
    static let pressNode = "press"
    static let verboseNode = "verbose"
    /// 开关值的实参键（`ui.py` 的 `_flag` 同时认 `values` 与 `arguments`）。
    static let verboseKey = "verbose"
}

// MARK: - 视图

struct HelloMainView: View {
    let host: PanelHost
    let row: HelloMainModel

    var body: some View {
        VStack(alignment: .leading, spacing: host.metric("spacing.s")) {
            header
            Text(HelloMainCopy.instancePrefix + row.instance)
                .kitText(.caption, tone: .fgSecondary)
                .lineLimit(1)
            KitDivider(.hairline)
            actionRow
            verboseToggle
        }
        .padding(host.metric("spacing.m"))
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: host.metric("spacing.s")) {
            Image(systemName: HelloMainCopy.symbol)
                .kitText(.title, tone: .fgSecondary)
            Text(row.title)
                .kitText(.sectionTitle, weight: .semibold)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    /// 计数 + 动作：计数用 `info` 语义（进行中/运行中的那档色），动作用 `brand` 实底。
    private var actionRow: some View {
        HStack(spacing: host.metric("spacing.s")) {
            KitTag(statusText, role: .info, glyph: .dot)
            Spacer(minLength: 0)
            KitButton(
                HelloMainCopy.pressTitle,
                tone: .brand,
                leadingIcon: HelloMainCopy.pressSymbol
            ) {
                // 数据回来之前不做本地自增：谎报的计数会让「链路通了没」重新变成猜测。
                host.dispatch(HelloMainCopy.pressNode, [:])
            }
            .kitButtonEmphasis(.prominent)
        }
    }

    /// 「已点击 N 次 · 开关：开/关」——与 IR 版那一行文案同源，只换成标签形态。
    private var statusText: String {
        let toggle = row.verbose ? HelloMainCopy.verboseOn : HelloMainCopy.verboseOff
        return "\(HelloMainCopy.hitsPrefix) \(row.hits) \(HelloMainCopy.hitsSuffix) · \(toggle)"
    }

    /// 开关：`set` 里把新值送给插件，界面等宿主推回的新 `data`（唯一事实源是服务端）。
    private var verboseToggle: some View {
        Toggle(
            isOn: Binding(
                get: { row.verbose },
                set: { host.dispatch(HelloMainCopy.verboseNode, [HelloMainCopy.verboseKey: $0]) }
            )
        ) {
            Text(HelloMainCopy.verboseTitle)
                .kitText(.caption, tone: .fgPrimary)
        }
        .toggleStyle(.switch)
        .tint(host.panelColor("brand.base"))
    }
}
