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
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor(red: 0.1, green: 0.1, blue: 0.11, alpha: 1.0)))
            .overlay(Divider().background(Color.white.opacity(0.1)), alignment: .bottom)
            .zIndex(1)

            VStack(spacing: 20) {
                // Inference Mode Box
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Modo de Processamento")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        
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
                .groupBoxStyle(PremiumQuickGroupBoxStyle())
                
                // Active Model Summary Box
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Modelo Atual")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        
                        if inferenceMode == .local {
                            Text("Ollama: \(localModelName)")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.6))
                        } else {
                            Text("\(selectedProvider.rawValue): \(apiModelName)")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .groupBoxStyle(PremiumQuickGroupBoxStyle())
                
                Spacer()
                
                // Advanced Settings Button
                Button {
                    AdvancedSettingsWindowManager.shared.showWindow()
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Configurações Avançadas...")
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 10)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0)))
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Custom Premium GroupBox Style
struct PremiumQuickGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
            configuration.content
        }
        .padding(16)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

#Preview {
    SettingsView()
        .frame(width: 350, height: 450)
}
