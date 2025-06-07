//
//  CGPoint+Utils.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import CoreGraphics
import simd

extension CGPoint {
    /// Calculate distance between two points
    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Calculate velocity between two points over time
    func velocity(to point: CGPoint, deltaTime: TimeInterval) -> CGPoint {
        guard deltaTime > 0 else { return .zero }
        let dx = point.x - x
        let dy = point.y - y
        return CGPoint(x: dx / CGFloat(deltaTime), y: dy / CGFloat(deltaTime))
    }
    
    /// Normalize point to unit vector
    func normalized() -> CGPoint {
        let magnitude = sqrt(x * x + y * y)
        guard magnitude > 0 else { return .zero }
        return CGPoint(x: x / magnitude, y: y / magnitude)
    }
    
    /// Convert to SIMD2<Float> for Metal compatibility
    func toSIMD2() -> SIMD2<Float> {
        return SIMD2<Float>(Float(x), Float(y))
    }
    
    /// Interpolate between two points
    func interpolated(to point: CGPoint, factor: CGFloat) -> CGPoint {
        let clampedFactor = max(0, min(1, factor))
        return CGPoint(
            x: x + (point.x - x) * clampedFactor,
            y: y + (point.y - y) * clampedFactor
        )
    }
    
    /// Apply a transform matrix
    func applying(_ transform: CGAffineTransform) -> CGPoint {
        return self.applying(transform)
    }
    
    /// Convert screen coordinates to normalized coordinates (0-1)
    func normalized(in bounds: CGRect) -> CGPoint {
        return CGPoint(
            x: (x - bounds.minX) / bounds.width,
            y: (y - bounds.minY) / bounds.height
        )
    }
    
    /// Convert normalized coordinates to screen coordinates
    static func fromNormalized(_ normalized: CGPoint, in bounds: CGRect) -> CGPoint {
        return CGPoint(
            x: bounds.minX + normalized.x * bounds.width,
            y: bounds.minY + normalized.y * bounds.height
        )
    }
    
    /// Add two points
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    /// Subtract two points
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    /// Multiply point by scalar
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    
    /// Divide point by scalar
    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        guard rhs != 0 else { return .zero }
        return CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }
}

// MARK: - Vector Operations
extension CGPoint {
    /// Dot product of two vectors
    func dot(_ other: CGPoint) -> CGFloat {
        return x * other.x + y * other.y
    }
    
    /// Cross product (returns scalar for 2D)
    func cross(_ other: CGPoint) -> CGFloat {
        return x * other.y - y * other.x
    }
    
    /// Magnitude of the vector
    var magnitude: CGFloat {
        return sqrt(x * x + y * y)
    }
    
    /// Squared magnitude (faster than magnitude)
    var magnitudeSquared: CGFloat {
        return x * x + y * y
    }
    
    /// Angle of the vector in radians
    var angle: CGFloat {
        return atan2(y, x)
    }
    
    /// Create point from polar coordinates
    static func fromPolar(radius: CGFloat, angle: CGFloat) -> CGPoint {
        return CGPoint(
            x: radius * cos(angle),
            y: radius * sin(angle)
        )
    }
    
    /// Rotate point around origin
    func rotated(by angle: CGFloat) -> CGPoint {
        let cos = Foundation.cos(angle)
        let sin = Foundation.sin(angle)
        return CGPoint(
            x: x * cos - y * sin,
            y: x * sin + y * cos
        )
    }
    
    /// Rotate point around a center
    func rotated(around center: CGPoint, by angle: CGFloat) -> CGPoint {
        let translated = self - center
        let rotated = translated.rotated(by: angle)
        return rotated + center
    }
}

// MARK: - Fluid Simulation Specific
extension CGPoint {
    /// Convert to grid coordinates for fluid simulation
    func toGridCoordinates(gridSize: SIMD2<Int>, screenSize: CGSize) -> SIMD2<Int> {
        let normalizedX = x / screenSize.width
        let normalizedY = y / screenSize.height
        
        let gridX = Int(normalizedX * Float(gridSize.x))
        let gridY = Int(normalizedY * Float(gridSize.y))
        
        return SIMD2<Int>(
            max(0, min(gridSize.x - 1, gridX)),
            max(0, min(gridSize.y - 1, gridY))
        )
    }
    
    /// Apply smoothing for fluid interaction
    func smoothed(with previous: CGPoint, factor: CGFloat = 0.8) -> CGPoint {
        return CGPoint(
            x: previous.x * factor + x * (1 - factor),
            y: previous.y * factor + y * (1 - factor)
        )
    }
    
    /// Calculate force vector for fluid simulation
    func forceVector(to target: CGPoint, strength: CGFloat = 1.0) -> CGPoint {
        let direction = (target - self).normalized()
        return direction * strength
    }
}