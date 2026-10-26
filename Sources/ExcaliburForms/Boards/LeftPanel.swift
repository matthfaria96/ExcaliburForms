import SwiftUI

/// Painel flutuante da esquerda com abas de quadros e camadas.
struct LeftPanel: View {
    @State private var tab: Tab = .boards

    enum Tab: String, CaseIterable, Identifiable {
        case boards = "Quadros"
        case layers = "Camadas"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            switch tab {
            case .boards:
                BoardList()
            case .layers:
                LayerList()
            }
        }
    }
}

/// Lista de camadas do quadro, da frente para o fundo: selecionar, reordenar e
/// apagar.
struct LayerList: View {
    @EnvironmentObject private var editor: EditorController

    var body: some View {
        if editor.layers.isEmpty {
            emptyState
        } else {
            List {
                ForEach(editor.layers) { layer in
                    row(layer)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text("Nenhum elemento ainda")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ layer: LayerItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: layer.icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(layer.label)
                .lineLimit(1)
            Spacer()
            if layer.selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
            Menu {
                Button("Trazer para o topo") { editor.layerAction(layer.id, "front") }
                Button("Subir uma camada") { editor.layerAction(layer.id, "up") }
                Button("Descer uma camada") { editor.layerAction(layer.id, "down") }
                Button("Enviar para o fundo") { editor.layerAction(layer.id, "back") }
                Divider()
                Button("Apagar", role: .destructive) { editor.layerAction(layer.id, "delete") }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { editor.layerAction(layer.id, "select") }
    }
}
