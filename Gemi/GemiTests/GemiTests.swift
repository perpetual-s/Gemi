//
//  GemiTests.swift
//  GemiTests
//
//  Created by Chaeho Shin on 7/5/25.
//

import Testing
@testable import Gemi
import Foundation

struct GemiTests {
    
    // MARK: - Ollama Service Tests
    
    @Test func testOllamaChatServiceHealthCheck() async throws {
        let service = await OllamaChatService.shared
        let health = await service.health()
        
        // Health returns a simple structure
        #expect(health != nil)
    }
}
