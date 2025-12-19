//
//
//  PipelineBuilder.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import Foundation
import Metal
import MetalKit

class PipelineBuilder {
    private let device: MTLDevice
    private let library: MTLLibrary
    
    init?(device: MTLDevice) {
        self.device = device
        let bundle = Bundle(for: PipelineBuilder.self)
        guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
            NSLog("❌ Failed to load Metal library from bundle: \(bundle.bundlePath)")
            return nil
        }
        self.library = library
    }
    
    // Compute pipeline states
    lazy var advectionPipeline: MTLComputePipelineState? = {
        return createComputePipeline(functionName: "advection_kernel")
    }()
    
    lazy var diffusionPipeline: MTLComputePipelineState? = {
        return createComputePipeline(functionName: "diffusion_kernel")
    }()
    
    lazy var divergencePipeline: MTLComputePipelineState? = {
        return createComputePipeline(functionName: "divergence_kernel")
    }()
    
    lazy var pressureGradientPipeline: MTLComputePipelineState? = {
        return createComputePipeline(functionName: "pressure_gradient_kernel")
    }()
    
    lazy var colorMixPipeline: MTLComputePipelineState? = {
        return createComputePipeline(functionName: "color_mix_kernel")
    }()
    
    lazy var addForcePipeline: MTLComputePipelineState? = {
        return createComputePipeline(functionName: "add_force_kernel")
    }()
    
    // Render pipeline state
    lazy var renderPipeline: MTLRenderPipelineState? = {
        return createRenderPipeline()
    }()
    
    private func createComputePipeline(functionName: String) -> MTLComputePipelineState? {
        guard let function = library.makeFunction(name: functionName) else {
            print("Failed to create function: \(functionName)")
            return nil
        }
        
        do {
            return try device.makeComputePipelineState(function: function)
        } catch {
            print("Failed to create compute pipeline for \(functionName): \(error)")
            return nil
        }
    }
    
    private func createRenderPipeline() -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "fluid_vertex"),
              let fragmentFunction = library.makeFunction(name: "fluid_fragment") else {
            print("Failed to create render functions")
            return nil
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Failed to create render pipeline: \(error)")
            return nil
        }
    }
}
