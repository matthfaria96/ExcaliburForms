import AppKit
import ExcaliburCore
import Foundation
import UniformTypeIdentifiers
import WebKit

/// Uma imagem devolvida pelo editor.
struct ExportedImage {
    let data: Data
    let mimeType: String
    let scope: String
}

enum ExcaliburError: LocalizedError {
    case export

    var errorDescription: String? {
        switch self {
        case .export: return "O editor não devolveu uma imagem válida."
        }
    }
}

/// Ponte entre a janela nativa e a página do editor. Recebe `ready`/`save`/
/// `state`/`error` pelo handler `excalibur` e chama `window.excalibur.*` via
/// `callAsyncJavaScript`, sempre passando dados em `arguments` (nunca
/// interpolando texto em JavaScript).
@MainActor
final class EditorController: NSObject, ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var activeTool: Tool?
    @Published private(set) var hasSelection = false
    @Published private(set) var editorTheme: EditorTheme = .light
    @Published private(set) var strokeColor: String? = TextColor.defaultHex
    @Published private(set) var highlightColor: String? = HighlightColor.defaultHex
    @Published private(set) var textSelection: TextSelection?
    @Published private(set) var stickySelection: StickySelection?
    @Published private(set) var layers: [LayerItem] = []
    @Published var lastError: String?

    let webView: WKWebView

    private let library: BoardLibrary
    private var currentBoardID: Board.ID?
    private var pendingBoardID: Board.ID?
    private var desiredTheme: EditorTheme = .light

    static let messageHandlerName = "excalibur"

    init(library: BoardLibrary) {
        self.library = library
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(
            WebAssetsSchemeHandler(root: Self.webRoot),
            forURLScheme: WebAssetsSchemeHandler.scheme
        )
        let userContent = WKUserContentController()
        configuration.userContentController = userContent
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        userContent.add(WeakScriptMessageHandler(self), name: Self.messageHandlerName)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.load(URLRequest(url: WebAssetsSchemeHandler.entryURL))
    }

    /// Pasta com os artefatos do editor. No app empacotado fica em
    /// `Resources/web`; em desenvolvimento, cai na build do Vite ao lado do
    /// repositório.
    static var webRoot: URL {
        if let resource = Bundle.main.resourceURL {
            let web = resource.appendingPathComponent("web", isDirectory: true)
            if FileManager.default.fileExists(atPath: web.path) {
                return web
            }
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return cwd.appendingPathComponent("excalidraw/excalibur-web/build", isDirectory: true)
    }

    // MARK: - Mensagens da página

    private func handle(_ body: [String: Any]) {
        switch body["type"] as? String {
        case "ready":
            isReady = true
            invoke("window.excalibur.setTheme(theme)", arguments: ["theme": desiredTheme.rawValue])
            if let id = pendingBoardID, let board = library.boards.first(where: { $0.id == id }) {
                pendingBoardID = nil
                loadBoardNow(board)
            } else if let board = library.selectedBoard {
                loadBoardNow(board)
            }
        case "save":
            handleSave(body)
        case "state":
            handleState(body)
        case "error":
            lastError = body["message"] as? String
        default:
            break
        }
    }

    private func handleSave(_ body: [String: Any]) {
        guard let boardId = body["boardId"] as? String,
              let scene = body["scene"] as? String,
              Board.isSafeIdentifier(boardId)
        else {
            lastError = "O editor enviou um quadro inválido."
            return
        }
        let rawFiles = body["files"] as? [Any] ?? []
        let files: [Data] = rawFiles.compactMap { raw in
            guard let dict = raw as? [String: Any] else { return nil }
            return try? JSONSerialization.data(withJSONObject: dict)
        }
        library.save(id: boardId, scene: scene, files: files)
    }

    private func handleState(_ body: [String: Any]) {
        activeTool = (body["tool"] as? String).flatMap(Tool.init(rawValue:))
        hasSelection = body["hasSelection"] as? Bool ?? false
        if let theme = body["theme"] as? String {
            editorTheme = theme == "dark" ? .dark : .light
        }
        strokeColor = body["strokeColor"] as? String
        highlightColor = body["highlightColor"] as? String

        if let text = body["text"] as? [String: Any],
           let fontSize = text["fontSize"] as? Double,
           let fontWeight = text["fontWeight"] as? String,
           let textAlign = text["textAlign"] as? String {
            textSelection = TextSelection(
                fontSize: fontSize,
                fontWeight: fontWeight,
                textAlign: textAlign,
                highlighted: text["highlighted"] as? Bool ?? false
            )
        } else {
            textSelection = nil
        }

        if let sticky = body["sticky"] as? [String: Any],
           let backgroundColor = sticky["backgroundColor"] as? String,
           let fontSize = sticky["fontSize"] as? Double {
            stickySelection = StickySelection(
                backgroundColor: backgroundColor,
                fontSize: fontSize
            )
        } else {
            stickySelection = nil
        }

        layers = (body["layers"] as? [[String: Any]] ?? []).compactMap { dict in
            guard let id = dict["id"] as? String,
                  let label = dict["label"] as? String,
                  let type = dict["type"] as? String
            else { return nil }
            return LayerItem(
                id: id,
                label: label,
                type: type,
                selected: dict["selected"] as? Bool ?? false
            )
        }
    }

    // MARK: - Chamadas à página

    func loadBoard(_ board: Board) {
        currentBoardID = board.id
        guard isReady else {
            pendingBoardID = board.id
            return
        }
        loadBoardNow(board)
    }

    private func loadBoardNow(_ board: Board) {
        let content = library.loadContent(board.id)
        let payload: [String: Any] = [
            "id": board.id,
            "scene": content?.scene ?? NSNull(),
            "files": (content?.files ?? []).map(Self.fileDictionary),
        ]
        invoke("window.excalibur.loadBoard(payload)", arguments: ["payload": payload])
    }

    func setTool(_ tool: Tool) {
        invoke("window.excalibur.setTool(tool)", arguments: ["tool": tool.rawValue])
    }

    func setTheme(_ theme: EditorTheme) {
        desiredTheme = theme
        invoke("window.excalibur.setTheme(theme)", arguments: ["theme": theme.rawValue])
    }

    /// Define a cor padrão do marca-texto da ferramenta texto (`nil` desliga).
    func setHighlight(_ color: String?) {
        invoke("window.excalibur.setHighlight(color)", arguments: ["color": color ?? NSNull()])
    }

    /// Define a cor padrão do texto.
    func setStrokeColor(_ color: String) {
        invoke("window.excalibur.setStrokeColor(color)", arguments: ["color": color])
    }

    /// Executa uma ação do editor (com valor opcional: tamanho, alinhamento…).
    func performAction(_ name: String, value: Any? = nil) {
        let payload: Any = value ?? NSNull()
        invoke("window.excalibur.action(name, value)", arguments: ["name": name, "value": payload])
    }

    /// Seleciona/move/apaga uma camada (front/back/up/down/delete/select).
    func layerAction(_ id: String, _ action: String) {
        invoke("window.excalibur.layerAction(id, action)", arguments: ["id": id, "action": action])
    }

    func command(_ command: Command) {
        invoke("window.excalibur.command(name)", arguments: ["name": command.rawValue])
    }

    /// Dispara o flush da página sem esperar (encerramento do app).
    func flush() {
        guard isReady else { return }
        webView.callAsyncJavaScript(
            "return window.excalibur.flush()",
            arguments: [:],
            in: nil,
            in: .page,
            completionHandler: { _ in }
        )
    }

    /// Espera a página gravar o que estiver pendente (trocar/duplicar/excluir).
    func flushAndWait() async {
        guard isReady else { return }
        _ = try? await webView.callAsyncJavaScript(
            "return window.excalibur.flush()",
            arguments: [:],
            contentWorld: .page
        )
    }

    func exportImage(
        format: ExportFormat,
        scope: ExportScope,
        scale: Double = 2
    ) async throws -> ExportedImage {
        let request: [String: Any] = [
            "format": format.rawValue,
            "scope": scope.rawValue,
            "scale": scale,
        ]
        let result = try await webView.callAsyncJavaScript(
            "return window.excalibur.exportImage(request)",
            arguments: ["request": request],
            contentWorld: .page
        )
        guard let dict = result as? [String: Any],
              let base64 = dict["base64"] as? String,
              let mimeType = dict["mimeType"] as? String,
              let scopeName = dict["scope"] as? String,
              let data = Data(base64Encoded: base64)
        else {
            throw ExcaliburError.export
        }
        return ExportedImage(data: data, mimeType: mimeType, scope: scopeName)
    }

    private func invoke(_ functionBody: String, arguments: [String: Any]) {
        guard isReady else { return }
        Task {
            do {
                _ = try await webView.callAsyncJavaScript(
                    functionBody,
                    arguments: arguments,
                    contentWorld: .page
                )
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private static func fileDictionary(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}

// MARK: - WKScriptMessageHandler

extension EditorController: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == Self.messageHandlerName,
              let body = message.body as? [String: Any]
        else { return }
        handle(body)
    }
}

// MARK: - WKUIDelegate

extension EditorController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.allowedContentTypes = [.image]
        let done: (NSApplication.ModalResponse) -> Void = { response in
            completionHandler(response == .OK ? panel.urls : nil)
        }
        if let window = webView.window {
            panel.beginSheetModal(for: window, completionHandler: done)
        } else {
            done(panel.runModal())
        }
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url, navigationAction.targetFrame == nil {
            NSWorkspace.shared.open(url)
        }
        return nil
    }
}

// MARK: - WKNavigationDelegate

extension EditorController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if url.scheme == WebAssetsSchemeHandler.scheme {
            decisionHandler(.allow)
            return
        }
        // Links externos abrem no navegador do sistema.
        if navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
        }
        decisionHandler(.cancel)
    }
}

/// O `WKUserContentController` retém o handler; esta ponte evita o ciclo com o
/// `EditorController` (dono do webview).
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
