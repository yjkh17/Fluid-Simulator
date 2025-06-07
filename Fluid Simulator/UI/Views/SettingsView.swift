//
//  SettingsView.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI

struct SettingsView: View {
    let fluidEngine: FluidEngine
    @StateObject private var settingsStore = SettingsStore()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Simulation Parameters Section
                Section("محاكاة الفيزياء") {
                    HStack {
                        Text("اللزوجة")
                        Spacer()
                        Slider(value: $settingsStore.parameters.viscosity, in: 0.001...0.1)
                        Text(String(format: "%.3f", settingsStore.parameters.viscosity))
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("الانتشار")
                        Spacer()
                        Slider(value: $settingsStore.parameters.diffusion, in: 0.001...0.1)
                        Text(String(format: "%.3f", settingsStore.parameters.diffusion))
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("قوة الدوامة")
                        Spacer()
                        Slider(value: $settingsStore.parameters.vorticity, in: 0...20)
                        Text(String(format: "%.1f", settingsStore.parameters.vorticity))
                            .frame(width: 50)
                    }
                    
                    Stepper("تكرارات الحلول: \(settingsStore.parameters.iterations)",
                           value: $settingsStore.parameters.iterations, in: 1...20)
                }
                
                // Visual Settings Section (based on WebGL display options)
                Section("الإعدادات البصرية") {
                    Toggle("تظليل ثلاثي الأبعاد", isOn: $settingsStore.visualSettings.shading)
                    Toggle("تأثير الإشعاع", isOn: $settingsStore.visualSettings.bloom)
                    Toggle("ألوان متحركة", isOn: $settingsStore.visualSettings.colorful)
                    Toggle("خلفية شفافة", isOn: $settingsStore.visualSettings.transparent)
                    Toggle("ألوان معكوسة", isOn: $settingsStore.visualSettings.inverted)
                    
                    if settingsStore.visualSettings.bloom {
                        HStack {
                            Text("قوة الإشعاع")
                            Spacer()
                            Slider(value: $settingsStore.visualSettings.bloomIntensity, in: 0...2)
                            Text(String(format: "%.1f", settingsStore.visualSettings.bloomIntensity))
                                .frame(width: 30)
                        }
                        
                        HStack {
                            Text("عتبة الإشعاع")
                            Spacer()
                            Slider(value: $settingsStore.visualSettings.bloomThreshold, in: 0...1)
                            Text(String(format: "%.1f", settingsStore.visualSettings.bloomThreshold))
                                .frame(width: 30)
                        }
                    }
                    
                    HStack {
                        Text("السطوع")
                        Spacer()
                        Slider(value: $settingsStore.visualSettings.brightness, in: 0...1)
                        Text(String(format: "%.1f", settingsStore.visualSettings.brightness))
                            .frame(width: 30)
                    }
                }
                
                // Interaction Settings Section (based on WebGL input config)
                Section("إعدادات التفاعل") {
                    Toggle("تفاعل عند التمرير", isOn: $settingsStore.interactionSettings.hover)
                    
                    HStack {
                        Text("حجم الفرشاة")
                        Spacer()
                        Slider(value: $settingsStore.interactionSettings.splatRadius, in: 0.1...1.0)
                        Text(String(format: "%.1f", settingsStore.interactionSettings.splatRadius))
                            .frame(width: 30)
                    }
                    
                    HStack {
                        Text("قوة اللمس")
                        Spacer()
                        Slider(value: $settingsStore.interactionSettings.splatForce, in: 1000...10000)
                        Text(String(format: "%.0f", settingsStore.interactionSettings.splatForce))
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("سرعة تغيير الألوان")
                        Spacer()
                        Slider(value: $settingsStore.interactionSettings.colorUpdateSpeed, in: 1...20)
                        Text(String(format: "%.0f", settingsStore.interactionSettings.colorUpdateSpeed))
                            .frame(width: 30)
                    }
                }
                
                // Presets Section (based on WebGL examples)
                Section("إعدادات مسبقة") {
                    ForEach(FluidPreset.allCases, id: \.self) { preset in
                        Button(preset.rawValue) {
                            settingsStore.applyPreset(preset)
                            fluidEngine.updateParameters(settingsStore.parameters)
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                // Reset Section
                Section("إعادة تعيين") {
                    Button("استعادة الإعدادات الافتراضية") {
                        settingsStore.resetToDefaults()
                        fluidEngine.updateParameters(settingsStore.parameters)
                    }
                    .foregroundColor(.red)
                    
                    Button("مسح المحاكاة") {
                        fluidEngine.clear()
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("إعدادات المحاكاة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("تم") {
                        dismiss()
                    }
                }
            }
            .onChange(of: settingsStore.parameters) { _, newParams in
                fluidEngine.updateParameters(newParams)
            }
        }
    }
}

#Preview {
    SettingsView(fluidEngine: FluidEngine(width: 32, height: 64))
}
