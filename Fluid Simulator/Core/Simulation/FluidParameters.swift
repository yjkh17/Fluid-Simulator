//
//  FluidParameters.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import Foundation
import simd

struct FluidParameters: Codable, Equatable {
    // Physical properties - OPTIMIZED: Better values for CPU rendering
    var viscosity: Float = 0.001         // Keep good flow
    var diffusion: Float = 0.005
    var density: Float = 1.0
    var vorticity: Float = 10.0
    
    // Simulation settings - OPTIMIZED: Better performance on CPU
    var iterations: Int = 2
    var timeStep: Float = 0.016          // Keep original timestep
    var gridSize: SIMD2<Int> = SIMD2(48, 96)
    
    // Visual properties
    var colorIntensity: Float = 1.0
    var fadeRate: Float = 0.990
    var bloomStrength: Float = 1.0
    
    // Interaction - OPTIMIZED: Better responsiveness
    var forceMultiplier: Float = 40.0
    var brushSize: Float = 6.0
    
    static let `default` = FluidParameters()
}
