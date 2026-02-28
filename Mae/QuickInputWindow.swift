//
//  QuickInputWindow.swift
//  Mae
//
//  Created by Joao Simi on 27/02/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - NSPanel Subclass (Spotlight-like)

final class QuickInputPanel: NSPanel {

    var onClose: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        close()
    }

    override func close() {
        super.close()
        onClose?()
    }
}

// MARK: - Window Manager

@MainActor
class QuickInputWindowManager {
    static let shared = QuickInputWindowManager()
    private var panel: NSPanel?
    private(set) var isCapturingScreen = false

    func toggleWindow() {
        if panel != nil {
            closeWindow()
        } else {
            AssistantViewModel.shared.pendingAttachments.removeAll()
            openWindow()
        }
    }

    private func openWindow() {
        let newPanel = QuickInputPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 0),
            styleMask: [.borderless, .nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = true
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.animationBehavior = .utilityWindow
        newPanel.sharingType = .none

        newPanel.standardWindowButton(.closeButton)?.isHidden = true
        newPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newPanel.standardWindowButton(.zoomButton)?.isHidden = true

        newPanel.contentView = NSHostingView(rootView: QuickInputView().ignoresSafeArea())

        newPanel.onClose = { [weak self] in
            guard let self, !self.isCapturingScreen else { return }
            self.panel = nil
        }

        newPanel.center()
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = newPanel.frame
            let x = screenFrame.midX - panelFrame.width / 2
            let y = screenFrame.midY + screenFrame.height * 0.15
            newPanel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.panel = newPanel
        NSApp.activate(ignoringOtherApps: true)
        newPanel.makeKeyAndOrderFront(nil)
        newPanel.orderFrontRegardless()
    }

    func closeWindow() {
        guard !isCapturingScreen else { return }
        panel?.close()
        panel = nil
    }

    func captureAndReopen() {
        isCapturingScreen = true
        panel?.close()
        panel = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            let image = AssistantViewModel.shared.captureScreen()

            self.isCapturingScreen = false

            if let image {
                let attachment = ChatAttachment(
                    name: "Captura de Tela", data: nil, content: nil, image: image, isImage: true
                )
                AssistantViewModel.shared.pendingAttachments.append(attachment)
            }

            self.openWindow()
        }
    }
}

// MARK: - Quick Input View

struct QuickInputView: View {
    @ObservedObject private var viewModel = AssistantViewModel.shared
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    private var hasContent: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !viewModel.pendingAttachments.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.pendingAttachments.isEmpty {
                attachmentsPreview
            }

            inputBar
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.radiusLarge, style: .continuous)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
        .frame(width: 680)
        .onAppear {
            isInputFocused = true
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .center, spacing: 10) {
            actionButtons

            TextField("Pergunte algo à Mãe...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onSubmit {
                    send()
                }

            if viewModel.isProcessing {
                MaeTypingDots()
                    .frame(width: 32, height: 32)
                    .transition(.maeScaleFade)
            } else {
                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(hasContent ? Theme.Colors.accent : Theme.Colors.textMuted)
                        .symbolEffect(.bounce, options: .nonRepeating)
                }
                .buttonStyle(.plain)
                .disabled(!hasContent)
                .maePressEffect()
                .transition(.maeScaleFade)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 4) {
            MaeIconButton(icon: "plus.circle.fill", size: 18, color: Theme.Colors.textSecondary, helpText: "Anexar arquivo") {
                attachFile()
            }

            MaeIconButton(
                icon: "camera.viewfinder",
                size: 18,
                color: viewModel.pendingAttachments.contains(where: { $0.name == "Captura de Tela" })
                    ? Theme.Colors.accent : Theme.Colors.textSecondary,
                helpText: "Capturar tela"
            ) {
                QuickInputWindowManager.shared.captureAndReopen()
            }
        }
    }

    // MARK: - Attachments Preview

    private var attachmentsPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(viewModel.pendingAttachments.enumerated()), id: \.offset) { index, attachment in
                    ZStack(alignment: .topTrailing) {
                        if attachment.isImage, let img = attachment.image {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall))
                                .overlay(
                                    attachment.name == "Captura de Tela"
                                    ? RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall)
                                        .stroke(Theme.Colors.accent.opacity(0.4), lineWidth: 1)
                                    : nil
                                )
                                .shadow(radius: 2)
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Theme.Colors.accent)
                                    .symbolEffect(.bounce, options: .nonRepeating)
                                Text(attachment.name)
                                    .font(.system(size: 9))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(width: 50)
                            }
                            .frame(width: 60, height: 60)
                            .background(Theme.Colors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall))
                            .shadow(radius: 2)
                        }

                        Button {
                            withAnimation(Theme.Animation.snappy) {
                                let i: Int = index
                                viewModel.pendingAttachments.remove(at: i)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.Colors.textPrimary, Theme.Colors.background)
                                .symbolEffect(.bounce, options: .nonRepeating)
                        }
                        .buttonStyle(.plain)
                        .offset(x: 6, y: -6)
                    }
                    .transition(.maeScaleFade)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .transition(.maeSlideUp)
    }

    // MARK: - Actions

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasContent && !viewModel.isProcessing else { return }

        viewModel.inputText = text

        Task {
            await viewModel.sendManualMessage()
        }

        QuickInputWindowManager.shared.closeWindow()
    }

    private func attachFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.image, UTType.plainText, UTType.pdf, UTType.json, UTType.sourceCode, UTType.data]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let attachment = viewModel.attachment(from: url) {
                    withAnimation(Theme.Animation.snappy) {
                        viewModel.pendingAttachments.append(attachment)
                    }
                }
            }
        }
    }
}
