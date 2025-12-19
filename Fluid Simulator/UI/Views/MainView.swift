//
//  MainView.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI
import Metal

struct MainView: View {
    @ObservedObject var settingsStore: SettingsStore
    @StateObject private var hapticsManager = HapticsManager()
    @StateObject private var gpuSimulator: FluidSimulatorGPU
    @State private var showSettings = false
    @State private var showDebugOverlay = false
    
    // CLEANUP: GPU simulator is now the single source of truth
    init(settingsStore: SettingsStore = SettingsStore()) {
        self._settingsStore = ObservedObject(wrappedValue: settingsStore)
        
        // Create GPU simulator with optimal dimensions for performance (following blueprint)
        guard let device = MTLCreateSystemDefaultDevice(),
              let simulator = FluidSimulatorGPU(device: device, width: 128, height: 256) else {
            fatalError("Failed to create GPU simulator - Metal not available")
        }
        
        simulator.parameters = settingsStore.fluidParameters
        let clampedIndex = MainView.clampedPaletteIndex(settingsStore.interactionSettings.selectedPaletteIndex)
        if clampedIndex != settingsStore.interactionSettings.selectedPaletteIndex {
            var updatedSettings = settingsStore.interactionSettings
            updatedSettings.selectedPaletteIndex = clampedIndex
            settingsStore.interactionSettings = updatedSettings
            SettingsStore.save(interactionSettings: updatedSettings)
        }
        
        self._gpuSimulator = StateObject(wrappedValue: simulator)
    }
    
    private var selectedPalette: ColorPalette {
        let index = MainView.clampedPaletteIndex(settingsStore.interactionSettings.selectedPaletteIndex)
        return ColorPalette.palettes[index]
    }
    
    private var interactionSettings: SettingsStore.InteractionSettings {
        settingsStore.interactionSettings
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // CLEANUP: Only GPU path remains - single source of truth
                FluidGPUCanvasView(
                    selectedPalette: selectedPalette,
                    interactionSettings: interactionSettings,
                    screenSize: geometry.size,
                    simulator: gpuSimulator
                )
                .ignoresSafeArea()
                
                // Controls Overlay - ENHANCED: Show GPU status
                VStack {
                    HStack {
                        Button {
                            showSettings.toggle()
                        } label: {
                            Image(systemName: "gear")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // Clear button
                        Button {
                            gpuSimulator.clear()
                            hapticsManager.clearFluid()
                        } label: {
                            Image(systemName: "trash")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // Debug toggle
                        Button {
                            showDebugOverlay.toggle()
                        } label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue.opacity(0.4))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // SHOW: Pure GPU indicator (blueprint complete)
                        Text("GPU")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(8)
                            .shadow(color: Color.green.opacity(0.3), radius: 4)
                    }
                    .padding(.horizontal)
                    .padding(.top, 60)
                    
                    // Debug overlay (blueprint verification)
                    if showDebugOverlay {
                        HStack {
                            DebugOverlayView(simulator: gpuSimulator)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Enhanced palette selector
                    VStack(spacing: 12) {
                        Text("Color Palettes")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .textCase(.uppercase)
                            .tracking(1)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(0..<ColorPalette.palettes.count, id: \.self) { index in
                                    let palette = ColorPalette.palettes[index]
                                    
                                    VStack(spacing: 8) {
                                        HStack(spacing: 2) {
                                            ForEach(0..<palette.swiftUIColors.count, id: \.self) { colorIndex in
                                                Circle()
                                                    .fill(palette.swiftUIColors[colorIndex])
                                                    .frame(width: 15, height: 15)
                                            }
                                        }
                                        
                                        Text(palette.name)
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(
                                                selectedPalette.name == palette.name ?
                                                Color.white.opacity(0.25) : Color.white.opacity(0.1)
                                            )
                                            .stroke(
                                                selectedPalette.name == palette.name ?
                                                Color.white.opacity(0.6) : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                    .scaleEffect(selectedPalette.name == palette.name ? 1.05 : 1.0)
                                    .animation(.spring(response: 0.3), value: selectedPalette.name)
                                    .onTapGesture {
                                        updateSelectedPalette(index: index)
                                        hapticsManager.colorChanged()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            // CLEANUP: Update to work with GPU simulator
            GPUSettingsView(simulator: gpuSimulator, settingsStore: settingsStore)
        }
        .onChange(of: settingsStore.interactionSettings) { newValue in
            SettingsStore.save(interactionSettings: newValue)
        }
    }
    
    private static func clampedPaletteIndex(_ index: Int) -> Int {
        guard !ColorPalette.palettes.isEmpty else { return 0 }
        return min(max(index, 0), ColorPalette.palettes.count - 1)
    }
    
    private func updateSelectedPalette(index: Int) {
        guard !ColorPalette.palettes.isEmpty else { return }
        var updatedSettings = settingsStore.interactionSettings
        updatedSettings.selectedPaletteIndex = MainView.clampedPaletteIndex(index)
        settingsStore.interactionSettings = updatedSettings
    }
}

#Preview {
    MainView()
}
