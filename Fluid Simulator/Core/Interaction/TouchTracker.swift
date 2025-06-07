//
//  TouchTracker.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI
import simd

class TouchTracker: ObservableObject {
    private var lastTouchPosition: CGPoint?
    private var lastTouchTime: TimeInterval?
    private var touchVelocity: CGPoint = .zero
    
    // Touch tracking settings
    private let velocitySmoothing: CGFloat = 0.8
    private let maxVelocity: CGFloat = 1000.0
    
    func handleTouchBegan(at location: CGPoint) {
        lastTouchPosition = location
        lastTouchTime = Date().timeIntervalSince1970
        touchVelocity = .zero
    }
    
    func handleTouchMoved(to location: CGPoint) -> TouchData {
        let currentTime = Date().timeIntervalSince1970
        
        defer {
            lastTouchPosition = location
            lastTouchTime = currentTime
        }
        
        guard let lastPosition = lastTouchPosition,
              let lastTime = lastTouchTime else {
            return TouchData(position: location, velocity: .zero, pressure: 1.0)
        }
        
        let deltaTime = currentTime - lastTime
        guard deltaTime > 0 else {
            return TouchData(position: location, velocity: touchVelocity, pressure: 1.0)
        }
        
        // Calculate velocity
        let deltaX = location.x - lastPosition.x
        let deltaY = location.y - lastPosition.y
        let instantVelocity = CGPoint(
            x: deltaX / CGFloat(deltaTime),
            y: deltaY / CGFloat(deltaTime)
        )
        
        // Smooth velocity and clamp
        touchVelocity.x = touchVelocity.x * velocitySmoothing + instantVelocity.x * (1 - velocitySmoothing)
        touchVelocity.y = touchVelocity.y * velocitySmoothing + instantVelocity.y * (1 - velocitySmoothing)
        
        let velocityMagnitude = sqrt(touchVelocity.x * touchVelocity.x + touchVelocity.y * touchVelocity.y)
        if velocityMagnitude > maxVelocity {
            let scale = maxVelocity / velocityMagnitude
            touchVelocity.x *= scale
            touchVelocity.y *= scale
        }
        
        // Calculate pressure based on velocity (faster movement = more pressure)
        let pressure = min(1.0, velocityMagnitude / 300.0)
        
        return TouchData(position: location, velocity: touchVelocity, pressure: pressure)
    }
    
    func handleTouchEnded() {
        lastTouchPosition = nil
        lastTouchTime = nil
        touchVelocity = .zero
    }
    
    // Convert screen coordinates to grid coordinates
    func screenToGrid(_ screenPosition: CGPoint, screenSize: CGSize, gridSize: SIMD2<Int>) -> SIMD2<Int> {
        let x = Int((screenPosition.x / screenSize.width) * CGFloat(gridSize.x))
        let y = Int((screenPosition.y / screenSize.height) * CGFloat(gridSize.y))
        
        return SIMD2<Int>(
            max(0, min(gridSize.x - 1, x)),
            max(0, min(gridSize.y - 1, y))
        )
    }
    
    // Apply force with brush radius - CHANGE: Add strict bounds checking
    func applyForceWithBrush(
        to engine: FluidEngine,
        touchData: TouchData,
        screenSize: CGSize,
        gridSize: SIMD2<Int>,
        brushSize: Float,
        colorPalette: ColorPalette
    ) {
        let gridPos = screenToGrid(touchData.position, screenSize: screenSize, gridSize: gridSize)
        let radius = Int(ceil(brushSize))
        
        // Get random color from palette
        let color = colorPalette.getRandomColor()
        
        // Apply force and color in brush radius
        for dy in -radius...radius {
            for dx in -radius...radius {
                let x = gridPos.x + dx
                let y = gridPos.y + dy
                
                guard x >= 0 && x < gridSize.x && y >= 0 && y < gridSize.y else { continue }
                
                let distance = sqrt(Float(dx * dx + dy * dy))
                if distance <= brushSize {
                    let falloff = max(0.0, 1.0 - (distance / brushSize))
                    let strength = falloff * Float(touchData.pressure)
                    
                    let clampedStrength = min(1.0, max(0.0, strength))
                    
                    // Add velocity - CHANGE: Reduce force magnitude
                    engine.addForce(
                        x: x, y: y,
                        deltaX: Float(touchData.velocity.x) * clampedStrength * 0.0005, // Reduced
                        deltaY: Float(touchData.velocity.y) * clampedStrength * 0.0005  // Reduced
                    )
                    
                    // Add color
                    engine.addColor(
                        x: x, y: y,
                        r: color.x * clampedStrength,
                        g: color.y * clampedStrength,
                        b: color.z * clampedStrength
                    )
                    
                    // Add density for smoke effect
                    engine.addDensity(x: x, y: y, amount: clampedStrength * 0.3) // Reduced
                }
            }
        }
    }
}

struct TouchData {
    let position: CGPoint
    let velocity: CGPoint
    let pressure: CGFloat
}
