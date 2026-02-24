import AppKit

let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
let task = Process()
task.launchPath = "/usr/sbin/screencapture"
task.arguments = ["-x", tempURL.path]
task.launch()
task.waitUntilExit()

if let image = NSImage(contentsOf: tempURL) {
    print("Success: \(image.size)")
} else {
    print("Failed")
}
