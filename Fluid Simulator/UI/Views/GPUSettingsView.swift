//
//  GPUSettingsView.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI

/// Settings view for GPU-first fluid simulator
struct GPUSettingsView: View {
    @ObservedObject var simulator: FluidSimulatorGPU
    @ObservedObject var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // GPU Simulation Parameters Section
                Section("GPU Simulation Physics") {
                    VStack(alignment: .leading) {
                        Text("Viscosity: \(simulator.parameters.viscosity, specifier: "%.4f")")
                        Slider(value: $simulator.parameters.viscosity, in: 0.001...0.1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Diffusion: \(simulator.parameters.diffusion, specifier: "%.4f")")
                        Slider(value: $simulator.parameters.diffusion, in: 0.001...0.1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Force Multiplier: \(simulator.parameters.forceMultiplier, specifier: "%.1f")")
                        Slider(value: $simulator.parameters.forceMultiplier, in: 0.1...5.0)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Fade Rate: \(simulator.parameters.fadeRate, specifier: "%.3f")")
                        Slider(value: $simulator.parameters.fadeRate, in: 0.9...1.0)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Projection Iterations: \(simulator.parameters.projectionIterations)")
                        Slider(value: Binding(
                            get: { Double(simulator.parameters.projectionIterations) },
                            set: { simulator.parameters.projectionIterations = Int($0) }
                        ), in: 1...50, step: 1)
                    }
                }
                
                // GPU Performance Section
                Section("GPU Performance") {
                    VStack(alignment: .leading) {
                        Text("Time Step: \(simulator.parameters.timeStep, specifier: "%.3f")")
                        Slider(value: $simulator.parameters.timeStep, in: 0.01...0.5)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Grid Resolution: \(simulator.width) × \(simulator.height)")
                            .font(.caption)
                        Text("Total Texels: \(simulator.width * simulator.height)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // GPU Debug Section
                Section("GPU Debug Tools") {
                    Button("Read Back Density Data") {
                        simulator.readBackDensity { densityArray in
                            let nonZeroCount = densityArray.filter { $0 > 0.001 }.count
                            print("GPU Debug: Non-zero density pixels: \(nonZeroCount)/\(densityArray.count)")
                        }
                    }
                    
                    Button("Check Total Mass") {
                        simulator.getTotalDensity { totalMass in
                            print("GPU Debug: Total mass in simulation: \(totalMass)")
                        }
                    }
                    
                    Button("Export GPU State") {
                        simulator.readBackColorTexture { data in
                            if let data = data {
                                print("GPU Debug: Exported \(data.count) bytes of color data")
                            }
                        }
                    }
                }
                
                // GPU Presets Section
                Section("GPU Simulation Presets") {
                    Button("High Performance") {
                        simulator.parameters = FluidParameters(
                            timeStep: 0.1,
                            viscosity: 0.01,
                            diffusion: 0.01,
                            fadeRate: 0.995,
                            forceMultiplier: 1.0,
                            projectionIterations: 10
                        )
                    }
                    
                    Button("High Quality") {
                        simulator.parameters = FluidParameters(
                            timeStep: 0.05,
                            viscosity: 0.005,
                            diffusion: 0.005,
                            fadeRate: 0.998,
                            forceMultiplier: 1.5,
                            projectionIterations: 25
                        )
                    }
                    
                    Button("Smoke-like") {
                        simulator.parameters = FluidParameters(
                            timeStep: 0.08,
                            viscosity: 0.001,
                            diffusion: 0.02,
                            fadeRate: 0.992,
                            forceMultiplier: 2.0,
                            projectionIterations: 15
                        )
                    }
                    
                    Button("Water-like") {
                        simulator.parameters = FluidParameters(
                            timeStep: 0.03,
                            viscosity: 0.05,
                            diffusion: 0.001,
                            fadeRate: 0.999,
                            forceMultiplier: 0.8,
                            projectionIterations: 30
                        )
                    }
                }
                
                // Reset Section
                Section("Reset GPU State") {
                    Button("Reset to Defaults") {
                        simulator.parameters = FluidParameters()
                    }
                    .foregroundColor(.blue)
                    
                    Button("Clear GPU Simulation") {
                        simulator.clear()
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("GPU Simulator Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: simulator.parameters) { newValue in
            settingsStore.fluidParameters = newValue
            SettingsStore.save(fluidParameters: newValue)
        }
    }
}

#Preview {
    if let device = MTLCreateSystemDefaultDevice(),
       let simulator = FluidSimulatorGPU(device: device, width: 128, height: 256) {
        let settingsStore = SettingsStore()
        GPUSettingsView(simulator: simulator, settingsStore: settingsStore)
    } else {
        Text("Metal not available")
    }
}
