import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let keepAwake = KeepAwakeController()
    private let claude = ClaudeAccountController()
    private var island: IslandController!
    private var lockFD: Int32 = -1

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard acquireLock() else { exit(0) } // otra instancia ya corre
        island = IslandController(keepAwake: keepAwake, claude: claude)
        island.onRightClick = { [weak self] event, view in self?.showMenu(event, in: view) }
        keepAwake.onChange = { [weak self] in self?.island.refresh() }
        claude.onChange = { [weak self] in self?.island.refresh() }
        island.start()
        claude.start()
    }

    func applicationWillTerminate(_ notification: Notification) { keepAwake.stop() }

    // MARK: instancia única

    /// Un candado en ~/Library/Application Support/Vaiven: si otra copia lo tiene, esta se va.
    private func acquireLock() -> Bool {
        let dir = NSHomeDirectory() + "/Library/Application Support/Vaiven"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        lockFD = open(dir + "/app.lock", O_CREAT | O_RDWR, 0o600)
        return lockFD >= 0 && flock(lockFD, LOCK_EX | LOCK_NB) == 0
    }

    // MARK: menú del clic derecho

    private func showMenu(_ event: NSEvent, in view: NSView) {
        let menu = NSMenu()
        if claude.connected {
            menu.addItem(item("Sincronizar uso de Claude", #selector(menuSync)))
            menu.addItem(item("Quitar cuenta de Claude", #selector(menuDisconnect)))
        } else {
            menu.addItem(item("Agregar cuenta de Claude", #selector(menuSync)))
        }
        menu.addItem(.separator())
        menu.addItem(item("Salir de Vaivén", #selector(menuQuit)))
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func menuSync() { claude.sync() }
    @objc private func menuDisconnect() { claude.disconnect() }
    @objc private func menuQuit() { NSApp.terminate(nil) }
}
