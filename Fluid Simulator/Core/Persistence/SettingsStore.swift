//
//  SettingsStore.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import Foundation
import SwiftUI

// Simplified settings store for pure GPU path
class SettingsStore: ObservableObject {
    @Published var visualSettings: VisualSettings
    @Published var interactionSettings: InteractionSettings
    
    // Visual settings for GPU renderer
    struct VisualSettings: Codable {
        var brightness: Float = 0.5
        var backgroundColor: String = "#000000"
        var transparent: Bool = false
        var inverted: Bool = false
    }
    
    // Interaction settings for GPU touch handling
    struct InteractionSettings: Codable {
        var splatRadius: Float = 50.0          // GPU splat radius in pixels
        var splatForce: Float = 1.0            // GPU force multiplier
        var selectedPaletteIndex: Int = 0
    }
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        // Load saved settings or use defaults
        self.visualSettings = SettingsStore.loadVisualSettings() ?? VisualSettings()
        self.interactionSettings = SettingsStore.loadInteractionSettings() ?? InteractionSettings()
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
    
    // Reset to defaults
    func resetToDefaults() {
        visualSettings = VisualSettings()
        interactionSettings = InteractionSettings()
        
        // Save changes
        SettingsStore.save(visualSettings: visualSettings)
        SettingsStore.save(interactionSettings: interactionSettings)
    }
}
