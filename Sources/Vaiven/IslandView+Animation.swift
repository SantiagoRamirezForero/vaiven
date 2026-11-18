import AppKit
import VaivenCore

/// Animaciones de la isla (Core Animation, sin temporizadores): la máscara crece con un resorte y el panel se revela.
extension IslandView {
    static let resizeDuration: CFTimeInterval = 0.2

    var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Abre: el panel pasa de golpe al rectángulo abierto y la máscara crece con un resorte.
    func animateOpen(height: CGFloat, completion: @escaping () -> Void) {
        guard let panel = window else { return completion() }
        let target = layoutInfo.expanded(height: height)
        let from = collapsedRectInView(frame: target)
        panel.setFrame(target, display: false)
        applyExpandedLayout(height: height)
        setBodyVisible(true)
        let bounds = CGRect(origin: .zero, size: target.size)
        let toPath = Self.path(bounds, bottomRadius: Palette.expandedRadius)
        if reduceMotion {
            setMask(toPath, bounds: bounds)
            fade(layer: layer, from: 0, to: 1, duration: 0.15, completion: completion)
            return
        }
        setMask(Self.path(from, bottomRadius: collapsedRadius), bounds: bounds)
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        let spring = CASpringAnimation(keyPath: "path")
        spring.fromValue = maskLayer.path
        spring.toValue = toPath
        spring.damping = 18
        spring.stiffness = 220
        spring.mass = 1
        spring.initialVelocity = 0
        spring.duration = spring.settlingDuration
        maskLayer.path = toPath
        maskLayer.add(spring, forKey: "path")
        fadeIn(activeSection, delay: 0.12)
        CATransaction.commit()
    }

    /// Cierra: el panel se apaga y la máscara vuelve a la forma plegada; al final la ventana se achica.
    func animateClose(completion: @escaping () -> Void) {
        guard window != nil else { return completion() }
        let frame = layoutInfo.expanded(height: currentHeight)
        let toPath = Self.path(collapsedRectInView(frame: frame), bottomRadius: collapsedRadius)
        let finish: () -> Void = { [weak self] in
            self?.finishCollapsed()
            completion()
        }
        if reduceMotion {
            fade(layer: layer, from: 1, to: 0, duration: 0.15, completion: finish)
            return
        }
        CATransaction.begin()
        CATransaction.setCompletionBlock(finish)
        let shrink = CABasicAnimation(keyPath: "path")
        shrink.fromValue = maskLayer.path
        shrink.toValue = toPath
        shrink.duration = 0.22
        shrink.timingFunction = CAMediaTimingFunction(name: .easeIn)
        maskLayer.path = toPath
        maskLayer.add(shrink, forKey: "path")
        if let l = activeSection.layer {
            let out = CABasicAnimation(keyPath: "opacity")
            out.fromValue = 1
            out.toValue = 0
            out.duration = 0.1
            l.opacity = 0
            l.add(out, forKey: "fade")
        }
        CATransaction.commit()
    }

    /// Al terminar de cerrar o al cambiar de pantalla: plegada, sin animación.
    func finishCollapsed() {
        guard let panel = window else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setBodyVisible(false)
        for section in [cursorSection, claudeSection] { section.layer?.opacity = 1; section.layer?.removeAllAnimations() }
        layer?.opacity = 1
        layer?.removeAllAnimations()
        maskLayer.removeAllAnimations()
        panel.setFrame(layoutInfo.collapsed, display: false)
        applyCollapsedLayout()
        CATransaction.commit()
    }

    /// Cambia el alto con la isla abierta (otro panel, o Claude pasó de «sin cuenta» a «con cuenta»).
    /// El borde superior no se mueve.
    func animateResize(toHeight height: CGFloat) {
        guard let panel = window, isExpandedFrame else { return }
        let old = layoutInfo.expanded(height: currentHeight)
        let target = layoutInfo.expanded(height: height)
        panel.setFrame(target, display: false)
        applyExpandedLayout(height: height)
        guard old != target else { return }
        let newBounds = CGRect(origin: .zero, size: target.size)
        let toPath = Self.path(newBounds, bottomRadius: Palette.expandedRadius)
        setMask(toPath, bounds: newBounds)
        guard !reduceMotion else { return }
        let move = CABasicAnimation(keyPath: "path")
        move.fromValue = Self.path(old.offsetBy(dx: -target.minX, dy: -target.minY), bottomRadius: Palette.expandedRadius)
        move.toValue = toPath
        move.duration = Self.resizeDuration
        move.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        maskLayer.add(move, forKey: "path")
    }

    func fadeIn(_ view: NSView, delay: CFTimeInterval) {
        view.wantsLayer = true
        guard let l = view.layer else { return }
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 0
        anim.toValue = 1
        anim.duration = 0.2
        anim.beginTime = CACurrentMediaTime() + delay
        anim.fillMode = .backwards
        l.opacity = 1
        l.add(anim, forKey: "fade")
    }

    func fade(layer: CALayer?, from: Float, to: Float, duration: CFTimeInterval, completion: @escaping () -> Void) {
        guard let layer else { return completion() }
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = from
        anim.toValue = to
        anim.duration = duration
        layer.opacity = to
        layer.add(anim, forKey: "fade")
        CATransaction.commit()
    }
}
