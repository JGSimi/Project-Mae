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
                                // New analysis button
                                Button(action: {
                                    Task {
                                        await viewModel.processarScreen()
                                    }
                                }) {
                                    Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Theme.Colors.accent)
                                        .padding(8)
                                        .background(Theme.Colors.accentSubtle)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Nova análise de tela")
                                .transition(.scale.combined(with: .opacity))
                                
                                // Continue conversation button with label
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        showConfirmation = true
                                    }
                                    
                                    // Transfer to chat after a brief moment
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                        viewModel.continueWithAnalysis(followUp: followUpText.isEmpty ? nil : followUpText)
                                        followUpText = ""
                                        AnalysisWindowManager.shared.closeWindow()
                                        showConfirmation = false
                                    }
                                }) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Theme.Colors.accent)
                                        .padding(8)
                                        .background(Theme.Colors.accentSubtle)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Transferir análise para o chat principal")
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.top, 30)
                        .padding(.bottom, 12)
                        .padding(.horizontal, 24)
                            
                        // Content
                        if viewModel.isAnalyzingScreen {
                            VStack(spacing: 16) {
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
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.Colors.textMuted)
                                    .padding(.top, 4)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ScrollView {
                                MarkdownWebView(markdown: viewModel.analysisResult)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 24)
                            }
                        }
                        
                        // Follow-up input area
                        if !viewModel.analysisResult.isEmpty && !viewModel.isAnalyzingScreen {
                            VStack(spacing: 0) {
                                Divider().background(Theme.Colors.border)
                                
                                HStack(spacing: 10) {
                                    TextField("Perguntar algo sobre a análise...", text: $followUpText, axis: .vertical)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Theme.Colors.surfaceSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(Theme.Colors.borderHighlight, lineWidth: 1)
                                        )
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
                                                ? Theme.Colors.textSecondary : Theme.Colors.accent
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
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
                                .padding(24)
                                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 60))
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
                                .foregroundStyle(.green)
                            Text("Conversa transferida para o chat!")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                        .padding(.bottom, 40)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
