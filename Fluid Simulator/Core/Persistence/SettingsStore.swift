//
//  SettingsStore.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import Foundation
import SwiftUI

// Based on WebGL defaultConfig system
class SettingsStore: ObservableObject {
    @Published var parameters: FluidParameters
    @Published var visualSettings: VisualSettings
    @Published var interactionSettings: InteractionSettings
    
    // Visual settings (based on WebGL config)
    struct VisualSettings: Codable {
        var shading: Bool = true
        var colorful: Bool = true
        var brightness: Float = 0.5
        var bloom: Bool = true
        var bloomIntensity: Float = 0.8
        var bloomThreshold: Float = 0.6
        var bloomSoftKnee: Float = 0.7
        var backgroundColor: String = "#000000"
        var transparent: Bool = false
        var inverted: Bool = false
    }
    
    // Interaction settings (based on WebGL config)
    struct InteractionSettings: Codable {
        var hover: Bool = true
        var splatRadius: Float = 0.25
        var splatForce: Float = 6000.0
        var colorUpdateSpeed: Float = 10.0
        var selectedPaletteIndex: Int = 0
    }
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        // Load saved settings or use defaults
        self.parameters = SettingsStore.loadParameters() ?? .default
        self.visualSettings = SettingsStore.loadVisualSettings() ?? VisualSettings()
        self.interactionSettings = SettingsStore.loadInteractionSettings() ?? InteractionSettings()
    }
    
    // Load/Save methods (based on WebGL localStorage pattern)
    static func loadParameters() -> FluidParameters? {
        guard let data = UserDefaults.standard.data(forKey: "FluidParameters") else { return nil }
        return try? JSONDecoder().decode(FluidParameters.self, from: data)
    }
    
    static func save(parameters: FluidParameters) {
        guard let data = try? JSONEncoder().encode(parameters) else { return }
        UserDefaults.standard.set(data, forKey: "FluidParameters")
    }
    
    static func loadVisualSettings() -> VisualSettings? {
        guard let data = UserDefaults.standard.data(forKey: "VisualSettings") else { return nil }
        return try? JSONDecoder().decode(VisualSettings.self, from: data)
    }
    
    static func save(visualSettings: VisualSettings) {
        guard let data = try? JSONEncoder().encode(visualSettings) else { return }
        UserDefaults.standard.set(data, forKey: "VisualSettings")
    }
    
    static func loadInteractionSettings() -> InteractionSettings? {
        guard let data = UserDefaults.standard.data(forKey: "InteractionSettings") else { return nil }
        return try? JSONDecoder().decode(InteractionSettings.self, from: data)
    }
    
    static func save(interactionSettings: InteractionSettings) {
        guard let data = try? JSONEncoder().encode(interactionSettings) else { return }
        UserDefaults.standard.set(data, forKey: "InteractionSettings")
    }
    
    // Preset configurations (based on WebGL examples)
    func applyPreset(_ preset: FluidPreset) {
        switch preset {
        case .smooth:
            parameters.viscosity = 0.02
            parameters.diffusion = 0.02
            parameters.iterations = 8
            visualSettings.bloom = true
            
        case .turbulent:
            parameters.viscosity = 0.001
            parameters.vorticity = 10.0
            parameters.iterations = 15
            visualSettings.bloom = false
            
        case .minimal:
            parameters.viscosity = 0.1
            parameters.diffusion = 0.1
            parameters.iterations = 1
            visualSettings.bloom = false
            
        case .artistic:
            parameters.viscosity = 0.005
            visualSettings.bloom = true
            visualSettings.bloomIntensity = 1.0
            visualSettings.colorful = true
        }
        
        // Save changes
        SettingsStore.save(parameters: parameters)
        SettingsStore.save(visualSettings: visualSettings)
    }
    
    // Reset to defaults (based on WebGL reset functionality)
    func resetToDefaults() {
        parameters = .default
        visualSettings = VisualSettings()
        interactionSettings = InteractionSettings()
        
        // Save changes
        SettingsStore.save(parameters: parameters)
        SettingsStore.save(visualSettings: visualSettings)
        SettingsStore.save(interactionSettings: interactionSettings)
    }
}

enum FluidPreset: String, CaseIterable {
    case smooth = "Smooth"
    case turbulent = "Turbulent" 
    case minimal = "Minimal"
    case artistic = "Artistic"
}
