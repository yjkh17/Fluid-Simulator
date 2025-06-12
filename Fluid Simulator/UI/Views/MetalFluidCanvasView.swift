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
        metalView.preferredFramesPerSecond = 120
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
        private var isMetalInitialized = false
        
        init(selectedPalette: ColorPalette, screenSize: CGSize, fluidEngine: FluidEngine) {
            self.selectedPalette = selectedPalette
            self.screenSize = screenSize
            self.fluidEngine = fluidEngine
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            guard let device = view.device else {
                isMetalInitialized = false
                return
            }
            
            self.device = device
            
            guard let commandQueue = device.makeCommandQueue() else {
                isMetalInitialized = false
                return
            }
            self.commandQueue = commandQueue
            
            // Create Metal simulator with safe dimensions
            let simWidth = 32
            let simHeight = 64
            
            if let simulator = MetalFluidSimulator(device: device, width: simWidth, height: simHeight) {
                metalSimulator = simulator
                isMetalInitialized = true
            } else {
                isMetalInitialized = false
            }
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            
            guard isMetalInitialized,
                  let metalSimulator = metalSimulator,
                  let commandQueue = commandQueue else {
                // Present black screen if Metal not ready
                if let commandQueue = commandQueue,
                   let commandBuffer = commandQueue.makeCommandBuffer() {
                    commandBuffer.present(drawable)
                    commandBuffer.commit()
                }
                return
            }
            
            // Step simulation
            metalSimulator.step(parameters: fluidEngine.parameters)
            
            // Simple rendering - just present the drawable
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        @objc func handleDrag(_ gesture: UIPanGestureRecognizer) {
            guard isMetalInitialized,
                  let metalSimulator = metalSimulator,
                  let view = gesture.view else { return }
            
            let location = gesture.location(in: view)
            let velocity = gesture.velocity(in: view)
            
            let normalizedPos = SIMD2<Float>(
                Float(location.x / view.bounds.width),
                Float(1.0 - location.y / view.bounds.height)
            )
            
            let normalizedVel = SIMD2<Float>(
                Float(velocity.x / view.bounds.width * 0.001),
                Float(-velocity.y / view.bounds.height * 0.001)
            )
            
            let color = selectedPalette.getRandomColor()
            
            metalSimulator.addForce(
                at: normalizedPos,
                velocity: normalizedVel,
                radius: 0.05,
                color: color
            )
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard isMetalInitialized,
                  let metalSimulator = metalSimulator,
                  let view = gesture.view else { return }
            
            let location = gesture.location(in: view)
            
            let normalizedPos = SIMD2<Float>(
                Float(location.x / view.bounds.width),
                Float(1.0 - location.y / view.bounds.height)
            )
            
            let color = selectedPalette.getRandomColor()
            
            // Create explosion effect
            for i in 0..<8 {
                let angle = Float(i) * Float.pi * 2.0 / 8.0
                let explosionVel = SIMD2<Float>(cos(angle), sin(angle)) * 0.01
                
                metalSimulator.addForce(
                    at: normalizedPos,
                    velocity: explosionVel,
                    radius: 0.08,
                    color: color
                )
            }
        }
    }
}
