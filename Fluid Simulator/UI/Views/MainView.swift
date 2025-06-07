//
//  MainView.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI

struct MainView: View {
    @StateObject private var fluidEngine = FluidEngine(width: 48, height: 96)
    @StateObject private var touchTracker = TouchTracker()
    @State private var selectedPalette = ColorPalette.palettes[0]
    @State private var showSettings = false
    @State private var useMetalRendering = false // DISABLE: Metal still has issues, focus on optimized CPU
    @State private var frameCount = 0
    @State private var lastFrameTime = Date()
    @State private var fps: Double = 0
    
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // OPTIMIZED: Use efficient CPU rendering for now
                FluidCanvasView(
                    fluidEngine: fluidEngine,
                    touchTracker: touchTracker,
                    selectedPalette: selectedPalette,
                    screenSize: geometry.size
                )
                .ignoresSafeArea()
                
                // Controls Overlay - ENHANCED: Show optimized CPU mode
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
                            fluidEngine.clear()
                        } label: {
                            Image(systemName: "trash")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // SHOW: Optimized CPU status
                        Text("CPU+")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(8)
                            .shadow(color: Color.blue.opacity(0.3), radius: 4)
                    }
                    .padding(.horizontal)
                    .padding(.top, 60)
                    
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
                                        selectedPalette = palette
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
            SettingsView(fluidEngine: fluidEngine)
        }
    }
    
    private func updateFPS() {
        frameCount += 1
        let now = Date()
        let delta = now.timeIntervalSince(lastFrameTime)
        
        if delta >= 1.0 {
            fps = Double(frameCount) / delta
            frameCount = 0
            lastFrameTime = now
        }
    }
}

#Preview {
    MainView()
}
