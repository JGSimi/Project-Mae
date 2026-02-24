import SwiftUI

struct SettingsView: View {
    @AppStorage("inferenceMode") var inferenceMode: InferenceMode = .local
    @AppStorage("selectedProvider") var selectedProvider: CloudProvider = .google
    @AppStorage("apiModelName") var apiModelName: String = "gpt-4o-mini"
    @AppStorage("localModelName") var localModelName: String = "gemma3:4b"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Configurações Rápidas", systemImage: "gearshape.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.regularMaterial)
            .overlay(Divider(), alignment: .bottom)
            .zIndex(1)

            VStack(spacing: 20) {
                // Inference Mode Box
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Modo de Processamento")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Picker("", selection: $inferenceMode) {
                            ForEach(InferenceMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .groupBoxStyle(GlassGroupBoxStyle())
                
                // Active Model Summary Box
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Modelo Atual")
                            .font(.headline)
                        
                        if inferenceMode == .local {
                            Text("Ollama: \(localModelName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(selectedProvider.rawValue): \(apiModelName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .groupBoxStyle(GlassGroupBoxStyle())
                
                Spacer()
                
                // Advanced Settings Button
                Button {
                    AdvancedSettingsWindowManager.shared.showWindow()
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Configurações Avançadas...")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 10)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Custom Glass GroupBox Style
struct GlassGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
            configuration.content
        }
        .padding(16)
        .background(.regularMaterial)
    }
}

#Preview {
    SettingsView()
        .frame(width: 350, height: 450)
}
