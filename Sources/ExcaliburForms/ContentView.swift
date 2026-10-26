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
            Menu {
                Button("Copiar como imagem") { ExportService.copyPNG(editor) }
                Divider()
                exportItems(.png)
                exportItems(.svg)
            } label: {
                Label("Compartilhar", systemImage: "square.and.arrow.up")
            }
            .help("Copiar ou exportar")
        }
    }

    @ViewBuilder
    private func exportItems(_ format: ExportFormat) -> some View {
        Menu("Exportar \(format.label)") {
            ForEach([ExportScope.board, .selection, .viewport]) { scope in
                Button(scope.label) {
                    ExportService.export(
                        editor,
                        format: format,
                        scope: scope,
                        suggestedName: library.selectedBoard?.name ?? "Quadro"
                    )
                }
                .disabled(scope == .selection && !editor.hasSelection)
            }
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fill(pressed: configuration.isPressed))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
