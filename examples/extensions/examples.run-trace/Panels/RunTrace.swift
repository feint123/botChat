//
//  RunTrace.swift
//  examples.run-trace · 运行轨迹面板（原生 SwiftUI）
//
//  视觉重做的三条判据（都来自真实数据实测，见 `.research/run-trace-dsh-ui.md` 与
//  `Prototypes/run-trace-panel/`，样本：会话 9cdd9ada，12 轮 / 1179 次工具）：
//
//  1. **时长条按「本轮最长」归一**：真实工具时长极差达 5 万倍（中位 1.2s / 最大 310s）。
//     按轮跨度线性归一会把一半以上的条压成 2pt 细线；按本轮最长归一每条都读得出分量。
//  2. **进行中不画宽度**：`endedAt` / `durationMs` 缺席时只画 2pt 起点标记、写「进行中」。
//     MUST NOT 补 0、MUST NOT 用当前时刻冒充结束（`ui.py` 与 spec 的同一条纪律）。
//  3. **状态只做点与竖轨，不做整行染色**：类型色与状态色混用会让「失败」读不开。
//
//  两条诚实纪律：
//  - **折叠不是消失**，换成一行摘要，且把失败数带到摘要行（实测第 3 轮的失败藏在子代理
//    折叠明细里，折叠态完全看不见 —— 状态 MUST 在折叠时不丢）。
//  - **截断计数只报一次**：轮级 `truncatedTools` 已含子代理被裁量（实测 turn2：
//    818−87=731=truncatedTools），MUST NOT 再把子代理差额二次累加。
//
//  ## 为什么是单文件
//
//  宿主只编**一个**面板源文件（`PanelCompiler.buildArguments` 的 `sources: [sdk, panel]`，
//  `client.panel.views[].entry` 也只指向一个文件），故数据层 / 几何层 / 视图层同文件分层。
//  为该约束，本文件允许超 300 行软线；宿主硬上限是 4000 行（`PanelSourceGate.maxLines`）。

import AppKit
import BotChatKit
import Foundation
import SwiftUI

// MARK: - 入口与实例

struct RunTraceEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        // Kit 组件与 `NSHostingView` 都是 `@MainActor`；宿主本来就在主线程取实例。
        MainActor.assumeIsolated { RunTracePanel(host: host) }
    }
}

/// 入口导出：宿主按符号 `botchat_panel_entry` 取它（符号按镜像解析，不按类名查表）。
@_cdecl("botchat_panel_entry")
public func runTracePanelEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(RunTraceEntry.self, hostRaw)
}

final class RunTracePanel: NSObject, PanelInstance {
    private let host: PanelHost
    private let hosting: NSHostingView<AnyView>

    init(host: PanelHost) {
        self.host = host
        self.hosting = NSHostingView(
            rootView: AnyView(RunTraceView(host: host, model: .waiting).panelKitRoot(host))
        )
        super.init()
        host.log("运行轨迹面板已创建")
    }

    var rootView: NSView { hosting }

    /// 幂等：解码是纯函数，同一份 data 连调两次结果一致。只换 `rootView`（同类型赋值保留
    /// `@State`，刷新即原位更新、不丢滚动位置与展开态）。
    func update(data: NSDictionary) {
        hosting.rootView = AnyView(
            RunTraceView(host: host, model: RunTraceModel(PanelData(data))).panelKitRoot(host)
        )
    }
}

// MARK: - 状态

/// 三态 + 未知。只认宿主给的字面值；未登记的取值原样保留，面板不猜语义。
enum RunTraceStatus: Equatable {
    case running, ok, failed
    case unknown(String)

    init(raw: String) {
        switch raw.lowercased() {
        case "running": self = .running
        case "ok", "done", "success", "completed", "finished": self = .ok
        case "failed", "error", "cancelled", "canceled", "timeout": self = .failed
        default: self = .unknown(raw)
        }
    }

    /// 点与条的角色：取 `*.fg` 档而非 `*.subtle` —— 后者在深色面板底上几乎同色。
    var role: KitRole {
        switch self {
        case .running: return .statusRunningFg
        case .ok: return .statusDoneFg
        case .failed: return .statusFailedFg
        case .unknown: return .statusMutedFg
        }
    }

    var text: String {
        switch self {
        case .running: return RunTraceCopy.statusRunning
        case .ok: return RunTraceCopy.statusOK
        case .failed: return RunTraceCopy.statusFailed
        case .unknown(let raw): return raw.isEmpty ? RunTraceCopy.statusUnknown : raw
        }
    }
}

// MARK: - 记录（轮 / 子代理 / 工具三层同形）

struct TraceSpan: Identifiable, Equatable {
    enum Kind: Equatable { case turn, subagent, tool }

    let id: String
    let kind: Kind
    let name: String
    /// 服务端拼的短标签（「工具名 + 参数摘要」）。展示时用 `brief`。
    let label: String
    let status: RunTraceStatus
    let startedAt: Date?
    let endedAt: Date?
    let durationMs: Int?
    /// 真实总次数：轮 = 本页下发 + `truncatedTools`；子代理 = 本页下发 + 它的 `truncatedTools`。
    let totalCount: Int
    /// 本页未下发条数（已含子代理被裁量，故只在轮级汇总一次）。
    let truncatedTools: Int
    let hiddenSubagents: Int
    let tools: [TraceSpan]
    let subagents: [TraceSpan]

    /// 同层子节点：子代理与主 agent 工具混排，按起始时刻（spec 硬要求）；缺席者排最前。
    var children: [TraceSpan] {
        (subagents + tools).sorted { lhs, rhs in
            (lhs.startedAt ?? .distantPast, lhs.id) < (rhs.startedAt ?? .distantPast, rhs.id)
        }
    }

    /// 进行中：有起点但没有结束事实。UI 据此只画起点标记，不画宽度。
    var isLive: Bool { endedAt == nil && kind != .turn }

    /// 本页可见条目里的失败数（不覆盖被裁掉的部分 —— 提示里会说明范围）。
    var visibleFailCount: Int {
        let own = status == .failed ? 1 : 0
        return own + tools.filter { $0.status == .failed }.count
            + subagents.reduce(0) { $0 + $1.visibleFailCount }
    }

    /// 剥掉「工具名 + 空白」前缀后的摘要。服务端 `label` 恒以工具名开头（实测 430/430 条），
    /// 而名称列已单独显示工具名 —— 不剥就是同一行把同一个词写两遍。
    var brief: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, trimmed.hasPrefix(name) else { return trimmed }
        return String(trimmed.dropFirst(name.count)).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - 解码

/// 时刻与时长文案：一次渲染建一次（不引入静态共享状态）。
struct RunTraceCodec {
    private let precise = RunTraceCodec.formatter(fractional: true)
    private let plain = RunTraceCodec.formatter(fractional: false)
    private let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static func formatter(fractional: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions =
            fractional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter
    }

    /// ISO-8601 → `Date`；带毫秒与不带毫秒两种形态都在宿主侧出现过，故各试一次。
    func date(_ text: String) -> Date? {
        text.isEmpty ? nil : (precise.date(from: text) ?? plain.date(from: text))
    }

    func clockText(_ date: Date?) -> String {
        date.map { clock.string(from: $0) } ?? RunTraceCopy.unknownTime
    }

    /// `HH:mm`：轮头专用的短格式（秒在轮头没有判别价值，却要吃掉 3 个等宽字符）。
    func minuteText(_ date: Date?) -> String {
        guard let date else { return RunTraceCopy.unknownTime }
        let text = clock.string(from: date)
        return String(text.prefix(5))
    }
}

/// 面板的完整解码结果：五种形状互不冒充。
struct RunTraceModel: Equatable {
    enum Shape: Equatable {
        /// 首次 `update` 之前：既不是空也不是不可用，MUST NOT 谎称「一轮都没跑过」。
        case waiting
        case runs([TraceSpan])
        case empty
        case unavailable(reason: String)
        case invalid
    }

    let title: String
    /// 插件算好的头部灰字（`ui.py` 的 `summary`；空串 = 未提供）。
    let summary: String
    /// 插件拼好的裁剪 / 分页提示（空串 = 无提示）。口径只在服务端一侧，面板不重算。
    let notice: String
    let shape: Shape

    static let waiting = RunTraceModel(shape: .waiting)

    private init(shape: Shape) {
        title = RunTraceCopy.fallbackTitle
        summary = ""
        notice = ""
        self.shape = shape
    }

    init(_ payload: PanelData) {
        title = payload.string("title", RunTraceCopy.fallbackTitle)
        summary = payload.string("summary")
        notice = payload.string("notice")

        guard let raw = payload.raw["runs"] else {
            // `available: false` 是插件**自己给出的可判定空**（读口拒绝 / 不可用），
            // 与「脏载荷」是两件事：前者给原因，后者给「载荷缺失」提示。
            let flag = (payload.raw["available"] as? NSNumber)?.boolValue
            shape = flag == false
                ? .unavailable(reason: payload.string("reason"))
                : .invalid
            return
        }
        let turns = RunTraceModel.rows(raw).compactMap { TraceSpan.turn($0) }
        shape = turns.isEmpty ? .empty : .runs(turns)
    }

    /// `runs` 不是数组时按空清单处理（形状不对由「`runs` 缺席」那条分支兜住）。
    static func rows(_ value: Any?) -> [PanelData] {
        if let items = value as? [NSDictionary] { return items.map(PanelData.init) }
        guard let items = value as? [Any] else { return [] }
        return items.compactMap { item in
            (item as? NSDictionary) ?? (item as? [String: Any]).map { $0 as NSDictionary }
        }.map(PanelData.init)
    }
}

/// 三层解码：任一层缺身份即整条丢弃（不猜、不补）。
extension TraceSpan {
    static func turn(_ payload: PanelData) -> TraceSpan? {
        let id = payload.string("turnId")
        guard !id.isEmpty else { return nil }
        let label = payload.string("label")
        let tools = payload.rows("tools").compactMap { tool($0) }
        let subs = payload.rows("subagents").compactMap { subagent($0) }
        let truncated = payload.int("truncatedTools")
        // 真实总次数 = 本页下发 + truncatedTools。子代理差额已含在 truncatedTools 里
        // （实测 turn2：818−87=731），故这里 MUST NOT 再累加子代理的差额。
        let delivered = tools.count + subs.reduce(0) { $0 + $1.tools.count }
        return make(
            payload, id: "turn:" + id, kind: .turn,
            // 读口把轮的 `label` 留空（它只给身份与状态），故按 `index`（0 起）编号。
            name: label.isEmpty ? RunTraceCopy.turnName(payload.int("index") + 1) : label,
            label: label, total: delivered + truncated,
            truncated: truncated, hidden: payload.int("hiddenSubagents"),
            tools: tools, subs: subs
        )
    }

    static func subagent(_ payload: PanelData) -> TraceSpan? {
        let taskId = payload.string("taskId")
        let name = payload.string("name")
        guard !taskId.isEmpty || !name.isEmpty else { return nil }
        let tools = payload.rows("tools").compactMap { tool($0) }
        // 服务端的子代理载荷**不含 `toolCount`**（实测 keys：name / taskId / status /
        // startedAt / endedAt / durationMs / truncatedTools / tools），真实总数只能由
        // 「本页下发 + truncatedTools」还原。按 toolCount 读会拿到 0，会把「共 197 次」
        // 静默降级成「本页 23 条」—— 这类解码缺陷只靠编译通过发现不了。
        let truncated = payload.int("truncatedTools")
        return make(
            payload, id: "task:" + (taskId.isEmpty ? name : taskId), kind: .subagent,
            name: name.isEmpty ? RunTraceCopy.subagentFallback : name,
            label: "", total: tools.count + truncated,
            truncated: truncated, hidden: 0,
            tools: tools, subs: []
        )
    }

    /// id 带起始时刻：同名工具在一轮里可以重复（实测单轮 execute 最多 12 次）。
    static func tool(_ payload: PanelData) -> TraceSpan? {
        let name = payload.string("name")
        guard !name.isEmpty else { return nil }
        return make(
            payload, id: "tool:" + name + "@" + payload.string("startedAt"), kind: .tool,
            name: name, label: payload.string("label"), total: 1,
            truncated: 0, hidden: 0, tools: [], subs: []
        )
    }

    private static func make(
        _ payload: PanelData, id: String, kind: Kind, name: String, label: String,
        total: Int, truncated: Int, hidden: Int, tools: [TraceSpan], subs: [TraceSpan]
    ) -> TraceSpan {
        TraceSpan(
            id: id, kind: kind, name: name, label: label,
            status: RunTraceStatus(raw: payload.string("status")),
            startedAt: codec.date(payload.string("startedAt")),
            endedAt: codec.date(payload.string("endedAt")),
            // 可选整数：缺键即 `nil`（MUST NOT 与「0 ms」混同）。
            durationMs: (payload.raw["durationMs"] as? NSNumber)?.intValue,
            totalCount: total, truncatedTools: truncated, hiddenSubagents: hidden,
            tools: tools, subagents: subs
        )
    }

    private static let codec = RunTraceCodec()
}

// MARK: - 文案与常量（一份真源）

enum RunTraceCopy {
    static let fallbackTitle = "运行轨迹"
    static let symbol = "chart.bar.xaxis"
    static let refreshTitle = "刷新轨迹"
    /// 刷新节点 id：服务端把任何 action 都交给同一个视图 handler，故只需一个稳定串。
    static let refreshNode = "refresh"
    static let statusRunning = "进行中"
    static let statusOK = "成功"
    static let statusFailed = "失败"
    static let statusUnknown = "未知"
    static let unknownTime = "—"
    static let subagentFallback = "子代理"
    static let waitingText = "正在读取运行轨迹…"
    static let emptyTitle = "这个会话还没有跑过一轮"
    static let emptySymbol = "chart.bar.xaxis"
    static let unavailableTitle = "取不到运行轨迹"
    static let unavailableSymbol = "eye.slash"
    static let invalidDetail = "载荷里没有可读的轨迹清单（缺 runs）；点刷新重新拉一帧。"

    /// spec 硬要求的最窄条宽（2pt）：再短的条也要点得到、看得见。
    static let minBarWidth: CGFloat = 2

    /// 计数段的段间分隔符（原型 `.ov-head` 的 `<span>·</span>`）。全文件只用这一处。
    static let countSeparator = "·"

    static func turnName(_ number: Int) -> String { "第 \(number) 轮" }

    static func truncatedToolsText(_ count: Int) -> String { "还有 \(count) 项工具未显示" }

    static func hiddenSubagentsText(_ count: Int) -> String { "还有 \(count) 个子代理未显示" }

    /// 时长文案：<1s 用毫秒，<1min 用秒（一位小数），再长用分秒。不给假精度。
    static func durationText(_ ms: Int?) -> String {
        guard let ms else { return unknownTime }
        if ms < 1000 { return "\(ms) ms" }
        let seconds = Double(ms) / 1000
        if seconds < 60 { return String(format: "%.1f s", seconds) }
        let minutes = Int(seconds) / 60
        let rest = Int(seconds) % 60
        return "\(minutes)m\(rest)s"
    }
}

// MARK: - 几何（纯函数）

/// 行内时长条的相对占比（`0…1`）。
///
/// 分母是**本轮最长的那条**，不是轮跨度：真实工具时长极差达 5 万倍，按轮跨度归一会让
/// 一半以上的条塌成 2pt 细线。按本轮最长归一，每条都还读得出相对分量。
enum TraceScale {
    static func longest(of turn: TraceSpan) -> Int? {
        let all = turn.subagents + turn.subagents.flatMap(\.tools) + turn.tools
        return all.compactMap(\.durationMs).max()
    }

    /// 归一指数：`0.5` 即开方标度。
    ///
    /// 为什么不是线性：真实数据里同一轮内单个子代理的跨度常比秒级工具大三个数量级
    /// （实测 295ms vs 5m9s）。线性归一后 295ms 与 5.8s 都塌到最窄 2pt（实测截图里两者
    /// 的条宽都是 13pt，读不出任何差异）。开方后 295ms→3%、5.8s→14%，可分辨。
    static let exponent = 0.5

    static func ratio(_ durationMs: Int?, longest: Int?) -> Double? {
        guard let durationMs, let longest, longest > 0, durationMs > 0 else { return nil }
        let linear = min(1, max(0, Double(durationMs) / Double(longest)))
        return pow(linear, exponent)
    }
}

/// 折叠态密度条：该时段起点落了几次调用、其中几次失败。
///
/// 折叠行只占一行高度，读数只能是「这一轮忙不忙、有没有失败」。实测有它时用户能一眼
/// 分出 831 次的重轮与 10 次的轻轮。
struct TraceSpark: Equatable {
    let counts: [Int]
    let fails: [Int]

    static let buckets = 14

    static func build(_ turn: TraceSpan) -> TraceSpark {
        let all = turn.subagents + turn.subagents.flatMap(\.tools) + turn.tools
        guard let turnStart = turn.startedAt, all.contains(where: { $0.startedAt != nil })
        else { return TraceSpark(counts: [], fails: []) }
        let end = turn.endedAt ?? turnStart.addingTimeInterval(Double(turn.durationMs ?? 1) / 1000)
        let span = max(end.timeIntervalSince(turnStart), 0.001)
        var counts = [Int](repeating: 0, count: buckets)
        var fails = counts
        for item in all {
            guard let at = item.startedAt else { continue }
            let offset = at.timeIntervalSince(turnStart) / span
            let index = min(buckets - 1, max(0, Int(offset * Double(buckets))))
            counts[index] += 1
            if item.status == .failed { fails[index] += 1 }
        }
        return TraceSpark(counts: counts, fails: fails)
    }

    /// 每格高度比例（`0…1`），按本行最大计数归一；非零格给 0.12 下限，避免读成「没发生」。
    func heights() -> [Double] {
        guard let maxCount = counts.max(), maxCount > 0 else { return [] }
        return counts.map { $0 == 0 ? 0 : max(0.12, Double($0) / Double(maxCount)) }
    }
}

/// 会话总览轨：把每轮起止投到整段会话的时间轴上。
struct TraceOverview: Equatable {
    struct Segment: Identifiable, Equatable {
        let id: String
        let start: Double
        let width: Double
        let status: RunTraceStatus
    }

    let segments: [Segment]
    let startText: String
    let endText: String
    /// 会话总跨度文案（`199m56s`）：原型把它放在**首行右端**，不在轴的两端。
    let spanText: String
    let turnCount: Int
    /// 工具条数合计：与 `ui.py:_tool_count` **同口径** —— 本页下发的工具条数，含各子代理下的。
    ///
    /// MUST NOT 用 `TraceSpan.totalCount` 累加：那个数还含 `truncatedTools`（本页未下发的），
    /// 与服务端 `summary`（`ui.py:headline` 同样只数已下发的）会当场给出两个不同的数。
    let toolCount: Int
    /// 含失败的轮数（原型 `failedTurns`：`turns.filter { status === 'failed' }.length`）。
    let failedTurns: Int

    static func build(_ turns: [TraceSpan], codec: RunTraceCodec) -> TraceOverview? {
        let starts = turns.compactMap(\.startedAt)
        guard let first = starts.min() else { return nil }
        let last = turns.compactMap { $0.endedAt ?? $0.startedAt }.max() ?? first
        let span = max(last.timeIntervalSince(first), 0.001)
        let segments = turns.map { turn -> Segment in
            let start = turn.startedAt ?? first
            let end = turn.endedAt ?? start
            let left = min(1, max(0, start.timeIntervalSince(first) / span))
            let right = min(1, max(0, end.timeIntervalSince(first) / span))
            return Segment(
                id: turn.id, start: left, width: max(right - left, 0), status: turn.status
            )
        }
        // 「次工具」按 `ui.py:_tool_count` 的同一口径数：`len(turn.tools) + Σ len(sub.tools)`。
        let toolCount = turns.reduce(0) { sum, turn in
            sum + turn.tools.count + turn.subagents.reduce(0) { $0 + $1.tools.count }
        }
        return TraceOverview(
            segments: segments, startText: codec.clockText(first),
            endText: codec.clockText(last),
            spanText: RunTraceCopy.durationText(Int(span * 1000)),
            turnCount: turns.count,
            toolCount: toolCount,
            failedTurns: turns.filter { $0.status == .failed }.count
        )
    }
}

// MARK: - 视图（只用 Kit 组件与语义档）

struct RunTraceView: View {
    let host: PanelHost
    let model: RunTraceModel

    /// 展开的轮 / 子代理（可同时开多个：用户常要对照两轮）。刷新是原位换 `rootView`，
    /// 故展开态跟着留下。
    @State private var openTurns: Set<String>
    @State private var openSubs: Set<String>

    /// 初值可注入：卸下 `@State` 的默认空集，验收渲染才能拍到展开态的那两层容器。
    /// 生产路径（`RunTracePanel`）不传，行为与写死空集完全一致。
    init(host: PanelHost, model: RunTraceModel,
         openTurns: Set<String> = [], openSubs: Set<String> = []) {
        self.host = host
        self.model = model
        _openTurns = State(initialValue: openTurns)
        _openSubs = State(initialValue: openSubs)
    }

    @Environment(\.kitPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: host.metric("spacing.s")) {
            header
            switch model.shape {
            case .waiting:
                placeholder(RunTraceCopy.waitingText, RunTraceCopy.emptySymbol)
            case let .runs(turns):
                ledger(turns)
            case .empty:
                placeholder(RunTraceCopy.emptyTitle, RunTraceCopy.emptySymbol)
            case let .unavailable(reason):
                placeholder(RunTraceCopy.unavailableTitle, RunTraceCopy.unavailableSymbol, reason)
            case .invalid:
                KitNotice(RunTraceCopy.invalidDetail, severity: .warning)
            }
        }
        .padding(host.metric("spacing.m"))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // 整块底色与聊天主区同角色（`bg.canvas`），与 todo-list / hello-panel 一致：
        // 面板贴在主区旁边，底色不同会显出一条接缝。MUST NOT 用 `.kitSurface(.inset)`
        // 把整面板铺成 sunken —— 那是「嵌进去的块」，不是「一列面板」。
        .background(palette.color(.bgCanvas))
    }

    /// `notice` 里 `summary` 尚未覆盖的片段（按「；」切，逐段判包含）。
    private var noticeOnly: String {
        model.notice
            .split(separator: "；")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !model.summary.contains($0) }
            .joined(separator: "；")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: host.metric("spacing.xs")) {
            HStack(spacing: host.metric("spacing.s")) {
                Image(systemName: RunTraceCopy.symbol).kitText(.title, tone: .fgSecondary)
                Text(model.title).kitText(.sectionTitle, weight: .semibold).lineLimit(1)
                Spacer(minLength: 0)
                KitButton(icon: "arrow.clockwise", label: RunTraceCopy.refreshTitle) {
                    // 唯一写方向动作：宿主生成幂等 action_id → 服务端重渲染 → 新 `rev`。
                    host.dispatch(RunTraceCopy.refreshNode, [:])
                }
                .kitButtonEmphasis(.plain)
                .kitButtonSize(.small)
            }
            if !model.summary.isEmpty {
                Text(model.summary).kitText(.annotation, tone: .fgTertiary).lineLimit(1)
            }
            // 服务端把同一句 tail 同时拼进 `summary` 与 `notice`（`ui.py:headline`），
            // 两个都原样渲染就是同一句话复读；这里只显示 `summary` 里还没有的部分。
            if !noticeOnly.isEmpty {
                KitNotice(noticeOnly, severity: .info)
            }
        }
    }

    private func ledger(_ turns: [TraceSpan]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: host.metric("spacing.xs")) {
                if let overview = TraceOverview.build(turns, codec: RunTraceCodec()) {
                    overviewStrip(overview)
                }
                ForEach(Array(turns.enumerated()), id: \.element.id) { index, turn in
                    turnBlock(turn, number: index + 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 会话总览卡：三段三行（原型 `.ov`，index.html:124-140 / 341-386 行）。
    ///
    /// 1. 首行 `N 轮 · M 次工具 · K 轮含失败`，右端是总时长；
    /// 2. 中段 rail：每轮起止投在整段会话的时间轴上；
    /// 3. 末行轴：**只有两端**（`justify-content:space-between`），跨度已上移到首行。
    private func overviewStrip(_ overview: TraceOverview) -> some View {
        VStack(alignment: .leading, spacing: host.metric("spacing.xs")) {
            overviewHead(overview)
            GeometryReader { proxy in
                let track = max(0, proxy.size.width)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: host.metric("radius.s"), style: .continuous)
                        .fill(host.panelColor(KitRole.bgSurfaceSunken.rawValue))
                    ForEach(overview.segments) { segment in
                        let width = max(RunTraceCopy.minBarWidth, track * segment.width)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(host.panelColor(segment.status.role.rawValue))
                            .opacity(segment.status == .ok ? 0.5 : 0.85)
                            .frame(width: width, height: proxy.size.height * 0.6)
                            .offset(
                                x: min(track * segment.start, max(0, track - width)),
                                y: proxy.size.height * 0.2
                            )
                    }
                }
            }
            .frame(height: host.metric("spacing.l"))
            // 末行只留两端：跨度已上移到首行右端（原型 `.ov-axis` 只有两个 `<span>`）。
            HStack(spacing: 0) {
                Text(overview.startText)
                Spacer(minLength: 0)
                Text(overview.endText)
            }
            .kitText(.annotationSmall, tone: .fgTertiary)
            .monospacedDigit()
            .lineLimit(1)
        }
        .padding(host.metric("spacing.xs"))
        .kitSurface(.raised)
    }

    /// 总览卡首行：计数段 + 右端总时长。
    ///
    /// 「K 轮含失败」为 0 时整段不出现（原型 `failedTurns ? '· <b>K</b> 轮含失败' : ''`）：
    /// 写「0 轮含失败」等于每次都宣告一遍「没出事」，是噪声。
    private func overviewHead(_ overview: TraceOverview) -> some View {
        // 段间 6pt：原型 `.ov-head{gap:6px}`。
        HStack(alignment: .firstTextBaseline, spacing: host.metric("spacing.s")) {
            overviewStat(overview.turnCount, "轮")
            countSeparator
            overviewStat(overview.toolCount, "次工具")
            if overview.failedTurns > 0 {
                countSeparator
                overviewStat(overview.failedTurns, "轮含失败")
            }
            Spacer(minLength: host.metric("spacing.s"))
            Text(overview.spanText).kitText(.annotation, tone: .fgTertiary).monospacedDigit()
        }
        .lineLimit(1)
    }

    /// 一个计数：数字用二级色加粗，单位用三级色（原型 `.ov-head b` 与 `.ov-head` 的两档色）。
    private func overviewStat(_ value: Int, _ unit: String) -> some View {
        HStack(spacing: 0) {
            Text("\(value) ").kitText(.annotation, weight: .semibold, tone: .fgSecondary)
            Text(unit).kitText(.annotation, tone: .fgTertiary)
        }
        .monospacedDigit()
    }

    private var countSeparator: some View {
        Text(RunTraceCopy.countSeparator).kitText(.annotation, tone: .fgTertiary)
    }

    // MARK: 一轮

    /// 一轮：折叠态**裸行**，展开态描边容器（原型 `.turn` / `.turn[data-open=\"true\"]`）。
    ///
    /// `.kitSurface` 没有「无容器」这一档（最轻的 `.raised` 也会画 `bg.surfaceRaised` +
    /// 0.5pt `border.default`，见 `KitSurface.swift`），故这里必须分两支表达：
    /// 折叠轮一旦套上 `.raised`，每轮都变成一张贴边的小描边卡，与原型「全列表靠留白分隔」
    /// 的层级完全不同。
    @ViewBuilder
    private func turnBlock(_ turn: TraceSpan, number: Int) -> some View {
        let isOpen = openTurns.contains(turn.id)
        if isOpen {
            VStack(alignment: .leading, spacing: host.metric("spacing.xs")) {
                turnHeaderButton(turn, number: number, isOpen: true)
                turnBody(turn)
            }
            .padding(host.metric("spacing.s"))
            .kitSurface(.card)
        } else {
            turnHeaderButton(turn, number: number, isOpen: false)
                // 裸行也要横向留白：原型 `.turn-hd{padding:0 7px}`。7pt 无对应 token，
                // 取 `spacing.s`(=6)，与展开态容器的内边距同一档，两种状态左右边缘才对得齐。
                .padding(.horizontal, host.metric("spacing.s"))
        }
    }

    private func turnHeaderButton(_ turn: TraceSpan, number: Int, isOpen: Bool) -> some View {
        Button {
            toggle(&openTurns, turn.id)
        } label: {
            turnHeader(turn, number: number, isOpen: isOpen)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(RunTraceCopy.turnName(number))，\(turn.status.text)")
    }

    /// 展开区：子代理与主 agent 工具按起始时刻混排，尾部两条截断计数各报一次。
    private func turnBody(_ turn: TraceSpan) -> some View {
        VStack(alignment: .leading, spacing: host.metric("spacing.xs")) {
            ForEach(turn.children) { child in
                if child.kind == .subagent {
                    subagentBlock(child, turn: turn)
                } else {
                    recordRow(child, turn: turn, isChild: false)
                }
            }
            if turn.truncatedTools > 0 {
                Text(RunTraceCopy.truncatedToolsText(turn.truncatedTools))
                    .kitText(.annotation, tone: .fgTertiary)
            }
            if turn.hiddenSubagents > 0 {
                Text(RunTraceCopy.hiddenSubagentsText(turn.hiddenSubagents))
                    .kitText(.annotation, tone: .fgTertiary)
            }
        }
    }

    /// 轮头：序号 + 时间区间 + 密度条 + 时长 + 状态点。
    private func turnHeader(_ turn: TraceSpan, number: Int, isOpen: Bool) -> some View {
        HStack(spacing: host.metric("spacing.s")) {
            Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                .kitText(.annotation, tone: .fgTertiary)
            Text(RunTraceCopy.turnName(number)).kitText(.caption, weight: .semibold).lineLimit(1)
            // 时间区间优先给足：它被截成「12:12:…」比少一句摘要坏得多（实测 420pt 下会先截它）。
            mono(rangeText(turn)).fixedSize(horizontal: true, vertical: false)
            // 中段摘要是「有则更好」的信息，让它在余量里收缩（layoutPriority 低于时间区间）。
            mono(turnDigest(turn), .annotationSmall)
                .truncationMode(.tail)
                .layoutPriority(-1)
            Spacer(minLength: host.metric("spacing.s"))
            sparkView(TraceSpark.build(turn)).frame(width: 44, alignment: .leading)
            mono(durationText(turn)).foregroundStyle(host.panelColor(KitRole.fgSecondary.rawValue))
                .frame(width: 56, alignment: .trailing)
            statusDot(turn.status)
        }
        .frame(minHeight: host.metric("row.height"), alignment: .leading)
        .contentShape(Rectangle())
    }

    /// 轮中段摘要：工具总数（含未下发）与本页可见失败数。
    /// 有裁剪时失败数只覆盖本页可见条目，故补一句范围说明放在 tooltip。
    private func turnDigest(_ turn: TraceSpan) -> String {
        var parts = ["\(turn.totalCount) 次工具"]
        let fails = toolsOf(turn).filter { $0.status == .failed }.count
        if fails > 0 { parts.append("\(fails) 次失败") }
        if turn.truncatedTools > 0 { parts.append("另有 \(turn.truncatedTools) 项未下发") }
        return parts.joined(separator: " · ")
    }

    /// 一轮内所有条目（子代理 + 各自的工具 + 主 agent 工具）。
    private func toolsOf(_ turn: TraceSpan) -> [TraceSpan] {
        turn.tools + turn.subagents + turn.subagents.flatMap(\.tools)
    }

    /// 等宽元信息（时刻 / 时长 / 计数）：同一套修饰链在文件里出现十余次，收成一处。
    private func mono(_ text: String, _ style: KitTextStyle = .annotation) -> some View {
        Text(text).kitText(style, tone: .fgTertiary).monospacedDigit().lineLimit(1)
    }

    /// 普通元信息。
    private func meta(_ text: String, _ style: KitTextStyle = .annotation,
                      _ tone: KitRole = .fgTertiary) -> some View {
        Text(text).kitText(style, tone: tone).lineLimit(1)
    }

    private func sparkView(_ spark: TraceSpark) -> some View {
        let heights = spark.heights()
        return HStack(alignment: .bottom, spacing: 1) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                Capsule()
                    .fill(
                        host.panelColor(
                            spark.fails[index] > 0
                                ? RunTraceStatus.failed.role.rawValue
                                : KitRole.fgTertiary.rawValue
                        )
                    )
                    .frame(width: 2, height: max(1, host.metric("spacing.m") * height))
            }
        }
        .frame(height: host.metric("spacing.m"), alignment: .bottom)
        .padding(.trailing, host.metric("spacing.xs"))
        .accessibilityHidden(true)
    }

    // MARK: 子代理

    private func subagentBlock(_ sub: TraceSpan, turn: TraceSpan) -> some View {
        let isOpen = openSubs.contains(sub.id)
        let hidden = max(0, sub.totalCount - sub.tools.count)
        let fails = sub.tools.filter { $0.status == .failed }.count
        return VStack(alignment: .leading, spacing: host.metric("spacing.xs")) {
            Button {
                toggle(&openSubs, sub.id)
            } label: {
                recordRow(sub, turn: turn, isChild: false)
                    // 子代理行是「浅底圆角条」而不是裸行：它是展开区里的一个子分组。
                    //
                    // MUST NOT 再叠一层 `padding(.horizontal)`：那会让子代理行的圆点比它
                    // 下面子行的圆点右移 4pt（子行只经过 `recordRow` 的对称内边距），
                    // 而原型里父子圆点在同一列（`.row` 的 `grid` 首列不随 `--child` 变）。
                    .background(
                        RoundedRectangle(cornerRadius: host.metric("radius.s"), style: .continuous)
                            .fill(host.panelColor(KitRole.bgFillSubtle.rawValue))
                    )
            }
            .buttonStyle(.plain)

            if isOpen {
                ForEach(sub.tools) { recordRow($0, turn: turn, isChild: true) }
            }
            if hidden > 0 || sub.tools.count > 3 {
                // 分组控件仍留 4pt 左内边距（原型 `.more-btn{padding:4px}`）；
                // 行的圆点列不加缩进（见本函数尾部注释）。
                HStack(spacing: host.metric("spacing.xs")) {
                    KitButton(isOpen ? "收起明细" : "展开 \(sub.tools.count) 条工具") {
                        toggle(&openSubs, sub.id)
                    }
                    .kitButtonEmphasis(.plain)
                    .kitButtonSize(.small)
                    if hidden > 0 {
                        Text("共 \(sub.totalCount) 次，本页 \(sub.tools.count) 条")
                            .kitText(.annotation, tone: .fgTertiary)
                    }
                    Spacer(minLength: 0)
                    // 折叠时失败不可见 = 状态丢失，故把它带到摘要行上。
                    if fails > 0 && !isOpen {
                        KitTag("\(fails) 次失败", role: .danger, glyph: .dot)
                    }
                }
                .padding(.leading, host.metric("spacing.xs"))
            }
        }
        // MUST NOT 再给子分组加 leading 缩进：原型里子代理行、它下面的工具子行、以及主 agent
        // 的工具行都是同一个 `.rows` 容器里的**平级兄弟**，圆点在同一竖列；层级只由名称列的
        // `.row--child .g-name{padding-left:var(--indent)}` 表达。分组再缩进一次会多出
        // 一条原型里不存在的假层级（实测主 agent 工具行圆点与子代理行差 4pt）。
    }

    // MARK: 一条记录

    private func recordRow(_ span: TraceSpan, turn: TraceSpan, isChild: Bool) -> some View {
        HStack(spacing: host.metric("spacing.s")) {
            statusDot(span.status)
            Text(span.name)
                .kitText(isChild ? .annotation : .caption, tone: .fgSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                // 子行缩进**只作用名称列**（原型 `.row--child .g-name{padding-left:var(--indent)}`）：
                // 加在整行上会把状态点、摘要列、时长列一起推进去，且左右内边距必然不对称。
                // 原型 `--indent` 是 13px，取最近的档 `spacing.l`(=14)；名称列固定 78pt，
                // 缩进在其内部吃掉，故列仍对齐（与 CSS 的 content-box 语义一致）。
                .padding(.leading, isChild ? host.metric("spacing.l") : 0)
                .frame(width: 78, alignment: .leading)
            Text(span.kind == .subagent ? "\(span.totalCount) 次工具" : span.brief)
                .kitText(.annotation, tone: .fgTertiary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(durationText(span))
                .kitText(.annotationSmall, tone: .fgTertiary)
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: 52, alignment: .trailing)
        }
        // 左右等宽（原型 `.row{padding:0 4px}`）：原先再叠一层 leading padding，
        // 左 8pt / 右 4pt，圆点与时长各自贴住的那条边不对等。
        .padding(.horizontal, host.metric("spacing.xs"))
        .frame(minHeight: host.metric("row.height"), alignment: .leading)
        // 时长条铺满整行作背景：**这才是可读的相对分量**。
        // 独立 44pt 列里 295ms 与 5.8s 都退化成细线（实测评审读不出差异），
        // 铺满整行后两者的绝对宽度差才有可读量。
        .background(alignment: .leading) {
            durationBar(span, turn: turn)
        }
        .contentShape(Rectangle())
    }

    /// 行内时长条：宽度按「本轮最长」归一；进行中只画 2pt 起点标记（不编宽度）。
    private func durationBar(_ span: TraceSpan, turn: TraceSpan) -> some View {
        let ratio = TraceScale.ratio(span.durationMs, longest: TraceScale.longest(of: turn))
        return GeometryReader { proxy in
            let track = max(0, proxy.size.width)
            let width = span.isLive
                ? RunTraceCopy.minBarWidth
                : max(RunTraceCopy.minBarWidth, track * (ratio ?? 0))
            RoundedRectangle(cornerRadius: host.metric("radius.s"), style: .continuous)
                .fill(host.panelColor(span.status.role.rawValue))
                // 背景条压得很淡：它是「量」，不是「状态」；状态由行首点表达。
                .opacity(span.isLive ? 0.30 : 0.14)
                .frame(width: min(width, track), height: proxy.size.height - 4)
                .offset(y: 2)
        }
    }

    private func statusDot(_ status: RunTraceStatus) -> some View {
        Circle()
            .fill(host.panelColor(status.role.rawValue))
            .frame(width: 5, height: 5)
            .accessibilityLabel(status.text)
    }

    // MARK: 辅助

    private func toggle(_ set: inout Set<String>, _ id: String) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }

    /// 轮头时长：进行中写「进行中」，不补 0。
    private func durationText(_ span: TraceSpan) -> String {
        span.kind == .turn && span.isLive
            ? RunTraceCopy.statusRunning
            : RunTraceCopy.durationText(span.durationMs)
    }

    /// 轮头时间区间：**只到分钟**（`HH:mm`）。
    ///
    /// 秒对「哪一轮」没有判别价值，却要吃掉 3 个等宽字符：实测 420pt 下带秒的区间会把
    /// 结束时刻截成 `12:12:…`。精确到秒的时刻在展开后的条目行里仍完整可见。
    private func rangeText(_ span: TraceSpan) -> String {
        guard span.startedAt != nil || span.endedAt != nil else { return RunTraceCopy.unknownTime }
        let codec = RunTraceCodec()
        let start = codec.minuteText(span.startedAt)
        let end = span.endedAt == nil ? RunTraceCopy.statusRunning : codec.minuteText(span.endedAt)
        return start + "–" + end
    }

    // MARK: 占位（不空白）

    private func placeholder(_ title: String, _ symbol: String, _ detail: String? = nil) -> some View {
        KitEmptyState(
            title: title,
            systemImage: symbol,
            description: (detail?.isEmpty ?? true) ? nil : detail
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
