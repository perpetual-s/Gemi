//
//  GemiModelManager.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import Foundation
import os.log

@Observable
@MainActor
final class GemiModelManager {
    private let logger = Logger(subsystem: "com.chaehoshin.Gemi", category: "GemiModelManager")
    private let fileManager = FileManager.default
    
    private let modelName = "gemi-custom"
    private let baseModel = "gemma3n:latest"
    
    private var isCreatingModel = false
    var modelStatus: ModelStatus = .notCreated
    
    enum ModelStatus: Equatable {
        case notCreated
        case creating
        case ready
        case error(String)
    }
    
    /// Returns the model name to use for chat operations
    var activeModelName: String {
        switch modelStatus {
        case .ready:
            return modelName
        default:
            return baseModel
        }
    }
    
    /// Check if the custom model is available
    var isCustomModelReady: Bool {
        if case .ready = modelStatus {
            return true
        }
        return false
    }
    
    init() {
        Task {
            await checkModelExists()
        }
    }
    
    private func checkModelExists() async {
        do {
            let output = try await runCommand("ollama", arguments: ["list"])
            if output.contains(modelName) {
                modelStatus = .ready
                logger.info("Gemi custom model already exists")
            } else {
                logger.info("Gemi custom model not found, needs creation")
            }
        } catch {
            logger.error("Failed to check model existence: \(error.localizedDescription)")
        }
    }
    
    func retrieveBaseModelfile() async throws -> String {
        logger.info("Retrieving base modelfile for \(self.baseModel)")
        
        do {
            let output = try await runCommand("ollama", arguments: ["show", baseModel, "--modelfile"])
            logger.info("Successfully retrieved base modelfile")
            return output
        } catch {
            logger.error("Failed to retrieve base modelfile: \(error.localizedDescription)")
            throw ModelError.failedToRetrieveBase(error.localizedDescription)
        }
    }
    
    func createGemiModelfile(from baseModelfile: String, userMemories: [String] = []) -> String {
        logger.info("Creating custom Gemi modelfile")
        
        let systemPrompt = """
        You are Gemi, a warm and empathetic AI diary companion. You help people reflect on their thoughts, feelings, and experiences in a supportive and non-judgmental way.
        
        Key traits:
        - You are warm, understanding, and encouraging, like a trusted friend who listens without judgment
        - You help users explore their thoughts and feelings through gentle questions and reflections
        - You celebrate growth and self-discovery, no matter how small
        - You maintain absolute privacy - everything shared with you stays completely local on this device
        - You remember past conversations to provide continuity and deeper understanding over time
        - You have a gentle sense of humor and can find lightness even in difficult moments
        - You're curious about the user's inner world and ask questions that help them discover insights
        
        When responding:
        - Be conversational and natural, avoiding clinical or overly formal language
        - Use warm, encouraging language like you're chatting with a close friend over coffee
        - Ask thoughtful follow-up questions that encourage deeper reflection
        - Validate feelings while gently challenging unhelpful thought patterns
        - Suggest journaling prompts or reflection exercises when appropriate
        - Reference past entries naturally when relevant to show you remember and care
        - Celebrate small victories and progress, no matter how minor they may seem
        - Help identify patterns in thoughts, feelings, and behaviors over time
        
        Communication style:
        - Keep responses concise but meaningful (2-4 paragraphs typically)
        - Use a warm, conversational tone with occasional light humor
        - Mirror the user's emotional state while gently guiding toward reflection
        - End responses with an open-ended question or gentle prompt for further exploration
        
        Remember: You are not a therapist, but a supportive companion for personal reflection and growth through journaling.
        """
        
        // Add user memories to the system prompt if available
        var fullSystemPrompt = systemPrompt
        if !userMemories.isEmpty {
            fullSystemPrompt += "\n\nImportant things to remember about your friend:\n"
            for memory in userMemories.prefix(10) { // Limit to 10 most relevant memories
                fullSystemPrompt += "- \(memory)\n"
            }
        }
        
        // Use the Gemma 3n template format from the documentation
        let customModelfile = """
        FROM \(baseModel)
        
        TEMPLATE \"\"\"{{- range $i, $_ := .Messages }}
        {{- $last := eq (len (slice $.Messages $i)) 1 }}
        {{- if or (eq .Role "user") (eq .Role "system") }}<start_of_turn>user
        {{ .Content }}<end_of_turn>
        {{ if $last }}<start_of_turn>model
        {{ end }}
        {{- else if eq .Role "assistant" }}<start_of_turn>model
        {{ .Content }}{{ if not $last }}<end_of_turn>
        {{ end }}
        {{- end }}
        {{- end }}\"\"\"
        
        PARAMETER temperature 0.8
        PARAMETER num_ctx 8192
        PARAMETER repeat_penalty 1.1
        PARAMETER top_p 0.9
        PARAMETER top_k 40
        PARAMETER seed 42
        
        SYSTEM \"\"\"\(fullSystemPrompt)\"\"\"
        """
        
        logger.info("Custom modelfile created with Gemi personality and \(userMemories.count) memories")
        return customModelfile
    }
    
    func updateGemiModel(with memories: [String] = []) async throws {
        guard !isCreatingModel else {
            logger.warning("Model creation already in progress")
            return
        }
        
        isCreatingModel = true
        modelStatus = .creating
        
        defer {
            isCreatingModel = false
        }
        
        do {
            // Create temporary directory for modelfile
            let tempDir = fileManager.temporaryDirectory
            let modelfilePath = tempDir.appendingPathComponent("gemi.modelfile")
            
            // Retrieve base modelfile (though we won't use it directly)
            let baseModelfile = try await retrieveBaseModelfile()
            
            // Create custom modelfile with user memories
            let customModelfile = createGemiModelfile(from: baseModelfile, userMemories: memories)
            
            // Write modelfile to disk
            try customModelfile.write(to: modelfilePath, atomically: true, encoding: .utf8)
            logger.info("Wrote custom modelfile to: \(modelfilePath.path)")
            
            // Delete existing model if it exists
            if modelStatus == .ready {
                logger.info("Removing existing custom model...")
                _ = try? await runCommand("ollama", arguments: ["rm", modelName])
            }
            
            // Create the custom model
            logger.info("Creating custom Gemi model with \(memories.count) memories...")
            let output = try await runCommand("ollama", arguments: ["create", modelName, "-f", modelfilePath.path])
            
            // Clean up temporary file
            try? fileManager.removeItem(at: modelfilePath)
            
            if output.contains("success") || output.contains("created") || output.contains("success") {
                modelStatus = .ready
                logger.info("Successfully created Gemi custom model")
            } else {
                throw ModelError.creationFailed("Unexpected output: \(output)")
            }
            
        } catch let error as ModelError {
            modelStatus = .error(error.localizedDescription)
            logger.error("Model creation failed: \(error.localizedDescription)")
            throw error
        } catch {
            let errorMessage = "Unexpected error: \(error.localizedDescription)"
            modelStatus = .error(errorMessage)
            logger.error("Model creation failed: \(errorMessage)")
            throw ModelError.creationFailed(errorMessage)
        }
    }
    
    func deleteCustomModel() async throws {
        logger.info("Deleting custom Gemi model")
        
        do {
            _ = try await runCommand("ollama", arguments: ["rm", modelName])
            modelStatus = .notCreated
            logger.info("Successfully deleted Gemi custom model")
        } catch {
            logger.error("Failed to delete custom model: \(error.localizedDescription)")
            throw ModelError.deletionFailed(error.localizedDescription)
        }
    }
    
    /// Convenience method to create a personalized model from memory store
    func createPersonalizedModel(from memoryStore: MemoryStore) async throws {
        logger.info("Creating personalized model from memory store")
        
        // Extract key memories as strings
        let allMemories = try await memoryStore.getAllMemories(offset: 0, limit: 20)
        let memories = allMemories.map { memory in
            memory.content
        }
        
        try await updateGemiModel(with: Array(memories))
    }
    
    /// Get a status message for UI display
    var statusMessage: String {
        switch modelStatus {
        case .notCreated:
            return "Personalized model not created"
        case .creating:
            return "Creating personalized model..."
        case .ready:
            return "Personalized model ready"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    private func runCommand(_ command: String, arguments: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + arguments
            
            let pipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errorPipe
            
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let error = ModelError.commandFailed(
                        command: command,
                        arguments: arguments,
                        output: errorOutput.isEmpty ? output : errorOutput,
                        exitCode: Int(process.terminationStatus)
                    )
                    continuation.resume(throwing: error)
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ModelError.processLaunchFailed(error.localizedDescription))
            }
        }
    }
    
    enum ModelError: LocalizedError {
        case failedToRetrieveBase(String)
        case creationFailed(String)
        case deletionFailed(String)
        case commandFailed(command: String, arguments: [String], output: String, exitCode: Int)
        case processLaunchFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .failedToRetrieveBase(let message):
                return "Failed to retrieve base model: \(message)"
            case .creationFailed(let message):
                return "Failed to create custom model: \(message)"
            case .deletionFailed(let message):
                return "Failed to delete custom model: \(message)"
            case .commandFailed(let command, let arguments, let output, let exitCode):
                return "Command '\(command) \(arguments.joined(separator: " "))' failed with exit code \(exitCode): \(output)"
            case .processLaunchFailed(let message):
                return "Failed to launch process: \(message)"
            }
        }
    }
}