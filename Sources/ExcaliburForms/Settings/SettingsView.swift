import AppKit
import SwiftUI

/// Janela de Ajustes (⌘,) no padrão do MacDash: abas no topo, linhas
/// agrupadas como nos Ajustes do Sistema e a página Sobre com as licenças.
struct SettingsView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case general = "Geral"
        case about = "Sobre"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .general

    var body: some View {
        VStack(spacing: 16) {
            Picker("Ajustes", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            switch tab {
            case .general: GeneralSettingsView()
            case .about: AboutView()
            }
        }
        .padding(.top, 16)
        .frame(width: 520, height: 460)
    }
}

// MARK: - Geral

private struct GeneralSettingsView: View {
    @AppStorage("appearance") private var appearance: Appearance = .system
    @AppStorage(ExportSettings.scaleKey) private var exportScale: Double = 2
    @AppStorage(ExportSettings.backgroundKey) private var exportBackground = true

    var body: some View {
        Form {
            Section {
                Picker("Aparência", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                }
            } footer: {
                Text("\"Sistema\" acompanha o modo claro ou escuro do Mac.")
                    .settingsFooter()
            }

            Section("Exportação") {
                Picker("Resolução do PNG", selection: $exportScale) {
                    Text("1× (tamanho real)").tag(1.0)
                    Text("2× (Retina)").tag(2.0)
                    Text("3× (alta resolução)").tag(3.0)
                }
                Toggle("Incluir fundo do quadro", isOn: $exportBackground)
            }

            Section {
                LabeledContent("Pasta dos quadros") {
                    Button("Mostrar no Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([BoardLibrary.defaultRoot])
                    }
                }
            } footer: {
                Text("Os quadros são salvos automaticamente nesta pasta. Quadros excluídos vão para o Lixo.")
                    .settingsFooter()
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private extension Text {
    func settingsFooter() -> some View {
        font(.system(size: 11.5)).foregroundStyle(.secondary)
    }
}

// MARK: - Sobre

struct AboutView: View {
    @State private var showLicenses = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
                    .padding(.bottom, 16)

                Text("ExcaliburForms")
                    .font(.system(size: 24, weight: .semibold))
                Text("Versão \(AppVersion.marketing) (\(AppVersion.build))")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.top, 4)

                Text("Um quadro infinito para juntar screenshots, anotar por cima com texto, marca-texto, notas, setas e desenhos, e organizar referências. Tudo fica salvo no seu Mac.")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 400)
                    .padding(.top, 22)

                Text("Feito sobre o Excalidraw, software livre sob a licença MIT, e as fontes listadas nas licenças.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                    .padding(.top, 12)

                HStack(spacing: 18) {
                    Link("witchmymac.com", destination: URL(string: "http://witchmymac.com")!)
                    Button("Licenças de código aberto") { showLicenses = true }
                        .buttonStyle(.link)
                }
                .font(.system(size: 12))
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .scrollIndicators(.never)
        .sheet(isPresented: $showLicenses) { OpenSourceLicensesView() }
    }
}

enum AppVersion {
    static var marketing: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}
