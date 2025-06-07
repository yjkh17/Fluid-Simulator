//
//  MainView.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI

struct MainView: View {
    @StateObject private var fluidEngine = FluidEngine(width: 32, height: 64)
    @StateObject private var touchTracker = TouchTracker()
    @State private var selectedPalette = ColorPalette.palettes[0]
    @State private var showSettings = false
    @State private var useMetalRendering = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                if useMetalRendering && MTLCreateSystemDefaultDevice() != nil {
                    MetalFluidCanvasView(
                        selectedPalette: selectedPalette,
                        screenSize: geometry.size,
                        fluidEngine: fluidEngine
                    )
                    .ignoresSafeArea()
                } else {
                    FluidCanvasView(
                        fluidEngine: fluidEngine,
                        touchTracker: touchTracker,
                        selectedPalette: selectedPalette,
                        screenSize: geometry.size
                    )
                    .ignoresSafeArea()
                }
                
                // Controls Overlay - positioned over the fluid
                VStack {
                    HStack {
                        Button {
                            showSettings.toggle()
                        } label: {
                            Image(systemName: "circle")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.clear)
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Button {
                            useMetalRendering.toggle()
                        } label: {
                            Text(useMetalRendering ? "GPU" : "CPU")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(useMetalRendering ? Color.green.opacity(0.8) : Color.orange.opacity(0.8))
                                .cornerRadius(6)
                        }
                        .disabled(MTLCreateSystemDefaultDevice() == nil)
                    }
                    .padding(.horizontal)
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Color Palette Selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(0..<ColorPalette.palettes.count, id: \.self) { index in
                                let palette = ColorPalette.palettes[index]
                                
                                HStack(spacing: 2) {
                                    ForEach(0..<palette.swiftUIColors.count, id: \.self) { colorIndex in
                                        Circle()
                                            .fill(palette.swiftUIColors[colorIndex])
                                            .frame(width: 15, height: 15)
                                    }
                                }
                                .padding(10)
                                .background(
                                    selectedPalette.name == palette.name ?
                                    Color.white.opacity(0.5) : Color.white.opacity(0.2)
                                )
                                .cornerRadius(12)
                                .onTapGesture {
                                    selectedPalette = palette
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 80)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(fluidEngine: fluidEngine)
        }
    }
}

#Preview {
    MainView()
}
