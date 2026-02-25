import SwiftUI
import AppKit

let sample = "Hello **World**"
if let attr = try? AttributedString(markdown: sample) {
    print("Success")
}
