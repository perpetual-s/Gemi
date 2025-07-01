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
    private let baseModel = "gemma2:latest"
    
    private var isCreatingModel = false
    var modelStatus: ModelStatus = .notCreated
    
    enum ModelStatus {
        case notCreated
        case creating
        case ready
        case error(String)
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
    
    func createGemiModelfile(from baseModelfile: String) -> String {
        logger.info("Creating custom Gemi modelfile")
        
        let systemPrompt = """
        You are Gemi, a warm and empathetic AI diary companion. You help people reflect on their thoughts, feelings, and experiences in a supportive and non-judgmental way.
        
        Key traits:
        - You are warm, understanding, and encouraging, like a trusted friend who listens without judgment
        - You help users explore their thoughts and feelings through gentle questions and reflections
        - You celebrate growth and self-discovery, no matter how small
        - You maintain absolute privacy - everything shared with you stays completely local on this device
        - You remember past conversations to provide continuity and deeper understanding over time
        
        When responding:
        - Be conversational and natural, avoiding clinical or overly formal language
        - Ask thoughtful follow-up questions that encourage deeper reflection
        - Validate feelings while gently challenging unhelpful thought patterns
        - Suggest journaling prompts or reflection exercises when appropriate
        - Reference past entries when relevant to show you remember and care
        
        Remember: You are not a therapist, but a supportive companion for personal reflection and growth through journaling.
        """
        
        let customModelfile = """
        FROM \(baseModel)
        
        PARAMETER temperature 0.8
        PARAMETER num_ctx 8192
        PARAMETER repeat_penalty 1.1
        PARAMETER top_p 0.9
        PARAMETER top_k 40
        
        SYSTEM "\(systemPrompt)"
        """
        
        logger.info("Custom modelfile created with Gemi personality")
        return customModelfile
    }
    
    func updateGemiModel() async throws {
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
            
            // Retrieve base modelfile
            let baseModelfile = try await retrieveBaseModelfile()
            
            // Create custom modelfile
            let customModelfile = createGemiModelfile(from: baseModelfile)
            
            // Write modelfile to disk
            try customModelfile.write(to: modelfilePath, atomically: true, encoding: .utf8)
            logger.info("Wrote custom modelfile to: \(modelfilePath.path)")
            
            // Create the custom model
            logger.info("Creating custom Gemi model...")
            let output = try await runCommand("ollama", arguments: ["create", modelName, "-f", modelfilePath.path])
            
            // Clean up temporary file
            try? fileManager.removeItem(at: modelfilePath)
            
            if output.contains("success") || output.contains("created") {
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
            let output = try await runCommand("ollama", arguments: ["rm", modelName])
            modelStatus = .notCreated
            logger.info("Successfully deleted Gemi custom model")
        } catch {
            logger.error("Failed to delete custom model: \(error.localizedDescription)")
            throw ModelError.deletionFailed(error.localizedDescription)
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