//
//  ChatViewModel.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import Foundation
import SwiftUI

/// Represents a single message in the chat
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    let isError: Bool
    
    init(content: String, isUser: Bool, timestamp: Date = Date(), isError: Bool = false) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.isError = isError
    }
}

/// Swift 6 Observable view model for AI chat functionality
@Observable
final class ChatViewModel {
    
    // MARK: - Published Properties
    
    /// All messages in the current conversation
    var messages: [ChatMessage] = []
    
    /// Current user input
    var currentInput: String = ""
    
    /// Whether the AI is currently generating a response
    var isGenerating: Bool = false
    
    /// Current streaming response being built
    var streamingResponse: String = ""
    
    /// Whether the chat is visible
    var isChatVisible: Bool = false
    
    /// Error message to display
    var errorMessage: String?
    
    /// Suggested prompts for inspiration
    var suggestedPrompts: [String] = [
        "What should I write about today?",
        "Help me reflect on my day",
        "I'm feeling grateful for...",
        "Something interesting happened today",
        "I've been thinking about..."
    ]
    
    // MARK: - Private Properties
    
    private let ollamaService: OllamaService
    private let memoryService: MemoryService?
    private var streamTask: Task<Void, Never>?
    private let messageQueue = DispatchQueue(label: "com.gemi.chat.messages", attributes: .concurrent)
    
    // MARK: - Initialization
    
    init(ollamaService: OllamaService, memoryService: MemoryService? = nil) {
        self.ollamaService = ollamaService
        self.memoryService = memoryService
        
        // Add welcome message
        addMessage(ChatMessage(
            content: "Hello! I'm Gemi, your private diary companion. I'm here to help you reflect, write, and explore your thoughts. Everything we discuss stays on your device. How can I help you today?",
            isUser: false
        ))
    }
    
    deinit {
        streamTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Send a message to the AI
    @MainActor
    func sendMessage() async {
        let userMessage = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }
        
        // Check Ollama status before sending
        let isConnected = await ollamaService.checkOllamaStatus()
        if !isConnected {
            addMessage(ChatMessage(content: userMessage, isUser: true))
            currentInput = ""
            addMessage(ChatMessage(
                content: "I'm sorry, I can't respond right now. The Ollama service isn't running. Please start it by opening Terminal and running 'ollama serve', then try again.",
                isUser: false,
                isError: true
            ))
            return
        }
        
        // Add user message
        addMessage(ChatMessage(content: userMessage, isUser: true))
        currentInput = ""
        errorMessage = nil
        
        // Cancel any existing stream
        streamTask?.cancel()
        streamTask = nil
        
        // Start generating response
        isGenerating = true
        streamingResponse = ""
        
        // Add placeholder for AI response
        let responseMessage = ChatMessage(content: "", isUser: false)
        let responseId = responseMessage.id
        addMessage(responseMessage)
        
        // Get relevant memories if available
        let memories = await Task {
            await fetchRelevantMemories(for: userMessage)
        }.value
        let prompt = ollamaService.createPromptWithMemory(userMessage: userMessage, memories: memories)
        
        // Create streaming task
        streamTask = Task {
            do {
                for try await chunk in ollamaService.chatCompletion(prompt: prompt) {
                    guard !Task.isCancelled else { break }
                    
                    await MainActor.run {
                        streamingResponse += chunk
                        updateStreamingMessage(id: responseId, content: streamingResponse)
                    }
                }
            } catch {
                await MainActor.run {
                    updateStreamingMessage(
                        id: responseId,
                        content: "I'm sorry, I encountered an error: \(error.localizedDescription)",
                        isError: true
                    )
                    errorMessage = error.localizedDescription
                }
            }
            
            await MainActor.run {
                isGenerating = false
                streamingResponse = ""
                streamTask = nil
                
                // Store this conversation in memory if service is available
                if let memoryService = memoryService {
                    let finalResponse = getFinalMessageContent(id: responseId)
                    Task {
                        await memoryService.storeConversationMemory(
                            userMessage: userMessage,
                            aiResponse: finalResponse
                        )
                    }
                }
            }
        }
    }
    
    /// Use a suggested prompt
    @MainActor
    func useSuggestedPrompt(_ prompt: String) {
        currentInput = prompt
    }
    
    /// Clear the current conversation
    @MainActor
    func clearConversation() {
        clearAllMessages()
        addMessage(ChatMessage(
            content: "Let's start fresh. What would you like to talk about?",
            isUser: false
        ))
        streamingResponse = ""
        errorMessage = nil
        ollamaService.clearContext()
    }
    
    /// Toggle chat visibility
    @MainActor
    func toggleChat() {
        isChatVisible.toggle()
    }
    
    /// Cancel current generation
    @MainActor
    func cancelGeneration() {
        streamTask?.cancel()
        streamTask = nil
        isGenerating = false
        streamingResponse = ""
    }
    
    // MARK: - Private Methods
    
    /// Thread-safe method to add a message
    private func addMessage(_ message: ChatMessage) {
        messageQueue.async(flags: .barrier) { [weak self] in
            Task { @MainActor in
                self?.messages.append(message)
            }
        }
    }
    
    /// Thread-safe method to update a streaming message
    @MainActor
    private func updateStreamingMessage(id: UUID, content: String, isError: Bool = false) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index] = ChatMessage(
                content: content,
                isUser: false,
                isError: isError
            )
        }
    }
    
    /// Thread-safe method to get final message content
    @MainActor
    private func getFinalMessageContent(id: UUID) -> String {
        messages.first(where: { $0.id == id })?.content ?? ""
    }
    
    /// Thread-safe method to clear all messages
    private func clearAllMessages() {
        messageQueue.async(flags: .barrier) { [weak self] in
            Task { @MainActor in
                self?.messages.removeAll()
            }
        }
    }
    
    /// Check Ollama connection and show appropriate message
    @MainActor
    private func checkOllamaConnection() async {
        let isConnected = await ollamaService.checkOllamaStatus()
        
        if !isConnected {
            // Add an error message if Ollama is not running
            addMessage(ChatMessage(
                content: "⚠️ I'm having trouble connecting to the Ollama service. Please make sure Ollama is running on your Mac. You can start it by opening Terminal and running 'ollama serve'.",
                isUser: false,
                isError: true
            ))
        }
    }
    
    private func fetchRelevantMemories(for query: String) async -> [String] {
        guard let memoryService = memoryService else { return [] }
        
        do {
            let memories = try await memoryService.retrieveRelevantMemories(for: query, limit: 5)
            return memories.map { $0.content }
        } catch {
            // Log error but don't fail the chat
            print("Failed to fetch memories: \(error)")
            return []
        }
    }
    
    /// Get formatted time for a message
    func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Check if this is the last message
    func isLastMessage(_ message: ChatMessage) -> Bool {
        messages.last?.id == message.id
    }
    
    /// Get typing indicator visibility
    var showTypingIndicator: Bool {
        isGenerating && !streamingResponse.isEmpty
    }
    
    /// Clear all chat messages and reset to welcome state
    @MainActor
    func clearChat() {
        // Cancel any ongoing generation
        streamTask?.cancel()
        streamTask = nil
        
        // Clear messages
        clearAllMessages()
        
        // Reset state
        currentInput = ""
        isGenerating = false
        streamingResponse = ""
        errorMessage = nil
        
        // Add welcome message back
        addMessage(ChatMessage(
            content: "Hello! I'm Gemi, your private diary companion. I'm here to help you reflect, write, and explore your thoughts. Everything we discuss stays on your device. How can I help you today?",
            isUser: false
        ))
    }
}

// MARK: - Memory Service Implementation

/// Concrete implementation of memory service using MemoryStore
final class ConcreteMemoryService: MemoryService {
    private let memoryStore: MemoryStore
    
    init(memoryStore: MemoryStore) {
        self.memoryStore = memoryStore
    }
    
    func retrieveRelevantMemories(for query: String, limit: Int) async throws -> [Memory] {
        return try await memoryStore.searchMemories(query: query, limit: limit)
    }
    
    func storeConversationMemory(userMessage: String, aiResponse: String) async {
        do {
            try await memoryStore.addMemoryFromConversation(userMessage: userMessage, aiResponse: aiResponse)
        } catch {
            print("Failed to store conversation memory: \(error)")
        }
    }
}

// MARK: - Memory Service Protocol

/// Protocol for memory service integration
protocol MemoryService: Sendable {
    func retrieveRelevantMemories(for query: String, limit: Int) async throws -> [Memory]
    func storeConversationMemory(userMessage: String, aiResponse: String) async
}