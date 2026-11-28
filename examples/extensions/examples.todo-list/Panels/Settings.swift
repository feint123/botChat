//  Settings.swift — `examples.todo-list` 的设置区原生面板（change `make-plugin-ui-native-kit` 3.3）
//
//  **这个文件不编进 app**：它随插件包分发，由宿主按清单 `client.panel` 的 `entry` 现编成
//  bundle 后加载。契约见 `docs/extension-panel-native.md`。
//
//  ## 为什么不和 `Panels/Todo.swift` 合成一个文件
//
//  宿主编译一个面板时只喂两份源（SDK 文本 + **该面板的入口文件**），且 `botchat_panel_entry`
//  一个源文件只能导出一次 —— 合并会在同一编译单元里撞符号，也让「改设置页」变成「重编主面板」。
//
//  ## 数据面（与 `plugin.py` 的 `settings_data` 一一对应）
//
//  `title` / `dataPath` / `counts{open,done}` / `notice` / `permissionHint`。所有读数走
//  `PanelData` 的容错取值：设置页是随手点开的地方，缺一个键就崩比空一屏糟糕得多。
//  文案（按钮标题、标签前缀）留在本文件 —— 服务端只给事实。
//
//  ## 唯一动作
//
//  `refresh`：面板自己不取数（门禁禁用一切网络与文件 API），重读盘只能靠
//  `host.dispatch("refresh", [:])`，插件侧 `view_settings` 认这个 `nodeId`。
//
//  ## 视觉口径
//
//  只经 `BotChatKit`：字号 `.kitText`、分隔 `KitDivider`、标签 `KitTag`、提示 `KitNotice`、
//  按钮 `KitButton`，根上挂 `.panelKitRoot(host)` 把宿主调色板注入进来。MUST NOT 写字面色值 /
//  字号 / 像素，也 MUST NOT 自建 palette —— 面板是独立编译的 bundle，读不到宿主的 environment。

import AppKit
import BotChatKit
import SwiftUI

// MARK: - 入口

struct TodoSettingsEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        MainActor.assumeIsolated { TodoSettingsPanel(host: host) }
    }
}

/// 入口导出：宿主按符号 `botchat_panel_entry` 取它（按镜像解析，不按类名查表）。
/// 一个面板源文件只能导出一次本符号。
@_cdecl("botchat_panel_entry")
public func todoSettingsPanelEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(TodoSettingsEntry.self, hostRaw)
}

// MARK: - 实例

final class TodoSettingsPanel: NSObject, PanelInstance {
    private let host: PanelHost
    /// 实例自己持有宿主视图：推数据只换 `rootView`，`NSView` 不重建。
    private let hosting: NSHostingView<AnyView>

    init(host: PanelHost) {
        self.host = host
        self.hosting = NSHostingView(
            rootView: AnyView(
                TodoSettingsView(host: host, model: TodoSettingsModel(payload: PanelData([:])))
                    .panelKitRoot(host)
            )
        )
        super.init()
        host.log("待办清单设置面板已创建")
    }

    var rootView: NSView { hosting }

    /// 幂等：解码是纯函数，同一份 data 连调两次结果一致。
    func update(data: NSDictionary) {
        hosting.rootView = AnyView(
            TodoSettingsView(host: host, model: TodoSettingsModel(payload: PanelData(data)))
                .panelKitRoot(host)
        )
    }
}

// MARK: - 数据

struct TodoSettingsModel: Equatable {
    let title: String
    let dataPath: String
    let openCount: Int
    let doneCount: Int
    /// 插件给的提示（保存失败等）；空串 = 无提示。
    let notice: String
    /// 权限事实（未授权时会怎样）；空串 = 插件没提供。
    let permissionHint: String

    init(payload: PanelData) {
        let rawTitle = payload.string("title")
        title = rawTitle.isEmpty ? TodoSettingsCopy.fallbackTitle : rawTitle
        let rawPath = payload.string("dataPath")
        dataPath = rawPath.isEmpty ? TodoSettingsCopy.unknownPath : rawPath
        // `counts` 缺席时按 0 显示而不是隐藏整块：设置页的数字是「现在的状态」，
        // 少一个键就整块消失会让用户以为插件没数据。
        let counts = payload.object("counts")
        openCount = counts?.int("open") ?? 0
        doneCount = counts?.int("done") ?? 0
        notice = payload.string("notice")
        permissionHint = payload.string("permissionHint")
    }
}

enum TodoSettingsCopy {
    static let fallbackTitle = "待办清单"
    static let headerSymbol = "gearshape.2"
    static let dataFileLabel = "数据文件"
    static let unknownPath = "（插件未提供数据文件路径）"
    static let openPrefix = "未完成"
    static let donePrefix = "已完成"
    static let refreshTitle = "重新读取文件"
    static let refreshSymbol = "arrow.clockwise"
    static let refreshHelp = "丢掉内存缓存，重新读一次数据文件"
}

// MARK: - 视图（只用 Kit 组件与语义档）

struct TodoSettingsView: View {
    let host: PanelHost
    let model: TodoSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: host.metric("spacing.s")) {
            header
            KitDivider(.hairline)
            dataFileRow
            if !model.notice.isEmpty {
                // 提示恒是「出事了」这一类（保存失败 / 读盘失败），故用 warning 档。
                KitNotice(model.notice, severity: .warning)
            }
            if !model.permissionHint.isEmpty {
                Text(model.permissionHint)
                    .kitText(.caption, tone: .statusMutedFg)
                    .fixedSize(horizontal: false, vertical: true)
            }
            refreshButton
        }
        .padding(host.metric("spacing.m"))
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: 头部（标题 + 两个计数）

    private var header: some View {
        HStack(spacing: host.metric("spacing.s")) {
            Image(systemName: TodoSettingsCopy.headerSymbol)
                .kitText(.meta, tone: .fgSecondary)
            Text(model.title)
                .kitText(.title, weight: .semibold)
                .lineLimit(1)
            Spacer(minLength: 0)
            // 能带图标就必须带（Kit 标签纪律）：圆点/勾与本插件「未完成 / 已完成」的含义同构。
            KitTag(
                "\(TodoSettingsCopy.openPrefix) \(model.openCount)",
                role: .info,
                glyph: .symbol("circle.dashed")
            )
            KitTag(
                "\(TodoSettingsCopy.donePrefix) \(model.doneCount)",
                role: .success,
                glyph: .symbol("checkmark")
            )
        }
    }

    // MARK: 数据文件（路径是最长的可变宽元素，必须可压缩）

    private var dataFileRow: some View {
        VStack(alignment: .leading, spacing: host.metric("spacing.xs")) {
            Text(TodoSettingsCopy.dataFileLabel)
                .kitText(.label, tone: .fgSecondary)
            Text(model.dataPath)
                .kitText(.mono, tone: .fgPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: 动作

    private var refreshButton: some View {
        KitButton(
            TodoSettingsCopy.refreshTitle,
            tone: .neutral,
            leadingIcon: TodoSettingsCopy.refreshSymbol,
            help: TodoSettingsCopy.refreshHelp
        ) {
            // 面板不自己取数：重读盘是插件侧的事，这里只上报意图。
            host.dispatch("refresh", [:])
        }
        .kitButtonEmphasis(.tinted)
        .kitButtonSize(.small)
    }
}
