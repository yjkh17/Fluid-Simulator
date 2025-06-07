//
//  FluidRenderer.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import Metal
import MetalKit
import SwiftUI

class FluidRenderer: NSObject, ObservableObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineBuilder: PipelineBuilder
    
    // Textures for double buffering
    private var velocityTextures: [MTLTexture] = []
    private var densityTextures: [MTLTexture] = []
    private var colorTextures: [MTLTexture] = []
    private var pressureTextures: [MTLTexture] = []
    private var divergenceTexture: MTLTexture?
    
    private var currentTextureIndex = 0
    private let textureWidth: Int
    private let textureHeight: Int
    
    // Uniform buffer
    private var uniformBuffer: MTLBuffer?
    
    init?(width: Int, height: Int) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let pipelineBuilder = PipelineBuilder(device: device) else {
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.pipelineBuilder = pipelineBuilder
        self.textureWidth = width
        self.textureHeight = height
        
        super.init()
        
        setupTextures()
        setupBuffers()
    }
    
    private func setupTextures() {
        let descriptor = MTLTextureDescriptor()
        descriptor.width = textureWidth
        descriptor.height = textureHeight
        descriptor.pixelFormat = .rgba32Float
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        // Create double-buffered textures
        for _ in 0..<2 {
            guard let velocityTexture = device.makeTexture(descriptor: descriptor),
                  let densityTexture = device.makeTexture(descriptor: descriptor),
                  let colorTexture = device.makeTexture(descriptor: descriptor),
                  let pressureTexture = device.makeTexture(descriptor: descriptor) else {
                return
            }
            
            velocityTextures.append(velocityTexture)
            densityTextures.append(densityTexture)
            colorTextures.append(colorTexture)
            pressureTextures.append(pressureTexture)
        }
        
        // Single divergence texture
        divergenceTexture = device.makeTexture(descriptor: descriptor)
    }
    
    private func setupBuffers() {
        let uniformSize = MemoryLayout<FluidUniforms>.size
        uniformBuffer = device.makeBuffer(length: uniformSize, options: .storageModeShared)
    }
    
    func step(with parameters: FluidParameters) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        updateUniforms(parameters)
        
        // Velocity step
        performVelocityStep(commandBuffer: commandBuffer, parameters: parameters)
        
        // Density step
        performDensityStep(commandBuffer: commandBuffer, parameters: parameters)
        
        // Color step
        performColorStep(commandBuffer: commandBuffer, parameters: parameters)
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Swap buffers
        currentTextureIndex = 1 - currentTextureIndex
    }
    
    private func updateUniforms(_ parameters: FluidParameters) {
        guard let uniformBuffer = uniformBuffer else { return }
        
        let uniforms = FluidUniforms(
            dt: parameters.timeStep,
            viscosity: parameters.viscosity,
            diffusion: parameters.diffusion,
            force_multiplier: parameters.forceMultiplier,
            fade_rate: parameters.fadeRate,
            width: UInt32(textureWidth),
            height: UInt32(textureHeight),
            iterations: Int32(parameters.iterations)
        )
        
        let uniformPointer = uniformBuffer.contents().bindMemory(to: FluidUniforms.self, capacity: 1)
        uniformPointer.pointee = uniforms
    }
    
    private func performVelocityStep(commandBuffer: MTLCommandBuffer, parameters: FluidParameters) {
        // Diffusion
        performDiffusion(
            commandBuffer: commandBuffer,
            source: velocityTextures[currentTextureIndex],
            destination: velocityTextures[1 - currentTextureIndex],
            iterations: parameters.iterations
        )
        
        // Projection
        performProjection(commandBuffer: commandBuffer, parameters: parameters)
        
        // Advection
        performAdvection(
            commandBuffer: commandBuffer,
            velocity: velocityTextures[currentTextureIndex],
            source: velocityTextures[1 - currentTextureIndex],
            destination: velocityTextures[currentTextureIndex]
        )
        
        // Final projection
        performProjection(commandBuffer: commandBuffer, parameters: parameters)
    }
    
    private func performDensityStep(commandBuffer: MTLCommandBuffer, parameters: FluidParameters) {
        // Diffusion
        performDiffusion(
            commandBuffer: commandBuffer,
            source: densityTextures[currentTextureIndex],
            destination: densityTextures[1 - currentTextureIndex],
            iterations: parameters.iterations
        )
        
        // Advection
        performAdvection(
            commandBuffer: commandBuffer,
            velocity: velocityTextures[currentTextureIndex],
            source: densityTextures[1 - currentTextureIndex],
            destination: densityTextures[currentTextureIndex]
        )
    }
    
    private func performColorStep(commandBuffer: MTLCommandBuffer, parameters: FluidParameters) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder(),
              let pipeline = pipelineBuilder.colorMixPipeline else { return }
        
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(colorTextures[currentTextureIndex], index: 0)
        encoder.setTexture(velocityTextures[currentTextureIndex], index: 1)
        encoder.setTexture(colorTextures[1 - currentTextureIndex], index: 2)
        encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
        
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (textureWidth + 15) / 16,
            height: (textureHeight + 15) / 16,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        
        // Swap color textures
        let temp = colorTextures[currentTextureIndex]
        colorTextures[currentTextureIndex] = colorTextures[1 - currentTextureIndex]
        colorTextures[1 - currentTextureIndex] = temp
    }
    
    private func performDiffusion(
        commandBuffer: MTLCommandBuffer,
        source: MTLTexture,
        destination: MTLTexture,
        iterations: Int
    ) {
        guard let pipeline = pipelineBuilder.diffusionPipeline else { return }
        
        var currentSource = source
        var currentDest = destination
        
        for _ in 0..<iterations {
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { continue }
            
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(currentSource, index: 0)
            encoder.setTexture(currentDest, index: 1)
            encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
            
            let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
            let threadGroups = MTLSize(
                width: (textureWidth + 15) / 16,
                height: (textureHeight + 15) / 16,
                depth: 1
            )
            
            encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
            
            // Swap for next iteration
            swap(&currentSource, &currentDest)
        }
    }
    
    private func performAdvection(
        commandBuffer: MTLCommandBuffer,
        velocity: MTLTexture,
        source: MTLTexture,
        destination: MTLTexture
    ) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder(),
              let pipeline = pipelineBuilder.advectionPipeline else { return }
        
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(velocity, index: 0)
        encoder.setTexture(source, index: 1)
        encoder.setTexture(destination, index: 2)
        encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
        
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (textureWidth + 15) / 16,
            height: (textureHeight + 15) / 16,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
    }
    
    private func performProjection(commandBuffer: MTLCommandBuffer, parameters: FluidParameters) {
        guard let divergenceTexture = divergenceTexture else { return }
        
        // Calculate divergence
        if let encoder = commandBuffer.makeComputeCommandEncoder(),
           let pipeline = pipelineBuilder.divergencePipeline {
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(velocityTextures[currentTextureIndex], index: 0)
            encoder.setTexture(divergenceTexture, index: 1)
            encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
            
            let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
            let threadGroups = MTLSize(
                width: (textureWidth + 15) / 16,
                height: (textureHeight + 15) / 16,
                depth: 1
            )
            
            encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
        }
        
        // Solve pressure
        performDiffusion(
            commandBuffer: commandBuffer,
            source: divergenceTexture,
            destination: pressureTextures[currentTextureIndex],
            iterations: parameters.iterations
        )
        
        // Apply pressure gradient
        if let encoder = commandBuffer.makeComputeCommandEncoder(),
           let pipeline = pipelineBuilder.pressureGradientPipeline {
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(pressureTextures[currentTextureIndex], index: 0)
            encoder.setTexture(velocityTextures[currentTextureIndex], index: 1)
            encoder.setTexture(velocityTextures[1 - currentTextureIndex], index: 2)
            encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
            
            let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
            let threadGroups = MTLSize(
                width: (textureWidth + 15) / 16,
                height: (textureHeight + 15) / 16,
                depth: 1
            )
            
            encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
        }
    }
    
    func addForce(at position: CGPoint, velocity: CGPoint, radius: Float, color: SIMD3<Float>) {
        // This would be called from the touch tracker
        // Implementation would add force and color to the simulation
    }
    
    func getCurrentColorTexture() -> MTLTexture? {
        return colorTextures[currentTextureIndex]
    }
    
    func getCurrentDensityTexture() -> MTLTexture? {
        return densityTextures[currentTextureIndex]
    }
}

// Uniforms structure matching Metal shader
struct FluidUniforms {
    let dt: Float
    let viscosity: Float
    let diffusion: Float
    let force_multiplier: Float
    let fade_rate: Float
    let width: UInt32
    let height: UInt32
    let iterations: Int32
}
