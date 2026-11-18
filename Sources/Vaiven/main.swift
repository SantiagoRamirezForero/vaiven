import AppKit
import Foundation

if CommandLine.arguments.dropFirst().first == "--check-claude" {
    exit(ClaudeCheck.run())
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory) // sin ícono en el Dock
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
