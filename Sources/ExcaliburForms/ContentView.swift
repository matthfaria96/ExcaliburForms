import AppKit
import SwiftUI

/// Janela principal: lista de quadros + editor, barra de ferramentas com as
/// ferramentas e menus de exportação/apariência.
struct ContentView: View {
    @EnvironmentObject private var library: BoardLibrary
    @EnvironmentObject private var editor: EditorController

    @AppStorage("appearance") private var appearance: Appearance = .system
    @State private var shapesHovering = false

    var body: some View {
        NavigationSplitView {
            BoardList()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            EditorView(webView: editor.webView)
                .navigationTitle(library.selectedBoard?.name ?? "ExcaliburForms")
        }
        .frame(minWidth: 900, minHeight: 560)
        .toolbar { toolbarContent }
        .alert(
            "ExcaliburForms",
            isPresented: errorPresented
        ) {
            Button("OK", role: .cancel) { editor.lastError = nil }
        } message: {
            Text(editor.lastError ?? "")
        }
        .preferredColorScheme(colorScheme)
        .onAppear { applyAppearance() }
        .onChange(of: appearance) { _, _ in applyAppearance() }
    }

    // MARK: - Barra de ferramentas

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            toolsBar
        }
        ToolbarItemGroup(placement: .primaryAction) {
            exportMenu
            appearanceMenu
        }
    }

    private var toolsBar: some View {
        HStack(spacing: 4) {
            ToolButton(tool: .selection, isActive: editor.activeTool == .selection) {
                editor.setTool(.selection)
            }
            ToolButton(tool: .hand, isActive: editor.activeTool == .hand) {
                editor.setTool(.hand)
            }
            separator
            ToolButton(tool: .image, isActive: editor.activeTool == .image) {
                editor.setTool(.image)
            }
            ToolButton(tool: .text, isActive: editor.activeTool == .text) {
                editor.setTool(.text)
            }
            ToolButton(tool: .stickynote, isActive: editor.activeTool == .stickynote) {
                editor.setTool(.stickynote)
            }
            separator
            shapesMenu
            ToolButton(tool: .arrow, isActive: editor.activeTool == .arrow) {
                editor.setTool(.arrow)
            }
            ToolButton(tool: .freedraw, isActive: editor.activeTool == .freedraw) {
                editor.setTool(.freedraw)
            }
        }
    }

    private var separator: some View {
        Divider()
            .frame(height: 16)
            .padding(.horizontal, 3)
    }

    private var shapesActive: Bool {
        [Tool.rectangle, .ellipse, .diamond, .line].contains(editor.activeTool ?? .selection)
    }

    private var shapesMenu: some View {
        Menu {
            ForEach([Tool.rectangle, .ellipse, .diamond, .line]) { tool in
                Button {
                    editor.setTool(tool)
                } label: {
                    Label(tool.label, systemImage: tool.systemImage)
                }
            }
        } label: {
            Image(systemName: "square.on.circle")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(shapesBackground)
                )
                .foregroundStyle(shapesActive ? Color.accentColor : .secondary)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { shapesHovering = $0 }
        .fixedSize()
        .help("Formas")
    }

    private var shapesBackground: Color {
        if shapesActive {
            return Color.accentColor.opacity(0.2)
        }
        if shapesHovering {
            return Color.primary.opacity(0.07)
        }
        return .clear
    }

    private var exportMenu: some View {
        Menu {
            Button("Copiar imagem (PNG)") {
                ExportService.copyPNG(editor)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            Divider()
            ForEach(ExportFormat.allCases) { format in
                Menu(format.label) {
                    ForEach([ExportScope.board, .selection, .viewport]) { scope in
                        Button(scope.label) {
                            ExportService.export(editor, format: format, scope: scope)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Exportar")
    }

    private var appearanceMenu: some View {
        Menu {
            ForEach(Appearance.allCases) { mode in
                Button {
                    appearance = mode
                } label: {
                    if appearance == mode {
                        Label(mode.label, systemImage: "checkmark")
                    } else {
                        Text(mode.label)
                    }
                }
            }
        } label: {
            Image(systemName: appearanceSymbol)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Aparência")
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

    private var appearanceSymbol: String {
        switch appearance {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { editor.lastError != nil },
            set: { if !$0 { editor.lastError = nil } }
        )
    }
}

// MARK: - Botão de ferramenta

/// Botão de ferramenta da barra nativa: discreto, com hover e estado ativo.
private struct ToolButton: View {
    let tool: Tool
    let isActive: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(background)
                )
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(helpText)
    }

    private var background: Color {
        if isActive {
            return Color.accentColor.opacity(0.2)
        }
        if hovering {
            return Color.primary.opacity(0.07)
        }
        return .clear
    }

    private var helpText: String {
        if let shortcut = tool.shortcut {
            return "\(tool.label)  (\(shortcut))"
        }
        return tool.label
    }
}
