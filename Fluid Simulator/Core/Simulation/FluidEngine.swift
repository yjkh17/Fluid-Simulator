//
//  FluidEngine.swift
//  Fluid Simulator
//
//  Created by Yousef Yousef Jawdat on 06/06/2025.
//

import Foundation
import simd

class FluidEngine: ObservableObject {
    private var state: FluidState
    @Published var parameters: FluidParameters
    private let serialQueue = DispatchQueue(label: "fluid.simulation", qos: .userInteractive)
    private let stateLock = NSLock()
    private var frameCount = 0

    init(width: Int, height: Int, parameters: FluidParameters = .default) {
        self.state = FluidState(width: width, height: height)
        self.parameters = parameters
    }
    
    func getState() -> FluidState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return state
    }
    
    func updateParameters(_ newParameters: FluidParameters) {
        stateLock.lock()
        self.parameters = newParameters
        stateLock.unlock()
    }
    
    func step() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            self.stateLock.lock()
            defer { self.stateLock.unlock() }
            self.performStep()
        }
    }
    
    private func performStep() {
        // OPTIMIZED: More efficient skip checking
        if shouldSkipEntireSimulation() {
            return
        }
        
        // OPTIMIZED: Reduce frequency of expensive operations
        if frameCount % 2 == 0 {  // Only do full step every other frame
            velocityStep()
            densityStep()
            colorStep()
        } else {
            // Light step - just advection
            lightStep()
        }
        
        frameCount += 1
    }
    
    // OPTIMIZED: Light step for better performance
    private func lightStep() {
        // Only do advection and light fade - much faster
        swapArray(&state.density, &state.previousDensity)
        advect(&state.density, state.previousDensity, state.velocityX, state.velocityY)
        
        swapArray(&state.colorR, &state.previousColorR)
        swapArray(&state.colorG, &state.previousColorG)
        swapArray(&state.colorB, &state.previousColorB)
        
        advect(&state.colorR, state.previousColorR, state.velocityX, state.velocityY)
        advect(&state.colorG, state.previousColorG, state.velocityX, state.velocityY)
        advect(&state.colorB, state.previousColorB, state.velocityX, state.velocityY)
        
        // Light fade
        applyFade(&state.density)
        applyFade(&state.colorR)
        applyFade(&state.colorG)
        applyFade(&state.colorB)
    }
    
    // Much more conservative skipping - only skip when truly empty
    private func shouldSkipEntireSimulation() -> Bool {
        // Quick check - only skip if completely empty
        for i in stride(from: 0, to: state.size, by: 16) { // Sample every 16th cell
            if state.density[i] > 0.001 ||
               abs(state.velocityX[i]) > 0.001 ||
               abs(state.velocityY[i]) > 0.001 ||
               state.colorR[i] > 0.001 ||
               state.colorG[i] > 0.001 ||
               state.colorB[i] > 0.001 {
                return false // Don't skip - there's activity
            }
        }
        return true // Skip only if completely empty
    }
    
    private func velocityStep() {
        swapVelocityBuffers()
        
        diffuse(&state.velocityX, state.previousVelocityX, parameters.viscosity)
        diffuse(&state.velocityY, state.previousVelocityY, parameters.viscosity)
        
        simpleProject()
        
        swapVelocityBuffers()
        
        advect(&state.velocityX, state.previousVelocityX, state.previousVelocityX, state.previousVelocityY)
        advect(&state.velocityY, state.previousVelocityY, state.previousVelocityX, state.previousVelocityY)
        
        simpleProject()
    }
    
    private func densityStep() {
        swapArray(&state.density, &state.previousDensity)
        
        diffuse(&state.density, state.previousDensity, parameters.diffusion)
        
        swapArray(&state.density, &state.previousDensity)
        
        advect(&state.density, state.previousDensity, state.velocityX, state.velocityY)
        
        applyFade(&state.density)
    }
    
    private func colorStep() {
        processColorChannel(&state.colorR, &state.previousColorR)
        processColorChannel(&state.colorG, &state.previousColorG)
        processColorChannel(&state.colorB, &state.previousColorB)
    }
    
    private func processColorChannel(_ current: inout [Float], _ previous: inout [Float]) {
        swapArray(&current, &previous)
        
        diffuse(&current, previous, parameters.diffusion * 0.5)
        
        swapArray(&current, &previous)
        
        advect(&current, previous, state.velocityX, state.velocityY)
        
        applyFade(&current)
    }
    
    private func diffuse(_ current: inout [Float], _ previous: [Float], _ diffusionRate: Float) {
        let a = parameters.timeStep * diffusionRate * Float(state.width * state.height)
        let c = 1.0 + 4.0 * a
        
        for _ in 0..<parameters.iterations {
            for y in 1..<(state.height - 1) {
                for x in 1..<(state.width - 1) {
                    let index = y * state.width + x
                    guard index >= 0 && index < current.count &&
                          index - 1 >= 0 && index + 1 < current.count &&
                          index - state.width >= 0 && index + state.width < current.count else {
                        continue
                    }
                    
                    current[index] = (previous[index] + a * (
                        current[index - 1] +
                        current[index + 1] +
                        current[index - state.width] +
                        current[index + state.width]
                    )) / c
                }
            }
            setBoundary(&current)
        }
    }
    
    private func simpleProject() {
        var divergence = Array(repeating: 0.0 as Float, count: state.size)
        var pressure = Array(repeating: 0.0 as Float, count: state.size)
        
        for y in 1..<(state.height - 1) {
            for x in 1..<(state.width - 1) {
                let index = y * state.width + x
                guard index >= 0 && index < state.size &&
                      index + 1 < state.velocityX.count &&
                      index - 1 >= 0 &&
                      index + state.width < state.velocityY.count &&
                      index - state.width >= 0 else {
                    continue
                }
                
                divergence[index] = -0.5 * (
                    state.velocityX[index + 1] - state.velocityX[index - 1] +
                    state.velocityY[index + state.width] - state.velocityY[index - state.width]
                ) / Float(state.width)
            }
        }
        
        setBoundary(&divergence)
        setBoundary(&pressure)
        
        for _ in 0..<parameters.iterations {
            for y in 1..<(state.height - 1) {
                for x in 1..<(state.width - 1) {
                    let index = y * state.width + x
                    guard index >= 0 && index < pressure.count &&
                          index - 1 >= 0 && index + 1 < pressure.count &&
                          index - state.width >= 0 && index + state.width < pressure.count else {
                        continue
                    }
                    
                    pressure[index] = (divergence[index] +
                        pressure[index - 1] + pressure[index + 1] +
                        pressure[index - state.width] + pressure[index + state.width]) / 4.0
                }
            }
            setBoundary(&pressure)
        }
        
        for y in 1..<(state.height - 1) {
            for x in 1..<(state.width - 1) {
                let index = y * state.width + x
                guard index >= 0 && index < state.size &&
                      index + 1 < pressure.count &&
                      index - 1 >= 0 &&
                      index + state.width < pressure.count &&
                      index - state.width >= 0 else {
                    continue
                }
                
                state.velocityX[index] -= 0.5 * (pressure[index + 1] - pressure[index - 1]) * Float(state.width)
                state.velocityY[index] -= 0.5 * (pressure[index + state.width] - pressure[index - state.width]) * Float(state.width)
            }
        }
        
        setBoundary(&state.velocityX)
        setBoundary(&state.velocityY)
    }
    
    private func advect(_ current: inout [Float], _ previous: [Float], _ velocityX: [Float], _ velocityY: [Float]) {
        let dt0 = parameters.timeStep * Float(state.width)
        
        for y in 1..<(state.height - 1) {
            for x in 1..<(state.width - 1) {
                let index = y * state.width + x
                guard index >= 0 && index < current.count &&
                      index < velocityX.count && index < velocityY.count else {
                    continue
                }
                
                var fx = Float(x) - dt0 * velocityX[index]
                var fy = Float(y) - dt0 * velocityY[index]
                
                fx = max(0.5, min(Float(state.width) - 1.5, fx))
                fy = max(0.5, min(Float(state.height) - 1.5, fy))
                
                let i0 = Int(fx)
                let i1 = i0 + 1
                let j0 = Int(fy)
                let j1 = j0 + 1
                
                guard i0 >= 0 && i1 < state.width && j0 >= 0 && j1 < state.height else {
                    continue
                }
                
                let idx00 = j0 * state.width + i0
                let idx01 = j0 * state.width + i1
                let idx10 = j1 * state.width + i0
                let idx11 = j1 * state.width + i1
                
                guard idx00 < previous.count && idx01 < previous.count &&
                      idx10 < previous.count && idx11 < previous.count else {
                    continue
                }
                
                let s1 = fx - Float(i0)
                let s0 = 1 - s1
                let t1 = fy - Float(j0)
                let t0 = 1 - t1
                
                current[index] = s0 * (t0 * previous[idx00] + t1 * previous[idx10]) +
                                s1 * (t0 * previous[idx01] + t1 * previous[idx11])
            }
        }
        setBoundary(&current)
    }
    
    private func setBoundary(_ field: inout [Float]) {
        for i in 0..<state.width {
            field[i] = 0
            field[(state.height - 1) * state.width + i] = 0
        }
        for j in 0..<state.height {
            field[j * state.width] = 0
            field[j * state.width + state.width - 1] = 0
        }
    }
    
    private func swapVelocityBuffers() {
        swapArray(&state.velocityX, &state.previousVelocityX)
        swapArray(&state.velocityY, &state.previousVelocityY)
    }
    
    private func swapArray(_ a: inout [Float], _ b: inout [Float]) {
        let temp = a
        a = b
        b = temp
    }
    
    private func applyFade(_ field: inout [Float]) {
        for i in 0..<field.count {
            field[i] *= parameters.fadeRate
        }
    }
    
    func addForce(x: Int, y: Int, deltaX: Float, deltaY: Float) {
        guard x >= 0 && x < state.width && y >= 0 && y < state.height else { return }
        
        stateLock.lock()
        defer { stateLock.unlock() }
        
        let index = y * state.width + x
        guard index >= 0 && index < state.velocityX.count && index < state.velocityY.count else { return }
        
        state.velocityX[index] += deltaX * parameters.forceMultiplier
        state.velocityY[index] += deltaY * parameters.forceMultiplier
    }
    
    func addDensity(x: Int, y: Int, amount: Float) {
        guard x >= 0 && x < state.width && y >= 0 && y < state.height else { return }
        
        stateLock.lock()
        defer { stateLock.unlock() }
        
        state.addDensity(x: x, y: y, amount: amount)
    }
    
    func addColor(x: Int, y: Int, r: Float, g: Float, b: Float) {
        guard x >= 0 && x < state.width && y >= 0 && y < state.height else { return }
        
        stateLock.lock()
        defer { stateLock.unlock() }
        
        state.addColor(x: x, y: y, r: r, g: g, b: b)
    }
    
    func clear() {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        state.clear()
    }
}
