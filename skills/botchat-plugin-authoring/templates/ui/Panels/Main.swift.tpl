// {{name}} — 面板视图（botchat.panel/1）。
//
// 这个文件**不编进 app**：它随插件包分发，客户端首次挂载时把 SDK 源与本文件同批交给 swiftc
// 编成 bundle，再按需加载出实例。契约见 docs/extension-panel-native.md。
//
// 四件事最容易写错，刻意保留在模板里：
//   1. 入口 MUST 用 `@_cdecl("botchat_panel_entry")` 导出**一次**，MUST NOT 给入口挂固定 ObjC 类名
//      （类名是进程级全局命名空间，同进程第二个面板拿不到自己的类）。
//   2. `PanelInstance` 的实现类 MUST 是 `NSObject` 子类（它是 @objc 协议，要 ObjC 兼容）。
//   3. 实例**持有** NSHostingView，`update(data:)` 只换 rootView —— 重建会让 @State 全丢
//      （滚动、焦点、输入都会回到初始值）。
//   4. 取色只经 `host.panelColor(角色名)`，不写字面色，也不自己缓存 NSColor（它是动态色）。
//
// 面板 MUST NOT 自己取数（门禁挡掉出网 / 文件 / 子进程 / 图形事件 / 自建窗口等 API）：
// 数据一律来自 data，动作一律经 host.dispatch，宿主负责生成幂等 action_id 并串行发给服务端。
// 注意：门禁对**注释里的禁用词**同样命中 —— 这份模板因此不列出具体符号名。

import AppKit
import SwiftUI

struct MainPanelEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        MainPanelInstance(host: host)
    }
}

/// 入口导出：宿主按符号 `botchat_panel_entry` 取它（按镜像解析，不按类名查表）。
@_cdecl("botchat_panel_entry")
public func mainPanelEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(MainPanelEntry.self, hostRaw)
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
        host.log("{{name}} 面板已创建")
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
