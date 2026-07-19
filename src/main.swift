import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Activation policy is set by AppDelegate (.regular for panel + menu bar)
app.run()
