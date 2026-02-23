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
                    Text("Análise de Tela")
                        .font(.title2.bold())
                        .padding(.top, 30) // Offset for titlebar
                        .padding(.bottom, 10)
                        
                    if viewModel.isAnalyzingScreen {
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView()
                                .controlSize(.regular)
                            Text("Analisando...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else if viewModel.analysisResult.isEmpty {
                        VStack {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.bottom, 8)
                            Text("Nenhuma análise disponível.")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollView {
                            Text(try! AttributedString(markdown: viewModel.analysisResult, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                                .font(.system(size: 15, weight: .regular))
                                .lineSpacing(6)
                                .foregroundColor(Color.primary.opacity(0.9))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                                .padding(.bottom, 24)
                                .padding(.trailing, 12)
                        }
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
                                .foregroundColor(.secondary.opacity(0.3))
                            Text("Nenhuma captura de tela no momento.")
                                .font(.headline)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
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
