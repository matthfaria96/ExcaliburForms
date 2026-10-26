import AppKit
import SwiftUI

/// Janela principal: o canvas ocupa tudo; sobre ele flutuam o painel de
/// quadros (esquerda) e o inspetor do que está selecionado (rodapé). A barra
/// da janela tem só o painel, as ferramentas e o compartilhar.
struct ContentView: View {
    @EnvironmentObject private var library: BoardLibrary
    @EnvironmentObject private var editor: EditorController
    @EnvironmentObject private var ui: WorkspaceUI

    @AppStorage("appearance") private var appearance: Appearance = .system

    /// Largura reservada à direita do rodapé para o zoom do editor.
    private let footerReserve: CGFloat = 150

    var body: some View {
        ZStack(alignment: .topLeading) {
            EditorView(webView: editor.webView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if ui.panelVisible {
                // clicar no canvas fecha o painel (pedido do usuário)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { ui.togglePanel() }

                BoardsPanel()
                    .frame(width: 260)
                    .frame(maxHeight: .infinity)
                    .floatingPanel()
                    .padding(10)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            ZoomControl()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(14)

            GeometryReader { proxy in
                let insets = inspectorInsets(width: proxy.size.width)
                InspectorBar()
                    .padding(.leading, insets.leading)
                    .padding(.trailing, insets.trailing)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            }
            .padding(.bottom, 14)
                .opacity(showsInspector ? 1 : 0)
                .offset(y: showsInspector ? 0 : 14)
                .allowsHitTesting(showsInspector)
                .animation(.smooth(duration: 0.22), value: showsInspector)
        }
        .frame(minWidth: 760, minHeight: 520)
        .navigationTitle(library.selectedBoard?.name ?? "ExcaliburForms")
        .toolbar { toolbarContent }
        .confirmationDialog(
            "Excluir quadro?",
            isPresented: deleteConfirmation,
            presenting: ui.boardToDelete
        ) { board in
            Button("Excluir \"\(board.name)\"", role: .destructive) {
                BoardActions.delete(board, library: library, editor: editor)
                ui.boardToDelete = nil
            }
            Button("Cancelar", role: .cancel) { ui.boardToDelete = nil }
        } message: { board in
            Text("\"\(board.name)\" vai para o Lixo. Os outros quadros não mudam.")
        }
        .alert("Algo deu errado", isPresented: errorPresented) {
            Button("OK", role: .cancel) {
                editor.lastError = nil
                library.errorMessage = nil
            }
        } message: {
            Text(editor.lastError ?? library.errorMessage ?? "")
        }
        .preferredColorScheme(colorScheme)
        .onAppear { applyAppearance() }
        .onChange(of: appearance) { _, _ in applyAppearance() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            applyAppearance()
        }
    }

    /// Margens do inspetor: fica entre o painel de quadros e o zoom; numa
    /// janela estreita, centraliza sobre o canvas (por cima do painel).
    private func inspectorInsets(width: CGFloat) -> (leading: CGFloat, trailing: CGFloat) {
        let panel: CGFloat = ui.panelVisible ? 280 : footerReserve
        if width - panel - footerReserve >= 420 {
            return (panel, footerReserve)
        }
        return (footerReserve, footerReserve)
    }

    private var showsInspector: Bool {
        editor.hasSelection
            || editor.activeTool == .text
            || editor.activeTool == .stickynote
            || editor.shapeSelection != nil
    }

    // MARK: - Barra da janela

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                ui.togglePanel()
            } label: {
                Label("Quadros", systemImage: "sidebar.left")
            }
            .help(ui.panelVisible ? "Ocultar quadros (⌃⌘S)" : "Mostrar quadros (⌃⌘S)")
        }
        ToolbarItem(placement: .principal) {
            ToolPalette()
        }
        ToolbarItem(placement: .primaryAction) {
            ShareMenu {
                Button {
                    ExportService.copyPNG(editor)
                } label: {
                    Label("Copiar como imagem", systemImage: "doc.on.doc")
                }
                Divider().padding(.vertical, 4)
                exportRow(.png, scope: .auto, title: "Exportar PNG…", symbol: "photo")
                exportRow(.svg, scope: .auto, title: "Exportar SVG…", symbol: "square.on.circle")
                exportRow(.png, scope: .viewport, title: "Área visível (PNG)…", symbol: "viewfinder")
            }
        }
    }

    /// Linha de exportação; `auto` = a seleção, ou o quadro sem seleção.
    private func exportRow(
        _ format: ExportFormat,
        scope: ExportScope,
        title: String,
        symbol: String
    ) -> some View {
        Button {
            ExportService.export(
                editor,
                format: format,
                scope: scope,
                suggestedName: library.selectedBoard?.name ?? "Quadro"
            )
        } label: {
            Label(title, systemImage: symbol)
        }
    }

    // MARK: - Aparência

    private func applyAppearance() {
        editor.setTheme(resolvedEditorTheme)
    }

    private var resolvedEditorTheme: EditorTheme {
        switch appearance {
        case .light: return .light
        case .dark: return .dark
        case .system:
            let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? .dark : .light
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { editor.lastError != nil || library.errorMessage != nil },
            set: {
                if !$0 {
                    editor.lastError = nil
                    library.errorMessage = nil
                }
            }
        )
    }

    private var deleteConfirmation: Binding<Bool> {
        Binding(
            get: { ui.boardToDelete != nil },
            set: { if !$0 { ui.boardToDelete = nil } }
        )
    }
}

// MARK: - Ferramentas

/// As ferramentas, numa só cápsula na barra da janela. Formas viram um menu
/// que lembra a última forma usada (como no Freeform).
private struct ToolPalette: View {
    @EnvironmentObject private var editor: EditorController
    @AppStorage("lastShapeTool") private var lastShape: Tool = .rectangle

    private static let shapes: [Tool] = [.rectangle, .ellipse, .diamond, .line]

    var body: some View {
        HStack(spacing: 2) {
            tool(.selection)
            tool(.hand)
            gap
            tool(.text)
            tool(.stickynote)
            tool(.image)
            gap
            shapeTool
            tool(.arrow)
            tool(.freedraw)
            tool(.eraser)
        }
        .padding(.horizontal, 4)
        .onChange(of: editor.activeTool) { _, tool in
            if let tool, Self.shapes.contains(tool) { lastShape = tool }
        }
    }

    private var gap: some View {
        Divider().frame(height: 16).padding(.horizontal, 4)
    }

    private func tool(_ tool: Tool) -> some View {
        Button {
            editor.setTool(tool)
        } label: {
            Image(systemName: tool.systemImage)
        }
        .buttonStyle(ToolButtonStyle(isActive: editor.activeTool == tool))
        .help(tool.helpText)
    }

    /// Clique usa a última forma; a setinha abre as outras.
    private var shapeTool: some View {
        let active = editor.activeTool.map(Self.shapes.contains) ?? false
        return HStack(spacing: 0) {
            Button {
                editor.setTool(lastShape)
            } label: {
                Image(systemName: lastShape.systemImage)
            }
            .buttonStyle(ToolButtonStyle(isActive: active))
            .help(lastShape.helpText)

            Menu {
                ForEach(Self.shapes) { shape in
                    Button {
                        editor.setTool(shape)
                    } label: {
                        Label(shape.label, systemImage: shape.systemImage)
                    }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .frame(width: 14, height: 28)
            .help("Outras formas")
        }
    }
}

/// Botão de ferramenta: ícone com destaque em accent quando ativo.
private struct ToolButtonStyle: ButtonStyle {
    let isActive: Bool
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .frame(width: 32, height: 28)
            .foregroundStyle(isActive ? Color.white : Color.primary.opacity(0.85))
            .background(
                Capsule(style: .continuous)
                    .fill(fill(pressed: configuration.isPressed))
            )
            .contentShape(Capsule(style: .continuous))
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isActive)
    }

    private func fill(pressed: Bool) -> Color {
        if isActive { return .accentColor }
        if pressed { return Color.primary.opacity(0.14) }
        return hovering ? Color.primary.opacity(0.07) : .clear
    }
}

private extension Tool {
    var helpText: String {
        shortcut.map { "\(label) (\($0))" } ?? label
    }
}

// MARK: - Compartilhar e zoom

/// Botão "Exportar" em destaque na barra (botão de verdade: um `Menu` a barra
/// reduz a só o ícone). Abre um painel com as opções, como o do Freeform.
private struct ShareMenu<Items: View>: View {
    @ViewBuilder let items: Items
    @State private var open = false

    var body: some View {
        let button = Button {
            open.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                Text("Exportar")
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 6)
        }
        .help("Copiar ou exportar o quadro")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            SharePanel(close: { open = false }) { items }
        }

        if #available(macOS 26.0, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.borderedProminent)
        }
    }
}

/// Conteúdo do painel de exportar: os itens do menu como botões de linha.
private struct SharePanel<Items: View>: View {
    let close: () -> Void
    @ViewBuilder let items: Items

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            items
        }
        .buttonStyle(ShareRowStyle(close: close))
        .menuStyle(.borderlessButton)
        .padding(8)
        .frame(width: 240)
    }
}

/// Linha clicável do painel de exportar (realce no hover, fecha ao clicar).
private struct ShareRowStyle: ButtonStyle {
    let close: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        ShareRow(configuration: configuration, close: close)
    }

    private struct ShareRow: View {
        let configuration: ButtonStyleConfiguration
        let close: () -> Void
        @State private var hovering = false

        var body: some View {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(hovering ? Color.accentColor : .clear)
                )
                .foregroundStyle(hovering ? Color.white : Color.primary)
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
                .onChange(of: configuration.isPressed) { _, pressed in
                    if !pressed { close() }
                }
        }
    }
}

/// Zoom no canto inferior direito: − porcentagem +, numa cápsula de vidro.
/// Clicar na porcentagem volta a 100%.
private struct ZoomControl: View {
    @EnvironmentObject private var editor: EditorController

    var body: some View {
        HStack(spacing: 2) {
            Button {
                editor.command(.zoomOut)
            } label: {
                Image(systemName: "minus")
            }
            .help("Afastar (⌘−)")

            Button {
                editor.command(.resetZoom)
            } label: {
                Text("\(Int((editor.zoom * 100).rounded()))%")
                    .monospacedDigit()
                    .frame(minWidth: 44)
            }
            .help("Tamanho real (⌘0)")

            Button {
                editor.command(.zoomIn)
            } label: {
                Image(systemName: "plus")
            }
            .help("Aproximar (⌘+)")
        }
        .buttonStyle(InspectorButtonStyle(showsTitle: true))
        .font(.system(size: 12, weight: .semibold))
        .inspectorCapsule()
    }
}
