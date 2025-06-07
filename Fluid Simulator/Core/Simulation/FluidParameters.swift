//
//  FluidParameters.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import Foundation
import simd

struct FluidParameters: Codable, Equatable {
    // Physical properties - CHANGE: Keep perfect spreading values
    var viscosity: Float = 0.001         // Keep original for good flow
    var diffusion: Float = 0.01          // Keep high diffusion for perfect spreading
    var density: Float = 1.0
    var vorticity: Float = 15.0
    
    // Simulation settings - CHANGE: Keep quality but optimize where possible
    var iterations: Int = 3              // Compromise: 3 instead of 4, but not 1
    var timeStep: Float = 0.016          // Keep original timestep
    var gridSize: SIMD2<Int> = SIMD2(32, 64)
    
    // Visual properties
    var colorIntensity: Float = 1.0
    var fadeRate: Float = 0.995          // Keep slow fade for visibility
    var bloomStrength: Float = 1.0
    
    // Interaction
    var forceMultiplier: Float = 30.0
    var brushSize: Float = 8.0
    
    static let `default` = FluidParameters()
}
