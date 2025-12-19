import Foundation
import Metal
import MetalKit
import simd

/// Standalone fluid simulation wrapper for the screen saver target.
/// It reuses the Metal-based GPU solver from the iOS app while
/// maintaining its own sizing and color palette logic.
final class FluidSim {
    private let device: MTLDevice
    private var simulator: FluidSimulatorGPU
    private var gridSize: (width: Int, height: Int)
    private var colorPhase: Float = 0.0
    private var hasSeeded = false

    init?(device: MTLDevice, drawableSize: CGSize) {
        self.device = device
        let targetSize = FluidSim.gridDimensions(for: drawableSize)
        self.gridSize = targetSize

        guard let simulator = FluidSimulatorGPU(
            device: device,
            width: targetSize.width,
            height: targetSize.height
        ) else {
            return nil
        }

        self.simulator = simulator
        configureParameters()
        ensureSeeded()
    }

    func updateDrawableSize(_ size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let desired = FluidSim.gridDimensions(for: size)
        guard desired != gridSize else { return }

        if let newSim = FluidSimulatorGPU(
            device: device,
            width: desired.width,
            height: desired.height
        ) {
            simulator = newSim
            gridSize = desired
            configureParameters()
            hasSeeded = false
            ensureSeeded()
        }
    }

    func step(dt: Float) {
        simulator.step(dt: dt)
    }

    func inject(at point: CGPoint, delta: CGVector, in viewSize: CGSize) {
        let normalizedPosition = SIMD2<Float>(
            Float(point.x / viewSize.width).clamped(to: 0...1),
            Float(1.0 - point.y / viewSize.height).clamped(to: 0...1)
        )

        let velocityScale: Float = 28.0
        let normalizedVelocity = SIMD2<Float>(
            Float(delta.dx / viewSize.width) * velocityScale,
            Float(-delta.dy / viewSize.height) * velocityScale
        )

        let radius = Float(max(gridSize.width, gridSize.height)) * 0.045
        simulator.addForce(
            at: normalizedPosition,
            velocity: normalizedVelocity,
            radius: radius,
            color: nextColor()
        )
        hasSeeded = true
    }

    func render(to descriptor: MTLRenderPassDescriptor, drawable: MTLDrawable) {
        simulator.render(to: descriptor, drawable: drawable)
    }

    // MARK: - Private helpers

    private func configureParameters() {
        let baseTimeStep: Float = 1.0 / 120.0
        simulator.parameters.timeStep = baseTimeStep
        simulator.parameters.viscosity = 0.0008
        simulator.parameters.diffusion = 0.0005
        simulator.parameters.fadeRate = 0.985
        simulator.parameters.forceMultiplier = 26.0
        simulator.parameters.projectionIterations = 35
    }

    func ensureSeeded() {
        guard !hasSeeded else { return }

        let center = SIMD2<Float>(0.5, 0.5)
        let upward = SIMD2<Float>(0.0, 18.0)
        let radius = Float(max(gridSize.width, gridSize.height)) * 0.06
        simulator.addForce(at: center, velocity: upward, radius: radius, color: nextColor())

        let swirlOffset = SIMD2<Float>(0.18, -0.12)
        let swirlVelocity = SIMD2<Float>(-upward.y * 0.25, upward.x * 0.15)
        simulator.addForce(at: center + swirlOffset, velocity: swirlVelocity, radius: radius * 0.7, color: nextColor())

        hasSeeded = true
    }

    private static func gridDimensions(for size: CGSize) -> (width: Int, height: Int) {
        // Keep a moderate resolution that scales with the view while staying efficient.
        let maxDimension = max(size.width, size.height)
        let target = max(192, min(640, Int(maxDimension / 2.0)))
        let aspect = size.width > 0 ? size.height / size.width : 1.0
        let width = target
        let height = Int(round(Float(target) * Float(aspect)))
        return (width: max(128, width), height: max(128, height))
    }

    private func nextColor() -> SIMD3<Float> {
        colorPhase = fmodf(colorPhase + 0.17, 1.0)
        return hslToRGB(h: colorPhase, s: 0.85, l: 0.55)
    }

    private func hslToRGB(h: Float, s: Float, l: Float) -> SIMD3<Float> {
        let q: Float = l < 0.5 ? (l * (1 + s)) : (l + s - l * s)
        let p: Float = 2 * l - q
        let r = hueToChannel(p: p, q: q, t: h + 1.0 / 3.0)
        let g = hueToChannel(p: p, q: q, t: h)
        let b = hueToChannel(p: p, q: q, t: h - 1.0 / 3.0)
        return SIMD3<Float>(r, g, b)
    }

    private func hueToChannel(p: Float, q: Float, t: Float) -> Float {
        var value = t
        if value < 0 { value += 1 }
        if value > 1 { value -= 1 }
        if value < 1.0 / 6.0 { return p + (q - p) * 6 * value }
        if value < 1.0 / 2.0 { return q }
        if value < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - value) * 6 }
        return p
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
