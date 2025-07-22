import Foundation
import AppKit
@preconcurrency import Vision
import os.log

/// Lightweight vision service optimized for speed and diary context
@MainActor
final class LightweightVisionService: ObservableObject {
    static let shared = LightweightVisionService()
    
    private let logger = Logger(subsystem: "com.gemi", category: "LightweightVision")
    
    enum QuickAnalysisError: LocalizedError {
        case invalidImage
        case analysisTimeout
        
        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Invalid or corrupted image"
            case .analysisTimeout:
                return "Image analysis took too long"
            }
        }
    }
    
    /// Quick analysis focused on diary-relevant information
    func quickAnalyze(_ image: NSImage) async throws -> String {
        logger.info("Starting quick image analysis")
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw QuickAnalysisError.invalidImage
        }
        
        // Get basic image info
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        var description = "Image (\(width)×\(height))"
        
        // Try ONE simple classification request with timeout
        let classificationResult = await withTaskGroup(of: String?.self) { group in
            group.addTask {
                do {
                    return try await self.performQuickClassification(cgImage)
                } catch {
                    self.logger.error("Classification failed: \(error)")
                    return nil
                }
            }
            
            group.addTask {
                // Timeout after 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                return nil
            }
            
            // Return first result (either classification or timeout)
            for await result in group {
                if let result = result {
                    group.cancelAll()
                    return result
                }
            }
            return "content" // Default fallback
        }
        
        description += " showing \(classificationResult)"
        
        return description
    }
    
    nonisolated private func performQuickClassification(_ cgImage: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNClassifyImageRequest()
                
                do {
                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    try handler.perform([request])
                    
                    guard let results = request.results,
                          !results.isEmpty else {
                        continuation.resume(returning: "content")
                        return
                    }
                    
                    // Get top 2 classifications for context
                    let topResults = results.prefix(2)
                        .filter { $0.confidence > 0.3 }
                        .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
                    
                    if topResults.isEmpty {
                        continuation.resume(returning: "content")
                    } else {
                        continuation.resume(returning: topResults.joined(separator: " and "))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Extract text if it's obviously a text-heavy image (screenshot, document)
    func quickTextExtraction(_ image: NSImage) async -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // Only try text extraction for reasonable sized images
        if image.size.width > 3000 || image.size.height > 3000 {
            return nil
        }
        
        return await withTaskGroup(of: String?.self) { group in
            group.addTask {
                do {
                    return try await self.performQuickTextRecognition(cgImage)
                } catch {
                    return nil
                }
            }
            
            group.addTask {
                // Timeout after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                return nil
            }
            
            for await result in group {
                if result != nil {
                    group.cancelAll()
                    return result
                }
            }
            return nil
        }
    }
    
    nonisolated private func performQuickTextRecognition(_ cgImage: CGImage) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                
                // Use fast mode for speed
                request.recognitionLevel = .fast
                request.usesLanguageCorrection = false
                
                do {
                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    try handler.perform([request])
                    
                    guard let results = request.results,
                          !results.isEmpty else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let text = results.compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: " ")
                    
                    // Only return if we found meaningful text
                    if text.count > 20 {
                        continuation.resume(returning: text)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}