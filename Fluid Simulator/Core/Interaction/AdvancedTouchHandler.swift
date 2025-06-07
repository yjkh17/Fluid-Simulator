//
//  AdvancedTouchHandler.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI
import simd

// Based on WebGL Pointer class
class AdvancedTouchHandler: ObservableObject {
    struct TouchPointer {
        var id: Int
        var position: CGPoint
        var deltaX: Float = 0
        var deltaY: Float = 0
        var down: Bool = false
        var moved: Bool = false
        var color: simd_float3
        
        var texcoordX: Float = 0
        var texcoordY: Float = 0
        
        init(id: Int, colorPalette: ColorPalette, brightness: Float) {
            self.id = id
            self.position = .zero
            self.color = colorPalette.getRandomColor() * brightness
        }
        
        mutating func updatePointerDownData(id: Int, x: Float, y: Float, canvas: CGSize, colorPalette: ColorPalette, brightness: Float) {
            self.id = id
            self.down = true
            self.moved = false
            self.position = CGPoint(x: CGFloat(x), y: CGFloat(y))
            self.color = colorPalette.getRandomColor() * brightness
            
            // Convert to normalized texture coordinates
            self.texcoordX = x / Float(canvas.width)
            self.texcoordY = 1.0 - y / Float(canvas.height)
        }
        
        mutating func updatePointerMoveData(x: Float, y: Float, canvas: CGSize, hover: Bool) {
            let newTexcoordX = x / Float(canvas.width)
            let newTexcoordY = 1.0 - y / Float(canvas.height)
            
            self.deltaX = newTexcoordX - self.texcoordX
            self.deltaY = newTexcoordY - self.texcoordY
            
            self.texcoordX = newTexcoordX
            self.texcoordY = newTexcoordY
            
            self.position = CGPoint(x: CGFloat(x), y: CGFloat(y))
            self.moved = abs(deltaX) > 0 || abs(deltaY) > 0
            
            if !hover {
                self.down = false
            }
        }
        
        mutating func updatePointerUpData() {
            self.down = false
        }
    }
    
    private var pointers: [TouchPointer] = []
    
    // Settings from WebGL config
    var splatRadius: Float = 0.25
    var splatForce: Float = 6000.0
    var hover: Bool = true
    var colorful: Bool = true
    var brightness: Float = 0.5
    
    func handleTouchDown(at location: CGPoint, in canvas: CGSize, colorPalette: ColorPalette) -> TouchPointer? {
        let posX = Float(location.x)
        let posY = Float(location.y)
        
        var pointer = pointers.first { !$0.down } ?? TouchPointer(id: -1, colorPalette: colorPalette, brightness: brightness)
        pointer.updatePointerDownData(id: -1, x: posX, y: posY, canvas: canvas, colorPalette: colorPalette, brightness: brightness)
        
        if let index = pointers.firstIndex(where: { $0.id == pointer.id }) {
            pointers[index] = pointer
        } else {
            pointers.append(pointer)
        }
        
        return pointer
    }
    
    func handleTouchMove(at location: CGPoint, in canvas: CGSize) -> TouchPointer? {
        let posX = Float(location.x)
        let posY = Float(location.y)
        
        guard let index = pointers.firstIndex(where: { $0.down }) else { return nil }
        
        pointers[index].updatePointerMoveData(x: posX, y: posY, canvas: canvas, hover: hover)
        return pointers[index]
    }
    
    func handleTouchUp() {
        if !hover {
            for i in pointers.indices {
                pointers[i].updatePointerUpData()
            }
        }
    }
    
    func getActivePointers() -> [TouchPointer] {
        return pointers.filter { $0.moved }
    }
    
    // Apply splat like WebGL version
    func applySplat(pointer: TouchPointer, to engine: FluidEngine) {
        let dx = pointer.deltaX * splatForce
        let dy = pointer.deltaY * splatForce
        
        // Convert normalized coordinates to grid coordinates
        let gridX = Int(pointer.texcoordX * 32) // Assuming 32x64 grid
        let gridY = Int(pointer.texcoordY * 64)
        
        // Apply splat effect in radius
        let radius = Int(splatRadius * 10) // Scale radius for grid
        
        for offsetY in -radius...radius {
            for offsetX in -radius...radius {
                let x = gridX + offsetX
                let y = gridY + offsetY
                
                guard x >= 0 && x < 32 && y >= 0 && y < 64 else { continue }
                
                let distance = sqrt(Float(offsetX * offsetX + offsetY * offsetY))
                let falloff = exp(-distance * distance / (splatRadius * splatRadius))
                
                if falloff > 0.01 {
                    engine.addColor(
                        x: x, y: y,
                        r: pointer.color.x * falloff,
                        g: pointer.color.y * falloff,
                        b: pointer.color.z * falloff
                    )
                    
                    engine.addDensity(x: x, y: y, amount: falloff)
                    
                    engine.addForce(
                        x: x, y: y,
                        deltaX: dx * falloff,
                        deltaY: dy * falloff
                    )
                }
            }
        }
    }
}