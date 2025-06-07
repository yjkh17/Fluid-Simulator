//
//  FluidState.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import Foundation
import simd
import Metal

class FluidState: ObservableObject {
    // Grid dimensions
    let width: Int
    let height: Int
    let size: Int
    
    // Velocity field (2D vector field)
    var velocityX: [Float]
    var velocityY: [Float]
    var previousVelocityX: [Float]
    var previousVelocityY: [Float]
    
    // Density field (scalar field for color/smoke)
    var density: [Float]
    var previousDensity: [Float]
    
    // Color fields for multiple dyes
    var colorR: [Float]
    var colorG: [Float]
    var colorB: [Float]
    var previousColorR: [Float]
    var previousColorG: [Float]
    var previousColorB: [Float]
    
    // Metal buffers for GPU computation
    var velocityBuffer: MTLBuffer?
    var densityBuffer: MTLBuffer?
    var colorBuffer: MTLBuffer?
    
    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.size = width * height
        
        // Initialize arrays
        self.velocityX = Array(repeating: 0.0, count: size)
        self.velocityY = Array(repeating: 0.0, count: size)
        self.previousVelocityX = Array(repeating: 0.0, count: size)
        self.previousVelocityY = Array(repeating: 0.0, count: size)
        
        self.density = Array(repeating: 0.0, count: size)
        self.previousDensity = Array(repeating: 0.0, count: size)
        
        self.colorR = Array(repeating: 0.0, count: size)
        self.colorG = Array(repeating: 0.0, count: size)
        self.colorB = Array(repeating: 0.0, count: size)
        self.previousColorR = Array(repeating: 0.0, count: size)
        self.previousColorG = Array(repeating: 0.0, count: size)
        self.previousColorB = Array(repeating: 0.0, count: size)
    }
    
    func setupMetalBuffers(device: MTLDevice) {
        let bufferSize = size * MemoryLayout<Float>.size
        
        velocityBuffer = device.makeBuffer(length: bufferSize * 2, options: .storageModeShared)
        densityBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared)
        colorBuffer = device.makeBuffer(length: bufferSize * 3, options: .storageModeShared)
    }
    
    func addDensity(x: Int, y: Int, amount: Float) {
        guard x >= 0 && x < width && y >= 0 && y < height else { return }
        let index = y * width + x
        guard index >= 0 && index < density.count else { return }
        
        let clampedAmount = min(1.0, max(0.0, amount))
        density[index] = min(1.0, density[index] + clampedAmount)
    }
    
    func addVelocity(x: Int, y: Int, velocityX: Float, velocityY: Float) {
        guard x >= 0 && x < width && y >= 0 && y < height else { return }
        let index = y * width + x
        guard index >= 0 && index < self.velocityX.count && index < self.velocityY.count else { return }
        
        let maxVel: Float = 100.0
        let clampedVelX = min(maxVel, max(-maxVel, velocityX))
        let clampedVelY = min(maxVel, max(-maxVel, velocityY))
        
        self.velocityX[index] += clampedVelX
        self.velocityY[index] += clampedVelY
    }
    
    func addColor(x: Int, y: Int, r: Float, g: Float, b: Float) {
        guard x >= 0 && x < width && y >= 0 && y < height else { return }
        let index = y * width + x
        guard index >= 0 && index < colorR.count &&
              index < colorG.count && index < colorB.count else { return }
        
        let clampedR = min(1.0, max(0.0, r))
        let clampedG = min(1.0, max(0.0, g))
        let clampedB = min(1.0, max(0.0, b))
        
        colorR[index] = min(1.0, colorR[index] + clampedR)
        colorG[index] = min(1.0, colorG[index] + clampedG)
        colorB[index] = min(1.0, colorB[index] + clampedB)
    }
    
    func clear() {
        velocityX = Array(repeating: 0.0, count: size)
        velocityY = Array(repeating: 0.0, count: size)
        density = Array(repeating: 0.0, count: size)
        colorR = Array(repeating: 0.0, count: size)
        colorG = Array(repeating: 0.0, count: size)
        colorB = Array(repeating: 0.0, count: size)
    }
}
