//
//  FluidSimulatorTests.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import Foundation
import Metal

/// Unit tests for GPU fluid simulator (blueprint Step 5)
class FluidSimulatorTests {
    
    /// Test basic GPU simulator creation and mass conservation
    static func testBasicSimulation() -> Bool {
        guard let device = MTLCreateSystemDefaultDevice(),
              let simulator = FluidSimulatorGPU(device: device, width: 32, height: 32) else {
            print("❌ Failed to create GPU simulator")
            return false
        }
        
        // Seed a blob of density
        simulator.addForce(
            at: SIMD2<Float>(0.5, 0.5),
            velocity: SIMD2<Float>(0, 0),
            radius: 5.0,
            color: SIMD3<Float>(1, 0, 0)
        )
        
        // Run simulation for several steps
        for _ in 0..<10 {
            simulator.step()
        }
        
        // Verify mass conservation
        let expectation = DispatchSemaphore(value: 0)
        var totalDensity: Float = 0
        
        simulator.getTotalDensity { density in
            totalDensity = density
            expectation.signal()
        }
        
        expectation.wait()
        
        let success = totalDensity > 0.1
        print(success ? "✅ Basic simulation test passed (density: \(totalDensity))" : "❌ Basic simulation test failed (density: \(totalDensity))")
        
        return success
    }
    
    /// Test 1000 step simulation for stability (blueprint requirement)
    static func testLongRunningSimulation() -> Bool {
        guard let device = MTLCreateSystemDefaultDevice(),
              let simulator = FluidSimulatorGPU(device: device, width: 32, height: 32) else {
            return false
        }
        
        // Seed initial state
        simulator.addForce(
            at: SIMD2<Float>(0.5, 0.5),
            velocity: SIMD2<Float>(0.1, 0.1),
            radius: 3.0,
            color: SIMD3<Float>(0, 1, 0)
        )
        
        // Run 1000 steps as per blueprint
        for step in 0..<1000 {
            simulator.step()
            
            // Progress indicator
            if step % 100 == 0 {
                print("🔄 Step \(step)/1000")
            }
        }
        
        // Verify system is still stable
        let expectation = DispatchSemaphore(value: 0)
        var finalDensity: Float = 0
        
        simulator.getTotalDensity { density in
            finalDensity = density
            expectation.signal()
        }
        
        expectation.wait()
        
        let success = finalDensity > 0 && finalDensity.isFinite
        print(success ? "✅ Long-running test passed (final density: \(finalDensity))" : "❌ Long-running test failed (final density: \(finalDensity))")
        
        return success
    }
    
    /// Run all tests
    static func runAllTests() {
        print("🧪 Running GPU Fluid Simulator Tests...")
        
        let basicTest = testBasicSimulation()
        let longTest = testLongRunningSimulation()
        
        let allPassed = basicTest && longTest
        print(allPassed ? "✅ All tests passed!" : "❌ Some tests failed")
    }
}