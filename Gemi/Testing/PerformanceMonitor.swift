import Foundation
import os.log

/// Performance monitoring utility for Ollama integration testing
final class PerformanceMonitor {
    
    static let shared = PerformanceMonitor()
    private let logger = Logger(subsystem: "com.gemi.performance", category: "OllamaIntegration")
    
    private var metrics: [String: [TimeInterval]] = [:]
    private var startTimes: [String: Date] = [:]
    
    // MARK: - Timing Methods
    
    /// Start timing an operation
    func startTiming(_ operation: String) {
        startTimes[operation] = Date()
        logger.debug("Started timing: \(operation)")
    }
    
    /// End timing an operation and record the duration
    func endTiming(_ operation: String) {
        guard let startTime = startTimes[operation] else {
            logger.error("No start time found for operation: \(operation)")
            return
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        if metrics[operation] == nil {
            metrics[operation] = []
        }
        metrics[operation]?.append(duration)
        
        startTimes.removeValue(forKey: operation)
        logger.debug("\(operation) completed in \(String(format: "%.3f", duration))s")
    }
    
    // MARK: - Memory Monitoring
    
    /// Get current memory usage in MB
    func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let memoryMB = Double(info.resident_size) / 1024 / 1024
            return memoryMB
        }
        
        return 0
    }
    
    // MARK: - Metrics Reporting
    
    /// Generate performance report
    func generateReport() -> PerformanceReport {
        var report = PerformanceReport()
        
        // Calculate timing statistics
        for (operation, durations) in metrics {
            guard !durations.isEmpty else { continue }
            
            let stats = TimingStats(
                operation: operation,
                min: durations.min() ?? 0,
                max: durations.max() ?? 0,
                average: durations.reduce(0, +) / Double(durations.count),
                count: durations.count
            )
            report.timingStats.append(stats)
        }
        
        // Current memory usage
        report.currentMemoryMB = getCurrentMemoryUsage()
        
        return report
    }
    
    /// Reset all metrics
    func reset() {
        metrics.removeAll()
        startTimes.removeAll()
        logger.info("Performance metrics reset")
    }
    
    // MARK: - Ollama Specific Metrics
    
    /// Monitor a streaming response
    func monitorStreamingResponse(messageLength: Int) async -> StreamingMetrics {
        let startTime = Date()
        var firstTokenTime: Date?
        var tokenCount = 0
        var totalContent = ""
        
        startTiming("streaming_response")
        
        return StreamingMetrics(
            messageLength: messageLength,
            startTime: startTime,
            endTime: Date(),
            firstTokenLatency: 0,
            tokensPerSecond: 0,
            totalTokens: tokenCount
        )
    }
}

// MARK: - Data Models

struct PerformanceReport {
    var timingStats: [TimingStats] = []
    var currentMemoryMB: Double = 0
    var timestamp = Date()
    
    var summary: String {
        var output = "Performance Report - \(timestamp.formatted())\n"
        output += "=====================================\n\n"
        
        output += "Timing Statistics:\n"
        for stat in timingStats {
            output += "  \(stat.operation):\n"
            output += "    - Average: \(String(format: "%.3f", stat.average))s\n"
            output += "    - Min: \(String(format: "%.3f", stat.min))s\n"
            output += "    - Max: \(String(format: "%.3f", stat.max))s\n"
            output += "    - Count: \(stat.count)\n\n"
        }
        
        output += "Memory Usage: \(String(format: "%.1f", currentMemoryMB)) MB\n"
        
        return output
    }
}

struct TimingStats {
    let operation: String
    let min: TimeInterval
    let max: TimeInterval
    let average: TimeInterval
    let count: Int
}

struct StreamingMetrics {
    let messageLength: Int
    let startTime: Date
    let endTime: Date
    let firstTokenLatency: TimeInterval
    let tokensPerSecond: Double
    let totalTokens: Int
    
    var totalDuration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

// MARK: - Test Helpers

extension PerformanceMonitor {
    
    /// Benchmark a specific operation
    func benchmark<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        startTiming(operation)
        defer { endTiming(operation) }
        return try await block()
    }
    
    /// Monitor memory during an operation
    func monitorMemory<T>(_ operation: String, block: () async throws -> T) async rethrows -> (result: T, memoryDelta: Double) {
        let startMemory = getCurrentMemoryUsage()
        let result = try await block()
        let endMemory = getCurrentMemoryUsage()
        
        let delta = endMemory - startMemory
        logger.info("\(operation) memory delta: \(String(format: "%.1f", delta)) MB")
        
        return (result, delta)
    }
}

// MARK: - Usage Example

/*
 // In your tests:
 
 let monitor = PerformanceMonitor.shared
 
 // Time an operation
 monitor.startTiming("ollama_health_check")
 let isHealthy = try await ollamaService.checkHealth()
 monitor.endTiming("ollama_health_check")
 
 // Or use benchmark helper
 let response = try await monitor.benchmark("chat_request") {
     return try await ollamaService.chat(messages: messages)
 }
 
 // Monitor memory
 let (result, memoryDelta) = try await monitor.monitorMemory("large_conversation") {
     // Run conversation test
 }
 
 // Generate report
 let report = monitor.generateReport()
 print(report.summary)
 */