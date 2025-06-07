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
        private var isMetalInitialized = false
        private var sampler: MTLSamplerState?
        
        init(selectedPalette: ColorPalette, screenSize: CGSize, fluidEngine: FluidEngine) {
            self.selectedPalette = selectedPalette
            self.screenSize = screenSize
            self.fluidEngine = fluidEngine
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            print("🔧 Metal setup starting...")
            
            guard let device = view.device else {
                print("❌ No Metal device available")
                isMetalInitialized = false
                return
            }
            
            print("🔧 Metal device: \(device.name)")
            self.device = device
            
            guard let commandQueue = device.makeCommandQueue() else {
                print("❌ Failed to create command queue")
                isMetalInitialized = false
                return
            }
            self.commandQueue = commandQueue
            
            // SAFE: Start with very small resolution
            let simWidth = 32   // Start small and safe
            let simHeight = 64  // Start small and safe
            
            print("🔧 Creating Metal simulator: \(simWidth)x\(simHeight)")
            
            // SAFE: Create simulator step by step with validation
            do {
                if let simulator = MetalFluidSimulator(device: device, width: simWidth, height: simHeight) {
                    metalSimulator = simulator
                    print("✅ Metal simulator created")
                    
                    // VALIDATE: Make sure textures are actually created
                    if simulator.getCurrentColorTexture() != nil &&
                       simulator.getCurrentDensityTexture() != nil {
                        print("✅ Metal textures validated")
                        isMetalInitialized = true
                    } else {
                        print("❌ Metal textures are nil")
                        metalSimulator = nil
                        isMetalInitialized = false
                        return
                    }
                } else {
                    print("❌ Failed to create Metal simulator")
                    isMetalInitialized = false
                    return
                }
            } catch {
                print("❌ Exception creating Metal simulator: \(error)")
                isMetalInitialized = false
                return
            }
            
            // SAFE: Setup render pipeline with validation
            setupRenderPipeline(device: device, view: view)
            
            // FINAL VALIDATION: Everything must be ready
            if renderPipeline == nil {
                print("❌ Render pipeline failed - disabling Metal")
                isMetalInitialized = false
                metalSimulator = nil
            } else {
                print("✅ Metal fully initialized and ready")
            }
        }
        
        private func setupRenderPipeline(device: MTLDevice, view: MTKView) {
            print("🔧 Setting up render pipeline...")
            
            guard let library = device.makeDefaultLibrary() else {
                print("❌ Failed to get default library")
                isMetalInitialized = false
                return
            }
            
            // Check if functions exist before creating pipeline
            guard let vertexFunction = library.makeFunction(name: "fluid_display_vertex") else {
                print("❌ Failed to find vertex function: fluid_display_vertex")
                isMetalInitialized = false
                return
            }
            
            guard let fragmentFunction = library.makeFunction(name: "fluid_display_fragment") else {
                print("❌ Failed to find fragment function: fluid_display_fragment")
                isMetalInitialized = false
                return
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            
            do {
                renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
                print("✅ Successfully created render pipeline")
            } catch {
                print("❌ Failed to create render pipeline: \(error)")
                isMetalInitialized = false
            }
        }
        
        func draw(in view: MTKView) {
            // Always get drawable and render pass descriptor first
            guard let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else {
                print("❌ No drawable or render pass descriptor")
                return
            }
            
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            
            // FIXED: More defensive checks for Metal initialization
            guard isMetalInitialized else {
                print("❌ Metal not initialized - presenting black screen")
                if let commandQueue = commandQueue,
                   let commandBuffer = commandQueue.makeCommandBuffer() {
                    commandBuffer.present(drawable)
                    commandBuffer.commit()
                }
                return
            }
            
            guard let metalSimulator = metalSimulator else {
                print("❌ No metal simulator - presenting black screen")
                if let commandQueue = commandQueue,
                   let commandBuffer = commandQueue.makeCommandBuffer() {
                    commandBuffer.present(drawable)
                    commandBuffer.commit()
                }
                return
            }
            
            guard let renderPipeline = renderPipeline else {
                print("❌ No render pipeline - presenting black screen")
                if let commandQueue = commandQueue,
                   let commandBuffer = commandQueue.makeCommandBuffer() {
                    commandBuffer.present(drawable)
                    commandBuffer.commit()
                }
                return
            }
            
            guard let commandQueue = commandQueue else {
                print("❌ No command queue")
                return
            }
            
            // FIXED: Step simulation with proper error handling
            metalSimulator.step(parameters: fluidEngine.parameters)
            
            // FIXED: Create command buffer with error handling
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                print("❌ Failed to create command buffer")
                return
            }
            
            // FIXED: Create render encoder with error handling
            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                print("❌ Failed to create render encoder")
                commandBuffer.present(drawable)
                commandBuffer.commit()
                return
            }
            
            // FIXED: Get textures with much safer error handling
            guard let colorTexture = metalSimulator.getCurrentColorTexture(),
                  let densityTexture = metalSimulator.getCurrentDensityTexture() else {
                print("❌ Failed to get simulation textures - using fallback")
                // FIXED: Still render something instead of crashing
                renderEncoder.setRenderPipelineState(renderPipeline)
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                renderEncoder.endEncoding()
                commandBuffer.present(drawable)
                commandBuffer.commit()
                return
            }
            
            // Finally render with textures
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
            guard isMetalInitialized,
                  let metalSimulator = metalSimulator,
                  let view = gesture.view else { return }
            
            let location = gesture.location(in: view)
            let velocity = gesture.velocity(in: view)
            
            // Convert to normalized coordinates
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
            
            // Convert to normalized coordinates
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
