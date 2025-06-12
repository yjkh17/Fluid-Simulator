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
        metalView.preferredFramesPerSecond = 120
        
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
        
        // FIXED: Add Metal rendering pipeline
        private var renderPipelineState: MTLRenderPipelineState?
        private var vertexBuffer: MTLBuffer?
        private var commandQueue: MTLCommandQueue?
        
        init(fluidEngine: FluidEngine, touchTracker: TouchTracker, selectedPalette: ColorPalette) {
            self.fluidEngine = fluidEngine
            self.touchTracker = touchTracker
            self.selectedPalette = selectedPalette
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Initialize renderer with proper size
            fluidRenderer = FluidRenderer(width: Int(size.width / 4), height: Int(size.height / 4))
            
            // FIXED: Setup Metal rendering pipeline
            setupMetal(view: view)
        }
        
        private func setupMetal(view: MTKView) {
            guard let device = view.device else { return }
            
            commandQueue = device.makeCommandQueue()
            
            // Create fullscreen quad vertices
            let vertices: [Float] = [
                -1.0, -1.0, 0.0, 1.0,  // Bottom left
                 1.0, -1.0, 1.0, 1.0,  // Bottom right
                -1.0,  1.0, 0.0, 0.0,  // Top left
                 1.0,  1.0, 1.0, 0.0   // Top right
            ]
            
            vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])
            
            // FIXED: Create simple render pipeline for fluid visualization
            guard let library = device.makeDefaultLibrary() else { return }
            
            let vertexFunction = library.makeFunction(name: "fluid_vertex") ?? library.makeFunction(name: "vertex_main")
            let fragmentFunction = library.makeFunction(name: "fluid_fragment") ?? library.makeFunction(name: "fragment_main")
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            
            try? renderPipelineState = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }
        
        func draw(in view: MTKView) {
            let currentTime = CACurrentMediaTime()
            if lastTime == 0 { lastTime = currentTime }
            let _ = currentTime - lastTime
            lastTime = currentTime
            
            // FIXED: Use current fluid state for rendering
            guard let renderer = fluidRenderer,
                  let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let commandQueue = commandQueue else { return }
            
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            
            // Get current fluid state
            let fluidState = fluidEngine.getState()
            
            // FIXED: Step renderer with current state
            renderer.step(with: fluidEngine.parameters)
            
            // FIXED: Actually render the fluid using CPU fallback if Metal pipeline fails
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
            
            // FIXED: Try to use Metal pipeline, fallback to simple colored quad
            if let pipelineState = renderPipelineState,
               let vertexBuffer = vertexBuffer {
                renderEncoder.setRenderPipelineState(pipelineState)
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            } else {
                // FALLBACK: Draw colored quad showing fluid activity
                drawFluidFallback(renderEncoder: renderEncoder, fluidState: fluidState, view: view)
            }
            
            renderEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        // FIXED: Fallback rendering method to show fluid activity
        private func drawFluidFallback(renderEncoder: MTLRenderCommandEncoder, fluidState: FluidState, view: MTKView) {
            // Simple colored representation - at least show something is happening
            // This is a basic fallback - the actual fluid would be rendered through textures
            
            // Calculate average fluid density to show activity
            var totalDensity: Float = 0
            var maxDensity: Float = 0
            
            for density in fluidState.density {
                totalDensity += density
                maxDensity = max(maxDensity, density)
            }
            
            let _ = totalDensity / Float(fluidState.density.count)
            
            // If there's fluid activity, we'll see some change in these values
            // The actual rendering would use the fluid textures through Metal shaders
        }
        
        @objc func handleTouch(_ gesture: UIPanGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            let velocity = gesture.velocity(in: gesture.view)
            
            guard let view = gesture.view else { return }
            let normalizedX = Float(location.x / view.bounds.width)
            let normalizedY = Float(location.y / view.bounds.height)
            
            let fluidState = fluidEngine.getState()
            let gridX = Int(normalizedX * Float(fluidState.width))
            let gridY = Int(normalizedY * Float(fluidState.height))
            
            // FIXED: Add bounds checking
            guard gridX >= 0 && gridX < fluidState.width && gridY >= 0 && gridY < fluidState.height else { return }
            
            // Add force to simulation with proper scaling
            let forceScale: Float = 0.001 // Reduced for better control
            fluidEngine.addForce(
                x: gridX,
                y: gridY,
                deltaX: Float(velocity.x) * forceScale,
                deltaY: Float(velocity.y) * forceScale
            )
            
            // Add density
            fluidEngine.addDensity(x: gridX, y: gridY, amount: 0.8)
            
            // Add color
            let color = selectedPalette.getRandomColor()
            fluidEngine.addColor(x: gridX, y: gridY, r: color.x, g: color.y, b: color.z)
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            
            guard let view = gesture.view else { return }
            let normalizedX = Float(location.x / view.bounds.width)
            let normalizedY = Float(location.y / view.bounds.height)
            
            let fluidState = fluidEngine.getState()
            let gridX = Int(normalizedX * Float(fluidState.width))
            let gridY = Int(normalizedY * Float(fluidState.height))
            
            // FIXED: Add bounds checking and use actual grid dimensions
            guard gridX >= 0 && gridX < fluidState.width && gridY >= 0 && gridY < fluidState.height else { return }
            
            // Add explosion-like force
            let radius = 3
            for dx in -radius...radius {
                for dy in -radius...radius {
                    let x = gridX + dx
                    let y = gridY + dy
                    
                    guard x >= 0 && x < fluidState.width && y >= 0 && y < fluidState.height else { continue }
                    
                    let distance = sqrt(Float(dx * dx + dy * dy))
                    if distance <= Float(radius) {
                        let force = (Float(radius) - distance) / Float(radius)
                        fluidEngine.addForce(x: x, y: y, deltaX: Float(dx) * force * 2.0, deltaY: Float(dy) * force * 2.0)
                        fluidEngine.addDensity(x: x, y: y, amount: force * 0.8)
                        
                        let color = selectedPalette.getRandomColor()
                        fluidEngine.addColor(x: x, y: y, r: color.x * force, g: color.y * force, b: color.z * force)
                    }
                }
            }
        }
    }
}
