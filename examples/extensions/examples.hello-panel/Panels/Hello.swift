// Hello.swift — 原生面板样例（change `add-native-extension-panels` 5.8）。
//
// 这个文件**不编进 app**：它随插件包分发，由客户端在首次挂载时用 swiftc 编译成 bundle，
// 再把入口类实例化出来。契约见 `docs/extension-panel-native.md`。
//
// 三件事刻意保留在样例里，因为它们是作者最容易写错的地方：
//   1. 入口 MUST 用 `@_cdecl("botchat_panel_entry")` 导出一次，MUST NOT 给入口类挂固定 ObjC 类名
//      （`@objc(固定名)` 已废弃：类名是进程级全局命名空间，同进程第二个面板会拿不到自己的类）；
//   2. 实例**持有** `NSHostingView`，`update(data:)` 只换 `rootView`（这样 @State 才留得住）；
//   3. 取色只经 `host.color(角色名)`，不写字面色。

import AppKit
import SwiftUI

struct HelloPanelEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        HelloPanelInstance(host: host)
    }
}

/// 入口导出：宿主按符号 `botchat_panel_entry` 取它（符号按镜像解析，不按类名查表）。
@_cdecl("botchat_panel_entry")
public func helloPanelEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(HelloPanelEntry.self, hostRaw)
}

final class HelloPanelInstance: NSObject, PanelInstance {
    private let host: PanelHost
    private let hosting: NSHostingView<AnyView>

    init(host: PanelHost) {
        self.host = host
        self.hosting = NSHostingView(rootView: AnyView(HelloView(host: host, data: PanelData([:]))))
        super.init()
        host.log("Hello 原生面板已创建")
    }

    var rootView: NSView { hosting }

    func update(data: NSDictionary) {
        hosting.rootView = AnyView(HelloView(host: host, data: PanelData(data)))
    }
}

struct HelloView: View {
    let host: PanelHost
    let data: PanelData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.string("title", "Hello 原生面板"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(host.panelColor("fg.primary"))
            Text("这段界面由插件里的 SwiftUI 源码编译而来；数据来自服务端子进程。")
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
                    // 上行交互：宿主生成幂等 action_id、串行发给服务端插件。
                    host.dispatch("press", [:])
                }
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
