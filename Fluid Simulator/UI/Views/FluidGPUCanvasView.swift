//
//  FluidGPUCanvasView.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI
import MetalKit
import QuartzCore

/// Step 4: GPU-first canvas view using FluidSimulatorGPU as single source of truth
struct FluidGPUCanvasView: UIViewRepresentable {
    let selectedPalette: ColorPalette
    let screenSize: CGSize
    @ObservedObject var simulator: FluidSimulatorGPU
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = simulator.device
        metalView.delegate = context.coordinator
        metalView.framebufferOnly = false
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.preferredFramesPerSecond = 120
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = false
        metalView.isUserInteractionEnabled = true
        metalView.isMultipleTouchEnabled = true
        
        // Enable touch interaction
        let dragGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDrag(_:)))
        metalView.addGestureRecognizer(dragGesture)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        metalView.addGestureRecognizer(tapGesture)

        // Pointer hover support so moving the cursor injects fluid without a drag
        if #available(iOS 13.4, *) {
            let hoverGesture = UIHoverGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleHover(_:)))
            hoverGesture.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)]
            metalView.addGestureRecognizer(hoverGesture)
        }
        
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.selectedPalette = selectedPalette
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(simulator: simulator, selectedPalette: selectedPalette)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        let simulator: FluidSimulatorGPU
        var selectedPalette: ColorPalette
        private var displayLink: CADisplayLink?
        private var latestDisplayLinkTimestamp: CFTimeInterval?
        private var lastFrameTimestamp: CFTimeInterval?
        private var lastCommandBufferEndTime: CFTimeInterval?
        private let maxDeltaTime: Float = 1.0 / 30.0
        private var lastHoverLocation: CGPoint?
        private var lastHoverTimestamp: CFTimeInterval?
        
        init(simulator: FluidSimulatorGPU, selectedPalette: ColorPalette) {
            self.simulator = simulator
            self.selectedPalette = selectedPalette
            super.init()
            startDisplayLink()
        }

        deinit {
            displayLink?.invalidate()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // GPU simulator handles its own sizing
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else {
                return
            }

            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

            let currentTimestamp = lastCommandBufferEndTime ?? latestDisplayLinkTimestamp ?? CACurrentMediaTime()
            let defaultDelta = 1.0 / Double(view.preferredFramesPerSecond)
            let rawDelta = lastFrameTimestamp.map { currentTimestamp - $0 } ?? defaultDelta
            lastFrameTimestamp = currentTimestamp
            let clampedDt = min(max(Float(rawDelta), 0), maxDeltaTime)
            
            // Step simulation on GPU
            simulator.step(dt: clampedDt)
            
            // Render directly from GPU textures
            simulator.render(to: renderPassDescriptor, drawable: drawable) { [weak self] commandBuffer in
                commandBuffer.addCompletedHandler { cb in
                    let gpuEndTime = cb.gpuEndTime
                    let completionTime = gpuEndTime.isFinite && gpuEndTime > 0 ? gpuEndTime : CACurrentMediaTime()
                    DispatchQueue.main.async {
                        self?.lastCommandBufferEndTime = completionTime
                    }
                }
            }
        }

        private func startDisplayLink() {
            let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
            link.preferredFramesPerSecond = 120
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        @objc private func handleDisplayLink(_ link: CADisplayLink) {
            latestDisplayLinkTimestamp = link.targetTimestamp
        }
        
        @objc func handleDrag(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            
            let location = gesture.location(in: view)
            let velocity = gesture.velocity(in: view)
            
            addForce(in: view, at: location, velocity: velocity)
        }

        @objc func handleHover(_ gesture: UIHoverGestureRecognizer) {
            guard let view = gesture.view else { return }
            
            switch gesture.state {
            case .began, .changed:
                let location = gesture.location(in: view)
                let now = CACurrentMediaTime()
                
                let velocity: CGPoint
                if let lastLocation = lastHoverLocation, let lastTimestamp = lastHoverTimestamp {
                    let dt = max(now - lastTimestamp, 0.001)
                    velocity = CGPoint(
                        x: (location.x - lastLocation.x) / dt,
                        y: (location.y - lastLocation.y) / dt
                    )
                } else {
                    velocity = .zero
                }
                
                addForce(in: view, at: location, velocity: velocity)
                lastHoverLocation = location
                lastHoverTimestamp = now
                
            case .ended, .cancelled:
                lastHoverLocation = nil
                lastHoverTimestamp = nil
            default:
                break
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            
            let location = gesture.location(in: view)
            
            let normalizedPos = SIMD2<Float>(
                Float(location.x / view.bounds.width),
                Float(1.0 - location.y / view.bounds.height)
            )
            
            let color = selectedPalette.getRandomColor()
            
            // Create explosion effect with multiple forces
            for i in 0..<8 {
                let angle = Float(i) * Float.pi * 2.0 / 8.0
                let explosionVel = SIMD2<Float>(cos(angle), sin(angle)) * 0.2
                
                simulator.addForce(
                    at: normalizedPos,
                    velocity: explosionVel,
                    radius: 80.0,
                    color: color
                )
            }
        }

        private func addForce(in view: UIView, at location: CGPoint, velocity: CGPoint) {
            guard view.bounds.width > 0, view.bounds.height > 0 else { return }

            let normalizedPos = SIMD2<Float>(
                Float(location.x / view.bounds.width),
                Float(1.0 - location.y / view.bounds.height)
            )

            let normalizedVel = SIMD2<Float>(
                Float(velocity.x / view.bounds.width * 0.1),
                Float(-velocity.y / view.bounds.height * 0.1)
            )

            let color = selectedPalette.getRandomColor()
            let radius = max(
                30.0,
                Float(min(simulator.width, simulator.height)) * 0.4
            )

            simulator.addForce(
                at: normalizedPos,
                velocity: normalizedVel,
                radius: radius,
                color: color
            )
        }
    }
}

#Preview {
    if let device = MTLCreateSystemDefaultDevice() {
        if let simulator = FluidSimulatorGPU(device: device, width: 128, height: 256) {
            FluidGPUCanvasView(
                selectedPalette: ColorPalette.palettes[0],
                screenSize: CGSize(width: 400, height: 800),
                simulator: simulator
            )
        } else {
            Text("Failed to create GPU simulator")
        }
    } else {
        Text("Metal not available")
    }
}
