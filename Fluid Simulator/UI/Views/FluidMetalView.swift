//
//  FluidMetalView.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI
import MetalKit
import Metal

struct FluidMetalView: UIViewRepresentable {
    let fluidEngine: FluidEngine
    let touchTracker: TouchTracker
    let selectedPalette: ColorPalette
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = context.coordinator
        metalView.framebufferOnly = false
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.preferredFramesPerSecond = 60
        
        // Enable touch interaction
        let gestureRecognizer = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTouch(_:)))
        metalView.addGestureRecognizer(gestureRecognizer)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        metalView.addGestureRecognizer(tapGestureRecognizer)
        
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.selectedPalette = selectedPalette
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(fluidEngine: fluidEngine, touchTracker: touchTracker, selectedPalette: selectedPalette)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        let fluidEngine: FluidEngine
        let touchTracker: TouchTracker
        var selectedPalette: ColorPalette
        private var fluidRenderer: FluidRenderer?
        private var lastTime: CFTimeInterval = 0
        
        init(fluidEngine: FluidEngine, touchTracker: TouchTracker, selectedPalette: ColorPalette) {
            self.fluidEngine = fluidEngine
            self.touchTracker = touchTracker
            self.selectedPalette = selectedPalette
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Initialize renderer with proper size
            fluidRenderer = FluidRenderer(width: Int(size.width / 4), height: Int(size.height / 4))
        }
        
        func draw(in view: MTKView) {
            let currentTime = CACurrentMediaTime()
            if lastTime == 0 { lastTime = currentTime }
            let _ = currentTime - lastTime
            lastTime = currentTime
            
            // Step the fluid simulation
            fluidEngine.step()
            
            // Render the fluid
            guard let renderer = fluidRenderer,
                  let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            
            renderer.step(with: fluidEngine.parameters)
            
            // Render to screen (simplified for now)
            guard let device = view.device,
                  let commandQueue = device.makeCommandQueue(),
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
            
            renderEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        @objc func handleTouch(_ gesture: UIPanGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            let velocity = gesture.velocity(in: gesture.view)
            
            guard let view = gesture.view else { return }
            let normalizedX = Float(location.x / view.bounds.width)
            let normalizedY = Float(location.y / view.bounds.height)
            
            let gridX = Int(normalizedX * 32)
            let gridY = Int(normalizedY * 64)
            
            // Add force to simulation
            let forceScale: Float = 0.1
            fluidEngine.addForce(
                x: gridX,
                y: gridY,
                deltaX: Float(velocity.x) * forceScale,
                deltaY: Float(velocity.y) * forceScale
            )
            
            // Add density
            fluidEngine.addDensity(x: gridX, y: gridY, amount: 0.5)
            
            // Add color
            let color = selectedPalette.getRandomColor()
            fluidEngine.addColor(x: gridX, y: gridY, r: color.x, g: color.y, b: color.z)
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            
            guard let view = gesture.view else { return }
            let normalizedX = Float(location.x / view.bounds.width)
            let normalizedY = Float(location.y / view.bounds.height)
            
            let gridX = Int(normalizedX * 32)
            let gridY = Int(normalizedY * 64)
            
            // Add explosion-like force
            for dx in -3...3 {
                for dy in -3...3 {
                    let x = gridX + dx
                    let y = gridY + dy
                    if x >= 0 && x < 32 && y >= 0 && y < 64 {
                        let distance = sqrt(Float(dx * dx + dy * dy))
                        if distance <= 3.0 {
                            let force = (3.0 - distance) / 3.0
                            fluidEngine.addForce(x: x, y: y, deltaX: Float(dx) * force, deltaY: Float(dy) * force)
                            fluidEngine.addDensity(x: x, y: y, amount: force * 0.3)
                            
                            let color = selectedPalette.getRandomColor()
                            fluidEngine.addColor(x: x, y: y, r: color.x * force, g: color.y * force, b: color.z * force)
                        }
                    }
                }
            }
        }
    }
}
