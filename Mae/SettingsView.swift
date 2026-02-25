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
                    .font(Theme.Typography.heading)
                    .foregroundStyle(Theme.Colors.textPrimary)
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
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            
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
                    
                    Divider().background(Theme.Colors.border)
                    
                    // Row do Modelo Ativo
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Modelo Ativo")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Theme.Colors.accent)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: Theme.Colors.accent.opacity(0.4), radius: 3)
                                
                                Text(inferenceMode == .local ? localModelName : "\(selectedProvider.rawValue) • \(apiModelName)")
                                    .font(Theme.Typography.bodyBold)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .background(Theme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusLarge, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.radiusLarge, style: .continuous)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
                
                Spacer()
                
                // Botão de Atualização Sleek
                Button {
                    UpdaterController.shared.checkForUpdates()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(Theme.Typography.bodySmall)
                            .foregroundStyle(Theme.Colors.accent.opacity(0.8))
                        Text("Verificar Atualizações")
                            .font(Theme.Typography.bodyBold)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous)
                            .stroke(Theme.Colors.border, lineWidth: 1)
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
                            .font(Theme.Typography.bodySmall)
                        Text("Configurações Avançadas")
                            .font(Theme.Typography.bodyBold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous)
                            .stroke(Theme.Colors.border, lineWidth: 1)
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
                Theme.Colors.backgroundSecondary.ignoresSafeArea()
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
