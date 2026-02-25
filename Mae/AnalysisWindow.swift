//
//  AnalysisWindow.swift
//  Mae
//
//  Created by Joao Simi on 23/02/26.
//

import SwiftUI
import AppKit

class AnalysisWindowManager {
    static let shared = AnalysisWindowManager()
    private var window: NSWindow?

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = AnalysisView()
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        
        newWindow.contentView = NSHostingView(rootView: contentView)
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeWindow() {
        window?.close()
    }
}

struct AnalysisView: View {
    @ObservedObject var viewModel = AssistantViewModel.shared
    @State private var followUpText: String = ""
    @State private var showConfirmation = false
    @State private var localImage: NSImage? = nil
    @FocusState private var isFollowUpFocused: Bool
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                HStack(spacing: 0) {
                    // Left Panel: Analysis
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack(spacing: 12) {
                            Text("Análise de Tela")
                                .font(Theme.Typography.title)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            
                            Spacer()
                            
                            if !viewModel.analysisResult.isEmpty && !viewModel.isAnalyzingScreen {
                                MaeIconButton(
                                    icon: "arrow.trianglehead.2.counterclockwise.rotate.90",
                                    color: Theme.Colors.accent,
                                    bgColor: Theme.Colors.accentSubtle,
                                    helpText: "Nova análise de tela"
                                ) {
                                    Task { await viewModel.processarScreen() }
                                }
                                .transition(.maeScaleFade)
                                
                                MaeIconButton(
                                    icon: "bubble.left.and.bubble.right.fill",
                                    color: Theme.Colors.accent,
                                    bgColor: Theme.Colors.accentSubtle,
                                    helpText: "Transferir análise para o chat principal"
                                ) {
                                    withAnimation(Theme.Animation.gentle) {
                                        showConfirmation = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                        viewModel.continueWithAnalysis(followUp: followUpText.isEmpty ? nil : followUpText)
                                        followUpText = ""
                                        AnalysisWindowManager.shared.closeWindow()
                                        showConfirmation = false
                                    }
                                }
                                .transition(.maeScaleFade)
                            }
                        }
                        .padding(.top, 30)
                        .padding(.bottom, 12)
                        .padding(.horizontal, Theme.Metrics.spacingXLarge)
                            
                        // Content
                        if viewModel.isAnalyzingScreen {
                            VStack(spacing: Theme.Metrics.spacingLarge) {
                                Spacer()
                                ProgressView()
                                    .controlSize(.regular)
                                Text("Analisando...")
                                    .font(Theme.Typography.bodyBold)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Text("Processando captura de tela com IA...")
                                    .font(Theme.Typography.bodySmall)
                                    .foregroundColor(Theme.Colors.textMuted)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else if viewModel.analysisResult.isEmpty {
                            VStack {
                                Spacer()
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40, weight: .ultraLight))
                                    .foregroundColor(Theme.Colors.accent.opacity(0.3))
                                    .padding(.bottom, 8)
                                Text("Nenhuma análise disponível.")
                                    .font(Theme.Typography.bodySmall)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Text("Pressione ⌘+⇧+Z para capturar sua tela")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textMuted)
                                    .padding(.top, 4)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ScrollView {
                                MarkdownWebView(markdown: viewModel.analysisResult)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, Theme.Metrics.spacingXLarge)
                            }
                        }
                        
                        // Follow-up input area
                        if !viewModel.analysisResult.isEmpty && !viewModel.isAnalyzingScreen {
                            VStack(spacing: 0) {
                                MaeDivider()
                                
                                HStack(spacing: 10) {
                                    TextField("Perguntar algo sobre a análise...", text: $followUpText, axis: .vertical)
                                        .maeInputStyle(cornerRadius: Theme.Metrics.radiusSmall)
                                        .lineLimit(1...4)
                                        .focused($isFollowUpFocused)
                                        .onSubmit {
                                            if !followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                viewModel.continueWithAnalysis(followUp: followUpText)
                                                followUpText = ""
                                                AnalysisWindowManager.shared.closeWindow()
                                            }
                                        }
                                    
                                    Button {
                                        viewModel.continueWithAnalysis(followUp: followUpText)
                                        followUpText = ""
                                        AnalysisWindowManager.shared.closeWindow()
                                    } label: {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(
                                                followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                                ? Theme.Colors.textMuted : Theme.Colors.accent
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, Theme.Metrics.spacingXLarge)
                                .padding(.vertical, Theme.Metrics.spacingDefault)
                            }
                            .transition(.maeSlideUp)
                        }
                    }
                    .frame(width: max(360, geo.size.width * 0.38))
                    .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
                    
                    Divider()
                    
                    // Right Panel: Image
                    VStack {
                        if let image = localImage {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(Theme.Metrics.spacingXLarge)
                                .maeMediumShadow()
                        } else {
                            VStack(spacing: Theme.Metrics.spacingLarge) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 60, weight: .ultraLight))
                                    .foregroundColor(Theme.Colors.textMuted)
                                Text("Nenhuma captura de tela no momento.")
                                    .font(Theme.Typography.bodyBold)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.background)
                }
                
                // Confirmation Toast Overlay
                if showConfirmation {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Theme.Colors.success)
                            Text("Conversa transferida para o chat!")
                                .font(Theme.Typography.bodyBold)
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .padding(.horizontal, Theme.Metrics.spacingXLarge)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .maeMediumShadow()
                        .padding(.bottom, 40)
                    }
                    .transition(.maeSlideUp)
                    .zIndex(10)
                }
            }
        }
        .edgesIgnoringSafeArea(.top)
        .onAppear {
            localImage = viewModel.analysisImage
        }
        .onChange(of: viewModel.analysisImage) { _, newImage in
            if let newImage = newImage {
                localImage = newImage
            }
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
