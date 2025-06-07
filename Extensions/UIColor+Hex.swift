//
//  UIColor+Hex.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import UIKit
import SwiftUI
import simd

extension UIColor {
    /// Create UIColor from hex string
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0
        
        let length = hexSanitized.count
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            self.init(red: r, green: g, blue: b, alpha: a)
            return
        }
        
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        }
        
        self.init(red: r, green: g, blue: b, alpha: a)
    }
    
    /// Convert UIColor to hex string
    var hexString: String {
        guard let components = cgColor.components else { return "#000000" }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
    
    /// Create from SIMD3<Float> (Metal compatibility)
    convenience init(simd: SIMD3<Float>, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat(simd.x),
            green: CGFloat(simd.y),
            blue: CGFloat(simd.z),
            alpha: alpha
        )
    }
    
    /// Convert to SIMD3<Float> for Metal shaders
    var simd3: SIMD3<Float> {
        guard let components = cgColor.components else {
            return SIMD3<Float>(0, 0, 0)
        }
        
        return SIMD3<Float>(
            Float(components[0]),
            Float(components[1]),
            Float(components[2])
        )
    }
    
    /// Convert to SIMD4<Float> with alpha
    var simd4: SIMD4<Float> {
        guard let components = cgColor.components else {
            return SIMD4<Float>(0, 0, 0, 1)
        }
        
        let alpha = components.count > 3 ? Float(components[3]) : 1.0
        
        return SIMD4<Float>(
            Float(components[0]),
            Float(components[1]),
            Float(components[2]),
            alpha
        )
    }
}

// MARK: - Color Manipulation
extension UIColor {
    /// Brighten color by factor
    func brightened(by factor: CGFloat = 0.2) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(
                hue: hue,
                saturation: saturation,
                brightness: min(brightness + factor, 1.0),
                alpha: alpha
            )
        }
        
        return self
    }
    
    /// Darken color by factor
    func darkened(by factor: CGFloat = 0.2) -> UIColor {
        return brightened(by: -factor)
    }
    
    /// Adjust saturation
    func saturated(by factor: CGFloat = 0.2) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(
                hue: hue,
                saturation: min(saturation + factor, 1.0),
                brightness: brightness,
                alpha: alpha
            )
        }
        
        return self
    }
    
    /// Get complementary color
    var complementary: UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            let complementaryHue = hue + 0.5
            let normalizedHue = complementaryHue > 1.0 ? complementaryHue - 1.0 : complementaryHue
            
            return UIColor(
                hue: normalizedHue,
                saturation: saturation,
                brightness: brightness,
                alpha: alpha
            )
        }
        
        return self
    }
    
    /// Interpolate between two colors
    func interpolated(to color: UIColor, factor: CGFloat) -> UIColor {
        let clampedFactor = max(0, min(1, factor))
        
        guard let fromComponents = cgColor.components,
              let toComponents = color.cgColor.components else {
            return self
        }
        
        let r = fromComponents[0] + (toComponents[0] - fromComponents[0]) * clampedFactor
        let g = fromComponents[1] + (toComponents[1] - fromComponents[1]) * clampedFactor
        let b = fromComponents[2] + (toComponents[2] - fromComponents[2]) * clampedFactor
        
        let fromAlpha = fromComponents.count > 3 ? fromComponents[3] : 1.0
        let toAlpha = toComponents.count > 3 ? toComponents[3] : 1.0
        let a = fromAlpha + (toAlpha - fromAlpha) * clampedFactor
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - SwiftUI Integration
extension Color {
    /// Create Color from hex string
    init(hex: String) {
        let uiColor = UIColor(hex: hex)
        self.init(uiColor)
    }
    
    /// Create from SIMD3<Float>
    init(simd: SIMD3<Float>, alpha: Double = 1.0) {
        self.init(
            red: Double(simd.x),
            green: Double(simd.y),
            blue: Double(simd.z),
            opacity: alpha
        )
    }
    
    /// Convert to SIMD3<Float>
    var simd3: SIMD3<Float> {
        let uiColor = UIColor(self)
        return uiColor.simd3
    }
    
    /// Convert to hex string
    var hexString: String {
        let uiColor = UIColor(self)
        return uiColor.hexString
    }
}

// MARK: - Fluid Simulation Color Palettes
extension UIColor {
    /// Predefined fluid simulation colors
    static let fluidBlue = UIColor(hex: "#00B4DB")
    static let fluidCyan = UIColor(hex: "#0083B0")
    static let fluidPurple = UIColor(hex: "#9D50BB")
    static let fluidPink = UIColor(hex: "#F093FB")
    static let fluidOrange = UIColor(hex: "#FFB347")
    static let fluidYellow = UIColor(hex: "#FFF700")
    static let fluidGreen = UIColor(hex: "#00F260")
    static let fluidRed = UIColor(hex: "#FF6B6B")
    
    /// Ocean palette
    static let oceanColors: [UIColor] = [
        UIColor(hex: "#006994"),
        UIColor(hex: "#0582CA"),
        UIColor(hex: "#00A6FB"),
        UIColor(hex: "#0CB0A9"),
        UIColor(hex: "#40E0D0")
    ]
    
    /// Sunset palette
    static let sunsetColors: [UIColor] = [
        UIColor(hex: "#FF6B35"),
        UIColor(hex: "#F7931E"),
        UIColor(hex: "#FFE135"),
        UIColor(hex: "#C7D93D"),
        UIColor(hex: "#85B3D1")
    ]
    
    /// Galaxy palette
    static let galaxyColors: [UIColor] = [
        UIColor(hex: "#4A148C"),
        UIColor(hex: "#7B1FA2"),
        UIColor(hex: "#8E24AA"),
        UIColor(hex: "#AB47BC"),
        UIColor(hex: "#CE93D8")
    ]
    
    /// Fire palette
    static let fireColors: [UIColor] = [
        UIColor(hex: "#FF0000"),
        UIColor(hex: "#FF4500"),
        UIColor(hex: "#FF8C00"),
        UIColor(hex: "#FFD700"),
        UIColor(hex: "#FFFF00")
    ]
    
    /// Forest palette
    static let forestColors: [UIColor] = [
        UIColor(hex: "#006400"),
        UIColor(hex: "#228B22"),
        UIColor(hex: "#32CD32"),
        UIColor(hex: "#90EE90"),
        UIColor(hex: "#98FB98")
    ]
}