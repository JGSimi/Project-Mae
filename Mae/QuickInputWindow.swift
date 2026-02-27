//
//  QuickInputWindow.swift
//  Mae
//
//  Created by Joao Simi on 27/02/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Window Manager

class QuickInputWindowManager {
    static let shared = QuickInputWindowManager()
    private var panel: NSPanel?

    func toggleWindow() {
        if let panel = panel, panel.isVisible {
            closeWindow()
        } else {
            showWindow()
        }
    }

    func showWindow() {
        if let panel = panel {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = QuickInputView()

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 72),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true
        newPanel.isMovableByWindowBackground = true
        newPanel.isReleasedWhenClosed = false
        newPanel.hidesOnDeactivate = false
        newPanel.animationBehavior = .utilityWindow
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.layer?.cornerRadius = Theme.Metrics.radiusLarge
        hostingView.layer?.masksToBounds = true
        newPanel.contentView = hostingView

        newPanel.center()
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = newPanel.frame
            let x = screenFrame.midX - panelFrame.width / 2
            let y = screenFrame.midY + screenFrame.height * 0.15
            newPanel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.panel = newPanel
        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        panel?.orderOut(nil)
    }

    func updatePanelHeight(_ height: CGFloat) {
        guard let panel = panel else { return }
        let frame = panel.frame
        let newHeight = max(72, min(height, 400))
        let newOrigin = NSPoint(x: frame.origin.x, y: frame.origin.y + frame.height - newHeight)
        panel.setFrame(NSRect(origin: newOrigin, size: NSSize(width: frame.width, height: newHeight)), display: true, animate: true)
    }
}

// MARK: - Quick Input View

struct QuickInputView: View {
    @ObservedObject private var viewModel = AssistantViewModel.shared
    @State private var inputText: String = ""
    @State private var localAttachments: [ChatAttachment] = []
    @State private var screenshotImage: NSImage? = nil
    @State private var isAppearing = false
    @FocusState private var isInputFocused: Bool

    private var hasContent: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !localAttachments.isEmpty
        || screenshotImage != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            if !localAttachments.isEmpty || screenshotImage != nil {
                attachmentsPreview
            }

            inputBar
        }
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.radiusLarge, style: .continuous)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 30, y: 10)
        .padding(1)
        .scaleEffect(isAppearing ? 1.0 : 0.95)
        .opacity(isAppearing ? 1.0 : 0.0)
        .onAppear {
            withAnimation(Theme.Animation.smooth) {
                isAppearing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
        .onExitCommand {
            dismiss()
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
                }
                .buttonStyle(.plain)
                .disabled(!hasContent)
                .keyboardShortcut(.defaultAction)
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

            MaeIconButton(icon: "camera.viewfinder", size: 18, color: screenshotImage != nil ? Theme.Colors.accent : Theme.Colors.textSecondary, helpText: "Capturar tela") {
                captureScreenshot()
            }
        }
    }

    // MARK: - Attachments Preview

    private var attachmentsPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if let screenshot = screenshotImage {
                    ZStack(alignment: .topTrailing) {
                        Image(nsImage: screenshot)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall)
                                    .stroke(Theme.Colors.accent.opacity(0.4), lineWidth: 1)
                            )

                        Button {
                            withAnimation(Theme.Animation.snappy) {
                                screenshotImage = nil
                                updatePanelSize()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.Colors.textPrimary, Theme.Colors.background)
                        }
                        .buttonStyle(.plain)
                        .offset(x: 6, y: -6)
                    }
                    .transition(.maeScaleFade)
                }

                ForEach(Array(localAttachments.enumerated()), id: \.offset) { index, attachment in
                    ZStack(alignment: .topTrailing) {
                        if attachment.isImage, let img = attachment.image {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall))
                                .shadow(radius: 2)
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Theme.Colors.accent)
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
                                localAttachments.remove(at: index)
                                updatePanelSize()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.Colors.textPrimary, Theme.Colors.background)
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

        var allAttachments = localAttachments
        if let screenshot = screenshotImage {
            allAttachments.insert(
                ChatAttachment(name: "Captura de Tela", data: nil, content: nil, image: screenshot, isImage: true),
                at: 0
            )
        }

        viewModel.inputText = text
        viewModel.pendingAttachments = allAttachments

        inputText = ""
        localAttachments = []
        screenshotImage = nil

        Task {
            await viewModel.sendManualMessage()
        }

        dismiss()
    }

    private func dismiss() {
        withAnimation(Theme.Animation.smooth) {
            isAppearing = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            QuickInputWindowManager.shared.closeWindow()
        }
    }

    private func attachFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.image, UTType.plainText, UTType.pdf, UTType.json, UTType.sourceCode, UTType.data]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let attachment = viewModel.attachment(from: url) {
                    withAnimation(Theme.Animation.snappy) {
                        localAttachments.append(attachment)
                    }
                }
            }
            updatePanelSize()
        }
    }

    private func captureScreenshot() {
        QuickInputWindowManager.shared.closeWindow()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let image = AssistantViewModel.shared.captureScreen()

            DispatchQueue.main.async {
                if let image = image {
                    self.screenshotImage = image
                }
                QuickInputWindowManager.shared.showWindow()
                updatePanelSize()
            }
        }
    }

    private func updatePanelSize() {
        let hasAttachments = !localAttachments.isEmpty || screenshotImage != nil
        let height: CGFloat = hasAttachments ? 150 : 72
        QuickInputWindowManager.shared.updatePanelHeight(height)
    }
}
