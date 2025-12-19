//
//  DebugOverlayView.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI

/// Debug overlay for performance monitoring (blueprint Step 4 verification)
struct DebugOverlayView: View {
    @ObservedObject var simulator: FluidSimulatorGPU
    @State private var fps: Double = 0
    @State private var frameTime: Double = 0
    @State private var effectiveDt: Double = 0
    @State private var totalDensity: Float = 0
    @State private var lastUpdateTime = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GPU DEBUG")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.yellow)
            
            Text("FPS: \(fps, specifier: "%.1f")")
                .font(.caption2)
                .foregroundColor(.white)
            
            Text("Frame: \(frameTime, specifier: "%.2f")ms")
                .font(.caption2)
                .foregroundColor(.white)
            
            Text("dt: \(effectiveDt, specifier: "%.3f")ms (target \(1000.0 / 120.0, specifier: "%.2f")ms)")
                .font(.caption2)
                .foregroundColor(.white)
            
            Text("Grid: \(simulator.width)×\(simulator.height)")
                .font(.caption2)
                .foregroundColor(.white)
            
            Text("Mass: \(totalDensity, specifier: "%.3f")")
                .font(.caption2)
                .foregroundColor(.white)
            
            // Target indicators from blueprint
            HStack(spacing: 4) {
                Circle()
                    .fill(frameTime < 1.0 ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text("1ms target")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            updateStats()
        }
    }
    
    private func updateStats() {
        let now = Date()
        let delta = now.timeIntervalSince(lastUpdateTime)
        
        if delta > 0 {
            fps = 1.0 / delta
            frameTime = delta * 1000.0 // Convert to milliseconds
            effectiveDt = Double(simulator.lastStepDelta) * 1000.0
        }
        
        lastUpdateTime = now
        
        // Read back density for mass conservation check
        simulator.getTotalDensity { density in
            totalDensity = density
        }
    }
}

#Preview {
    if let device = MTLCreateSystemDefaultDevice(),
       let simulator = FluidSimulatorGPU(device: device, width: 128, height: 256) {
        DebugOverlayView(simulator: simulator)
    } else {
        Text("Metal not available")
    }
}
