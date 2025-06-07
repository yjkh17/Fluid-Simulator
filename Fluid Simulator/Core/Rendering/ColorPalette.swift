//
//  ColorPalette.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import SwiftUI
import simd

// Based on WebGL Color class
struct ColorPalette {
    let name: String
    let colors: [String] // Hex colors
    
    // Enhanced color generation (based on WebGL generateColor)
    func getRandomColor(brightness: Float = 1.0) -> simd_float3 {
        guard !colors.isEmpty else {
            // Generate random hue if no palette
            let hue = Float.random(in: 0...1)
            return hsvToRgb(h: hue, s: 1.0, v: brightness)
        }
        
        let randomColor = colors.randomElement()!
        let hsvColor = hexToHSV(hex: randomColor)
        return hsvToRgb(h: hsvColor.x, s: hsvColor.y, v: brightness)
    }
    
    // Generate color with intensity (based on WebGL color generation)
    func getRandomColorWithIntensity(brightness: Float = 0.5) -> simd_float3 {
        let baseColor = getRandomColor(brightness: brightness)
        // Apply intensity multiplier like WebGL version
        return baseColor * 0.15
    }
    
    // Convert hex to HSV (based on WebGL HEXtoHSV)
    private func hexToHSV(hex: String) -> simd_float3 {
        let cleanHex = hex.replacingOccurrences(of: "#", with: "")
        
        let r = Float(Int(cleanHex.prefix(2), radix: 16) ?? 0) / 255.0
        let g = Float(Int(cleanHex.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255.0
        let b = Float(Int(cleanHex.dropFirst(4).prefix(2), radix: 16) ?? 0) / 255.0
        
        let maxVal = max(r, max(g, b))
        let minVal = min(r, min(g, b))
        
        var h: Float = 0
        let s: Float
        let v: Float = maxVal
        
        if maxVal == minVal {
            h = 0 // achromatic
        } else if maxVal == r {
            h = ((g - b) / (maxVal - minVal) + 6).truncatingRemainder(dividingBy: 6)
        } else if maxVal == g {
            h = (b - r) / (maxVal - minVal) + 2
        } else {
            h = (r - g) / (maxVal - minVal) + 4
        }
        h /= 6
        
        s = maxVal == 0 ? 0 : (maxVal - minVal) / maxVal
        
        return simd_float3(h, s, v)
    }
    
    // Convert HSV to RGB (based on WebGL HSVtoRGB)
    private func hsvToRgb(h: Float, s: Float, v: Float) -> simd_float3 {
        let i = Int(h * 6)
        let f = h * 6 - Float(i)
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)
        
        switch i % 6 {
        case 0: return simd_float3(v, t, p)
        case 1: return simd_float3(q, v, p)
        case 2: return simd_float3(p, v, t)
        case 3: return simd_float3(p, q, v)
        case 4: return simd_float3(t, p, v)
        case 5: return simd_float3(v, p, q)
        default: return simd_float3(0, 0, 0)
        }
    }
    
    // Normalize color (based on WebGL normalizeColor)
    func normalizeColor(_ color: simd_float3) -> simd_float3 {
        return color / 255.0
    }
    
    // Convert to SwiftUI colors for UI display
    var swiftUIColors: [Color] {
        return colors.map { hex in
            let rgb = hexToRgb(hex: hex)
            return Color(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z))
        }
    }
    
    private func hexToRgb(hex: String) -> simd_float3 {
        let cleanHex = hex.replacingOccurrences(of: "#", with: "")
        let r = Float(Int(cleanHex.prefix(2), radix: 16) ?? 0) / 255.0
        let g = Float(Int(cleanHex.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255.0
        let b = Float(Int(cleanHex.dropFirst(4).prefix(2), radix: 16) ?? 0) / 255.0
        return simd_float3(r, g, b)
    }
    
    // Enhanced palette collection (based on WebGL themes)
    static let palettes: [ColorPalette] = [
        ColorPalette(name: "Ocean", colors: [
            "#006994", "#0b7fab", "#2d96c4", "#54aed4", "#7bc7e4"
        ]),
        ColorPalette(name: "Sunset", colors: [
            "#ff6b35", "#f7931e", "#ffd23f", "#ff9a56", "#ff7849"
        ]),
        ColorPalette(name: "Forest", colors: [
            "#2d5016", "#3e6b1f", "#548c2f", "#6aad3d", "#86c943"
        ]),
        ColorPalette(name: "Galaxy", colors: [
            "#2d1b69", "#553c9a", "#7b5fb0", "#9f82ce", "#c3a6e4"
        ]),
        ColorPalette(name: "Fire", colors: [
            "#8b0000", "#dc143c", "#ff4500", "#ff6347", "#ff8c00"
        ]),
        ColorPalette(name: "Neon", colors: [
            "#ff0080", "#00ff80", "#8000ff", "#ff8000", "#0080ff"
        ]),
        ColorPalette(name: "Pastel", colors: [
            "#ffb3ba", "#ffdfba", "#ffffba", "#baffc9", "#bae1ff"
        ]),
        ColorPalette(name: "Monochrome", colors: [
            "#ffffff", "#e0e0e0", "#c0c0c0", "#a0a0a0", "#808080"
        ])
    ]
}
