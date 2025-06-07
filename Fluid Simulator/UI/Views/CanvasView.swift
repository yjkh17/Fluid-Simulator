//
//  CanvasView.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI

struct FluidCanvasView: View {
    let fluidEngine: FluidEngine
    let touchTracker: TouchTracker
    let selectedPalette: ColorPalette
    let screenSize: CGSize
    
    @State private var timer: Timer?
    @State private var lastTouchLocation: CGPoint?
    @State private var isRunning = true
    @State private var frameCount = 0
    
    var body: some View {
        Canvas { context, size in
            // Get current fluid state
            let fluidState = fluidEngine.getState()
            
            let cellWidth = size.width / CGFloat(fluidState.width)
            let cellHeight = size.height / CGFloat(fluidState.height)
            
            // Debug: Add some initial fluid for testing
            if frameCount < 10 {
                fluidEngine.addDensity(x: 16, y: 32, amount: 1.0)
                let color = selectedPalette.getRandomColor()
                fluidEngine.addColor(x: 16, y: 32, r: color.x, g: color.y, b: color.z)
            }
            
            // Render density field with colors
            for y in 0..<fluidState.height {
                for x in 0..<fluidState.width {
                    let index = y * fluidState.width + x
                    guard index < fluidState.density.count else { continue }
                    
                    let density = fluidState.density[index]
                    let colorR = fluidState.colorR[index]
                    let colorG = fluidState.colorG[index]
                    let colorB = fluidState.colorB[index]
                    
                    // Lower threshold to see more fluid
                    if density > 0.005 || colorR > 0.005 || colorG > 0.005 || colorB > 0.005 {
                        let alpha = max(density, max(colorR, max(colorG, colorB)))
                        let color = Color(
                            red: Double(max(0.1, colorR)), // Ensure minimum visibility
                            green: Double(max(0.1, colorG)),
                            blue: Double(max(0.1, colorB)),
                            opacity: Double(min(1.0, alpha * 2.0)) // Amplify visibility
                        )
                        
                        let rect = CGRect(
                            x: CGFloat(x) * cellWidth,
                            y: CGFloat(y) * cellHeight,
                            width: cellWidth + 1,
                            height: cellHeight + 1
                        )
                        
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
            
            // Debug visualization - show grid
            if frameCount < 5 {
                for x in 0...fluidState.width {
                    let xPos = CGFloat(x) * cellWidth
                    var path = Path()
                    path.move(to: CGPoint(x: xPos, y: 0))
                    path.addLine(to: CGPoint(x: xPos, y: size.height))
                    context.stroke(path, with: .color(.gray.opacity(0.1)), lineWidth: 0.5)
                }
                for y in 0...fluidState.height {
                    let yPos = CGFloat(y) * cellHeight
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: yPos))
                    path.addLine(to: CGPoint(x: size.width, y: yPos))
                    context.stroke(path, with: .color(.gray.opacity(0.1)), lineWidth: 0.5)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleTouch(at: value.location, velocity: calculateVelocity(from: value))
                    lastTouchLocation = value.location
                }
                .onEnded { _ in
                    lastTouchLocation = nil
                }
        )
        .onTapGesture { location in
            handleTap(at: location)
        }
        .onAppear {
            startSimulation()
        }
        .onDisappear {
            stopSimulation()
        }
        .onChange(of: isRunning) { _, newValue in
            if newValue {
                startSimulation()
            } else {
                stopSimulation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearFluid)) { _ in
            fluidEngine.clear()
        }
    }
    
    private func calculateVelocity(from value: DragGesture.Value) -> CGPoint {
        let currentLocation = value.location
        guard let lastLocation = lastTouchLocation else {
            return CGPoint.zero
        }
        
        let deltaX = currentLocation.x - lastLocation.x
        let deltaY = currentLocation.y - lastLocation.y
        
        return CGPoint(x: deltaX, y: deltaY)
    }
    
    private func handleTouch(at location: CGPoint, velocity: CGPoint) {
        let fluidState = fluidEngine.getState()
        
        // Convert screen coordinates to grid coordinates
        let x = Int((location.x / screenSize.width) * CGFloat(fluidState.width))
        let y = Int((location.y / screenSize.height) * CGFloat(fluidState.height))
        
        // Add force based on drag velocity
        let forceScale: Float = 1.0 // Increased force
        fluidEngine.addForce(
            x: x,
            y: y,
            deltaX: Float(velocity.x) * forceScale,
            deltaY: Float(velocity.y) * forceScale
        )
        
        // Add density in a small radius
        let radius = 3 // Larger radius
        for dx in -radius...radius {
            for dy in -radius...radius {
                let newX = x + dx
                let newY = y + dy
                
                if newX >= 0 && newX < fluidState.width && newY >= 0 && newY < fluidState.height {
                    let distance = sqrt(Float(dx * dx + dy * dy))
                    if distance <= Float(radius) {
                        let amount = (Float(radius) - distance) / Float(radius) * 1.0 // Increased amount
                        fluidEngine.addDensity(x: newX, y: newY, amount: amount)
                        
                        // Add color
                        let color = selectedPalette.getRandomColor()
                        fluidEngine.addColor(x: newX, y: newY, r: color.x * amount, g: color.y * amount, b: color.z * amount)
                    }
                }
            }
        }
    }
    
    private func handleTap(at location: CGPoint) {
        let fluidState = fluidEngine.getState()
        
        // Convert screen coordinates to grid coordinates
        let x = Int((location.x / screenSize.width) * CGFloat(fluidState.width))
        let y = Int((location.y / screenSize.height) * CGFloat(fluidState.height))
        
        // Create explosion effect
        let radius = 5 // Larger explosion
        for dx in -radius...radius {
            for dy in -radius...radius {
                let newX = x + dx
                let newY = y + dy
                
                if newX >= 0 && newX < fluidState.width && newY >= 0 && newY < fluidState.height {
                    let distance = sqrt(Float(dx * dx + dy * dy))
                    if distance <= Float(radius) {
                        let force = (Float(radius) - distance) / Float(radius)
                        
                        // Radial force outward
                        let forceX = Float(dx) * force * 5.0 // Stronger force
                        let forceY = Float(dy) * force * 5.0
                        
                        fluidEngine.addForce(x: newX, y: newY, deltaX: forceX, deltaY: forceY)
                        fluidEngine.addDensity(x: newX, y: newY, amount: force * 1.0) // More density
                        
                        // Add colorful explosion
                        let color = selectedPalette.getRandomColor()
                        fluidEngine.addColor(x: newX, y: newY, r: color.x * force, g: color.y * force, b: color.z * force)
                    }
                }
            }
        }
    }
    
    private func startSimulation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/25.0, repeats: true) { _ in
            frameCount += 1
            // Step the fluid simulation at 25 FPS
            fluidEngine.step()
        }
    }
    
    private func stopSimulation() {
        timer?.invalidate()
        timer = nil
    }
}

extension Notification.Name {
    static let clearFluid = Notification.Name("clearFluid")
}

#Preview {
    FluidCanvasView(
        fluidEngine: FluidEngine(width: 32, height: 64),
        touchTracker: TouchTracker(),
        selectedPalette: ColorPalette.palettes[0],
        screenSize: CGSize(width: 400, height: 800)
    )
}
