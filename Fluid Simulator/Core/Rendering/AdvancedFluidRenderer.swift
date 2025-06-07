//
//  AdvancedFluidRenderer.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import Metal
import MetalKit
import simd

class AdvancedFluidRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // Render pipelines (based on WebGL Programs)
    private var displayPipeline: MTLRenderPipelineState?
    private var blurPipeline: MTLRenderPipelineState?
    private var bloomPrefilterPipeline: MTLRenderPipelineState?
    private var splatPipeline: MTLRenderPipelineState?
    
    // Textures for multi-pass rendering
    private var fluidTexture: MTLTexture?
    private var bloomTexture: MTLTexture?
    private var tempTextures: [MTLTexture] = []
    
    // Render settings (based on WebGL material system)
    var enableShading: Bool = true
    var enableBloom: Bool = true
    var bloomIntensity: Float = 0.8
    var bloomThreshold: Float = 0.6
    
    init?(device: MTLDevice) {
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else {
            return nil
        }
        
        self.commandQueue = commandQueue
        self.library = library
        
        setupPipelines()
        setupTextures()
    }
    
    private func setupPipelines() {
        // Display pipeline with shading and bloom
        let displayDescriptor = MTLRenderPipelineDescriptor()
        displayDescriptor.vertexFunction = library.makeFunction(name: "displayVertexShader")
        displayDescriptor.fragmentFunction = library.makeFunction(name: "displayFragmentShader")
        displayDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        displayDescriptor.colorAttachments[0].isBlendingEnabled = true
        displayDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        displayDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            displayPipeline = try device.makeRenderPipelineState(descriptor: displayDescriptor)
        } catch {
            print("Failed to create display pipeline: \(error)")
        }
        
        // Blur pipeline for bloom effect
        let blurDescriptor = MTLRenderPipelineDescriptor()
        blurDescriptor.vertexFunction = library.makeFunction(name: "displayVertexShader")
        blurDescriptor.fragmentFunction = library.makeFunction(name: "blurFragmentShader")
        blurDescriptor.colorAttachments[0].pixelFormat = .rgba16Float
        
        do {
            blurPipeline = try device.makeRenderPipelineState(descriptor: blurDescriptor)
        } catch {
            print("Failed to create blur pipeline: \(error)")
        }
        
        // Bloom prefilter pipeline
        let bloomDescriptor = MTLRenderPipelineDescriptor()
        bloomDescriptor.vertexFunction = library.makeFunction(name: "displayVertexShader")
        bloomDescriptor.fragmentFunction = library.makeFunction(name: "bloomPrefilterShader")
        bloomDescriptor.colorAttachments[0].pixelFormat = .rgba16Float
        
        do {
            bloomPrefilterPipeline = try device.makeRenderPipelineState(descriptor: bloomDescriptor)
        } catch {
            print("Failed to create bloom prefilter pipeline: \(error)")
        }
    }
    
    private func setupTextures() {
        let descriptor = MTLTextureDescriptor()
        descriptor.width = 512
        descriptor.height = 512
        descriptor.pixelFormat = .rgba16Float
        descriptor.usage = [.shaderRead, .renderTarget]
        
        fluidTexture = device.makeTexture(descriptor: descriptor)
        bloomTexture = device.makeTexture(descriptor: descriptor)
        
        // Create temporary textures for bloom passes
        for _ in 0..<4 {
            if let texture = device.makeTexture(descriptor: descriptor) {
                tempTextures.append(texture)
            }
        }
    }
    
    // Main render function (based on WebGL render method)
    func render(fluidState: FluidState, to drawable: CAMetalDrawable) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // Convert fluid state to texture
        updateFluidTexture(fluidState: fluidState, commandBuffer: commandBuffer)
        
        // Apply bloom effect if enabled
        if enableBloom {
            applyBloom(commandBuffer: commandBuffer)
        }
        
        // Final display pass
        renderToDrawable(drawable: drawable, commandBuffer: commandBuffer)
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func updateFluidTexture(fluidState: FluidState, commandBuffer: MTLCommandBuffer) {
        // Convert CPU fluid state to GPU texture
        // This would involve uploading the color/density data to the GPU
        // Implementation details depend on the specific Metal setup
    }
    
    private func applyBloom(commandBuffer: MTLCommandBuffer) {
        guard let bloomPrefilterPipeline = bloomPrefilterPipeline,
              let blurPipeline = blurPipeline,
              let fluidTexture = fluidTexture,
              let bloomTexture = bloomTexture else { return }
        
        // Prefilter pass (extract bright areas)
        let prefilterDescriptor = MTLRenderPassDescriptor()
        prefilterDescriptor.colorAttachments[0].texture = tempTextures[0]
        prefilterDescriptor.colorAttachments[0].loadAction = .clear
        prefilterDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        guard let prefilterEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: prefilterDescriptor) else { return }
        prefilterEncoder.setRenderPipelineState(bloomPrefilterPipeline)
        prefilterEncoder.setFragmentTexture(fluidTexture, index: 0)
        
        var curve = simd_float3(bloomThreshold * 0.5, bloomThreshold * 2.0, 0.25 / bloomThreshold)
        prefilterEncoder.setFragmentBytes(&curve, length: MemoryLayout<simd_float3>.size, index: 0)
        prefilterEncoder.setFragmentBytes(&bloomThreshold, length: MemoryLayout<Float>.size, index: 1)
        
        // Draw full screen quad
        prefilterEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        prefilterEncoder.endEncoding()
        
        // Blur passes for bloom effect
        for i in 1..<tempTextures.count {
            let blurDescriptor = MTLRenderPassDescriptor()
            blurDescriptor.colorAttachments[0].texture = tempTextures[i]
            blurDescriptor.colorAttachments[0].loadAction = .clear
            
            guard let blurEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: blurDescriptor) else { continue }
            blurEncoder.setRenderPipelineState(blurPipeline)
            blurEncoder.setFragmentTexture(tempTextures[i-1], index: 0)
            blurEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            blurEncoder.endEncoding()
        }
        
        // Final bloom result goes to bloomTexture
        let finalDescriptor = MTLRenderPassDescriptor()
        finalDescriptor.colorAttachments[0].texture = bloomTexture
        finalDescriptor.colorAttachments[0].loadAction = .clear
        
        guard let finalEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: finalDescriptor) else { return }
        finalEncoder.setRenderPipelineState(blurPipeline)
        finalEncoder.setFragmentTexture(tempTextures.last, index: 0)
        finalEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        finalEncoder.endEncoding()
    }
    
    private func renderToDrawable(drawable: CAMetalDrawable, commandBuffer: MTLCommandBuffer) {
        guard let displayPipeline = displayPipeline,
              let fluidTexture = fluidTexture else { return }
        
        let renderDescriptor = MTLRenderPassDescriptor()
        renderDescriptor.colorAttachments[0].texture = drawable.texture
        renderDescriptor.colorAttachments[0].loadAction = .clear
        renderDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderDescriptor) else { return }
        renderEncoder.setRenderPipelineState(displayPipeline)
        renderEncoder.setFragmentTexture(fluidTexture, index: 0)
        
        if enableBloom, let bloomTexture = bloomTexture {
            renderEncoder.setFragmentTexture(bloomTexture, index: 1)
        }
        
        var texelSize = simd_float2(1.0 / Float(fluidTexture.width), 1.0 / Float(fluidTexture.height))
        renderEncoder.setFragmentBytes(&texelSize, length: MemoryLayout<simd_float2>.size, index: 0)
        renderEncoder.setFragmentBytes(&enableShading, length: MemoryLayout<Bool>.size, index: 1)
        renderEncoder.setFragmentBytes(&enableBloom, length: MemoryLayout<Bool>.size, index: 2)
        
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
    }
}