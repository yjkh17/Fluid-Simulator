//
//  DitheringTexture.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import Metal
import MetalKit

// Based on WebGL Texture class ditheringTexture
class DitheringTexture {
    private let device: MTLDevice
    private var texture: MTLTexture?
    
    // Dithering pattern data (based on WebGL base64 pattern)
    private let ditheringPattern: [UInt8] = [
        // 64x64 dithering pattern (simplified version of WebGL pattern)
        0x00, 0x80, 0x20, 0xA0, 0x08, 0x88, 0x28, 0xA8,
        0xC0, 0x40, 0xE0, 0x60, 0xC8, 0x48, 0xE8, 0x68,
        0x30, 0xB0, 0x10, 0x90, 0x38, 0xB8, 0x18, 0x98,
        0xF0, 0x70, 0xD0, 0x50, 0xF8, 0x78, 0xD8, 0x58,
        0x0C, 0x8C, 0x2C, 0xAC, 0x04, 0x84, 0x24, 0xA4,
        0xCC, 0x4C, 0xEC, 0x6C, 0xC4, 0x44, 0xE4, 0x64,
        0x3C, 0xBC, 0x1C, 0x9C, 0x34, 0xB4, 0x14, 0x94,
        0xFC, 0x7C, 0xDC, 0x5C, 0xF4, 0x74, 0xD4, 0x54
    ]
    
    init(device: MTLDevice) {
        self.device = device
        createDitheringTexture()
    }
    
    private func createDitheringTexture() {
        let descriptor = MTLTextureDescriptor()
        descriptor.width = 64
        descriptor.height = 64
        descriptor.pixelFormat = .r8Unorm
        descriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            print("Failed to create dithering texture")
            return
        }
        
        // Generate full 64x64 pattern by repeating and varying the base pattern
        var fullPattern = [UInt8](repeating: 0, count: 64 * 64)
        
        for y in 0..<64 {
            for x in 0..<64 {
                let baseIndex = (y % 8) * 8 + (x % 8)
                let variation = UInt8((x / 8) + (y / 8) * 8)
                fullPattern[y * 64 + x] = ditheringPattern[baseIndex % ditheringPattern.count] ^ variation
            }
        }
        
        // Upload pattern to texture
        texture.replace(
            region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                            size: MTLSize(width: 64, height: 64, depth: 1)),
            mipmapLevel: 0,
            withBytes: fullPattern,
            bytesPerRow: 64
        )
        
        self.texture = texture
    }
    
    // Get texture scale like WebGL getTextureScale
    func getTextureScale(for size: CGSize) -> simd_float2 {
        guard let texture = texture else {
            return simd_float2(1.0, 1.0)
        }
        
        return simd_float2(
            Float(size.width) / Float(texture.width),
            Float(size.height) / Float(texture.height)
        )
    }
    
    func getTexture() -> MTLTexture? {
        return texture
    }
}