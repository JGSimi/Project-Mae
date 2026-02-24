import SwiftUI

struct SettingsView: View {
    @AppStorage("inferenceMode") var inferenceMode: InferenceMode = .local
    @AppStorage("selectedProvider") var selectedProvider: CloudProvider = .google
    @AppStorage("apiModelName") var apiModelName: String = "gpt-4o-mini"
    @AppStorage("localModelName") var localModelName: String = "gemma3:4b"

    var body: some View {
        VStack(spacing: 0) {
            // Header Minimalista
            HStack {
                Text("M.A.E")
                    .font(.cormorantGaramond(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            VStack(spacing: 12) {
                // Cartão Único Integrado
                VStack(spacing: 0) {
                    // Row de Seleção de Modo
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Processamento")
                                .font(.cormorantGaramond(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.5))
                            
                            Picker("", selection: $inferenceMode) {
                                ForEach(InferenceMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .colorScheme(.dark) // Forçar tint dark para o picker
                        }
                    }
                    .padding(16)
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    // Row do Modelo Ativo
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Modelo Ativo")
                                .font(.cormorantGaramond(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.5))
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(inferenceMode == .local ? Color.green : Color.blue)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: (inferenceMode == .local ? Color.green : Color.blue).opacity(0.5), radius: 3)
                                
                                Text(inferenceMode == .local ? localModelName : "\(selectedProvider.rawValue) • \(apiModelName)")
                                    .font(.cormorantGaramond(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                
                Spacer()
                
                // Botão de Atualização Sleek
                Button {
                    UpdaterController.shared.checkForUpdates()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.cormorantGaramond(size: 14))
                            .foregroundStyle(.cyan.opacity(0.8))
                        Text("Verificar Atualizações")
                            .font(.cormorantGaramond(size: 14, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)
                
                // Botão Avançado Sleek
                Button {
                    AdvancedSettingsWindowManager.shared.showWindow()
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .font(.cormorantGaramond(size: 14))
                        Text("Configurações Avançadas")
                            .font(.cormorantGaramond(size: 14, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.cormorantGaramond(size: 12, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
        }
        // Fundo super escuro (estilo material glass) com gradiente radial sutil para não ficar chapado
        .background(
            ZStack {
                Color(NSColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1.0)).ignoresSafeArea()
                RadialGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.03), .clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 400
                )
            }
        )
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView()
        .frame(width: 320, height: 350)
}
