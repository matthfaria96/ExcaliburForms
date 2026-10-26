import Foundation
import UniformTypeIdentifiers
import WebKit

/// Serve a página do editor (em `Resources/web` do app) pelo esquema
/// `excalibur://app/…`. Módulos ES, fontes e `fetch` não funcionam bem em
/// `file://` no WebKit; num esquema próprio a página tem origem estável.
final class WebAssetsSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "excalibur"
    static let entryURL = URL(string: "\(scheme)://app/index.html")!

    private let root: URL

    init(root: URL) {
        self.root = root.standardizedFileURL
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, let fileURL = resolve(url) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": Self.mimeType(for: fileURL),
                    "Content-Length": String(data.count),
                    "Cache-Control": "no-cache",
                ]
            )!
            task.didReceive(response)
            task.didReceive(data)
            task.didFinish()
        } catch {
            task.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    /// Só arquivos dentro da pasta da página (nada de `..` para fora dela).
    private func resolve(_ url: URL) -> URL? {
        let path = url.path.isEmpty || url.path == "/" ? "/index.html" : url.path
        let fileURL = root.appendingPathComponent(String(path.dropFirst())).standardizedFileURL
        guard fileURL.path.hasPrefix(root.path + "/"),
              FileManager.default.fileExists(atPath: fileURL.path)
        else { return nil }
        return fileURL
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "js", "mjs": return "text/javascript; charset=utf-8"
        case "html": return "text/html; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "woff2": return "font/woff2"
        case "wasm": return "application/wasm"
        default:
            return UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
                ?? "application/octet-stream"
        }
    }
}
