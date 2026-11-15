// Todo.swift — examples.todo-list 的原生面板（`render: "native"`）。
//
// 这个文件**不编进 app**：它随插件包分发，由客户端首次挂载时用 swiftc 编译成 bundle，
// 再把入口类实例化出来。契约见 `docs/extension-panel-native.md`。
//
// ## 视觉口径：与宿主「应用整体风格」对齐，但不引用宿主组件
//
// 面板能拿到的只有三样东西：46 个主题角色色（`host.color`）、7 个语义尺寸档
// （`host.metric`）、以及服务端给的 data。因此「一致」不是共享代码，而是逐项复刻
// 应用内既定几何（`ThemeFont` / `ThemeMetrics` / `InlineCapsuleLabel` 的口径）：
//
//   · 字号 11 / 12 / 13 / 14，控制字重 semibold；正文用 13。
//   · 卡片 `bg.surface` + `radius.m`(10) + 单层 `border.muted` 描边（MUST NOT 双层）。
//   · 胶囊主行动：`brand.base` 实心底 + 白字 + 高 28 + 水平内边距 12（应用唯一主行动形态）。
//   · 面板列头已显示「待办清单」，本页 MUST NOT 再放第二个大标题（双层头部是已知观感问题）。
//
// ## 交互口径
//
// 动作一律 `host.dispatch(nodeId, arguments)`：勾选 `toggle:<id>`、删除 `remove:<id>`、
// 新增 `add`（标题放 `arguments["title"]`）、清除 `clearDone`、重读 `refresh`。
// 面板不自己取数：数据只来自 `data`，写盘只发生在服务端插件里。
//
// 命中区口径：**一行待办整体就是勾选按钮**（圆点与标题都在它的 label 里，再
// `contentShape(Rectangle())` 铺满），MUST NOT 把 `toggle` 只挂在 16pt 圆点上 ——
// 那会让「点这一条」（用户实际会点的地方）变成死区；`contentShape` 也 MUST NOT 挂在
// 没有手势的容器上充数（它只定义容器自身的命中形状，没手势就什么也不做）。

import AppKit
import SwiftUI

struct TodoPanelEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        TodoPanelInstance(host: host)
    }
}

/// 入口导出：宿主按符号 `botchat_panel_entry` 取它（符号按镜像解析）。
///
/// MUST NOT 给入口类挂固定的 ObjC 类名（`@objc(固定名)` 注解已废弃）—— 类名是进程级全局命名空间，
/// 只认先注册者，同进程第二个原生面板会拿不到自己的类（入口直接返 nil）。
/// 一个面板源文件只能导出一次本符号。
@_cdecl("botchat_panel_entry")
public func todoPanelEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(TodoPanelEntry.self, hostRaw)
}

final class TodoPanelInstance: NSObject, PanelInstance {
    private let host: PanelHost
    private let hosting: NSHostingView<AnyView>

    init(host: PanelHost) {
        self.host = host
        self.hosting = NSHostingView(rootView: AnyView(TodoPanelView(host: host, data: PanelData([:]))))
        super.init()
        host.log("待办清单原生面板已创建")
    }

    var rootView: NSView { hosting }

    func update(data: NSDictionary) {
        // 只换 rootView：同类型替换会保留 @State（草稿文字、焦点），重建 NSView 会全丢。
        hosting.rootView = AnyView(TodoPanelView(host: host, data: PanelData(data)))
    }
}

struct TodoPanelView: View {
    let host: PanelHost
    let data: PanelData

    @State private var draft = ""
    @State private var hoveredID: String?
    @FocusState private var isComposerFocused: Bool

    // MARK: - 读数

    private var openRows: [PanelData] { data.rows("open") }
    private var doneRows: [PanelData] { data.rows("done") }
    private var openCount: Int { data.object("counts")?.int("open") ?? openRows.count }
    private var doneCount: Int { data.object("counts")?.int("done") ?? doneRows.count }
    private var notice: String { data.string("notice") }
    private var canSubmit: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: - 主题取用（绘制时解析，不缓存）

    private func tone(_ role: String) -> Color { host.panelColor(role) }
    private var radiusCard: CGFloat { host.metric("radius.m") }
    private var radiusField: CGFloat { host.metric("radius.s") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolRow
            Divider().overlay(tone("border.muted"))
            if !notice.isEmpty {
                noticeRow
            }
            composer
            Divider().overlay(tone("border.muted"))
            ScrollView {
                VStack(alignment: .leading, spacing: host.metric("spacing.s")) {
                    openSection
                    doneSection
                }
                .padding(.horizontal, 12)
                .padding(.vertical, host.metric("spacing.m"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tone("bg.surfaceSunken"))
    }

    // MARK: - 工具行（列头已有标题，这里只放计数与刷新）

    private var toolRow: some View {
        HStack(spacing: host.metric("spacing.s")) {
            Text("\(openCount) 未完成 · \(doneCount) 已完成")
                .font(.system(size: 11))
                .foregroundStyle(tone("fg.secondary"))
            Spacer(minLength: 0)
            Button {
                host.dispatch("refresh", NSDictionary())
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tone("fg.tertiary"))
                    // 图标字号的命中区只有 10pt：显式给到 20pt 并撑满形状，MUST NOT 靠字号
                    // 碰运气（与行内勾选区同一口径）。
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("重新读取文件")
            .accessibilityLabel("重新读取待办文件")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var noticeRow: some View {
        HStack(spacing: host.metric("spacing.xs")) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9, weight: .semibold))
            Text(notice)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(tone("status.warning.fg"))
        .padding(.horizontal, host.metric("spacing.m"))
        .padding(.vertical, host.metric("spacing.xs"))
        .background(tone("status.warning.subtle"), in: RoundedRectangle(cornerRadius: radiusField))
        .padding(.horizontal, 12)
        .padding(.top, host.metric("spacing.s"))
    }

    // MARK: - 新增

    private var composer: some View {
        HStack(spacing: host.metric("spacing.s")) {
            TextField("写一条待办…", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(tone("fg.primary"))
                .focused($isComposerFocused)
                .onSubmit(submit)
                .padding(.horizontal, host.metric("spacing.m"))
                .padding(.vertical, host.metric("spacing.s"))
                .background(tone("bg.fillSubtle"), in: RoundedRectangle(cornerRadius: radiusField))
                .overlay(
                    RoundedRectangle(cornerRadius: radiusField)
                        .strokeBorder(
                            tone(isComposerFocused ? "border.focus" : "border.muted"),
                            lineWidth: 1
                        )
                )
                .accessibilityLabel("新待办标题")
            capsule("添加", enabled: canSubmit, action: submit)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, host.metric("spacing.m"))
    }

    private func submit() {
        guard canSubmit else { return }
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        host.dispatch("add", NSDictionary(object: title, forKey: "title" as NSString))
        draft = ""
        isComposerFocused = true
    }

    // MARK: - 列表

    @ViewBuilder
    private var openSection: some View {
        sectionHeader("未完成", count: openCount, trailing: AnyView(EmptyView()))
        if openRows.isEmpty {
            emptyState
        } else {
            ForEach(openRows.indices, id: \.self) { index in
                rowCard(openRows[index], done: false)
            }
            if data.int("truncatedOpen") > 0 {
                Text("还有 \(data.int("truncatedOpen")) 条未显示（先处理上面的）")
                    .font(.system(size: 11))
                    .foregroundStyle(tone("status.muted.fg"))
            }
        }
    }

    @ViewBuilder
    private var doneSection: some View {
        if !doneRows.isEmpty {
            sectionHeader(
                "已完成",
                count: doneCount,
                trailing: AnyView(
                    Button {
                        host.dispatch("clearDone", NSDictionary())
                    } label: {
                        Text("清除已完成")
                            .font(.system(size: 11))
                            .foregroundStyle(tone("fg.secondary"))
                    }
                    .buttonStyle(.plain)
                    .help("删除全部已完成的待办")
                )
            )
            ForEach(doneRows.indices, id: \.self) { index in
                rowCard(doneRows[index], done: true)
            }
            if data.int("truncatedDone") > 0 {
                Text("还有 \(data.int("truncatedDone")) 条已完成未显示")
                    .font(.system(size: 11))
                    .foregroundStyle(tone("status.muted.fg"))
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int, trailing: AnyView) -> some View {
        HStack(spacing: host.metric("spacing.s")) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tone("fg.secondary"))
            Text("\(count)")
                .font(.system(size: 11))
                .foregroundStyle(tone("fg.tertiary"))
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, 2)
        .padding(.top, host.metric("spacing.xs"))
    }

    /// 一行待办。**勾选区是整条目本体，不是那个 16pt 圆点**。
    ///
    /// 旧形态把 `toggle` 只挂在 16×16 的圆点 Button 上，标题与卡片背景是死区：
    /// 用户说「点这一条」时指的是行，点在文字/内边距上没有任何事件 —— 这正是「点了没反应」
    /// 的来源。行级 `contentShape(RoundedRectangle)` 当年是**死代码**：`contentShape` 只定义
    /// 容器自身的命中形状，容器上没有任何手势/按钮时它什么也不做。
    ///
    /// 现形态：勾选按钮的 label = `圆点 + 标题 + Spacer`，再 `contentShape(Rectangle())`，
    /// 于是整行左侧（含标题两侧空白）都是命中区；删除按钮是行内**独立**的第二个按钮，
    /// 命中区 16×16 且带 `contentShape`，不靠字号碰运气。
    private func rowCard(_ row: PanelData, done: Bool) -> some View {
        let id = row.string("id")
        let title = row.string("title", "（无标题）")
        return HStack(spacing: host.metric("spacing.s")) {
            Button {
                host.dispatch("toggle:\(id)", NSDictionary())
            } label: {
                HStack(spacing: host.metric("spacing.s")) {
                    stateDot(done: done)
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(tone(done ? "fg.tertiary" : "fg.primary"))
                        .strikethrough(done, color: tone("fg.tertiary"))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                // 标题右侧的空白也算这条待办：否则「点在文字右边一点」又变成没反应。
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(done ? "标记为未完成" : "标记为完成")
            .accessibilityLabel(done ? "标记「\(title)」为未完成" : "标记「\(title)」为完成")

            Button {
                host.dispatch("remove:\(id)", NSDictionary())
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(tone(hoveredID == id ? "fg.secondary" : "fg.tertiary"))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("删除这条待办")
            .accessibilityLabel("删除「\(title)」")
        }
        .padding(.horizontal, host.metric("spacing.m"))
        .padding(.vertical, 7)
        // 悬停高亮：整行可点就必须有可点的反馈，否则用户仍然猜不到该点哪儿。
        .background(
            tone(hoveredID == id ? "bg.surfaceRaised" : "bg.surface"),
            in: RoundedRectangle(cornerRadius: radiusCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radiusCard)
                .strokeBorder(tone("border.muted"), lineWidth: 1)
        )
        .onHover { inside in
            if inside {
                hoveredID = id
            } else if hoveredID == id {
                hoveredID = nil
            }
        }
    }

    /// 完成态圆点（纯展示：命中区在整行按钮上，这里只是状态指示）。
    private func stateDot(done: Bool) -> some View {
        ZStack {
            if done {
                Circle().fill(tone("status.done.fg"))
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white)
            } else {
                Circle().strokeBorder(tone("fg.tertiary"), lineWidth: 1.2)
            }
        }
        .frame(width: 16, height: 16)
    }

    private var emptyState: some View {
        VStack(spacing: host.metric("spacing.s")) {
            Image(systemName: "checklist")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(tone("fg.tertiary"))
            Text("没有未完成的待办")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tone("fg.secondary"))
            Text("在上面写一条，或让 Agent 调 todo_add")
                .font(.system(size: 11))
                .foregroundStyle(tone("fg.tertiary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, host.metric("spacing.m"))
    }

    // MARK: - 胶囊（复刻 `InlineCapsuleLabel` 的几何：高 28 / 水平 12 / semibold）

    private func capsule(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(enabled ? Color.white : tone("fg.tertiary"))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    enabled ? tone("brand.base") : tone("bg.fillSubtle"),
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
