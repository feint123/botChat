//  Browser.swift — `examples.browser` 的 `panel` 视图面板
//
//  **这个文件不编进 app**：它随插件包分发，由宿主编译（源码形态）或直接加载（预编形态）成 bundle。
//  契约见 `docs/extension-panel-native.md`，本文件对应 §四「内嵌网页」那份边界。
//
//  ## 与其它样例最大的不同：`update(data:)` MUST NOT 重建 `WKWebView`
//
//  `HelloMain.swift` 之类样例在每次 `update(data:)` 里换掉 `hosting.rootView` —— 对无状态视图
//  没问题，对浏览器是致命的：换一次根视图就换一个 `WKWebView`，页面会被反复重载、滚动位置与
//  登录态全丢。所以这里反过来做：
//
//  - `WKWebView` 与一个 `@Observable` 数据模型都是**实例持有**，构造时建一次；
//  - `update(data:)` 只改模型字段，根视图**始终是同一个** `NSHostingView`；
//  - SwiftUI 靠 `@Observable` 自己重绘，webview 本体一动不动。
//
//  ## 三条边界的落点
//
//  1. **可出网、可执行远程 JS**：不关 `allowsContentJavaScript`，不注入脚本。
//  2. **MUST NOT 读本地文件**：非 `http`/`https`/`about` 的 scheme 在 `decidePolicyFor` 里取消
//     并给出中文提示；本文件不出现那两个本地文件入口符号（它们是禁用符号，出现即被门禁拒）。
//  3. **不新开窗口**：开窗口的两个构造器都是禁用符号，`target=_blank` 一律在同一个 webview
//     里加载（`createWebViewWith` 返回 nil，再手动 load）。
//
//  颜色只经 `host.panelColor(…)` 取；尺寸只经 `host.metric(…)` 取。MUST NOT 写字面色值 / 字号 / 像素。

import AppKit
import BotChatKit
import Observation
import SwiftUI
import WebKit

// MARK: - 入口

struct BrowserEntry: PanelEntry {
    static func makeInstance(host: PanelHost) -> PanelInstance {
        MainActor.assumeIsolated { BrowserPanel(host: host) }
    }
}

@_cdecl("botchat_panel_entry")
public func browserPanelEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    botchatPanelInstance(BrowserEntry.self, hostRaw)
}

// MARK: - 文案

private enum BrowserCopy {
    static let home = "https://example.com/"
    static let addressPlaceholder = "输入网址（只支持 http / https）"
    static let addressLabel = "网址"
    static let goTitle = "打开"
    static let goSymbol = "arrow.right.circle"
    static let backSymbol = "chevron.backward"
    static let backLabel = "后退"
    static let forwardSymbol = "chevron.forward"
    static let forwardLabel = "前进"
    static let reloadSymbol = "arrow.clockwise"
    static let reloadLabel = "重新加载"
    static let emptyTitle = "还没有加载任何页面"
    static let emptyNote = "在上面输入网址，或按「主页」"
    static let homeSymbol = "house"
    static let homeLabel = "主页"
    static let loading = "加载中"
    static let forbidden = "只允许 http / https 地址；本地文件与其它协议已被拒绝"
    static let failedPrefix = "加载失败："
    static let visitedPrefix = "已加载"
    static let visitedSuffix = "页"
    /// 交互节点 id：与服务端 `ui.py` 的 `payload.get("nodeId") == "commit"` 逐字一致。
    static let commitNode = "commit"
    /// 回传实参键（服务端 `_argument` 读的就是这两个名字）。
    static let urlKey = "url"
    static let titleKey = "title"
}

/// 允许导航的 scheme 白名单（契约的第 2 条边界，唯一判定点）。
private enum BrowserScheme {
    static let allowed: Set<String> = ["http", "https", "about"]

    /// 归一化用户输入：允许省略 scheme（补 `https://`），其余原样解析。
    static func normalize(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: candidate) else { return nil }
        return isAllowed(url) ? url : nil
    }

    static func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return allowed.contains(scheme)
    }
}

// MARK: - 状态

/// 面板可见状态。`@Observable` ⇒ 改字段即重绘，**不需要**换根视图（换根视图会重建 webview）。
@MainActor
@Observable
final class BrowserModel {
    var addressText: String = ""
    var pageTitle: String = ""
    var isLoading: Bool = false
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var failureText: String?
    var visited: Int = 0
    var home: String = BrowserCopy.home
}

// MARK: - 实例

@MainActor
final class BrowserPanel: NSObject, PanelInstance, WKNavigationDelegate, WKUIDelegate {
    private let host: PanelHost
    private let model = BrowserModel()
    private let webView: WKWebView
    private let hosting: NSHostingView<AnyView>
    /// 已经按 `home` 起跳过没有。`update` 会在每次交互后重入，重复起跳会把用户正在看的页面顶掉。
    private var didLoadHome = false

    init(host: PanelHost) {
        self.host = host
        let configuration = WKWebViewConfiguration()
        // 边界 1：JS 不关（用户裁定的三条之一）。想收紧就改这一行，别在文档里另立一套口径。
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        self.webView = view
        self.hosting = NSHostingView(
            rootView: AnyView(BrowserView(host: host, model: model, webView: view).panelKitRoot(host))
        )
        super.init()
        view.navigationDelegate = self
        view.uiDelegate = self
        host.log("浏览器面板已创建")
    }

    var rootView: NSView { hosting }

    /// 只更新模型，**不动** `hosting.rootView`、**不动** `webView`。
    func update(data: NSDictionary) {
        let payload = PanelData(data)
        model.visited = payload.int("visited")
        model.home = payload.string("home", BrowserCopy.home)
        if !didLoadHome, let url = BrowserScheme.normalize(model.home) {
            didLoadHome = true
            navigate(to: url)
        }
    }

    // MARK: 导航

    private func navigate(to url: URL) {
        model.failureText = nil
        model.addressText = url.absoluteString
        webView.load(URLRequest(url: url))
    }

    private func report(_ message: String) {
        model.failureText = message
        model.isLoading = false
        host.log(message)
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        model.isLoading = true
        model.failureText = nil
    }

    /// 边界 2 的唯一落点：不白名单的 scheme 一律取消并说明原因。
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }
        if BrowserScheme.isAllowed(url) { return .allow }
        report(BrowserCopy.forbidden)
        return .cancel
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        syncFromWebView()
        model.isLoading = false
        // 活体探针：告诉服务端「又加载完一页」，回包里的计数变了就说明往返真的走通了。
        host.dispatch(
            BrowserCopy.commitNode,
            [
                BrowserCopy.urlKey: webView.url?.absoluteString ?? "",
                BrowserCopy.titleKey: webView.title ?? "",
            ]
        )
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        report(BrowserCopy.failedPrefix + error.localizedDescription)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        report(BrowserCopy.failedPrefix + error.localizedDescription)
    }

    /// 边界 3：`target=_blank` / `window.open` 不新开窗口，改成在同一个 webview 里加载。
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url, BrowserScheme.isAllowed(url) {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    /// 把 webview 的真实状态同步进模型（**唯一**方向：webview 是导航的事实源）。
    private func syncFromWebView() {
        model.canGoBack = webView.canGoBack
        model.canGoForward = webView.canGoForward
        model.pageTitle = webView.title ?? ""
        if let current = webView.url?.absoluteString {
            model.addressText = current
        }
    }
}

// MARK: - 视图

struct BrowserView: View {
    let host: PanelHost
    let model: BrowserModel
    let webView: WKWebView

    var body: some View {
        VStack(alignment: .leading, spacing: host.metric("spacing.s")) {
            toolbar
            if model.isLoading {
                HStack(spacing: host.metric("spacing.xs")) {
                    KitProgress(size: .xs)
                    Text(BrowserCopy.loading)
                        .kitText(.caption, tone: .fgSecondary)
                    Spacer(minLength: 0)
                }
            }
            if let failure = model.failureText {
                KitNotice(failure, severity: .danger)
            }
            WebViewContainer(webView: webView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .padding(host.metric("spacing.m"))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 地址栏 + 导航按钮。地址栏回车即导航，与「打开」按钮同一动作。
    private var toolbar: some View {
        HStack(spacing: host.metric("spacing.xs")) {
            KitButton(icon: BrowserCopy.backSymbol, label: BrowserCopy.backLabel) {
                if webView.canGoBack { webView.goBack() }
            }
            .disabled(!model.canGoBack)
            KitButton(icon: BrowserCopy.forwardSymbol, label: BrowserCopy.forwardLabel) {
                if webView.canGoForward { webView.goForward() }
            }
            .disabled(!model.canGoForward)
            KitButton(icon: BrowserCopy.reloadSymbol, label: BrowserCopy.reloadLabel) {
                webView.reload()
            }
            KitButton(icon: BrowserCopy.homeSymbol, label: BrowserCopy.homeLabel) {
                if let url = BrowserScheme.normalize(model.home) { webView.load(URLRequest(url: url)) }
            }
            addressField
        }
    }

    private var addressField: some View {
        KitInput(
            Binding(
                get: { model.addressText },
                set: { model.addressText = $0 }
            ),
            placeholder: BrowserCopy.addressPlaceholder,
            kind: .text,
            leadingSymbol: "globe",
            accessibilityLabel: BrowserCopy.addressLabel,
            onSubmit: { submitAddress() }
        )
    }

    private func submitAddress() {
        guard let url = BrowserScheme.normalize(model.addressText) else {
            model.failureText = BrowserCopy.forbidden
            return
        }
        model.failureText = nil
        webView.load(URLRequest(url: url))
    }

    /// 页脚：标题 + 「已加载 N 页」（后者是往返探针的显示面）。
    private var footer: some View {
        HStack(spacing: host.metric("spacing.s")) {
            Text(model.pageTitle.isEmpty ? BrowserCopy.emptyTitle : model.pageTitle)
                .kitText(.caption, tone: .fgSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if model.visited > 0 {
                KitTag(
                    "\(BrowserCopy.visitedPrefix) \(model.visited) \(BrowserCopy.visitedSuffix)",
                    role: .info,
                    glyph: .dot
                )
            }
        }
    }
}

/// `WKWebView` 的 SwiftUI 容器。**实例由面板持有**，这里只负责挂上去 ——
/// 若在此处 `makeNSView` 里新建 webview，每次视图重建都会白屏重载。
private struct WebViewContainer: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
