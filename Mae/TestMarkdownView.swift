import SwiftUI

struct TestMarkdownView: View {
    let markdown = """
    ## Análise
    * Item 1
    * Item 2
      * Subitem
    **Bold text** with `code`
    """
    
    var body: some View {
        ScrollView {
            // Native SwiftUI Markdown!
            if let attr = try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .full)) {
                Text(attr)
                    .padding()
            } else {
                Text(markdown)
            }
        }
        .frame(width: 400, height: 300)
    }
}

// Preview to check compilation
#Preview {
    TestMarkdownView()
}
