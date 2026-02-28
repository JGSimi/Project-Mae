import SwiftUI
import MarkdownUI

struct MaeMarkdownView: View {
    let markdown: String

    private var trimmedMarkdown: String {
        markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if trimmedMarkdown.isEmpty {
                Text("")
            } else {
                Markdown(markdown)
                    .markdownTheme(.gitHub)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .tint(Theme.Colors.accent)
                    .textSelection(.enabled)
            }
        }
    }
}
