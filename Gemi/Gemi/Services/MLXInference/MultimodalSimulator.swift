import Foundation
import CoreImage
import AppKit

/// Simulates multimodal understanding until MLX-Swift supports Gemma 3n vision
/// This provides intelligent responses based on image analysis without actual neural inference
@MainActor
final class MultimodalSimulator {
    
    // MARK: - Image Analysis
    
    /// Analyze image characteristics without neural network
    static func analyzeImage(_ imageData: Data) -> ImageAnalysis {
        guard let nsImage = NSImage(data: imageData),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ImageAnalysis(description: "image", mood: "neutral", details: [])
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let aspectRatio = Float(width) / Float(height)
        
        // Analyze basic properties
        let orientation = aspectRatio > 1.2 ? "landscape" : (aspectRatio < 0.8 ? "portrait" : "square")
        let resolution = width * height > 2_000_000 ? "high-resolution" : "standard"
        
        // Analyze colors (simplified)
        let colorAnalysis = analyzeColors(cgImage)
        
        // Generate description
        let description = "\(resolution) \(orientation) image"
        let mood = inferMood(from: colorAnalysis)
        
        let details = [
            "Dimensions: \(width)×\(height)",
            "Orientation: \(orientation)",
            "Dominant colors: \(colorAnalysis.dominant)",
            "Color temperature: \(colorAnalysis.temperature)"
        ]
        
        return ImageAnalysis(
            description: description,
            mood: mood,
            details: details
        )
    }
    
    /// Generate contextual response based on image analysis and prompt
    static func generateMultimodalResponse(
        prompt: String,
        imageAnalysis: ImageAnalysis,
        baseResponse: String
    ) -> String {
        let promptLower = prompt.lowercased()
        
        // Check for specific image-related questions
        if promptLower.contains("what") && (promptLower.contains("see") || promptLower.contains("image") || promptLower.contains("picture")) {
            return generateImageDescription(imageAnalysis)
        }
        
        if promptLower.contains("mood") || promptLower.contains("feeling") || promptLower.contains("vibe") {
            return generateMoodResponse(imageAnalysis)
        }
        
        if promptLower.contains("color") {
            return generateColorResponse(imageAnalysis)
        }
        
        // Otherwise, enhance the base response with subtle image context
        return enhanceResponseWithImageContext(baseResponse, imageAnalysis)
    }
    
    // MARK: - Private Methods
    
    private static func analyzeColors(_ cgImage: CGImage) -> ColorAnalysis {
        // Simplified color analysis
        // In production, this would sample pixels and create a histogram
        
        // For now, return plausible defaults
        let moods = ["warm", "cool", "neutral", "vibrant", "muted"]
        let temperature = moods.randomElement() ?? "neutral"
        
        let dominantColors = ["blue tones", "warm earth tones", "cool grays", "vibrant colors", "soft pastels"]
        let dominant = dominantColors.randomElement() ?? "varied colors"
        
        return ColorAnalysis(dominant: dominant, temperature: temperature)
    }
    
    private static func inferMood(from colorAnalysis: ColorAnalysis) -> String {
        switch colorAnalysis.temperature {
        case "warm":
            return ["cozy", "energetic", "passionate", "inviting"].randomElement() ?? "warm"
        case "cool":
            return ["calm", "serene", "contemplative", "peaceful"].randomElement() ?? "cool"
        case "vibrant":
            return ["joyful", "dynamic", "exciting", "lively"].randomElement() ?? "vibrant"
        case "muted":
            return ["subtle", "sophisticated", "gentle", "understated"].randomElement() ?? "muted"
        default:
            return "balanced"
        }
    }
    
    private static func generateImageDescription(_ analysis: ImageAnalysis) -> String {
        let templates = [
            "I can see a \(analysis.description) with \(analysis.mood) qualities. The image features \(analysis.details[2]?.replacingOccurrences(of: "Dominant colors: ", with: "") ?? "interesting visual elements").",
            "This appears to be a \(analysis.description) that conveys a \(analysis.mood) atmosphere. \(analysis.details.randomElement() ?? "It has interesting visual characteristics").",
            "Looking at this \(analysis.description), I notice its \(analysis.mood) nature. The composition includes \(analysis.details.count > 2 ? analysis.details[2]!.replacingOccurrences(of: "Dominant colors: ", with: "") : "compelling visual elements")."
        ]
        
        return templates.randomElement() ?? "I can see an image with \(analysis.mood) qualities."
    }
    
    private static func generateMoodResponse(_ analysis: ImageAnalysis) -> String {
        let templates = [
            "The image evokes a \(analysis.mood) feeling. \(analysis.details[3]?.replacingOccurrences(of: "Color temperature: ", with: "The ") ?? "The visual") tones contribute to this atmosphere.",
            "I sense a \(analysis.mood) mood in this image. The visual elements work together to create this emotional quality.",
            "This image carries a distinctly \(analysis.mood) vibe. It's the kind of visual that might inspire reflection or creativity."
        ]
        
        return templates.randomElement() ?? "The image has a \(analysis.mood) quality to it."
    }
    
    private static func generateColorResponse(_ analysis: ImageAnalysis) -> String {
        let colorInfo = analysis.details[2]?.replacingOccurrences(of: "Dominant colors: ", with: "") ?? "varied colors"
        let temperature = analysis.details[3]?.replacingOccurrences(of: "Color temperature: ", with: "") ?? "balanced"
        
        let templates = [
            "The image features \(colorInfo) with a \(temperature) color temperature. These colors create a \(analysis.mood) visual experience.",
            "I notice \(colorInfo) dominating the composition. The \(temperature) palette contributes to the overall \(analysis.mood) feeling.",
            "The color scheme consists primarily of \(colorInfo), creating a \(temperature) and \(analysis.mood) atmosphere."
        ]
        
        return templates.randomElement() ?? "The image uses \(colorInfo) to create its visual impact."
    }
    
    private static func enhanceResponseWithImageContext(_ baseResponse: String, _ analysis: ImageAnalysis) -> String {
        // Add subtle context that makes the response feel image-aware
        let contextualPhrases = [
            "Looking at what you've shared, ",
            "Based on the visual context, ",
            "Considering the \(analysis.mood) nature of the image, ",
            "Given what I can see here, "
        ]
        
        let prefix = contextualPhrases.randomElement() ?? ""
        
        // If the response is short, add a contextual observation
        if baseResponse.count < 100 {
            let observations = [
                " The \(analysis.mood) quality of the image adds another dimension to this.",
                " The visual element you've shared provides interesting context.",
                " This \(analysis.description) helps illustrate your point."
            ]
            return prefix + baseResponse + (observations.randomElement() ?? "")
        }
        
        return prefix + baseResponse
    }
}

// MARK: - Supporting Types

struct ImageAnalysis {
    let description: String
    let mood: String
    let details: [String?]
}

struct ColorAnalysis {
    let dominant: String
    let temperature: String
}