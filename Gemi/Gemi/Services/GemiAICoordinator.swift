//
//  GemiAICoordinator.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import Foundation
import SwiftUI
import os.log

/// Central coordinator for all AI services in Gemi
@Observable
@MainActor
final class GemiAICoordinator {
    
    // MARK: - Singleton
    
    static let shared = GemiAICoordinator()
    
    // MARK: - Published Properties
    
    var aiStatus: AISystemStatus = .initializing
    var currentModel: ModelInfo?
    var isProcessing = false
    var backgroundTasksActive = 0
    var lastError: AIError?
    
    // Performance metrics
    var averageResponseTime: Double = 0
    var embeddingQueueSize = 0
    var memoryUsageMB: Double = 0
    
    // MARK: - Services
    
    private let ollamaService = OllamaService.shared
    private let modelManager = GemiModelManager()
    private let ragService = JournalRAGService.shared
    private let memoryStore = MemoryStore.shared
    private let embeddingService = EmbeddingService()
    private let conversationStore = ConversationStore.shared
    
    // MARK: - Internal State
    
    private let logger = Logger(subsystem: "com.chaehoshin.Gemi", category: "GemiAICoordinator")
    private var initializationTask: Task<Void, Never>?
    private var backgroundTaskCoordinator: BackgroundTaskCoordinator?
    private var modelHealthCheckTimer: Timer?
    private var performanceMonitor: PerformanceMonitor?
    
    // Cache
    private let embeddingCache = EmbeddingCache()
    private let contextCache = ContextCache()
    
    // Settings
    private var settings = AISettings()
    
    // MARK: - Initialization
    
    private init() {
        initializationTask = Task { @MainActor in
            await initialize()
        }
    }
    
    // MARK: - Public Methods
    
    /// Initialize the AI system
    func initialize() async {
        logger.info("Initializing Gemi AI system...")
        aiStatus = .initializing
        
        // Step 1: Check Ollama status
        let ollamaReady = await checkOllamaStatus()
        guard ollamaReady else {
            aiStatus = .offline("Ollama is not running")
            return
        }
        
        // Step 2: Ensure custom model exists
        let modelReady = await ensureCustomModel()
        if !modelReady {
            aiStatus = .degraded("Using base model")
        }
        
        // Step 3: Initialize background tasks
        await initializeBackgroundTasks()
        
        // Step 4: Start health monitoring
        startHealthMonitoring()
        
        // Step 5: Load cached data
        await loadCaches()
        
        aiStatus = modelReady ? .ready : .degraded("Custom model unavailable")
        logger.info("AI system initialization complete: \(String(describing: self.aiStatus))")
    }
    
    /// Process a chat message with full context
    func processChatMessage(_ message: String) async throws -> AsyncThrowingStream<String, Error> {
        logger.info("Processing chat message")
        
        // Check system status
        guard aiStatus == .ready || aiStatus == .degraded("Using base model") else {
            throw AIError.systemNotReady
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Build context with error handling
        let context = try await buildRobustContext(for: message)
        
        // Record start time for metrics
        let startTime = Date()
        
        // Get response stream
        let stream = ollamaService.generateChatStream(
            prompt: context,
            model: currentModel?.name ?? "gemma2:latest"
        )
        
        // Update metrics
        Task {
            await updateResponseMetrics(startTime: startTime)
        }
        
        return stream
    }
    
    /// Process a new journal entry
    func processJournalEntry(_ entry: JournalEntry) async {
        logger.info("Processing new journal entry: \(entry.id)")
        
        backgroundTasksActive += 1
        defer { backgroundTasksActive -= 1 }
        
        // Queue for embedding generation
        await backgroundTaskCoordinator?.queueEmbeddingTask(for: entry)
        
        // Extract memories if enabled
        if settings.automaticMemoryExtraction {
            await backgroundTaskCoordinator?.queueMemoryExtraction(from: entry)
        }
    }
    
    // MARK: - Model Lifecycle Management
    
    /// Compare model versions and check for updates
    nonisolated func compareModelVersions() async -> ModelComparison {
        logger.info("Comparing model versions")
        
        do {
            let models = try await ollamaService.listModels()
            
            // Find base and custom models
            let baseModel = models.first { $0.contains("gemma") && !$0.contains("gemi-custom") }
            let customModel = models.first { $0.contains("gemi-custom") }
            
            guard baseModel != nil else {
                return ModelComparison(needsUpdate: false, reason: "Base model not found")
            }
            
            if customModel == nil {
                return ModelComparison(needsUpdate: true, reason: "Custom model doesn't exist")
            }
            
            // TODO: Compare actual version numbers when available
            return ModelComparison(needsUpdate: false, reason: "Models are up to date")
            
        } catch {
            logger.error("Failed to compare models: \(error)")
            return ModelComparison(needsUpdate: false, reason: "Comparison failed")
        }
    }
    
    /// Update the custom model
    func updateCustomModel() async throws {
        logger.info("Updating custom model")
        
        aiStatus = .updating
        
        do {
            // Create new custom model
            try await modelManager.updateGemiModel()
            
            // Verify it works
            let healthy = await modelHealthCheck()
            
            if healthy {
                currentModel = ModelInfo(
                    name: "gemi-custom",
                    version: "1.0",
                    createdAt: Date()
                )
                aiStatus = .ready
                logger.info("Custom model updated successfully")
            } else {
                throw AIError.modelUpdateFailed("Health check failed")
            }
            
        } catch {
            logger.error("Failed to update custom model: \(error)")
            aiStatus = .degraded("Update failed, using base model")
            throw error
        }
    }
    
    /// Rollback to base model
    func rollbackModel() async {
        logger.info("Rolling back to base model")
        
        aiStatus = .degraded("Using base model")
        currentModel = ModelInfo(
            name: "gemma2:latest",
            version: "base",
            createdAt: Date()
        )
        
        // Delete custom model
        do {
            try await modelManager.deleteCustomModel()
        } catch {
            logger.error("Failed to delete custom model: \(error)")
        }
    }
    
    /// Check model health
    func modelHealthCheck() async -> Bool {
        logger.info("Performing model health check")
        
        do {
            let testPrompt = "Hello, this is a health check. Please respond briefly."
            let response = try await ollamaService.generateChat(
                prompt: testPrompt,
                model: currentModel?.name ?? "gemi-custom"
            )
            
            return !response.isEmpty && response.count < 1000
        } catch {
            logger.error("Model health check failed: \(error)")
            return false
        }
    }
    
    // MARK: - Background Tasks
    
    private func initializeBackgroundTasks() async {
        logger.info("Initializing background tasks")
        
        backgroundTaskCoordinator = BackgroundTaskCoordinator(
            embeddingService: embeddingService,
            memoryStore: memoryStore,
            conversationStore: conversationStore,
            settings: settings
        )
        
        await backgroundTaskCoordinator?.start()
        
        // Process any existing entries without embeddings
        Task {
            await processUnembeddedEntries()
        }
    }
    
    private func processUnembeddedEntries() async {
        logger.info("Processing unembedded entries")
        
        do {
            let entries = try await DatabaseManager.shared().fetchEntriesWithoutEmbeddings()
            logger.info("Found \(entries.count) entries without embeddings")
            
            for entry in entries {
                await backgroundTaskCoordinator?.queueEmbeddingTask(for: entry)
            }
        } catch {
            logger.error("Failed to process unembedded entries: \(error)")
        }
    }
    
    // MARK: - Error Recovery
    
    private func buildRobustContext(for message: String) async throws -> String {
        do {
            // Try full context building
            return try await ragService.enhanceMessageWithContext(message)
        } catch {
            logger.warning("Full context building failed, falling back: \(error)")
            
            // Fallback 1: Try with reduced context
            if let reducedContext = try? await buildReducedContext(for: message) {
                return reducedContext
            }
            
            // Fallback 2: Use message with inline system prompt
            return buildMinimalContext(for: message)
        }
    }
    
    private func buildReducedContext(for message: String) async throws -> String {
        // Get only most recent conversation
        let recentMessages = try await conversationStore.getRecentMessages(limit: 5)
        
        let conversationContext = recentMessages.map { msg in
            "\(msg.role == "user" ? "User" : "Gemi"): \(msg.content)"
        }.joined(separator: "\n")
        
        return """
        Recent conversation:
        \(conversationContext)
        
        Current message: \(message)
        """
    }
    
    private func buildMinimalContext(for message: String) -> String {
        return """
        You are Gemi, a warm and empathetic AI diary companion.
        Please respond helpfully to: \(message)
        """
    }
    
    // MARK: - Performance Optimization
    
    private func startHealthMonitoring() {
        modelHealthCheckTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in
                let healthy = await self.modelHealthCheck()
                if !healthy && self.aiStatus == .ready {
                    self.aiStatus = .degraded("Model health check failed")
                }
            }
        }
        
        performanceMonitor = PerformanceMonitor { [weak self] metrics in
            Task { @MainActor in
                self?.updatePerformanceMetrics(metrics)
            }
        }
    }
    
    private func updatePerformanceMetrics(_ metrics: PerformanceMetrics) {
        averageResponseTime = metrics.averageResponseTime
        memoryUsageMB = metrics.memoryUsageMB
        embeddingQueueSize = metrics.embeddingQueueSize
    }
    
    private func updateResponseMetrics(startTime: Date) async {
        let responseTime = Date().timeIntervalSince(startTime)
        await performanceMonitor?.recordResponseTime(responseTime)
    }
    
    // MARK: - Cache Management
    
    private func loadCaches() async {
        await embeddingCache.load()
        await contextCache.load()
    }
    
    // MARK: - Settings
    
    func updateSettings(_ newSettings: AISettings) {
        settings = newSettings
        Task {
            await backgroundTaskCoordinator?.updateSettings(newSettings)
        }
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "aiSettings")
        }
    }
    
    // MARK: - Helpers
    
    private func checkOllamaStatus() async -> Bool {
        await ollamaService.checkModelStatus()
        return ollamaService.currentError == nil
    }
    
    private func ensureCustomModel() async -> Bool {
        // Check if custom model exists
        if case .ready = modelManager.modelStatus {
            currentModel = ModelInfo(
                name: "gemi-custom",
                version: "1.0",
                createdAt: Date()
            )
            return true
        }
        
        // Try to create it
        do {
            try await modelManager.updateGemiModel()
            currentModel = ModelInfo(
                name: "gemi-custom",
                version: "1.0",
                createdAt: Date()
            )
            return true
        } catch {
            logger.error("Failed to create custom model: \(error)")
            return false
        }
    }
}

// MARK: - Supporting Types

enum AISystemStatus: Equatable {
    case initializing
    case ready
    case degraded(String)
    case updating
    case offline(String)
    
    var displayText: String {
        switch self {
        case .initializing: return "Initializing..."
        case .ready: return "Ready"
        case .degraded(let reason): return "Degraded: \(reason)"
        case .updating: return "Updating model..."
        case .offline(let reason): return "Offline: \(reason)"
        }
    }
    
    var isOperational: Bool {
        switch self {
        case .ready, .degraded: return true
        default: return false
        }
    }
}

struct ModelInfo {
    let name: String
    let version: String
    let createdAt: Date
}

struct ModelComparison {
    let needsUpdate: Bool
    let reason: String
}

struct AISettings: Codable, Equatable {
    var automaticMemoryExtraction = true
    var maxContextTokens = 8192
    var conversationHistoryLimit = 20
    var embeddingBatchSize = 10
    var cleanupOldConversationsDays = 30
    var cacheSize = 100 // MB
    var modelTemperature = 0.8
    var creativityLevel = 0.7
}

enum AIError: LocalizedError {
    case systemNotReady
    case modelUpdateFailed(String)
    case contextBuildFailed
    case embeddingFailed
    
    var errorDescription: String? {
        switch self {
        case .systemNotReady:
            return "AI system is not ready"
        case .modelUpdateFailed(let reason):
            return "Model update failed: \(reason)"
        case .contextBuildFailed:
            return "Failed to build context"
        case .embeddingFailed:
            return "Failed to generate embeddings"
        }
    }
}

// MARK: - Background Task Coordinator

actor BackgroundTaskCoordinator {
    private let embeddingService: EmbeddingService
    private let memoryStore: MemoryStore
    private let conversationStore: ConversationStore
    private var settings: AISettings
    
    private var embeddingQueue: [JournalEntry] = []
    private var memoryExtractionQueue: [JournalEntry] = []
    private var isProcessing = false
    
    private let logger = Logger(subsystem: "com.chaehoshin.Gemi", category: "BackgroundTaskCoordinator")
    
    init(
        embeddingService: EmbeddingService,
        memoryStore: MemoryStore,
        conversationStore: ConversationStore,
        settings: AISettings
    ) {
        self.embeddingService = embeddingService
        self.memoryStore = memoryStore
        self.conversationStore = conversationStore
        self.settings = settings
    }
    
    func start() async {
        // Start processing loop
        Task {
            await processQueues()
        }
        
        // Schedule cleanup tasks
        Task {
            await scheduleCleanupTasks()
        }
    }
    
    func queueEmbeddingTask(for entry: JournalEntry) {
        embeddingQueue.append(entry)
        Task {
            await processQueues()
        }
    }
    
    func queueMemoryExtraction(from entry: JournalEntry) {
        memoryExtractionQueue.append(entry)
        Task {
            await processQueues()
        }
    }
    
    func updateSettings(_ newSettings: AISettings) {
        settings = newSettings
    }
    
    private func processQueues() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        
        // Process embeddings
        while !embeddingQueue.isEmpty {
            let batch = Array(embeddingQueue.prefix(settings.embeddingBatchSize))
            embeddingQueue.removeFirst(min(settings.embeddingBatchSize, embeddingQueue.count))
            
            for entry in batch {
                do {
                    let embedding = try await embeddingService.generateEmbedding(for: entry.content)
                    try await embeddingService.storeEmbedding(
                        entryId: entry.id,
                        text: entry.content,
                        embedding: embedding
                    )
                } catch {
                    logger.error("Failed to process embedding for entry \(entry.id): \(error)")
                }
            }
        }
        
        // Process memory extractions
        while !memoryExtractionQueue.isEmpty {
            let entry = memoryExtractionQueue.removeFirst()
            
            do {
                // Extract key facts from journal entry
                let memories = try await extractMemories(from: entry)
                for memory in memories {
                    try await memoryStore.addMemory(memory)
                }
            } catch {
                logger.error("Failed to extract memories from entry \(entry.id): \(error)")
            }
        }
    }
    
    private func extractMemories(from entry: JournalEntry) async throws -> [Memory] {
        // Use AI to extract important facts
        let prompt = """
        Extract important personal facts, preferences, or events from this journal entry.
        Format each fact on a new line, starting with a dash.
        Only include significant information worth remembering.
        
        Journal entry:
        \(entry.content)
        """
        
        let response = try await OllamaService.shared.generateChat(
            prompt: prompt,
            model: "gemi-custom"
        )
        
        let facts = response
            .components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).starts(with: "-") }
            .map { $0.dropFirst().trimmingCharacters(in: .whitespaces) }
        
        return facts.compactMap { fact in
            guard !fact.isEmpty else { return nil }
            
            return Memory(
                content: String(fact),
                embedding: nil,
                sourceEntryId: entry.id,
                importance: 0.6,
                tags: ["journal", "extracted"],
                isPinned: false,
                memoryType: .journalFact
            )
        }
    }
    
    private func scheduleCleanupTasks() async {
        // Clean up old conversations periodically
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            Task {
                try? await self.conversationStore.cleanupOldConversations(
                    olderThan: self.settings.cleanupOldConversationsDays
                )
            }
        }
        
        // Clean up orphaned memories
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            Task {
                try? await self.embeddingService.cleanupOrphanedEmbeddings()
            }
        }
    }
}

// MARK: - Performance Monitor

actor PerformanceMonitor {
    private var responseTimes: [TimeInterval] = []
    private var maxSamples = 100
    private let updateHandler: @Sendable (PerformanceMetrics) -> Void
    
    init(updateHandler: @escaping @Sendable (PerformanceMetrics) -> Void) {
        self.updateHandler = updateHandler
        
        // Monitor memory usage
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task {
                await self.updateMetrics()
            }
        }
    }
    
    func recordResponseTime(_ time: TimeInterval) {
        responseTimes.append(time)
        if responseTimes.count > maxSamples {
            responseTimes.removeFirst()
        }
        Task {
            await updateMetrics()
        }
    }
    
    private func updateMetrics() async {
        let avgResponseTime = responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count)
        
        let memoryUsage = Double(getMemoryUsage()) / 1024 / 1024 // MB
        
        let metrics = PerformanceMetrics(
            averageResponseTime: avgResponseTime,
            memoryUsageMB: memoryUsage,
            embeddingQueueSize: 0 // TODO: Get from coordinator
        )
        
        updateHandler(metrics)
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

struct PerformanceMetrics {
    let averageResponseTime: TimeInterval
    let memoryUsageMB: Double
    let embeddingQueueSize: Int
}

// MARK: - Caches

actor EmbeddingCache {
    private var cache: [UUID: [Float]] = [:]
    private let maxSize = 100
    
    func get(_ id: UUID) -> [Float]? {
        cache[id]
    }
    
    func set(_ id: UUID, embedding: [Float]) {
        cache[id] = embedding
        
        // Evict oldest if needed
        if cache.count > maxSize {
            if let oldest = cache.keys.first {
                cache.removeValue(forKey: oldest)
            }
        }
    }
    
    func load() async {
        // Load from disk if needed
    }
}

actor ContextCache {
    private var cache: [String: String] = [:]
    private let maxSize = 50
    
    func get(_ key: String) -> String? {
        cache[key]
    }
    
    func set(_ key: String, context: String) {
        cache[key] = context
        
        // Evict oldest if needed
        if cache.count > maxSize {
            if let oldest = cache.keys.first {
                cache.removeValue(forKey: oldest)
            }
        }
    }
    
    func load() async {
        // Load from disk if needed
    }
}