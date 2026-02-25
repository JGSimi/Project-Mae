import SwiftUI

let md = """
## Analysis
* Item 1
* Item 2
  * Subitem
"""

if let attr = try? AttributedString(markdown: md, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)) {
    print("Parsed successfully!")
    print(attr.description)
} else {
    print("Failed")
}
