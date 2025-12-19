import AppKit
import MetalKit

final class FluidSaverRenderer: NSObject, MTKViewDelegate {
    private let mtkView: MTKView
    private var sim: FluidSim
    private var clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

    init?(view: MTKView) {
        self.mtkView = view
        let device = view.device ?? MTLCreateSystemDefaultDevice()
        guard let metalDevice = device else { return nil }
        mtkView.device = metalDevice
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = false
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 60

        let initialDrawableSize = view.bounds.size.scaled(by: view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0)
        mtkView.drawableSize = initialDrawableSize

        guard let sim = FluidSim(device: metalDevice, drawableSize: initialDrawableSize) else {
            return nil
        }

        self.sim = sim
        super.init()
        mtkView.delegate = self
    }

    func update(dt: Float) {
        sim.updateDrawableSize(mtkView.drawableSize)
        sim.step(dt: dt)
    }

    func inject(at location: CGPoint, delta: CGVector) {
        sim.inject(at: location, delta: delta, in: mtkView.bounds.size)
    }

    func updateDrawableSizeForCurrentBounds() {
        let scale = mtkView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let drawableSize = mtkView.bounds.size.scaled(by: scale)
        if drawableSize != mtkView.drawableSize {
            mtkView.drawableSize = drawableSize
            sim.updateDrawableSize(drawableSize)
        }
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        sim.updateDrawableSize(size)
    }

    func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            return
        }

        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = clearColor
        sim.render(to: descriptor, drawable: drawable)
    }
}

private extension CGSize {
    func scaled(by scale: CGFloat) -> CGSize {
        return CGSize(width: width * scale, height: height * scale)
    }
}
