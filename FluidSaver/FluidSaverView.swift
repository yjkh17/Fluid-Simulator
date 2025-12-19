import AppKit
import MetalKit
import ScreenSaver

final class FluidSaverView: ScreenSaverView {
    private let metalView: MTKView
    private var renderer: FluidSaverRenderer?
    private var lastTimestamp: CFTimeInterval = CACurrentMediaTime()
    private var trackingArea: NSTrackingArea?

    override init?(frame: NSRect, isPreview: Bool) {
        self.metalView = MTKView(frame: frame)
        self.renderer = nil
        super.init(frame: frame, isPreview: isPreview)
        configureView()
    }

    required init?(coder: NSCoder) {
        self.metalView = MTKView(frame: .zero)
        self.renderer = nil
        super.init(coder: coder)
        configureView()
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func startAnimation() {
        super.startAnimation()
        window?.acceptsMouseMovedEvents = true
    }

    override func animateOneFrame() {
        guard let renderer = renderer else { return }

        let now = CACurrentMediaTime()
        let rawDelta = now - lastTimestamp
        lastTimestamp = now

        let clamped = min(max(rawDelta, 1.0 / 120.0), 1.0 / 15.0)
        renderer.updateDrawableSizeForCurrentBounds()
        renderer.update(dt: Float(clamped))
        metalView.draw()
    }

    override func mouseMoved(with event: NSEvent) {
        guard let renderer = renderer else { return }
        let location = convert(event.locationInWindow, from: nil)
        let delta = CGVector(dx: event.deltaX, dy: event.deltaY)
        renderer.inject(at: location, delta: delta)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseMoved, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }

    // MARK: - Private helpers

    private func configureView() {
        animationTimeInterval = 1.0 / 60.0
        metalView.frame = bounds
        metalView.autoresizingMask = [.width, .height]
        metalView.wantsLayer = true
        metalView.isOpaque = true
        addSubview(metalView)

        renderer = FluidSaverRenderer(view: metalView)
        window?.acceptsMouseMovedEvents = true
        updateTrackingAreas()
    }
}
