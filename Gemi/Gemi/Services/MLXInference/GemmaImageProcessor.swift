import Foundation
import MLX
import CoreImage
import AppKit

/// Image processor for Gemma 3n multimodal model
@MainActor
class GemmaImageProcessor {
    // Gemma 3n expects 256-768px images
    static let minSize = 256
    static let maxSize = 768
    static let channels = 3
    
    /// Process image data into MLX tensor format
    static func processImage(_ imageData: Data) throws -> MLXArray {
        guard let nsImage = NSImage(data: imageData) else {
            throw ModelError.invalidFormat("Invalid image data")
        }
        
        // Get the best representation
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ModelError.invalidFormat("Could not create CGImage")
        }
        
        // Calculate target size maintaining aspect ratio
        let targetSize = calculateTargetSize(
            width: cgImage.width,
            height: cgImage.height
        )
        
        // Resize image
        let resizedImage = try resizeImage(cgImage, to: targetSize)
        
        // Convert to RGB tensor
        let tensor = try imageToTensor(resizedImage)
        
        return tensor
    }
    
    /// Calculate target size maintaining aspect ratio
    private static func calculateTargetSize(width: Int, height: Int) -> CGSize {
        let aspectRatio = Double(width) / Double(height)
        
        // Determine if we should fit to width or height
        let targetWidth: Int
        let targetHeight: Int
        
        if width > height {
            // Landscape: fit to width
            targetWidth = min(width, maxSize)
            targetHeight = Int(Double(targetWidth) / aspectRatio)
        } else {
            // Portrait or square: fit to height
            targetHeight = min(height, maxSize)
            targetWidth = Int(Double(targetHeight) * aspectRatio)
        }
        
        // Ensure minimum size
        let scaleFactor = max(
            Double(minSize) / Double(targetWidth),
            Double(minSize) / Double(targetHeight),
            1.0
        )
        
        return CGSize(
            width: Int(Double(targetWidth) * scaleFactor),
            height: Int(Double(targetHeight) * scaleFactor)
        )
    }
    
    /// Resize image to target size
    private static func resizeImage(_ image: CGImage, to size: CGSize) throws -> CGImage {
        let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        guard let context = context else {
            throw ModelError.invalidFormat("Could not create graphics context")
        }
        
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        
        guard let resizedImage = context.makeImage() else {
            throw ModelError.invalidFormat("Could not create resized image")
        }
        
        return resizedImage
    }
    
    /// Convert CGImage to MLX tensor
    private static func imageToTensor(_ image: CGImage) throws -> MLXArray {
        let width = image.width
        let height = image.height
        
        // Create bitmap context
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let totalBytes = height * bytesPerRow
        
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw ModelError.invalidFormat("Could not create bitmap context")
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Convert RGBA to RGB and normalize to [0, 1]
        var rgbValues: [Float32] = []
        rgbValues.reserveCapacity(width * height * channels)
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                let r = Float32(pixelData[pixelIndex]) / 255.0
                let g = Float32(pixelData[pixelIndex + 1]) / 255.0
                let b = Float32(pixelData[pixelIndex + 2]) / 255.0
                
                rgbValues.append(r)
                rgbValues.append(g)
                rgbValues.append(b)
            }
        }
        
        // Create MLX array with shape [height, width, channels]
        return MLXArray(rgbValues, [height, width, channels])
    }
    
    /// Preprocess image tensor for Gemma 3n
    static func preprocessForGemma(_ tensor: MLXArray) -> MLXArray {
        // Gemma 3n expects normalized images with specific preprocessing
        // This is a simplified version - actual preprocessing depends on model training
        
        // Normalize to [-1, 1] range (common for vision models)
        let normalized = tensor * 2.0 - 1.0
        
        // Add batch dimension: [1, height, width, channels]
        return normalized.expandedDimensions(axis: 0)
    }
}

// MARK: - ProcessedImage Factory

extension ProcessedImage {
    /// Create a processed image with tensor data
    @MainActor
    static func create(from data: Data) async throws -> ProcessedImage {
        let tensor = try GemmaImageProcessor.processImage(data)
        let preprocessedTensor = GemmaImageProcessor.preprocessForGemma(tensor)
        
        return ProcessedImage(
            data: data,
            tensor: tensor,
            preprocessedTensor: preprocessedTensor
        )
    }
}