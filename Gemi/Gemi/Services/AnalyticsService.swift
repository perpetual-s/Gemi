import Foundation
import SwiftUI

@MainActor
final class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()
    
    @Published var sessionStartTime: Date?
    @Published var currentSessionDuration: TimeInterval = 0
    @Published var sessions: [WritingSession] = []
    
    private var sessionTimer: Timer?
    
    private init() {
        loadSessions()
    }
    
    // MARK: - Session Tracking
    
    func startSession() {
        sessionStartTime = Date()
        
        // Update duration every second
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if let start = self?.sessionStartTime {
                    self?.currentSessionDuration = Date().timeIntervalSince(start)
                }
            }
        }
    }
    
    func endSession() {
        guard let start = sessionStartTime else { return }
        
        let duration = Date().timeIntervalSince(start)
        let session = WritingSession(
            id: UUID(),
            startTime: start,
            duration: duration,
            wordsWritten: 0 // Will be updated when entry is saved
        )
        
        sessions.append(session)
        saveSessions()
        
        // Reset
        sessionStartTime = nil
        currentSessionDuration = 0
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
    
    func updateSessionWithWords(_ wordCount: Int) {
        guard let start = sessionStartTime else { return }
        
        // Find or create session for today
        if let index = sessions.lastIndex(where: { Calendar.current.isDate($0.startTime, inSameDayAs: start) }) {
            sessions[index].wordsWritten += wordCount
        }
        
        saveSessions()
    }
    
    // MARK: - Analytics Calculations
    
    func calculateTrend(for entries: [JournalEntry], timeRange: InsightsView.TimeRange, previousTimeRange: InsightsView.TimeRange? = nil) -> Double? {
        let calendar = Calendar.current
        let now = Date()
        
        // Current period entries
        let currentEntries = filterEntries(entries, for: timeRange, from: now)
        let currentCount = currentEntries.count
        
        guard currentCount > 0 else { return nil }
        
        // Calculate previous period based on time range
        let previousDate: Date
        switch timeRange {
        case .week:
            previousDate = calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            previousDate = calendar.date(byAdding: .month, value: -1, to: now)!
        case .year:
            previousDate = calendar.date(byAdding: .year, value: -1, to: now)!
        case .allTime:
            return nil // No trend for all time
        }
        
        // Previous period entries
        let previousEntries = filterEntries(entries, for: timeRange, from: previousDate)
        let previousCount = previousEntries.count
        
        if previousCount == 0 {
            return currentCount > 0 ? 100.0 : nil
        }
        
        let percentageChange = ((Double(currentCount) - Double(previousCount)) / Double(previousCount)) * 100
        return percentageChange
    }
    
    func calculateWordsTrend(for entries: [JournalEntry], timeRange: InsightsView.TimeRange) -> Double? {
        let calendar = Calendar.current
        let now = Date()
        
        // Current period words
        let currentEntries = filterEntries(entries, for: timeRange, from: now)
        let currentWords = currentEntries.reduce(0) { $0 + $1.wordCount }
        
        guard currentWords > 0 else { return nil }
        
        // Previous period
        let previousDate: Date
        switch timeRange {
        case .week:
            previousDate = calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            previousDate = calendar.date(byAdding: .month, value: -1, to: now)!
        case .year:
            previousDate = calendar.date(byAdding: .year, value: -1, to: now)!
        case .allTime:
            return nil
        }
        
        let previousEntries = filterEntries(entries, for: timeRange, from: previousDate)
        let previousWords = previousEntries.reduce(0) { $0 + $1.wordCount }
        
        if previousWords == 0 {
            return currentWords > 0 ? 100.0 : nil
        }
        
        let percentageChange = ((Double(currentWords) - Double(previousWords)) / Double(previousWords)) * 100
        return percentageChange
    }
    
    func averageSessionDuration(for timeRange: InsightsView.TimeRange) -> TimeInterval? {
        let filteredSessions = filterSessions(for: timeRange)
        guard !filteredSessions.isEmpty else { return nil }
        
        let totalDuration = filteredSessions.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(filteredSessions.count)
    }
    
    func totalSessionsCount(for timeRange: InsightsView.TimeRange) -> Int {
        filterSessions(for: timeRange).count
    }
    
    // MARK: - Helper Methods
    
    private func filterEntries(_ entries: [JournalEntry], for timeRange: InsightsView.TimeRange, from date: Date) -> [JournalEntry] {
        let calendar = Calendar.current
        
        switch timeRange {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: date)!
            return entries.filter { $0.createdAt >= weekAgo && $0.createdAt <= date }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: date)!
            return entries.filter { $0.createdAt >= monthAgo && $0.createdAt <= date }
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: date)!
            return entries.filter { $0.createdAt >= yearAgo && $0.createdAt <= date }
        case .allTime:
            return entries.filter { $0.createdAt <= date }
        }
    }
    
    private func filterSessions(for timeRange: InsightsView.TimeRange) -> [WritingSession] {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeRange {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return sessions.filter { $0.startTime >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return sessions.filter { $0.startTime >= monthAgo }
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            return sessions.filter { $0.startTime >= yearAgo }
        case .allTime:
            return sessions
        }
    }
    
    // MARK: - Persistence
    
    private var sessionsURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Gemi")
            .appendingPathComponent("analytics_sessions.json")
    }
    
    private func saveSessions() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(sessions)
            
            // Create directory if needed
            let directory = sessionsURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            try data.write(to: sessionsURL)
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
    
    private func loadSessions() {
        do {
            let data = try Data(contentsOf: sessionsURL)
            let decoder = JSONDecoder()
            sessions = try decoder.decode([WritingSession].self, from: data)
        } catch {
            // File doesn't exist or couldn't be decoded, start fresh
            sessions = []
        }
    }
}

// MARK: - Models

struct WritingSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let duration: TimeInterval
    var wordsWritten: Int
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(seconds) sec"
        }
    }
}

// MARK: - Time Formatting Helpers

extension AnalyticsService {
    static func formatSessionDuration(_ duration: TimeInterval?) -> String {
        guard let duration = duration else { return "No data" }
        
        let minutes = Int(duration) / 60
        
        if minutes < 1 {
            return "< 1 min"
        } else if minutes <= 5 {
            return "1-5 min"
        } else if minutes <= 10 {
            return "5-10 min"
        } else if minutes <= 20 {
            return "10-20 min"
        } else if minutes <= 30 {
            return "20-30 min"
        } else if minutes <= 60 {
            return "30-60 min"
        } else {
            return "> 1 hour"
        }
    }
    
    static func formatTrend(_ trend: Double?) -> String? {
        guard let trend = trend else { return nil }
        
        let rounded = Int(trend.rounded())
        if rounded > 0 {
            return "+\(rounded)%"
        } else if rounded < 0 {
            return "\(rounded)%"
        } else {
            return "0%"
        }
    }
}