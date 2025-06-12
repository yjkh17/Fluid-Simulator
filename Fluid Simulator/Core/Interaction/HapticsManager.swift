//
//  HapticsManager.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import UIKit
import CoreHaptics

class HapticsManager: ObservableObject {
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    @Published var isHapticsEnabled = true
    
    init() {
        // Prepare the feedback generators
        impactFeedback.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    func touchBegan() {
        guard isHapticsEnabled else { return }
        selectionFeedback.selectionChanged()
    }
    
    func touchMoved(velocity: CGFloat) {
        guard isHapticsEnabled else { return }
        
        // Scale haptic intensity based on touch velocity
        let normalizedVelocity = min(velocity / 1000.0, 1.0)
        
        if normalizedVelocity > 0.3 {
            let intensity = Float(normalizedVelocity)
            let sharpness = Float(0.5 + normalizedVelocity * 0.5)
            
            let hapticEvent = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0,
                duration: 0.1
            )
            
            playCustomHaptic(events: [hapticEvent])
        }
    }
    
    func touchEnded() {
        guard isHapticsEnabled else { return }
        impactFeedback.impactOccurred(intensity: 0.3)
    }
    
    func colorChanged() {
        guard isHapticsEnabled else { return }
        selectionFeedback.selectionChanged()
    }
    
    func settingsChanged() {
        guard isHapticsEnabled else { return }
        impactFeedback.impactOccurred(intensity: 0.5)
    }
    
    func explosion() {
        guard isHapticsEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
    }
    
    func clearFluid() {
        guard isHapticsEnabled else { return }
        notificationFeedback.notificationOccurred(.warning)
    }
    
    private func playCustomHaptic(events: [CHHapticEvent]) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            let engine = try CHHapticEngine()
            try engine.start()
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }
}
