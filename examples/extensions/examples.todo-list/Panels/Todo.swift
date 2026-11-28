// Todo.swift — examples.todo-list 的原生面板（`render: "native"`）。
//
// **这个文件不编进 app**：随插件包分发，由宿主首次挂载时用 swiftc 编译成 bundle；
// 契约见 `docs/extension-panel-native.md`。
//
// 视觉只经 `BotChatKit`（`.kitText` / `.kitSurface` / `KitTag` / `KitButton` / `KitInput` /
// `KitNotice` / `KitEmptyState`），根上挂 `.panelKitRoot(host)` 注入宿主调色板 —— 面板是独立
// 编译的 bundle，读不到宿主 environment，漏挂只会静默退回系统色。MUST NOT 写字面色值 /
// 字号 / 像素。面板列头已显示「待办清单」，本页 MUST NOT 再放第二个大标题。
//
// 动作一律 `host.dispatch(nodeId, arguments)`（名字见 `TodoPanelCopy`）；面板不自己取数。
//
// 命中区：**一行待办整体就是勾选按钮**（状态图标 + 标题 + 右侧空白都在它的 label 里，再
// `contentShape(Rectangle())` 铺满），MUST NOT 把 `toggle` 只挂在状态图标上。`KitButton` 的
// label 是文案/图标内容（装不了任意视图铺满一行），故行级命中区保留系统 `Button` +
// `.buttonStyle(.plain)`；颜色仍只经注入的调色板。

import AppKit
import BotChatKit
import SwiftUI

// MARK: - 入口

struct TodoPanelEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        // Kit 组件与 `NSHostingView` 都是 `@MainActor`，宿主本来就在主线程取实例。
        MainActor.assumeIsolated { TodoPanelInstance(host: host) }
    }
}

/// 入口导出：宿主按符号 `botchat_panel_entry` 取它（按镜像解析）。
/// 一个面板源文件只能导出一次本符号。
@_cdecl("botchat_panel_entry")
public func todoPanelEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(TodoPanelEntry.self, hostRaw)
}

// MARK: - 实例

final class TodoPanelInstance: NSObject, PanelInstance {
    private let host: PanelHost
    /// 实例自己持有宿主视图：推数据只换 `rootView`，`NSView` 与 `@State`（草稿、焦点）都留着。
    private let hosting: NSHostingView<AnyView>

    init(host: PanelHost) {
        self.host = host
        self.hosting = NSHostingView(
            rootView: AnyView(
                TodoPanelView(host: host, model: TodoPanelModel(payload: PanelData([:])))
                    .panelKitRoot(host)
            )
        )
        super.init()
        host.log("待办清单原生面板已创建")
    }

    var rootView: NSView { hosting }

    func update(data: NSDictionary) {
        hosting.rootView = AnyView(
            TodoPanelView(host: host, model: TodoPanelModel(payload: PanelData(data)))
                .panelKitRoot(host)
        )
    }
}

// MARK: - 数据（纯函数解码；缺键 / 形状不对都要能读出来，不许崩）

struct TodoRow: Equatable {
    let id: String
    let title: String

    init(_ payload: PanelData) {
        id = payload.string("id")
        title = payload.string("title", TodoPanelCopy.untitled)
    }
}

struct TodoPanelModel: Equatable {
    let openRows: [TodoRow]
    let doneRows: [TodoRow]
    let openCount: Int
    let doneCount: Int
    /// 插件给的提示（读盘 / 保存失败）；空串 = 无提示。
    let notice: String
    let truncatedOpen: Int
    let truncatedDone: Int

    init(payload: PanelData) {
        let open = payload.rows("open").map(TodoRow.init)
        let done = payload.rows("done").map(TodoRow.init)
        openRows = open
        doneRows = done
        // 缺 `counts` 时退回行数：计数与清单不同源会让「N 未完成」与列表对不上。
        let counts = payload.object("counts")
        openCount = counts?.int("open") ?? open.count
        doneCount = counts?.int("done") ?? done.count
        notice = payload.string("notice")
        truncatedOpen = payload.int("truncatedOpen")
        truncatedDone = payload.int("truncatedDone")
    }
}

enum TodoPanelCopy {
    // 节点 id 与实参键：与 `plugin.py` 的 `nodeId` 判定 / `arguments` 读取逐字一致。
    static let refreshNode = "refresh"
    static let addNode = "add"
    static let clearDoneNode = "clearDone"
    static let addTitleKey = "title"
    static func toggleNode(_ id: String) -> String { "toggle:" + id }
    static func removeNode(_ id: String) -> String { "remove:" + id }

    // 文案
    static let openTitle = "未完成"
    static let doneTitle = "已完成"
    static let untitled = "（无标题）"

    static func toggleHelp(_ done: Bool) -> String { done ? "标记为未完成" : "标记为完成" }
    static func toggleAccessibility(_ title: String, done: Bool) -> String {
        done ? "标记「\(title)」为未完成" : "标记「\(title)」为完成"
    }
    static func removeAccessibility(_ title: String) -> String { "删除「\(title)」" }
}

// MARK: - 视图

struct TodoPanelView: View {
    let host: PanelHost
    let model: TodoPanelModel

    @State private var draft = ""
    @State private var hoveredID: String?
    @FocusState private var isComposerFocused: Bool

    @Environment(\.kitPalette) private var palette

    private var canSubmit: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolRow
            KitDivider(.hairline)
            if !model.notice.isEmpty {
                // 提示恒是「出事了」这一类（读盘 / 保存失败），故用 warning 档。
                KitNotice(model.notice, severity: .warning)
                    .padding(.horizontal, host.metric("spacing.m"))
                    .padding(.top, host.metric("spacing.s"))
            }
            composer
            KitDivider(.hairline)
            ScrollView { listContent }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // 整块底色与聊天主区同角色（`bg.canvas`）：面板贴在主区旁边，两者底色不一致会显出一条接缝。
        .background(palette.color(.bgCanvas))
    }

    // MARK: 工具行（列头已有标题，这里只放计数与刷新）

    private var toolRow: some View {
        HStack(spacing: host.metric("spacing.s")) {
            KitTag("\(model.openCount) \(TodoPanelCopy.openTitle)", role: .info, glyph: .symbol("circle.dashed"))
            KitTag("\(model.doneCount) \(TodoPanelCopy.doneTitle)", role: .success, glyph: .symbol("checkmark"))
            Spacer(minLength: 0)
            KitButton(icon: "arrow.clockwise", label: "重新读取待办文件", help: "重新读取文件") {
                // 面板不自己取数：重读盘是插件侧的事，这里只上报意图。
                host.dispatch(TodoPanelCopy.refreshNode, NSDictionary())
            }
            // 密集行内动作统一走 `.plain`（无底无框、hover 浮 `bg.selectionEmphasis`）：
            // 工具行里只有两枚 `KitTag`，描边档会读成「和主行动一个量级」。
            .kitButtonEmphasis(.plain)
            .kitButtonSize(.mini)
        }
        .padding(.horizontal, host.metric("spacing.m"))
        .padding(.vertical, host.metric("spacing.s"))
    }

    // MARK: 新增（焦点环由 `KitInput` 依焦点绑定自绘，不再手写描边换色）

    private var composer: some View {
        HStack(spacing: host.metric("spacing.s")) {
            KitInput(
                $draft,
                placeholder: "写一条待办…",
                accessibilityLabel: "新待办标题",
                focus: $isComposerFocused,
                onSubmit: submit
            )
            // 面板唯一的主行动：沿用原胶囊形态（`.kitButtonShape` 只作用于这一枚）。
            KitButton("添加", tone: .brand) { submit() }
                .kitButtonEmphasis(.prominent)
                .kitButtonShape(.capsule)
                .disabled(!canSubmit)
        }
        .padding(.horizontal, host.metric("spacing.m"))
        .padding(.vertical, host.metric("spacing.m"))
    }

    private func submit() {
        guard canSubmit else { return }
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        host.dispatch(
            TodoPanelCopy.addNode,
            NSDictionary(object: title, forKey: TodoPanelCopy.addTitleKey as NSString)
        )
        draft = ""
        isComposerFocused = true
    }

    // MARK: 列表

    private var listContent: some View {
        VStack(alignment: .leading, spacing: host.metric("spacing.s")) {
            openSection
            doneSection
        }
        .padding(.horizontal, host.metric("spacing.m"))
        .padding(.vertical, host.metric("spacing.m"))
    }

    @ViewBuilder
    private var openSection: some View {
        sectionHeader(TodoPanelCopy.openTitle, count: model.openCount, role: .info) { EmptyView() }
        if model.openRows.isEmpty {
            KitEmptyState(
                title: "没有未完成的待办",
                systemImage: "checklist",
                description: "在上面写一条，或让 Agent 调 todo_add"
            )
            .padding(.vertical, host.metric("spacing.m"))
        } else {
            ForEach(model.openRows.indices, id: \.self) { index in
                rowCard(model.openRows[index], done: false)
            }
            if model.truncatedOpen > 0 {
                Text("还有 \(model.truncatedOpen) 条未显示（先处理上面的）")
                    .kitText(.meta, tone: .statusMutedFg)
            }
        }
    }

    @ViewBuilder
    private var doneSection: some View {
        if !model.doneRows.isEmpty {
            sectionHeader(TodoPanelCopy.doneTitle, count: model.doneCount, role: .success) {
                KitButton("清除已完成", tone: .neutral, leadingIcon: "trash", help: "删除全部已完成的待办") {
                    host.dispatch(TodoPanelCopy.clearDoneNode, NSDictionary())
                }
                .kitButtonEmphasis(.plain)
                .kitButtonSize(.mini)
            }
            ForEach(model.doneRows.indices, id: \.self) { index in
                rowCard(model.doneRows[index], done: true)
            }
            if model.truncatedDone > 0 {
                Text("还有 \(model.truncatedDone) 条已完成未显示")
                    .kitText(.meta, tone: .statusMutedFg)
            }
        }
    }

    private func sectionHeader<Accessory: View>(
        _ title: String,
        count: Int,
        role: KitTagRole,
        @ViewBuilder trailing: () -> Accessory
    ) -> some View {
        HStack(spacing: host.metric("spacing.s")) {
            Text(title)
                .kitText(.meta, weight: .semibold, tone: .fgSecondary)
            KitTag(count, role: role)
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.top, host.metric("spacing.xs"))
    }

    /// 一行待办：勾选区是整条目本体，删除是行内独立按钮。
    private func rowCard(_ row: TodoRow, done: Bool) -> some View {
        HStack(spacing: host.metric("spacing.s")) {
            Button {
                host.dispatch(TodoPanelCopy.toggleNode(row.id), NSDictionary())
            } label: {
                HStack(spacing: host.metric("spacing.s")) {
                    stateDot(done: done)
                    Text(row.title)
                        .kitText(.caption, tone: done ? .fgTertiary : .fgPrimary)
                        .strikethrough(done, color: palette.color(.fgTertiary))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                // 标题右侧的空白也算这条待办：否则「点在文字右边一点」又变成没反应。
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(TodoPanelCopy.toggleHelp(done))
            .accessibilityLabel(TodoPanelCopy.toggleAccessibility(row.title, done: done))

            KitButton(
                icon: "xmark",
                label: TodoPanelCopy.removeAccessibility(row.title),
                help: "删除这条待办"
            ) {
                host.dispatch(TodoPanelCopy.removeNode(row.id), NSDictionary())
            }
            .kitButtonEmphasis(.plain)
            .kitButtonSize(.mini)
        }
        .padding(.horizontal, host.metric("spacing.m"))
        .padding(.vertical, host.metric("spacing.s"))
        // 悬停高亮：整行可点就必须有可点的反馈，否则用户仍然猜不到该点哪儿。
        .background(
            palette.color(hoveredID == row.id ? .bgSurfaceRaised : .bgSurface),
            in: RoundedRectangle(cornerRadius: palette.metric(.radius10), style: .continuous)
        )
        .kitStroke()
        .onHover { inside in
            if inside {
                hoveredID = row.id
            } else if hoveredID == row.id {
                hoveredID = nil
            }
        }
    }

    /// 完成态指示（纯展示：命中区在整行按钮上）；用 SF Symbol + Kit 字阶/角色，不手画圆圈。
    private func stateDot(done: Bool) -> some View {
        Image(systemName: done ? "checkmark.circle.fill" : "circle")
            .kitText(.body, tone: done ? .statusDoneFg : .fgTertiary)
    }
}
