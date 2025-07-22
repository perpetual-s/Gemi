import Foundation
import CoreGraphics
import ImageIO

/// Helper for testing Chat with Gemi feature
@MainActor
final class ChatTestHelper {
    
    /// Test basic text generation
    static func testTextGeneration() async {
        print("\n🧪 Testing Text Generation...")
        
        let chatService = OllamaChatService.shared
        
        // Check if model is loaded
        let health = await chatService.health()
        print("Model loaded: \(health.modelLoaded)")
        
        if !health.modelLoaded {
            print("⏳ Loading model...")
            do {
                try await chatService.loadModel()
                print("✅ Model loaded successfully")
            } catch {
                print("❌ Failed to load model: \(error)")
                return
            }
        }
        
        // Test text generation
        let request = OllamaChatService.ChatRequest(
            messages: [
                OllamaChatService.ChatMessage(
                    role: "user",
                    content: "Hello, Gemi! How are you today?",
                    images: nil
                )
            ],
            model: "gemma-3n",
            stream: false,
            options: OllamaChatService.ChatOptions(
                temperature: 0.7,
                maxTokens: 100,
                topK: 40,
                topP: 0.95
            )
        )
        
        do {
            for try await response in try await chatService.chat(request) {
                if response.done {
                    print("✅ Response: \(response.message.content)")
                    print("   Tokens: \(response.evalCount ?? 0)")
                    print("   Time: \(Double(response.totalDuration ?? 0) / 1_000_000_000)s")
                }
            }
        } catch {
            print("❌ Generation failed: \(error)")
        }
    }
    
    /// Test multimodal generation with image
    static func testMultimodalGeneration() async {
        print("\n🧪 Testing Multimodal Generation...")
        
        // Create a simple test image
        guard let testImageData = createTestImage() else {
            print("❌ Failed to create test image")
            return
        }
        
        let base64Image = testImageData.base64EncodedString()
        
        let chatService = OllamaChatService.shared
        
        let request = OllamaChatService.ChatRequest(
            messages: [
                OllamaChatService.ChatMessage(
                    role: "user",
                    content: "What do you see in this image?",
                    images: ["data:image/png;base64,\(base64Image)"]
                )
            ],
            model: "gemma-3n",
            stream: false,
            options: OllamaChatService.ChatOptions(
                temperature: 0.7,
                maxTokens: 150,
                topK: 40,
                topP: 0.95
            )
        )
        
        do {
            for try await response in try await chatService.chat(request) {
                if response.done {
                    print("✅ Multimodal Response: \(response.message.content)")
                }
            }
        } catch {
            print("❌ Multimodal generation failed: \(error)")
        }
    }
    
    /// Create a simple test image
    private static func createTestImage() -> Data? {
        let size = CGSize(width: 200, height: 200)
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // Draw a gradient
        let colors = [
            CGColor(red: 0.2, green: 0.3, blue: 0.8, alpha: 1.0),
            CGColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1.0)
        ] as CFArray
        
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: nil
        ) else { return nil }
        
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )
        
        // Create image from context
        guard let cgImage = context.makeImage(),
              let data = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                  data,
                  "public.png" as CFString,
                  1,
                  nil
              ) else { return nil }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
        
        return data as Data
    }
    
    /// Run all tests
    static func runAllTests() async {
        print("🚀 Starting Chat with Gemi Tests...")
        
        await testTextGeneration()
        await testMultimodalGeneration()
        
        print("\n✅ All tests completed!")
    }
}