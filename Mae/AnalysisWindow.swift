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
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Left Panel: Analysis
                VStack(alignment: .leading) {
                    HStack {
                        Text("Análise de Tela")
                            .font(Theme.Typography.title)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        
                        Spacer()
                        
                        if !viewModel.analysisResult.isEmpty && !viewModel.isAnalyzingScreen {
                            Button(action: {
                                viewModel.continueWithAnalysis()
                                AnalysisWindowManager.shared.closeWindow()
                            }) {
                                Image(systemName: "message.and.waveform.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.Colors.accent)
                                    .padding(8)
                                    .background(Theme.Colors.surfaceSecondary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Continuar conversa no chat")
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.top, 30) // Offset for titlebar
                    .padding(.bottom, 10)
                        
                    if viewModel.isAnalyzingScreen {
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView()
                                .controlSize(.regular)
                            Text("Analisando...")
                                .font(Theme.Typography.bodyBold)
                                .foregroundColor(Theme.Colors.textSecondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else if viewModel.analysisResult.isEmpty {
                        VStack {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.Colors.textMuted)
                                .padding(.bottom, 8)
                            Text("Nenhuma análise disponível.")
                                .font(Theme.Typography.bodySmall)
                                .foregroundColor(Theme.Colors.textSecondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        MarkdownWebView(markdown: viewModel.analysisResult)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(.horizontal, 24)
                .frame(width: max(320, geo.size.width * 0.35))
                .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
                
                Divider()
                
                // Right Panel: Image
                VStack {
                    if let image = viewModel.analysisImage {
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
        }
        .edgesIgnoringSafeArea(.top)
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
