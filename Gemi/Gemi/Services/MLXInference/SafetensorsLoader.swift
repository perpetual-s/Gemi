import Foundation
import MLX

/// Loads model weights from safetensors files
@MainActor
class SafetensorsLoader {
    
    struct TensorInfo: Codable {
        let dtype: String
        let shape: [Int]
        let data_offsets: [Int]
    }
    
    struct SafetensorsHeader: Codable {
        let tensors: [String: TensorInfo]
    }
    
    /// Load weights from a safetensors file
    static func loadSafetensors(from url: URL) throws -> [String: MLXArray] {
        let data = try Data(contentsOf: url)
        
        // Check if the file is HTML (common with authentication errors)
        if let htmlCheck = String(data: data.prefix(1000), encoding: .utf8),
           (htmlCheck.contains("<!DOCTYPE") || htmlCheck.contains("<html") || 
            htmlCheck.contains("401") || htmlCheck.contains("403") || 
            htmlCheck.contains("Unauthorized")) {
            
            throw ModelError.authenticationRequired("""
                The model file appears to be an HTML error page instead of model data.
                
                This usually means:
                1. Your HuggingFace token is missing or invalid
                2. You haven't accepted the Gemma model license
                3. The model requires authentication that wasn't provided
                
                Please check your HuggingFace token and ensure you've accepted the license at:
                https://huggingface.co/google/gemma-3n-E4B-it
                """)
        }
        
        // Read header size (first 8 bytes, little-endian)
        guard data.count >= 8 else {
            throw ModelError.invalidFormat("Safetensors file too small (\(data.count) bytes). This may indicate a download error.")
        }
        
        let headerSize = data.withUnsafeBytes { bytes in
            bytes.load(as: UInt64.self)
        }
        
        // Validate header size
        guard headerSize > 0 && headerSize < data.count - 8 else {
            // Check if it might be a JSON error response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("File appears to be JSON/text instead of safetensors: \(String(jsonString.prefix(500)))")
                throw ModelError.invalidFormat("Invalid safetensors format - file appears to be text/JSON")
            }
            throw ModelError.invalidFormat("Invalid header size: \(headerSize)")
        }
        
        // Read header JSON
        let headerData = data.subdata(in: 8..<(8 + Int(headerSize)))
        
        // Try to decode header with better error handling
        let header: [String: TensorInfo]
        do {
            header = try JSONDecoder().decode([String: TensorInfo].self, from: headerData)
        } catch {
            // Print header for debugging
            if let headerString = String(data: headerData, encoding: .utf8) {
                print("Failed to decode safetensors header. Content: \(headerString)")
            }
            print("Safetensors decoding error: \(error)")
            throw ModelError.invalidFormat("Failed to decode safetensors header: \(error.localizedDescription)")
        }
        
        // Load tensors
        var tensors: [String: MLXArray] = [:]
        let tensorDataStart = 8 + Int(headerSize)
        
        for (name, info) in header {
            // Skip metadata entries
            if name == "__metadata__" { continue }
            
            let start = tensorDataStart + info.data_offsets[0]
            let end = tensorDataStart + info.data_offsets[1]
            let tensorData = data.subdata(in: start..<end)
            
            // Convert to MLXArray based on dtype
            let array = try createMLXArray(
                from: tensorData,
                dtype: info.dtype,
                shape: info.shape
            )
            
            tensors[name] = array
        }
        
        return tensors
    }
    
    /// Create MLXArray from raw data
    private static func createMLXArray(from data: Data, dtype: String, shape: [Int]) throws -> MLXArray {
        switch dtype {
        case "F32", "f32":
            return data.withUnsafeBytes { bytes in
                let pointer = bytes.bindMemory(to: Float32.self)
                let values = Array(UnsafeBufferPointer(start: pointer.baseAddress, count: bytes.count / 4))
                return MLXArray(values, shape)
            }
            
        case "F16", "f16":
            // For F16, we need to convert to F32 first
            return data.withUnsafeBytes { bytes in
                let pointer = bytes.bindMemory(to: UInt16.self)
                let uint16Values = Array(UnsafeBufferPointer(start: pointer.baseAddress, count: bytes.count / 2))
                
                // Convert F16 to F32
                let floatValues = uint16Values.map { uint16 -> Float32 in
                    // Simple F16 to F32 conversion
                    let sign = (uint16 & 0x8000) != 0 ? -1.0 : 1.0
                    let exponent = Int((uint16 & 0x7C00) >> 10) - 15
                    let mantissa = Float32(uint16 & 0x03FF) / 1024.0
                    
                    if exponent == -15 {
                        // Subnormal
                        return Float32(sign) * mantissa * pow(2.0, -14.0)
                    } else if exponent == 16 {
                        // Infinity or NaN
                        return mantissa == 0 ? Float32(sign) * .infinity : .nan
                    } else {
                        // Normal
                        return Float32(sign) * (1.0 + mantissa) * pow(2.0, Float32(exponent))
                    }
                }
                
                return MLXArray(floatValues, shape)
            }
            
        case "BF16", "bf16":
            // For BF16, convert to F32
            return data.withUnsafeBytes { bytes in
                let pointer = bytes.bindMemory(to: UInt16.self)
                let uint16Values = Array(UnsafeBufferPointer(start: pointer.baseAddress, count: bytes.count / 2))
                
                // BF16 to F32: just shift left by 16 bits
                let floatValues = uint16Values.map { uint16 -> Float32 in
                    let uint32 = UInt32(uint16) << 16
                    return Float32(bitPattern: uint32)
                }
                
                return MLXArray(floatValues, shape)
            }
            
        default:
            throw ModelError.invalidFormat("Unsupported dtype: \(dtype)")
        }
    }
    
    /// Load all safetensors files for a model
    static func loadModelWeights(from modelPath: URL, fileNames: [String]) async throws -> [String: MLXArray] {
        var allWeights: [String: MLXArray] = [:]
        
        for fileName in fileNames {
            let filePath = modelPath.appendingPathComponent(fileName)
            let weights = try loadSafetensors(from: filePath)
            
            // Merge weights
            for (key, value) in weights {
                allWeights[key] = value
            }
        }
        
        return allWeights
    }
}

extension ModelError {
    static func invalidFormat(_ message: String) -> ModelError {
        return ModelError.downloadFailed("Invalid format: \(message)")
    }
}