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
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Physics") {
                    VStack(alignment: .leading) {
                        Text("Viscosity: \(simulator.parameters.viscosity, specifier: "%.4f")")
                        Slider(value: $simulator.parameters.viscosity, in: 0.001...0.1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Diffusion: \(simulator.parameters.diffusion, specifier: "%.4f")")
                        Slider(value: $simulator.parameters.diffusion, in: 0.001...0.05)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Fade Rate: \(simulator.parameters.fadeRate, specifier: "%.3f")")
                        Slider(value: $simulator.parameters.fadeRate, in: 0.95...0.999)
                    }
                }
                
                Section("Interaction") {
                    VStack(alignment: .leading) {
                        Text("Force: \(simulator.parameters.forceMultiplier, specifier: "%.1f")")
                        Slider(value: $simulator.parameters.forceMultiplier, in: 1...100)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Brush Size: \(simulator.parameters.brushSize, specifier: "%.1f")")
                        Slider(value: $simulator.parameters.brushSize, in: 1...20)
                    }
                }
                
                Section("Performance") {
                    VStack(alignment: .leading) {
                        Text("Projection Iterations: \(simulator.parameters.projectionIterations)")
                        Slider(value: Binding(
                            get: { Double(simulator.parameters.projectionIterations) },
                            set: { simulator.parameters.projectionIterations = Int($0) }
                        ), in: 1...10, step: 1)
                    }
                    
                    HStack {
                        Text("Grid Size")
                        Spacer()
                        Text("\(simulator.width)×\(simulator.height)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Actions") {
                    Button("Reset to Defaults") {
                        simulator.parameters = FluidParameters.default
                    }
                    
                    Button("Clear Simulation") {
                        simulator.clear()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("GPU Fluid Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    if let device = MTLCreateSystemDefaultDevice(),
       let simulator = FluidSimulatorGPU(device: device, width: 128, height: 256) {
        GPUSettingsView(simulator: simulator)
    } else {
        Text("Metal not available")
    }
}