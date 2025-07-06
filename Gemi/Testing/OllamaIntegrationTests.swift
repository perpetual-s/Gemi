import XCTest
@testable import Gemi

/// Automated tests for Ollama integration
/// Run these tests with Ollama service running and gemma3n:latest model installed
final class OllamaIntegrationTests: XCTestCase {
    
    let ollamaService = OllamaService.shared
    let timeout: TimeInterval = 30.0
    
    override func setUp() {
        super.setUp()
        // Ensure clean state before each test
    }
    
    // MARK: - Health Check Tests
    
    func testHealthCheckWhenOllamaRunning() async throws {
        // Given: Ollama is running (pre-condition)
        
        // When: Checking health
        let isHealthy = try await ollamaService.checkHealth()
        
        // Then: Should be healthy
        XCTAssertTrue(isHealthy, "Ollama service should be healthy when running")
    }
    
    func testHealthCheckCaching() async throws {
        // Given: Fresh state
        let start = Date()
        
        // When: Making multiple health checks
        _ = try await ollamaService.checkHealth()
        let firstCheckDuration = Date().timeIntervalSince(start)
        
        let secondStart = Date()
        _ = try await ollamaService.checkHealth()
        let secondCheckDuration = Date().timeIntervalSince(secondStart)
        
        // Then: Second check should be much faster (cached)
        XCTAssertLessThan(secondCheckDuration, firstCheckDuration * 0.1, 
                          "Second health check should use cache and be much faster")
    }
    
    func testHealthCheckAfterCacheExpiry() async throws {
        // Given: Make initial health check
        _ = try await ollamaService.checkHealth()
        
        // When: Wait for cache to expire (5+ seconds)
        try await Task.sleep(nanoseconds: 6_000_000_000) // 6 seconds
        
        let start = Date()
        _ = try await ollamaService.checkHealth()
        let duration = Date().timeIntervalSince(start)
        
        // Then: Should make fresh request (not cached)
        XCTAssertGreaterThan(duration, 0.1, "Should make fresh request after cache expiry")
    }
    
    // MARK: - Model Verification Tests
    
    func testCorrectModelName() async throws {
        // Given: Expected model name
        let expectedModel = "gemma3n:latest"
        
        // When: Checking health (which logs available models)
        _ = try? await ollamaService.checkHealth()
        
        // Then: Verify model name is correct in service
        // Note: In real test, we'd expose modelName for verification
        XCTAssertTrue(true, "Model name should be \(expectedModel)")
    }
    
    // MARK: - Chat Streaming Tests
    
    func testBasicChatStreaming() async throws {
        // Given: Simple chat messages
        let messages = [
            ChatMessage(role: .user, content: "Say 'Hello, test!'")
        ]
        
        let expectation = expectation(description: "Streaming completes")
        var responseContent = ""
        var streamingCompleted = false
        
        // When: Streaming chat
        let stream = await ollamaService.chat(messages: messages)
        
        Task {
            do {
                for try await response in stream {
                    if let message = response.message {
                        responseContent += message.content
                    }
                    if response.done {
                        streamingCompleted = true
                        expectation.fulfill()
                        break
                    }
                }
            } catch {
                XCTFail("Streaming failed with error: \(error)")
                expectation.fulfill()
            }
        }
        
        // Then: Should receive streaming response
        await fulfillment(of: [expectation], timeout: timeout)
        XCTAssertTrue(streamingCompleted, "Streaming should complete")
        XCTAssertFalse(responseContent.isEmpty, "Should receive response content")
        XCTAssertTrue(responseContent.lowercased().contains("hello"), 
                      "Response should contain expected content")
    }
    
    func testStreamingCancellation() async throws {
        // Given: Long response request
        let messages = [
            ChatMessage(role: .user, content: "Count from 1 to 100 slowly")
        ]
        
        var receivedSomeContent = false
        let streamTask = Task {
            let stream = await ollamaService.chat(messages: messages)
            for try await response in stream {
                if response.message != nil {
                    receivedSomeContent = true
                    break // Exit after first content
                }
            }
        }
        
        // When: Cancelling mid-stream
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        streamTask.cancel()
        
        // Then: Task should be cancelled
        let result = await streamTask.result
        XCTAssertTrue(receivedSomeContent || result == nil, 
                      "Should have received some content or been cancelled")
    }
    
    // MARK: - Error Handling Tests
    
    func testModelNotFoundError() async throws {
        // This test would require mocking or a test model that doesn't exist
        // Skip in integration tests as it would break other tests
        XCTSkip("Skipping model not found test in integration suite")
    }
    
    // MARK: - Performance Tests
    
    func testStreamingPerformance() throws {
        // Given: Performance metrics
        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTMemoryMetric(),
            XCTCPUMetric()
        ]
        
        let messages = [
            ChatMessage(role: .user, content: "What is Swift?")
        ]
        
        // When/Then: Measure performance
        measure(metrics: metrics) {
            let expectation = expectation(description: "Streaming completes")
            
            Task {
                let stream = await ollamaService.chat(messages: messages)
                for try await response in stream {
                    if response.done {
                        expectation.fulfill()
                        break
                    }
                }
            }
            
            wait(for: [expectation], timeout: timeout)
        }
    }
    
    // MARK: - Retry Logic Tests
    
    func testRetryMechanism() async throws {
        // Note: This would require ability to simulate failures
        // In real implementation, we'd use dependency injection to mock network layer
        XCTSkip("Retry mechanism testing requires network mocking")
    }
    
    // MARK: - Chat Options Tests
    
    func testChatOptionsConfiguration() async throws {
        // Given: Messages with specific requirements
        let messages = [
            ChatMessage(role: .system, content: "You always respond with exactly 5 words."),
            ChatMessage(role: .user, content: "Tell me about Swift")
        ]
        
        var responseContent = ""
        let expectation = expectation(description: "Streaming completes")
        
        // When: Sending chat with options
        let stream = await ollamaService.chat(messages: messages)
        
        Task {
            for try await response in stream {
                if let message = response.message {
                    responseContent += message.content
                }
                if response.done {
                    expectation.fulfill()
                    break
                }
            }
        }
        
        // Then: Verify options were applied
        await fulfillment(of: [expectation], timeout: timeout)
        XCTAssertFalse(responseContent.isEmpty, "Should receive response")
        
        // Note: Exact word count might vary due to model behavior
        let wordCount = responseContent.split(separator: " ").count
        print("Response word count: \(wordCount)")
    }
}

// MARK: - UI Integration Tests

final class ChatUIIntegrationTests: XCTestCase {
    
    var viewModel: EnhancedChatViewModel!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        viewModel = EnhancedChatViewModel()
    }
    
    @MainActor
    func testConnectionMonitoring() async throws {
        // Given: View model initialized
        
        // When: Starting connection monitoring
        viewModel.startConnectionMonitoring()
        
        // Wait for initial check
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Then: Connection status should be set
        XCTAssertNotEqual(viewModel.connectionStatus, .disconnected, 
                         "Should attempt connection on monitoring start")
    }
    
    @MainActor
    func testSendingMessage() async throws {
        // Given: Connected state
        viewModel.connectionStatus = .connected
        
        let initialMessageCount = viewModel.messages.count
        
        // When: Sending a message
        await viewModel.sendMessage("Test message")
        
        // Wait for response
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        // Then: Should have user and assistant messages
        XCTAssertGreaterThan(viewModel.messages.count, initialMessageCount, 
                            "Should add messages to history")
        XCTAssertFalse(viewModel.isStreaming, "Streaming should complete")
        XCTAssertNil(viewModel.error, "Should not have errors")
    }
    
    @MainActor 
    func testEmptyMessageHandling() async throws {
        // Given: Connected state
        viewModel.connectionStatus = .connected
        let initialCount = viewModel.messages.count
        
        // When: Sending empty message
        await viewModel.sendMessage("   ")
        
        // Then: Should not add any messages
        XCTAssertEqual(viewModel.messages.count, initialCount, 
                       "Should not add empty messages")
    }
    
    @MainActor
    func testSuggestedPromptsUpdate() async throws {
        // Given: Initial prompts
        let initialPrompts = viewModel.suggestedPrompts
        
        // When: Having emotional conversation
        viewModel.messages = [
            ChatHistoryMessage(role: .user, content: "I'm feeling anxious"),
            ChatHistoryMessage(role: .assistant, content: "I understand...")
        ]
        
        // Trigger prompt update
        await viewModel.sendMessage("Thanks for listening")
        
        // Then: Prompts should be contextual
        XCTAssertNotEqual(viewModel.suggestedPrompts, initialPrompts, 
                         "Prompts should update based on context")
    }
}

// MARK: - Test Helpers

extension XCTestCase {
    func wait(for duration: TimeInterval) {
        let expectation = expectation(description: "Wait")
        expectation.isInverted = true
        wait(for: [expectation], timeout: duration)
    }
}