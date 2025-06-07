//
//  MetalFluidSimulator.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import Metal
import MetalKit
import simd

class MetalFluidSimulator {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // Compute pipeline states - CHANGE: Make optional for safety
    private var advectionPipeline: MTLComputePipelineState?
    private var diffusionPipeline: MTLComputePipelineState?
    private var projectionDivergencePipeline: MTLComputePipelineState?
    private var projectionPressurePipeline: MTLComputePipelineState?
    private var projectionGradientPipeline: MTLComputePipelineState?
    private var addForcePipeline: MTLComputePipelineState?
    private var fadePipeline: MTLComputePipelineState?
    
    // Simulation textures (double buffered)
    private var velocityTextures: [MTLTexture] = []
    private var densityTextures: [MTLTexture] = []
    private var colorTextures: [MTLTexture] = []
    private var pressureTextures: [MTLTexture] = []
    private var divergenceTexture: MTLTexture?
    
    private var currentBuffer = 0
    private let width: Int
    private let height: Int
    
    // Uniform buffer
    private var uniformBuffer: MTLBuffer?
    private var isInitialized = false
    
    init?(device: MTLDevice, width: Int, height: Int) {
        self.device = device
        self.width = width
        self.height = height
        
        guard let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else {
            print("Failed to create Metal command queue or library")
            return nil
        }
        
        self.commandQueue = commandQueue
        self.library = library
        
        guard setupTextures() && setupPipelines() && setupBuffers() else {
            print("Failed to initialize Metal fluid simulator")
            return nil
        }
        
        isInitialized = true
    }
    
    private func setupTextures() -> Bool {
        // Create texture descriptor
        let descriptor = MTLTextureDescriptor()
        descriptor.width = width
        descriptor.height = height
        descriptor.pixelFormat = .rgba32Float
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        
        // Create double buffered textures
        for _ in 0..<2 {
            guard let velocityTex = device.makeTexture(descriptor: descriptor),
                  let densityTex = device.makeTexture(descriptor: descriptor),
                  let colorTex = device.makeTexture(descriptor: descriptor),
                  let pressureTex = device.makeTexture(descriptor: descriptor) else {
                print("Failed to create textures")
                return false
            }
            
            velocityTextures.append(velocityTex)
            densityTextures.append(densityTex)
            colorTextures.append(colorTex)
            pressureTextures.append(pressureTex)
        }
        
        // Single divergence texture
        guard let divTex = device.makeTexture(descriptor: descriptor) else {
            print("Failed to create divergence texture")
            return false
        }
        divergenceTexture = divTex
        
        return true
    }
    
    private func setupPipelines() -> Bool {
        advectionPipeline = createComputePipeline(functionName: "advection_kernel")
        diffusionPipeline = createComputePipeline(functionName: "diffusion_kernel")
        projectionDivergencePipeline = createComputePipeline(functionName: "projection_divergence_kernel")
        projectionPressurePipeline = createComputePipeline(functionName: "projection_pressure_kernel")
        projectionGradientPipeline = createComputePipeline(functionName: "projection_gradient_kernel")
        addForcePipeline = createComputePipeline(functionName: "add_force_kernel")
        fadePipeline = createComputePipeline(functionName: "fade_kernel")
        
        // Check if all pipelines were created successfully
        return advectionPipeline != nil &&
               diffusionPipeline != nil &&
               projectionDivergencePipeline != nil &&
               projectionPressurePipeline != nil &&
               projectionGradientPipeline != nil &&
               addForcePipeline != nil &&
               fadePipeline != nil
    }
    
    private func createComputePipeline(functionName: String) -> MTLComputePipelineState? {
        guard let function = library.makeFunction(name: functionName) else {
            print("Failed to create function: \(functionName)")
            return nil
        }
        
        do {
            return try device.makeComputePipelineState(function: function)
        } catch {
            print("Failed to create pipeline for \(functionName): \(error)")
            return nil
        }
    }
    
    private func setupBuffers() -> Bool {
        let uniformSize = MemoryLayout<MetalFluidUniforms>.size
        uniformBuffer = device.makeBuffer(length: uniformSize, options: .storageModeShared)
        return uniformBuffer != nil
    }
    
    func step(parameters: FluidParameters) {
        guard isInitialized else { return }
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
        currentBuffer = 1 - currentBuffer
    }
    
    private func updateUniforms(_ parameters: FluidParameters) {
        guard let uniformBuffer = uniformBuffer else { return }
        
        let uniforms = MetalFluidUniforms(
            dt: parameters.timeStep,
            viscosity: parameters.viscosity,
            diffusion: parameters.diffusion,
            fadeRate: parameters.fadeRate,
            forceMultiplier: parameters.forceMultiplier,
            width: UInt32(width),
            height: UInt32(height),
            iterations: UInt32(parameters.iterations)
        )
        
        let uniformPointer = uniformBuffer.contents().bindMemory(to: MetalFluidUniforms.self, capacity: 1)
        uniformPointer.pointee = uniforms
    }
    
    private func performVelocityStep(commandBuffer: MTLCommandBuffer, parameters: FluidParameters) {
        let currentVel = velocityTextures[currentBuffer]
        let previousVel = velocityTextures[1 - currentBuffer]
        
        // Diffusion
        performDiffusion(commandBuffer: commandBuffer, source: currentVel, destination: previousVel, iterations: parameters.iterations)
        
        // Projection
        performProjection(commandBuffer: commandBuffer, velocityTexture: previousVel)
        
        // Advection
        performAdvection(commandBuffer: commandBuffer, velocity: previousVel, source: previousVel, destination: currentVel)
        
        // Final projection
        performProjection(commandBuffer: commandBuffer, velocityTexture: currentVel)
    }
    
    private func performDensityStep(commandBuffer: MTLCommandBuffer, parameters: FluidParameters) {
        let currentDensity = densityTextures[currentBuffer]
        let previousDensity = densityTextures[1 - currentBuffer]
        let velocity = velocityTextures[currentBuffer]
        
        // Diffusion
        performDiffusion(commandBuffer: commandBuffer, source: currentDensity, destination: previousDensity, iterations: parameters.iterations)
        
        // Advection
        performAdvection(commandBuffer: commandBuffer, velocity: velocity, source: previousDensity, destination: currentDensity)
        
        // Fade
        performFade(commandBuffer: commandBuffer, texture: currentDensity)
    }
    
    private func performColorStep(commandBuffer: MTLCommandBuffer, parameters: FluidParameters) {
        let currentColor = colorTextures[currentBuffer]
        let previousColor = colorTextures[1 - currentBuffer]
        let velocity = velocityTextures[currentBuffer]
        
        // Diffusion
        performDiffusion(commandBuffer: commandBuffer, source: currentColor, destination: previousColor, iterations: max(1, parameters.iterations / 2))
        
        // Advection
        performAdvection(commandBuffer: commandBuffer, velocity: velocity, source: previousColor, destination: currentColor)
        
        // Fade
        performFade(commandBuffer: commandBuffer, texture: currentColor)
    }
    
    private func performDiffusion(commandBuffer: MTLCommandBuffer, source: MTLTexture, destination: MTLTexture, iterations: Int) {
        guard let pipeline = diffusionPipeline,
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
        
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (width + 15) / 16,
            height: (height + 15) / 16,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
    }
    
    private func performAdvection(commandBuffer: MTLCommandBuffer, velocity: MTLTexture, source: MTLTexture, destination: MTLTexture) {
        guard let pipeline = advectionPipeline,
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(velocity, index: 0)
        encoder.setTexture(source, index: 1)
        encoder.setTexture(destination, index: 2)
        encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
        
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (width + 15) / 16,
            height: (height + 15) / 16,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
    }
    
    private func performProjection(commandBuffer: MTLCommandBuffer, velocityTexture: MTLTexture) {
        guard let divergenceTexture = divergenceTexture,
              let divergencePipeline = projectionDivergencePipeline,
              let gradientPipeline = projectionGradientPipeline else { return }
        
        // Calculate divergence
        guard let encoder1 = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder1.setComputePipelineState(divergencePipeline)
        encoder1.setTexture(velocityTexture, index: 0)
        encoder1.setTexture(divergenceTexture, index: 1)
        encoder1.setBuffer(uniformBuffer, offset: 0, index: 0)
        
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (width + 15) / 16,
            height: (height + 15) / 16,
            depth: 1
        )
        
        encoder1.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder1.endEncoding()
        
        // Solve pressure with safer iteration count
        let pressure = pressureTextures[currentBuffer]
        performDiffusion(commandBuffer: commandBuffer, source: divergenceTexture, destination: pressure, iterations: 20)
        
        // Apply pressure gradient
        guard let encoder2 = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder2.setComputePipelineState(gradientPipeline)
        encoder2.setTexture(pressure, index: 0)
        encoder2.setTexture(velocityTexture, index: 1)
        encoder2.setBuffer(uniformBuffer, offset: 0, index: 0)
        
        encoder2.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder2.endEncoding()
    }
    
    private func performFade(commandBuffer: MTLCommandBuffer, texture: MTLTexture) {
        guard let pipeline = fadePipeline,
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
        
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (width + 15) / 16,
            height: (height + 15) / 16,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
    }
    
    func addForce(at position: SIMD2<Float>, velocity: SIMD2<Float>, radius: Float, color: SIMD3<Float>) {
        guard isInitialized,
              let pipeline = addForcePipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        // Create force data with safe values
        var forceData = ForceData(
            position: position,
            velocity: velocity,
            radius: radius,
            color: color
        )
        
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(velocityTextures[currentBuffer], index: 0)
        encoder.setTexture(densityTextures[currentBuffer], index: 1)
        encoder.setTexture(colorTextures[currentBuffer], index: 2)
        encoder.setBytes(&forceData, length: MemoryLayout<ForceData>.size, index: 0)
        encoder.setBuffer(uniformBuffer, offset: 0, index: 1)
        
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (width + 15) / 16,
            height: (height + 15) / 16,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        
        commandBuffer.commit()
    }
    
    func getCurrentColorTexture() -> MTLTexture? {
        guard isInitialized, 
              currentBuffer >= 0,
              currentBuffer < colorTextures.count,
              !colorTextures.isEmpty else {
            print("❌ MetalFluidSimulator: Invalid state for getCurrentColorTexture")
            return nil
        }
        return colorTextures[currentBuffer]
    }
    
    func getCurrentDensityTexture() -> MTLTexture? {
        guard isInitialized,
              currentBuffer >= 0,
              currentBuffer < densityTextures.count,
              !densityTextures.isEmpty else {
            print("❌ MetalFluidSimulator: Invalid state for getCurrentDensityTexture")
            return nil
        }
        return densityTextures[currentBuffer]
    }
    
    func clear() {
        guard isInitialized,
              let pipeline = fadePipeline,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // Use fade kernel with 0.0 factor to clear
        for texture in velocityTextures + densityTextures + colorTextures + pressureTextures {
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { continue }
            
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(texture, index: 0)
            
            // Set fade rate to 0 to clear completely
            var clearUniforms = MetalFluidUniforms(
                dt: 0, viscosity: 0, diffusion: 0, fadeRate: 0.0,
                forceMultiplier: 0, width: UInt32(width), height: UInt32(height), iterations: 0
            )
            encoder.setBytes(&clearUniforms, length: MemoryLayout<MetalFluidUniforms>.size, index: 0)
            
            let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
            let threadGroups = MTLSize(
                width: (width + 15) / 16,
                height: (height + 15) / 16,
                depth: 1
            )
            
            encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
        }
        
        commandBuffer.commit()
    }
}

// Metal uniform structure
struct MetalFluidUniforms {
    let dt: Float
    let viscosity: Float
    let diffusion: Float
    let fadeRate: Float
    let forceMultiplier: Float
    let width: UInt32
    let height: UInt32
    let iterations: UInt32
}

// Force data structure
struct ForceData {
    let position: SIMD2<Float>
    let velocity: SIMD2<Float>
    let radius: Float
    let color: SIMD3<Float>
}
