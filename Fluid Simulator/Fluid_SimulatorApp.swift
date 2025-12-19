//
//  Fluid_SimulatorApp.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI

@main
struct Fluid_SimulatorApp: App {
    @StateObject private var settingsStore = SettingsStore()
    
    var body: some Scene {
        WindowGroup {
            MainView(settingsStore: settingsStore)
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}
