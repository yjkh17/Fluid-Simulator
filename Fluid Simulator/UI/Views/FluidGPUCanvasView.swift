//
//  FluidGPUCanvasView.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI
import MetalKit

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
        
        // Enable touch interaction
        let dragGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDrag(_:)))
        metalView.addGestureRecognizer(dragGesture)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        metalView.addGestureRecognizer(tapGesture)
        
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
        
        init(simulator: FluidSimulatorGPU, selectedPalette: ColorPalette) {
            self.simulator = simulator
            self.selectedPalette = selectedPalette
            super.init()
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
            
            // Step simulation on GPU
            simulator.step()
            
            // Render directly from GPU textures
            simulator.render(to: renderPassDescriptor)
        }
        
        @objc func handleDrag(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            
            let location = gesture.location(in: view)
            let velocity = gesture.velocity(in: view)
            
            // Convert to normalized coordinates
            let normalizedPos = SIMD2<Float>(
                Float(location.x / view.bounds.width),
                Float(1.0 - location.y / view.bounds.height)
            )
            
            // Scale velocity appropriately
            let normalizedVel = SIMD2<Float>(
                Float(velocity.x / view.bounds.width * 0.1),
                Float(-velocity.y / view.bounds.height * 0.1)
            )
            
            let color = selectedPalette.getRandomColor()
            
            // Add force directly to GPU
            simulator.addForce(
                at: normalizedPos,
                velocity: normalizedVel,
                radius: 50.0,
                color: color
            )
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
    }
}

#Preview {
    if let device = MTLCreateSystemDefaultDevice(),
       let simulator = FluidSimulatorGPU(device: device, width: 128, height: 256) {
        FluidGPUCanvasView(
            selectedPalette: ColorPalette.palettes[0],
            screenSize: CGSize(width: 400, height: 800),
            simulator: simulator
        )
    } else {
        Text("Metal not available")
    }
}