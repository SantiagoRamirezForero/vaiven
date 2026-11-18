import AppKit
import VaivenCore

/// Estado de la isla, clic afuera, cambios de pantalla y refresco mientras está abierta.
@MainActor
final class IslandController {
    private static let refreshWhileOpen: TimeInterval = 30

    private let keepAwake: KeepAwakeController
    private let claude: ClaudeAccountController
    private var state = IslandState()
    private var panel: IslandPanel!
    private var view: IslandView!
    private var layout: IslandLayout
    private var outsideMonitor: Any?
    private var refreshTimer: DispatchSourceTimer?
    /// El último «Mover cursor» no arrancó (no se pudo reservar Esc): el botón lo dice hasta cerrar.
    private var keepAwakeFailed = false
    /// El vaivén arrancó mientras la isla se abría: se cierra al terminar la animación.
    private var closeWhenIdle = false

    var onRightClick: ((NSEvent, NSView) -> Void)?

    init(keepAwake: KeepAwakeController, claude: ClaudeAccountController) {
        self.keepAwake = keepAwake
        self.claude = claude
        layout = Self.currentLayout() ?? IslandLayout(mode: .pill, screenFrame: .zero, notch: .zero, collapsed: .zero,
                                                      expandedWidth: IslandGeometry.expandedMinWidth)
    }

    // MARK: pantallas

    static func currentLayout() -> IslandLayout? {
        IslandGeometry.layout(screens: NSScreen.screens.map { screen in
            let hasNotch = screen.safeAreaInsets.top > 0 && (screen.auxiliaryTopLeftArea != nil || screen.auxiliaryTopRightArea != nil)
            let bar = max(screen.frame.maxY - screen.visibleFrame.maxY, NSStatusBar.system.thickness)
            return ScreenInfo(frame: screen.frame, safeAreaTop: hasNotch ? screen.safeAreaInsets.top : 0,
                              leftAuxWidth: screen.auxiliaryTopLeftArea?.width ?? 0,
                              rightAuxWidth: screen.auxiliaryTopRightArea?.width ?? 0, menuBarHeight: bar)
        })
    }

    // MARK: arranque

    func start() {
        panel = IslandPanel(frame: layout.collapsed)
        view = IslandView(layout: layout)
        panel.contentView = view
        panel.onEscape = { [weak self] in self?.close() }
        panel.onResignKey = { [weak self] in self?.close() }
        view.onWingClick = { [weak self] wing in self?.click(wing) }
        view.onHeaderClick = { [weak self] in self?.close() }
        view.onRightClick = { [weak self] event in
            guard let self else { return }
            self.onRightClick?(event, self.view)
        }
        view.cursorSection.onPress = { [weak self] in self?.pressCursor() }
        view.claudeSection.onPress = { [weak self] in self?.claude.press() }
        panel.setFrame(layout.collapsed, display: false)
        refresh()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.screensChanged() } }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.screensChanged() } }
    }

    // MARK: contenido

    /// Alas siempre; los paneles y el alto, con la isla abierta.
    func refresh() {
        let presentation = claude.presentation
        view.cursorWing.update(active: keepAwake.isActive)
        view.usageRing.update(presentation)
        view.cursorSection.update(active: keepAwake.isActive, failed: keepAwakeFailed)
        view.claudeSection.update(presentation)
        if state.phase == .expanded, abs(view.currentHeight - targetHeight) > 0.5 {
            view.animateResize(toHeight: targetHeight)
        }
    }

    private var targetHeight: CGFloat {
        let body = state.panel == .cursor ? CursorSectionView.height : ClaudeSectionView.height(connected: claude.connected)
        return layout.collapsed.height + Palette.bodyGap + body + Palette.bottomMargin
    }

    // MARK: entradas

    func toggle(_ wing: IslandWing) { click(wing) }

    private func click(_ wing: IslandWing) { run(state.click(wing: wing)) }

    private func close() { run(state.close()) }

    /// «Mover cursor»: arranca y cierra la isla; si no pudo reservar Esc, se queda abierta y el botón lo dice.
    private func pressCursor() {
        if keepAwake.isActive { keepAwake.stop(); return }
        keepAwakeFailed = !keepAwake.start()
        refresh()
        guard !keepAwakeFailed else { return }
        if state.isBusy { closeWhenIdle = true } else { close() }
    }

    // MARK: efectos

    private func run(_ effect: IslandEffect) {
        switch effect {
        case .none: break
        case .expand: open()
        case .switchPanel:
            view.switchPanel(state.panel)
            view.animateResize(toHeight: targetHeight)
            panelDidShow()
        case .collapse: collapse()
        case .collapseImmediately: collapseNow()
        }
    }

    private func open() {
        view.preparePanel(state.panel)
        refresh()
        panel.isExpanded = true
        view.animateOpen(height: targetHeight) { [weak self] in
            guard let self else { return }
            self.state.animationFinished()
            self.panel.makeKey()
            if self.closeWhenIdle { self.closeWhenIdle = false; self.close() }
        }
        panel.makeKey()
        installOutsideMonitor()
        startRefreshTimer()
        panelDidShow()
    }

    private func collapse() {
        removeOutsideMonitor()
        stopRefreshTimer()
        view.animateClose { [weak self] in
            guard let self else { return }
            self.panel.isExpanded = false
            self.returnKeyboard()
            self.state.animationFinished()
            self.keepAwakeFailed = false
            self.refresh()
        }
    }

    private func collapseNow() {
        removeOutsideMonitor()
        stopRefreshTimer()
        panel.isExpanded = false
        returnKeyboard()
        closeWhenIdle = false
        view.update(layout: layout)
        view.finishCollapsed()
    }

    /// Devuelve el teclado a la app de atrás sin esconder la isla (esconderla y volverla a mostrar la hace parpadear).
    /// Tras un clic afuera el panel ya no tiene el teclado; con Esc o un clic en el ala, `deactivate` le pasa el foco
    /// a la app que estaba activa. Esconder y mostrar queda solo como último recurso.
    private func returnKeyboard() {
        panel.makeFirstResponder(nil)
        guard panel.isKeyWindow else { return }
        if NSApp.isActive { NSApp.deactivate() }
        if panel.isKeyWindow {
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
    }

    /// Con el panel de Claude a la vista y el dato de hace más de un minuto: se lee de nuevo.
    private func panelDidShow() {
        guard state.panel == .claude, claude.connected else { return }
        if let usage = claude.usage, Date().timeIntervalSince(usage.fetchedAt) < 60 { return }
        claude.sync()
    }

    private func screensChanged() {
        guard let next = Self.currentLayout() else { return }
        let changed = next != layout
        layout = next
        view.update(layout: next)
        if state.phase != .collapsed {
            run(state.screenChanged())
        } else if changed {
            view.finishCollapsed()
        }
    }

    // MARK: clic afuera y refresco de textos (solo con la isla abierta)

    private func installOutsideMonitor() {
        guard outsideMonitor == nil else { return }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private func removeOutsideMonitor() {
        if let monitor = outsideMonitor { NSEvent.removeMonitor(monitor) }
        outsideMonitor = nil
    }

    private func startRefreshTimer() {
        guard refreshTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Self.refreshWhileOpen, repeating: Self.refreshWhileOpen, leeway: .seconds(2))
        timer.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.refresh() } }
        timer.resume()
        refreshTimer = timer
    }

    private func stopRefreshTimer() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }
}
