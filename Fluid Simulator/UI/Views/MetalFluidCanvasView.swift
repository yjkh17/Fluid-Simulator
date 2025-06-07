//
//  MetalFluidCanvasView.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI
import MetalKit

struct MetalFluidCanvasView: UIViewRepresentable {
    let selectedPalette: ColorPalette
    let screenSize: CGSize
    @ObservedObject var fluidEngine: FluidEngine
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = context.coordinator
        metalView.framebufferOnly = false
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.preferredFramesPerSecond = 60
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = false
        
        // Enable touch interaction
        let dragGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDrag(_:)))
        metalView.addGestureRecognizer(dragGesture)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        metalView.addGestureRecognizer(tapGesture)
        
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.selectedPalette = selectedPalette
        context.coordinator.fluidEngine = fluidEngine
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(selectedPalette: selectedPalette, screenSize: screenSize, fluidEngine: fluidEngine)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var selectedPalette: ColorPalette
        var screenSize: CGSize
        var fluidEngine: FluidEngine
        
        private var metalSimulator: MetalFluidSimulator?
        private var renderPipeline: MTLRenderPipelineState?
        private var device: MTLDevice?
        private var commandQueue: MTLCommandQueue?
        
        init(selectedPalette: ColorPalette, screenSize: CGSize, fluidEngine: FluidEngine) {
            self.selectedPalette = selectedPalette
            self.screenSize = screenSize
            self.fluidEngine = fluidEngine
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            guard let device = view.device else { 
                print("No Metal device available")
                return
            }
            self.device = device
            self.commandQueue = device.makeCommandQueue()
            
            // Create Metal fluid simulator with higher resolution
            let simWidth = min(128, Int(size.width / 4))  // Conservative resolution
            let simHeight = min(256, Int(size.height / 4))
            
            // Safe Metal simulator creation
            metalSimulator = MetalFluidSimulator(device: device, width: simWidth, height: simHeight)
            
            if metalSimulator == nil {
                print("Failed to create Metal fluid simulator - falling back to CPU")
            }
            
            setupRenderPipeline(device: device, view: view)
        }
        
        private func setupRenderPipeline(device: MTLDevice, view: MTKView) {
            guard let library = device.makeDefaultLibrary() else { return }
            
            let vertexFunction = library.makeFunction(name: "fluid_display_vertex")
            let fragmentFunction = library.makeFunction(name: "fluid_display_fragment")
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            
            do {
                renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("Failed to create render pipeline: \(error)")
            }
        }
        
        func draw(in view: MTKView) {
            // Graceful fallback if Metal isn't working
            guard let metalSimulator = metalSimulator,
                  let renderPipeline = renderPipeline,
                  let commandQueue = commandQueue,
                  let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else {
                // Clear to black if Metal isn't working
                view.currentRenderPassDescriptor?.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
                return
            }
            
            // Step the Metal fluid simulation
            metalSimulator.step(parameters: fluidEngine.parameters)
            
            // Render the result
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
                  let colorTexture = metalSimulator.getCurrentColorTexture(),
                  let densityTexture = metalSimulator.getCurrentDensityTexture() else { return }
            
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            
            renderEncoder.setRenderPipelineState(renderPipeline)
            renderEncoder.setFragmentTexture(colorTexture, index: 0)
            renderEncoder.setFragmentTexture(densityTexture, index: 1)
            
            // Draw fullscreen quad
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            
            renderEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        @objc func handleDrag(_ gesture: UIPanGestureRecognizer) {
            guard let metalSimulator = metalSimulator,
                  let view = gesture.view else { return }
            
            let location = gesture.location(in: view)
            let velocity = gesture.velocity(in: view)
            
            // Convert to normalized coordinates
            let normalizedPos = SIMD2<Float>(
                Float(location.x / view.bounds.width),
                Float(1.0 - location.y / view.bounds.height) // Flip Y coordinate
            )
            
            let normalizedVel = SIMD2<Float>(
                Float(velocity.x / view.bounds.width * 0.001),
                Float(-velocity.y / view.bounds.height * 0.001) // Flip Y coordinate
            )
            
            let color = selectedPalette.getRandomColor()
            
            metalSimulator.addForce(
                at: normalizedPos,
                velocity: normalizedVel,
                radius: 0.05, // 5% of screen size
                color: color
            )
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let metalSimulator = metalSimulator,
                  let view = gesture.view else { return }
            
            let location = gesture.location(in: view)
            
            // Convert to normalized coordinates
            let normalizedPos = SIMD2<Float>(
                Float(location.x / view.bounds.width),
                Float(1.0 - location.y / view.bounds.height) // Flip Y coordinate
            )
            
            let color = selectedPalette.getRandomColor()
            
            // Create explosion effect
            for i in 0..<8 {
                let angle = Float(i) * Float.pi * 2.0 / 8.0
                let explosionVel = SIMD2<Float>(cos(angle), sin(angle)) * 0.01
                
                metalSimulator.addForce(
                    at: normalizedPos,
                    velocity: explosionVel,
                    radius: 0.08, // 8% of screen size
                    color: color
                )
            }
        }
    }
}
