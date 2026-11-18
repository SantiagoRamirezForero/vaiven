import AppKit
import VaivenCore

/// Contenedor negro con una máscara animada: lo que crece es la máscara y el panel se revela.
@MainActor
final class IslandView: NSView {
    let cursorWing = CursorWingView(frame: .zero)
    let usageRing = UsageRingView(frame: .zero)
    let cursorSection = CursorSectionView(frame: .zero)
    let claudeSection = ClaudeSectionView(frame: .zero)

    var onWingClick: ((IslandWing) -> Void)?
    var onHeaderClick: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?

    private(set) var layoutInfo: IslandLayout
    private(set) var isExpandedFrame = false
    private(set) var currentHeight: CGFloat = 0
    private(set) var activePanel: IslandWing = .cursor
    let maskLayer = CAShapeLayer()
    private var hoverAreas: [NSTrackingArea] = []

    init(layout: IslandLayout) {
        layoutInfo = layout
        super.init(frame: NSRect(origin: .zero, size: layout.collapsed.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        maskLayer.fillColor = NSColor.black.cgColor
        layer?.mask = maskLayer
        for view in [cursorWing, usageRing, cursorSection, claudeSection] { addSubview(view) }
        for section in [cursorSection, claudeSection] { section.wantsLayer = true }
        setBodyVisible(false)
        applyCollapsedLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    /// El panel que se ve.
    var activeSection: NSView { activePanel == .cursor ? cursorSection : claudeSection }

    // MARK: formas

    /// Rectángulo con las esquinas inferiores redondeadas y las superiores rectas.
    /// Misma construcción para todos los radios: así la interpolación de `path` no salta.
    static func path(_ rect: CGRect, bottomRadius r: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + r))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX - r, y: rect.minY), radius: r)
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX, y: rect.minY + r), radius: r)
        path.closeSubpath()
        return path
    }

    var collapsedRadius: CGFloat {
        layoutInfo.mode == .pill ? layoutInfo.collapsed.height / 2 : Palette.collapsedRadius
    }

    /// El rectángulo plegado en las coordenadas de una vista con ese marco.
    func collapsedRectInView(frame: CGRect) -> CGRect {
        layoutInfo.collapsed.offsetBy(dx: -frame.minX, dy: -frame.minY)
    }

    func setMask(_ path: CGPath, bounds: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.frame = bounds
        maskLayer.path = path
        CATransaction.commit()
    }

    // MARK: diseño

    func update(layout: IslandLayout) { layoutInfo = layout }

    func applyCollapsedLayout() {
        isExpandedFrame = false
        let size = layoutInfo.collapsed.size
        setFrameSize(size)
        positionWings(collapsed: CGRect(origin: .zero, size: size))
        setMask(Self.path(CGRect(origin: .zero, size: size), bottomRadius: collapsedRadius), bounds: CGRect(origin: .zero, size: size))
    }

    func applyExpandedLayout(height: CGFloat) {
        isExpandedFrame = true
        currentHeight = height
        let frame = layoutInfo.expanded(height: height)
        setFrameSize(frame.size)
        positionWings(collapsed: collapsedRectInView(frame: frame))
        // El panel va centrado y pegado abajo.
        let section = activeSection
        section.frame.origin = NSPoint(x: (bounds.width - Palette.columnWidth) / 2, y: Palette.bottomMargin)
    }

    func positionWings(collapsed rect: CGRect) {
        let mode = layoutInfo.mode
        let rightX = layoutInfo.rightWingX - layoutInfo.collapsed.minX + rect.minX
        cursorWing.frame = CGRect(x: rect.minX, y: rect.minY, width: layoutInfo.leftWingWidth, height: rect.height)
        usageRing.frame = CGRect(x: rightX, y: rect.minY, width: max(0, rect.maxX - rightX), height: rect.height)
        cursorWing.layoutIcon(x: IslandGeometry.cursorIconX(mode: mode))
        usageRing.layoutRing(x: IslandGeometry.ringX(mode: mode))
        updateHoverAreas()
    }

    func setBodyVisible(_ visible: Bool) {
        cursorSection.isHidden = !(visible && activePanel == .cursor)
        claudeSection.isHidden = !(visible && activePanel == .claude)
    }

    /// Fija el panel antes de abrir.
    func preparePanel(_ panel: IslandWing) { activePanel = panel }

    /// Cambia de panel con la isla abierta.
    func switchPanel(_ panel: IslandWing) {
        activePanel = panel
        setBodyVisible(true)
        fadeIn(activeSection, delay: 0)
    }

    // MARK: ratón

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard event.clickCount <= 1 else { return }
        let point = convert(event.locationInWindow, from: nil)
        if let wing = wing(at: point) {
            onWingClick?(wing)
        } else if isExpandedFrame, point.y >= bounds.height - layoutInfo.collapsed.height {
            onHeaderClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) { onRightClick?(event) }

    /// Qué ala se tocó (nil: el notch u otra zona).
    func wing(at point: NSPoint) -> IslandWing? {
        if cursorWing.frame.contains(point) { return .cursor }
        if usageRing.frame.contains(point) { return .claude }
        return nil
    }

    private func updateHoverAreas() {
        hoverAreas.forEach(removeTrackingArea)
        hoverAreas = [("cursor", cursorWing), ("claude", usageRing)].map { name, view in
            NSTrackingArea(rect: view.frame, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: ["wing": name])
        }
        hoverAreas.forEach(addTrackingArea)
    }

    override func mouseEntered(with event: NSEvent) { hover(event, true) }
    override func mouseExited(with event: NSEvent) { hover(event, false) }

    private func hover(_ event: NSEvent, _ inside: Bool) {
        guard let name = event.trackingArea?.userInfo?["wing"] as? String else { return }
        if name == "cursor" { cursorWing.setHover(inside) } else { usageRing.setHover(inside) }
    }
}
