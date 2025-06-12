//
//  FluidViewModel.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI
import Combine

class FluidViewModel: ObservableObject {
    @Published var fluidEngine: FluidEngine
    @Published var touchTracker: TouchTracker
    @Published var settingsStore: SettingsStore
    @Published var selectedPalette: ColorPalette
    @Published var isSimulating: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    private var displayLinkTimer: DisplayLinkTimer?
    private let hapticsManager: HapticsManager
    
    init(width: Int, height: Int, hapticsManager: HapticsManager) {
        self.fluidEngine = FluidEngine(width: width, height: height)
        self.touchTracker = TouchTracker()
        self.settingsStore = SettingsStore()
        self.selectedPalette = ColorPalette.palettes[0]
        self.hapticsManager = hapticsManager
        
        setupBindings()
        startSimulation()
    }
    
    private func setupBindings() {
        settingsStore.$parameters
            .assign(to: \.parameters, on: fluidEngine)
            .store(in: &cancellables)
        
        // Update engine parameters when settings change
        settingsStore.$parameters
            .sink { [weak self] parameters in
                self?.fluidEngine.updateParameters(parameters)
            }
            .store(in: &cancellables)
        
        // Update interaction settings when they change
        settingsStore.$interactionSettings
            .sink { _ in
                // Apply interaction settings to touch tracker
                // Implementation would depend on touch tracker properties
            }
            .store(in: &cancellables)
    }
    
    func startSimulation() {
        displayLinkTimer = DisplayLinkTimer { [weak self] deltaTime in
            guard let self = self, self.isSimulating else { return }
            // Single point of truth for simulation stepping
            self.fluidEngine.step()
        }
        displayLinkTimer?.start()
    }
    
    func stopSimulation() {
        displayLinkTimer?.stop()
        displayLinkTimer = nil
    }
    
    func clearSimulation() {
        fluidEngine.clear()
        hapticsManager.clearFluid()
    }
    
    func selectPalette(_ palette: ColorPalette) {
        selectedPalette = palette
        hapticsManager.colorChanged()
    }
    
    func toggleSimulation() {
        isSimulating.toggle()
        hapticsManager.settingsChanged()
    }
    
    func resetSettings() {
        settingsStore.resetToDefaults()
    }
    
    func applyPreset(_ preset: FluidPreset) {
        settingsStore.applyPreset(preset)
    }
    
    func showSettingsView() {
        hapticsManager.settingsChanged()
    }
    
    func createExplosion(at position: CGPoint, screenSize: CGSize) {
        let gridPos = screenToGrid(position, screenSize: screenSize)
        let color = selectedPalette.getRandomColor()
        
        let explosionRadius = Int(fluidEngine.parameters.brushSize * 2)
        
        for dy in -explosionRadius...explosionRadius {
            for dx in -explosionRadius...explosionRadius {
                let x = gridPos.x + dx
                let y = gridPos.y + dy
                
                guard x >= 0 && x < fluidEngine.parameters.gridSize.x &&
                      y >= 0 && y < fluidEngine.parameters.gridSize.y else { continue }
                
                let distance = sqrt(Float(dx * dx + dy * dy))
                if distance <= Float(explosionRadius) {
                    let strength = 1.0 - (distance / Float(explosionRadius))
                    let angle = atan2(Float(dy), Float(dx))
                    
                    // Radial explosion force
                    let forceX = cos(angle) * strength * 200.0
                    let forceY = sin(angle) * strength * 200.0
                    
                    fluidEngine.addForce(x: x, y: y, deltaX: forceX * 0.01, deltaY: forceY * 0.01)
                    fluidEngine.addColor(x: x, y: y, r: color.x * strength, g: color.y * strength, b: color.z * strength)
                    fluidEngine.addDensity(x: x, y: y, amount: strength * 0.8)
                }
            }
        }
        
        hapticsManager.explosion()
    }
    
    private func screenToGrid(_ screenPosition: CGPoint, screenSize: CGSize) -> SIMD2<Int> {
        let x = Int((screenPosition.x / screenSize.width) * CGFloat(fluidEngine.parameters.gridSize.x))
        let y = Int((screenPosition.y / screenSize.height) * CGFloat(fluidEngine.parameters.gridSize.y))
        
        return SIMD2<Int>(
            max(0, min(fluidEngine.parameters.gridSize.x - 1, x)),
            max(0, min(fluidEngine.parameters.gridSize.y - 1, y))
        )
    }
    
    deinit {
        stopSimulation()
    }
}
