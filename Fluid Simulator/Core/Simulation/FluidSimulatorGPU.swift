//
//  FluidSimulatorGPU.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import Metal
import MetalKit
import simd

/// GPU-first fluid simulator following migration blueprint
/// This replaces FluidEngine as the single source of truth
class FluidSimulatorGPU: ObservableObject {
    
    // MARK: - GPU State (Step 1 from blueprint)
    
    struct FluidGPUState {
        let velocity: [MTLTexture]   // double-buffered [rgba32Float: u,v,unused,unused]
        let density: [MTLTexture]    // double-buffered [r32Float: ρ]
        let color: [MTLTexture]      // double-buffered [rgba16Float: R,G,B,unused]
        let pressure: [MTLTexture]   // double-buffered for Jacobi iteration
        let divergence: MTLTexture   // single buffer
        var current: Int = 0         // ping-pong index
        
        func swap() -> Int {
            return 1 - current
        }
    }
    
    // MARK: - Properties
    
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var gpuState: FluidGPUState?
    private var drawable: MTLDrawable?
    
    // Pipeline states for each kernel
    private var advectionPSO: MTLComputePipelineState?
    private var diffusionPSO: MTLComputePipelineState?
    private var projectionDivergencePSO: MTLComputePipelineState?
    private var projectionPressurePSO: MTLComputePipelineState?
    private var projectionGradientPSO: MTLComputePipelineState?
    private var addForcePSO: MTLComputePipelineState?
    private var fadePSO: MTLComputePipelineState?
    
    // Rendering pipeline
    private var renderPSO: MTLRenderPipelineState?
    private var sampler: MTLSamplerState?
    
    // Uniforms
    private var uniformsBuffer: MTLBuffer?
    
    // Simulation parameters
    @Published var parameters: FluidParameters
    
    // Grid dimensions
    @Published private(set) var width: Int
    @Published private(set) var height: Int
    
    // MARK: - Initialization
    
    init?(device: MTLDevice, width: Int, height: Int) {
        self.device = device
        self.width = width
        self.height = height
        self.parameters = FluidParameters()
        
        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue
        
        setupTextures()
        setupPipelineStates()
        setupUniforms()
        setupSampler()
    }
    
    // MARK: - Resize Handling
    
    func resize(width newWidth: Int, height newHeight: Int) {
        let clampedWidth = max(1, newWidth)
        let clampedHeight = max(1, newHeight)
        
        guard clampedWidth != width || clampedHeight != height else {
            return
        }
        
        width = clampedWidth
        height = clampedHeight
        
        setupTextures()
        updateUniforms()
    }
    
    // MARK: - Setup Methods
    
    private func setupTextures() {
        // Velocity: rgba32Float (u, v, unused, unused)
        let velocityTextures = createTextureArray(
            pixelFormat: .rgba32Float,
            usage: [.shaderRead, .shaderWrite],
            count: 2
        )
        
        // Density: r32Float (ρ)
        let densityTextures = createTextureArray(
            pixelFormat: .r32Float,
            usage: [.shaderRead, .shaderWrite],
            count: 2
        )
        
        // Color: rgba16Float (R, G, B, unused)
        let colorTextures = createTextureArray(
            pixelFormat: .rgba16Float,
            usage: [.shaderRead, .shaderWrite],
            count: 2
        )
        
        // Pressure: r32Float (double-buffered for Jacobi)
        let pressureTextures = createTextureArray(
            pixelFormat: .r32Float,
            usage: [.shaderRead, .shaderWrite],
            count: 2
        )
        
        // Divergence: single buffer
        guard let divergenceTexture = createTexture(
            pixelFormat: .r32Float,
            usage: [.shaderRead, .shaderWrite]
        ) else {
            print("Failed to create divergence texture")
            return
        }
        
        gpuState = FluidGPUState(
            velocity: velocityTextures,
            density: densityTextures,
            color: colorTextures,
            pressure: pressureTextures,
            divergence: divergenceTexture
        )
    }
    
    private func createTextureArray(pixelFormat: MTLPixelFormat, usage: MTLTextureUsage, count: Int) -> [MTLTexture] {
        var textures: [MTLTexture] = []
        for _ in 0..<count {
            if let texture = createTexture(pixelFormat: pixelFormat, usage: usage) {
                textures.append(texture)
            }
        }
        return textures
    }
    
    private func createTexture(pixelFormat: MTLPixelFormat, usage: MTLTextureUsage) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor()
        descriptor.width = width
        descriptor.height = height
        descriptor.pixelFormat = pixelFormat
        descriptor.usage = usage
        descriptor.storageMode = .private
        
        return device.makeTexture(descriptor: descriptor)
    }
    
    private func setupPipelineStates() {
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to get default library")
            return
        }
        
        // Create compute pipeline states
        advectionPSO = createComputePipeline(library: library, functionName: "advection_kernel")
        diffusionPSO = createComputePipeline(library: library, functionName: "diffusion_kernel")
        projectionDivergencePSO = createComputePipeline(library: library, functionName: "projection_divergence_kernel")
        projectionPressurePSO = createComputePipeline(library: library, functionName: "projection_pressure_kernel")
        projectionGradientPSO = createComputePipeline(library: library, functionName: "projection_gradient_kernel")
        addForcePSO = createComputePipeline(library: library, functionName: "add_force_kernel")
        fadePSO = createComputePipeline(library: library, functionName: "fade_kernel")
        
        // Create render pipeline state
        setupRenderPipeline(library: library)
    }
    
    private func createComputePipeline(library: MTLLibrary, functionName: String) -> MTLComputePipelineState? {
        guard let function = library.makeFunction(name: functionName) else {
            print("Failed to create function: \(functionName)")
            return nil
        }
        
        do {
            return try device.makeComputePipelineState(function: function)
        } catch {
            print("Failed to create pipeline state for \(functionName): \(error)")
            return nil
        }
    }
    
    private func setupRenderPipeline(library: MTLLibrary) {
        guard let vertexFunction = library.makeFunction(name: "fluid_display_vertex"),
              let fragmentFunction = library.makeFunction(name: "fluid_display_fragment") else {
            print("Failed to create render functions")
            return
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            renderPSO = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Failed to create render pipeline: \(error)")
        }
    }
    
    private func setupUniforms() {
        let size = MemoryLayout<GPUFluidUniforms>.size
        uniformsBuffer = device.makeBuffer(length: size, options: .storageModeShared)
    }
    
    private func setupSampler() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        sampler = device.makeSamplerState(descriptor: descriptor)
    }
    
    // MARK: - Step 3: GPU Dispatcher (replacing FluidEngine.step())
    
    func step(dt: Float? = nil) {
        guard let gpuState = gpuState,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        if let dt {
            parameters.timeStep = dt
        }
        
        updateUniforms()
        
        let src = gpuState.current
        let dst = gpuState.swap()
        
        // 1. Diffusion (velocity)
        if let pso = diffusionPSO {
            runDiffusion(pso, commandBuffer: commandBuffer,
                        source: gpuState.velocity[src],
                        destination: gpuState.velocity[dst])
        }
        
        // 2. Projection (divergence → pressure → gradient)
        runProjection(commandBuffer: commandBuffer, gpuState: gpuState, velocityIndex: dst)
        
        // 3. Advection (velocity, density, color)
        if let pso = advectionPSO {
            runAdvection(pso, commandBuffer: commandBuffer,
                        velocity: gpuState.velocity[dst],
                        source: gpuState.velocity[dst],
                        destination: gpuState.velocity[src])
            
            runAdvection(pso, commandBuffer: commandBuffer,
                        velocity: gpuState.velocity[dst],
                        source: gpuState.density[dst],
                        destination: gpuState.density[src])
            
            runAdvection(pso, commandBuffer: commandBuffer,
                        velocity: gpuState.velocity[dst],
                        source: gpuState.color[dst],
                        destination: gpuState.color[src])
        }
        
        // 4. Fade density & color
        if let pso = fadePSO {
            runFade(pso, commandBuffer: commandBuffer, texture: gpuState.density[src])
            runFade(pso, commandBuffer: commandBuffer, texture: gpuState.color[src])
        }
        
        // Commit and update current index
        commandBuffer.commit()
        
        DispatchQueue.main.async {
            self.gpuState?.current = src
        }
    }
    
    // MARK: - Kernel Runners
    
    private func runDiffusion(_ pso: MTLComputePipelineState, commandBuffer: MTLCommandBuffer,
                             source: MTLTexture, destination: MTLTexture) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(pso)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        encoder.setBuffer(uniformsBuffer, offset: 0, index: 0)
        
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let groupsPerGrid = MTLSize(
            width: (width + threadsPerGroup.width - 1) / threadsPerGroup.width,
            height: (height + threadsPerGroup.height - 1) / threadsPerGroup.height,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
    }
    
    private func runProjection(commandBuffer: MTLCommandBuffer, gpuState: FluidGPUState, velocityIndex: Int) {
        // 1. Calculate divergence
        if let pso = projectionDivergencePSO {
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
            
            encoder.setComputePipelineState(pso)
            encoder.setTexture(gpuState.velocity[velocityIndex], index: 0)
            encoder.setTexture(gpuState.divergence, index: 1)
            encoder.setBuffer(uniformsBuffer, offset: 0, index: 0)
            
            dispatchThreads(encoder: encoder)
            encoder.endEncoding()
        }
        
        // 2. Solve pressure (Jacobi iterations)
        if let pso = projectionPressurePSO {
            for i in 0..<parameters.projectionIterations {
                let src = i % 2
                let dst = 1 - src
                
                guard let encoder = commandBuffer.makeComputeCommandEncoder() else { continue }
                
                encoder.setComputePipelineState(pso)
                encoder.setTexture(i == 0 ? gpuState.divergence : gpuState.pressure[src], index: 0)
                encoder.setTexture(gpuState.pressure[dst], index: 1)
                encoder.setBuffer(uniformsBuffer, offset: 0, index: 0)
                
                dispatchThreads(encoder: encoder)
                encoder.endEncoding()
            }
        }
        
        // 3. Subtract pressure gradient
        if let pso = projectionGradientPSO {
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
            
            encoder.setComputePipelineState(pso)
            encoder.setTexture(gpuState.pressure[parameters.projectionIterations % 2], index: 0)
            encoder.setTexture(gpuState.velocity[velocityIndex], index: 1)
            encoder.setBuffer(uniformsBuffer, offset: 0, index: 0)
            
            dispatchThreads(encoder: encoder)
            encoder.endEncoding()
        }
    }
    
    private func runAdvection(_ pso: MTLComputePipelineState, commandBuffer: MTLCommandBuffer,
                             velocity: MTLTexture, source: MTLTexture, destination: MTLTexture) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(pso)
        encoder.setTexture(velocity, index: 0)
        encoder.setTexture(source, index: 1)
        encoder.setTexture(destination, index: 2)
        encoder.setBuffer(uniformsBuffer, offset: 0, index: 0)
        
        dispatchThreads(encoder: encoder)
        encoder.endEncoding()
    }
    
    private func runFade(_ pso: MTLComputePipelineState, commandBuffer: MTLCommandBuffer, texture: MTLTexture) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(pso)
        encoder.setTexture(texture, index: 0)
        encoder.setBuffer(uniformsBuffer, offset: 0, index: 0)
        
        dispatchThreads(encoder: encoder)
        encoder.endEncoding()
    }
    
    private func dispatchThreads(encoder: MTLComputeCommandEncoder) {
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let groupsPerGrid = MTLSize(
            width: (width + threadsPerGroup.width - 1) / threadsPerGroup.width,
            height: (height + threadsPerGroup.height - 1) / threadsPerGroup.height,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
    }
    
    // MARK: - Step 4: Touch Interaction → GPU Splats
    
    func addForce(at position: SIMD2<Float>, velocity: SIMD2<Float>, radius: Float, color: SIMD3<Float>) {
        guard let gpuState = gpuState,
              let pso = addForcePSO,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        // Create force data
        var forceData = GPUForceData(
            position: position,
            velocity: velocity,
            radius: radius,
            color: color
        )
        
        let forceBuffer = device.makeBuffer(bytes: &forceData, length: MemoryLayout<GPUForceData>.size, options: .storageModeShared)
        
        encoder.setComputePipelineState(pso)
        encoder.setTexture(gpuState.velocity[gpuState.current], index: 0)
        encoder.setTexture(gpuState.density[gpuState.current], index: 1)
        encoder.setTexture(gpuState.color[gpuState.current], index: 2)
        encoder.setBuffer(forceBuffer, offset: 0, index: 0)
        encoder.setBuffer(uniformsBuffer, offset: 0, index: 1)
        
        dispatchThreads(encoder: encoder)
        encoder.endEncoding()
        
        commandBuffer.commit()
    }
    
    // MARK: - Rendering
    
    func render(to renderPassDescriptor: MTLRenderPassDescriptor, drawable: MTLDrawable) {
        guard let gpuState = gpuState,
              let renderPSO = renderPSO,
              let sampler = sampler,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        encoder.setRenderPipelineState(renderPSO)
        encoder.setFragmentTexture(gpuState.color[gpuState.current], index: 0)
        encoder.setFragmentTexture(gpuState.density[gpuState.current], index: 1)
        encoder.setFragmentSamplerState(sampler, index: 0)
        
        // Draw fullscreen quad
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    // MARK: - Step 5: Verification & Debug Read-back
    
    /// Read back GPU texture data for verification (blueprint Step 5)
    func readBackDensity(completion: @escaping ([Float]) -> Void) {
        guard let gpuState = gpuState,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            completion([])
            return
        }
        
        let texture = gpuState.density[gpuState.current]
        let bytesPerRow = texture.width * MemoryLayout<Float>.size
        let totalBytes = texture.height * bytesPerRow
        
        guard let buffer = device.makeBuffer(length: totalBytes, options: .storageModeShared) else {
            completion([])
            return
        }
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            completion([])
            return
        }
        
        blitEncoder.copy(from: texture,
                        sourceSlice: 0,
                        sourceLevel: 0,
                        sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                        sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                        to: buffer,
                        destinationOffset: 0,
                        destinationBytesPerRow: bytesPerRow,
                        destinationBytesPerImage: totalBytes)
        
        blitEncoder.endEncoding()
        
        commandBuffer.addCompletedHandler { _ in
            let data = buffer.contents().bindMemory(to: Float.self, capacity: texture.width * texture.height)
            let array = Array(UnsafeBufferPointer(start: data, count: texture.width * texture.height))
            
            DispatchQueue.main.async {
                completion(array)
            }
        }
        
        commandBuffer.commit()
    }
    
    /// Mass conservation check (blueprint verification)
    func getTotalDensity(completion: @escaping (Float) -> Void) {
        readBackDensity { densityArray in
            let total = densityArray.reduce(0, +)
            completion(total)
        }
    }
    
    /// Pixel-perfect comparison helper (blueprint verification)
    func readBackColorTexture(completion: @escaping (Data?) -> Void) {
        guard let gpuState = gpuState,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            completion(nil)
            return
        }
        
        let texture = gpuState.color[gpuState.current]
        let bytesPerPixel = 4 * MemoryLayout<Float16>.size // RGBA16Float
        let bytesPerRow = texture.width * bytesPerPixel
        let totalBytes = texture.height * bytesPerRow
        
        guard let buffer = device.makeBuffer(length: totalBytes, options: .storageModeShared) else {
            completion(nil)
            return
        }
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            completion(nil)
            return
        }
        
        blitEncoder.copy(from: texture,
                        sourceSlice: 0,
                        sourceLevel: 0,
                        sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                        sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                        to: buffer,
                        destinationOffset: 0,
                        destinationBytesPerRow: bytesPerRow,
                        destinationBytesPerImage: totalBytes)
        
        blitEncoder.endEncoding()
        
        commandBuffer.addCompletedHandler { _ in
            let data = Data(bytes: buffer.contents(), count: totalBytes)
            DispatchQueue.main.async {
                completion(data)
            }
        }
        
        commandBuffer.commit()
    }
    
    // MARK: - Utilities
    
    private func updateUniforms() {
        guard let buffer = uniformsBuffer?.contents() else { return }
        
        var uniforms = GPUFluidUniforms(
            dt: parameters.timeStep,
            viscosity: parameters.viscosity,
            diffusion: parameters.diffusion,
            fadeRate: parameters.fadeRate,
            forceMultiplier: parameters.forceMultiplier,
            width: UInt32(width),
            height: UInt32(height),
            iterations: UInt32(parameters.projectionIterations)
        )
        
        buffer.copyMemory(from: &uniforms, byteCount: MemoryLayout<GPUFluidUniforms>.size)
    }
    
    func clear() {
        // Clear all textures on GPU
        guard let gpuState = gpuState,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        // Clear velocity
        clearTexture(commandBuffer: commandBuffer, texture: gpuState.velocity[0])
        clearTexture(commandBuffer: commandBuffer, texture: gpuState.velocity[1])
        
        // Clear density
        clearTexture(commandBuffer: commandBuffer, texture: gpuState.density[0])
        clearTexture(commandBuffer: commandBuffer, texture: gpuState.density[1])
        
        // Clear color
        clearTexture(commandBuffer: commandBuffer, texture: gpuState.color[0])
        clearTexture(commandBuffer: commandBuffer, texture: gpuState.color[1])
        
        commandBuffer.commit()
    }
    
    private func clearTexture(commandBuffer: MTLCommandBuffer, texture: MTLTexture) {
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
        
        // FIXED: Use proper clear method for textures
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                              size: MTLSize(width: texture.width, height: texture.height, depth: 1))
        
        // Create empty data buffer
        let bytesPerPixel = 4 * MemoryLayout<Float>.size // RGBA float
        let bytesPerRow = texture.width * bytesPerPixel
        let totalBytes = texture.height * bytesPerRow
        let emptyData = Data(count: totalBytes)
        
        emptyData.withUnsafeBytes { bytes in
            texture.replace(region: region, mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: bytesPerRow)
        }
        
        blitEncoder.endEncoding()
    }
    
    // MARK: - State Access
    
    func getCurrentColorTexture() -> MTLTexture? {
        return gpuState?.color[gpuState?.current ?? 0]
    }
    
    func getCurrentDensityTexture() -> MTLTexture? {
        return gpuState?.density[gpuState?.current ?? 0]
    }
}

// MARK: - Supporting Structures

struct GPUFluidUniforms {
    let dt: Float
    let viscosity: Float
    let diffusion: Float
    let fadeRate: Float
    let forceMultiplier: Float
    let width: UInt32
    let height: UInt32
    let iterations: UInt32
}

struct GPUForceData {
    let position: SIMD2<Float>
    let velocity: SIMD2<Float>
    let radius: Float
    let color: SIMD3<Float>
}
