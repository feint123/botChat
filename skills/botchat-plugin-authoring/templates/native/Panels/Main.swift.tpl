// {{name}} — 原生面板（botchat.panel/1）。
//
// 这个文件**不编进 app**：它随插件包分发，客户端首次挂载时把 SDK 源与本文件同批交给 swiftc
// 编成 bundle，再按需加载出实例。契约见 docs/extension-panel-native.md。
//
// 三件事最容易写错，刻意保留在模板里：
//   1. 入口类名必须逐字 `@objc(BotChatPanelEntry)`，否则宿主报 nativeEntryMissing；
//   2. 实例**持有** NSHostingView，update(data:) 只换 rootView —— 每次重建会让 @State 全丢；
//   3. 取色只经 host.panelColor(角色名)，不写字面色，也不自己缓存 NSColor。
//
// 面板 MUST NOT 自己取数（门禁挡掉出网/文件/子进程的 API）：数据一律来自 data，
// 动作一律经 host.dispatch，宿主负责生成幂等 action_id 并串行发给服务端。

import AppKit
import SwiftUI

@objc(BotChatPanelEntry)
final class MainPanelEntry: NSObject, PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        MainPanelInstance(host: host)
    }
}

final class MainPanelInstance: NSObject, PanelInstance {
    private let host: PanelHost
    private let hosting: NSHostingView<AnyView>

    init(host: PanelHost) {
        self.host = host
        self.hosting = NSHostingView(
            rootView: AnyView(MainPanelView(host: host, data: PanelData([:])))
        )
        super.init()
        host.log("{{name}} 原生面板已创建")
    }

    var rootView: NSView { hosting }

    func update(data: NSDictionary) {
        hosting.rootView = AnyView(MainPanelView(host: host, data: PanelData(data)))
    }
}

struct MainPanelView: View {
    let host: PanelHost
    let data: PanelData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.string("title", "{{name}}"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(host.panelColor("fg.primary"))
            Text(data.string("hint", "数据由服务端插件产出，界面在宿主内编译运行。"))
                .font(.system(size: 10))
                .foregroundStyle(host.panelColor("fg.secondary"))
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack(spacing: 8) {
                Text("已点击 \(data.int("hits")) 次")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(host.panelColor("status.running.fg"))
                Spacer(minLength: 0)
                Button("点我") {
                    host.dispatch("press", [:])
                }
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
