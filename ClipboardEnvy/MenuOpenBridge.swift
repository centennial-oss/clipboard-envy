import AppKit
import Foundation

extension Notification.Name {
    static let clipboardEnvyMenuWillOpen = Notification.Name("clipboardEnvyMenuWillOpen")
}

@MainActor
enum MenuOpenBridge {
    private static var isInstalled = false
    private static var trackingObserver: NSObjectProtocol?

    static func install() {
        guard !isInstalled else { return }
        isInstalled = true

        trackingObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let menu = note.object as? NSMenu else { return }
            // Only the root status menu opening should trigger a refresh.
            guard menu.supermenu == nil else { return }
            NotificationCenter.default.post(name: .clipboardEnvyMenuWillOpen, object: nil)
        }
    }
}
