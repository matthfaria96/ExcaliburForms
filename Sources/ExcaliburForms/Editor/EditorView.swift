import SwiftUI
import WebKit

/// O WKWebView do editor dentro da janela SwiftUI.
struct EditorView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
