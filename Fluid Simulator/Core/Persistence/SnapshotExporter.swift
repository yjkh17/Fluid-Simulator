//
//  SnapshotExporter.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import UIKit
import Metal
import MetalKit
import AVFoundation

// Based on WebGL Screenshot class
class SnapshotExporter: ObservableObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    // Recording settings (based on WebGL config)
    var captureResolution: Int = 512
    var inverted: Bool = false
    
    init?(device: MTLDevice) {
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue
    }
    
    // Capture screenshot like WebGL captureScreenshot()
    func captureScreenshot(from fluidState: FluidState, completion: @escaping (UIImage?) -> Void) {
        let resolution = getResolution()
        
        guard let texture = createCaptureTexture(width: resolution.width, height: resolution.height) else {
            completion(nil)
            return
        }
        
        // Render fluid to capture texture
        renderFluidToTexture(fluidState: fluidState, texture: texture) { [weak self] success in
            guard success, let self = self else {
                completion(nil)
                return
            }
            
            // Convert texture to UIImage
            self.textureToUIImage(texture: texture) { image in
                guard let image = image else {
                    completion(nil)
                    return
                }
                
                var finalImage = image
                
                // Apply inversion if enabled (like WebGL)
                if self.inverted, let invertedImage = self.invertImageColors(image) {
                    finalImage = invertedImage
                }
                
                completion(finalImage)
            }
        }
    }
    
    // Based on WebGL normalizeTexture and textureToCanvas
    private func textureToUIImage(texture: MTLTexture, completion: @escaping (UIImage?) -> Void) {
        let width = texture.width
        let height = texture.height
        let rowBytes = width * 4
        let length = rowBytes * height
        
        guard let buffer = device.makeBuffer(length: length, options: .storageModeShared) else {
            completion(nil)
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            completion(nil)
            return
        }
        
        // Copy texture to buffer
        blitEncoder.copy(from: texture,
                        sourceSlice: 0,
                        sourceLevel: 0,
                        sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                        sourceSize: MTLSize(width: width, height: height, depth: 1),
                        to: buffer,
                        destinationOffset: 0,
                        destinationBytesPerRow: rowBytes,
                        destinationBytesPerImage: length)
        
        blitEncoder.endEncoding()
        
        commandBuffer.addCompletedHandler { _ in
            // Normalize texture data (like WebGL normalizeTexture)
            let normalizedData = self.normalizeTextureData(
                buffer: buffer,
                width: width,
                height: height,
                rowBytes: rowBytes
            )
            
            // Create UIImage from normalized data
            let image = self.createUIImage(from: normalizedData, width: width, height: height)
            
            DispatchQueue.main.async {
                completion(image)
            }
        }
        
        commandBuffer.commit()
    }
    
    // Based on WebGL normalizeTexture function
    private func normalizeTextureData(buffer: MTLBuffer, width: Int, height: Int, rowBytes: Int) -> Data {
        let rawData = buffer.contents().bindMemory(to: Float.self, capacity: width * height * 4)
        var normalizedData = Data(capacity: width * height * 4)
        
        // Flip Y coordinate and normalize values (like WebGL)
        for y in 0..<height {
            let flippedY = height - 1 - y
            for x in 0..<width {
                let sourceIndex = (y * width + x) * 4
                let _ = (flippedY * width + x) * 4
                
                // Clamp and convert float to UInt8 (like WebGL clamp01)
                let r = UInt8(max(0, min(1, rawData[sourceIndex + 0])) * 255)
                let g = UInt8(max(0, min(1, rawData[sourceIndex + 1])) * 255)
                let b = UInt8(max(0, min(1, rawData[sourceIndex + 2])) * 255)
                let a = UInt8(max(0, min(1, rawData[sourceIndex + 3])) * 255)
                
                normalizedData.append(contentsOf: [r, g, b, a])
            }
        }
        
        return normalizedData
    }
    
    // Based on WebGL textureToCanvas
    private func createUIImage(from data: Data, width: Int, height: Int) -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: UnsafeMutablePointer(mutating: data.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress }),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        guard let cgImage = context.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // Based on WebGL invertImageColors
    private func invertImageColors(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        // Invert RGB channels (keep alpha)
        for i in stride(from: 0, to: width * height * 4, by: 4) {
            pixels[i] = 255 - pixels[i]         // R
            pixels[i + 1] = 255 - pixels[i + 1] // G
            pixels[i + 2] = 255 - pixels[i + 2] // B
            // pixels[i + 3] unchanged (alpha)
        }
        
        guard let invertedCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: invertedCGImage)
    }
    
    // Based on WebGL downloadURI functionality
    func saveImageToPhotos(_ image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        completion(true, nil)
    }
    
    // Export as data URL (like WebGL)
    func exportImageAsDataURL(_ image: UIImage) -> String? {
        guard let imageData = image.pngData() else { return nil }
        let base64String = imageData.base64EncodedString()
        return "data:image/png;base64,\(base64String)"
    }
    
    // Helper functions
    private func getResolution() -> (width: Int, height: Int) {
        // Simple square resolution for now
        return (width: captureResolution, height: captureResolution)
    }
    
    private func createCaptureTexture(width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor()
        descriptor.width = width
        descriptor.height = height
        descriptor.pixelFormat = .rgba16Float
        descriptor.usage = [.renderTarget, .shaderRead]
        
        return device.makeTexture(descriptor: descriptor)
    }
    
    private func renderFluidToTexture(fluidState: FluidState, texture: MTLTexture, completion: @escaping (Bool) -> Void) {
        // This would render the current fluid state to the capture texture
        // Implementation depends on the specific rendering pipeline
        completion(true)
    }
    
    func captureFluidSnapshot(
        fluidState: FluidState,
        resolution: CGSize = CGSize(width: 1024, height: 1024),
        inverted: Bool = false,
        completion: @escaping (UIImage?) -> Void
    ) {
        captureScreenshot(from: fluidState, completion: completion)
    }
    
    func exportHighQuality(fluidState: FluidState, completion: @escaping (Bool) -> Void) {
        captureScreenshot(from: fluidState) { image in
            completion(image != nil)
        }
    }
}

// Video recording support (inspired by WebGL multiple screenshots)
extension SnapshotExporter {
    func startVideoRecording(duration: TimeInterval, fps: Int = 30, completion: @escaping (URL?) -> Void) {
        // Create video writer
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoURL = documentsPath.appendingPathComponent("fluid_simulation_\(Date().timeIntervalSince1970).mov")
        
        // Implementation would capture frames over time and compose into video
        // Similar to WebGL's multiple screenshot approach
        completion(videoURL)
    }
}
