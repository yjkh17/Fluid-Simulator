//
//  FluidParameters.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import Foundation
import simd

struct FluidParameters: Codable, Equatable {
    // Core GPU simulation parameters
    var timeStep: Float = 0.1
    var viscosity: Float = 0.01
    var diffusion: Float = 0.01
    var fadeRate: Float = 0.995
    var forceMultiplier: Float = 1.0
    
    // GPU-specific iterations (for pressure solver)
    var projectionIterations: Int = 20
    
    static let `default` = FluidParameters()
}
