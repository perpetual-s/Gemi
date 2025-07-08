//
//  HomeView.swift
//  Gemi
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var journalStore: JournalStore
    @Binding var selectedEntry: JournalEntry?
    let onNewEntry: () -> Void
    let onEditEntry: (JournalEntry) -> Void
    
    @State private var showAllEntries = false
    
    private var recentEntries: [JournalEntry] {
        Array(journalStore.entries.prefix(5))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Welcome Card - Always visible
                WelcomeCard(onNewEntry: onNewEntry, journalStore: journalStore)
                    .padding(.horizontal)
                
                // Recent Entries Section
                if !journalStore.entries.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        // Section Header
                        HStack {
                            Text("Recent Entries")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button(action: { showAllEntries = true }) {
                                HStack(spacing: 4) {
                                    Text("See All")
                                        .font(.subheadline)
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                }
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        
                        // Recent Entry Cards
                        VStack(spacing: 12) {
                            ForEach(recentEntries) { entry in
                                CompactEntryCard(
                                    entry: entry,
                                    onSelect: { selectedEntry = entry },
                                    onEdit: { onEditEntry(entry) }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Quick Stats Section
                if journalStore.entries.count > 10 {
                    InsightsSummaryCard(entries: journalStore.entries)
                        .padding(.horizontal)
                }
                
                // Bottom padding
                Color.clear.frame(height: 20)
            }
            .padding(.vertical)
        }
        .background(Theme.Colors.windowBackground)
        .sheet(isPresented: $showAllEntries) {
            NavigationStack {
                EnhancedTimelineView(
                    journalStore: journalStore,
                    selectedEntry: $selectedEntry,
                    onNewEntry: onNewEntry,
                    onEditEntry: onEditEntry
                )
                .navigationTitle("All Entries")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            showAllEntries = false
                        }
                    }
                }
            }
        }
    }
}

/// Compact entry card for home view
struct CompactEntryCard: View {
    let entry: JournalEntry
    let onSelect: () -> Void
    let onEdit: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Mood indicator
                if let mood = entry.mood {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: moodColors(for: mood),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(entry.title)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(entry.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Quick actions on hover
                if isHovered {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.cornerRadius)
            .shadow(color: isHovered ? Color.black.opacity(0.1) : Color.black.opacity(0.05), 
                   radius: isHovered ? 8 : 4, 
                   x: 0, 
                   y: isHovered ? 4 : 2)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func moodColors(for mood: Mood) -> [Color] {
        switch mood {
        case .happy: return [.yellow.opacity(0.6), .orange.opacity(0.4)]
        case .sad: return [.blue.opacity(0.6), .indigo.opacity(0.4)]
        case .neutral: return [.gray.opacity(0.4), .gray.opacity(0.2)]
        case .excited: return [.pink.opacity(0.6), .purple.opacity(0.4)]
        case .anxious: return [.orange.opacity(0.6), .red.opacity(0.4)]
        case .peaceful: return [.green.opacity(0.6), .teal.opacity(0.4)]
        case .grateful: return [.purple.opacity(0.6), .pink.opacity(0.4)]
        case .accomplished: return [.blue.opacity(0.6), .cyan.opacity(0.4)]
        case .frustrated: return [.red.opacity(0.6), .orange.opacity(0.4)]
        }
    }
}

/// Quick insights card for home view
struct InsightsSummaryCard: View {
    let entries: [JournalEntry]
    
    private var averageMood: String {
        let moodValues = entries.compactMap { entry -> Int? in
            guard let mood = entry.mood else { return nil }
            switch mood {
            case .excited, .accomplished: return 5
            case .happy, .grateful: return 4
            case .peaceful, .neutral: return 3
            case .anxious, .frustrated: return 2
            case .sad: return 1
            }
        }
        
        guard !moodValues.isEmpty else { return "—" }
        let average = Double(moodValues.reduce(0, +)) / Double(moodValues.count)
        
        switch average {
        case 4.5...: return "😊 Excellent"
        case 3.5..<4.5: return "🙂 Good"
        case 2.5..<3.5: return "😐 Neutral"
        case 1.5..<2.5: return "😔 Low"
        default: return "😟 Challenging"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Journey")
                .font(.title3)
                .fontWeight(.semibold)
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average Mood")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(averageMood)
                        .font(.headline)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(entriesThisWeek()) entries")
                        .font(.headline)
                }
                
                Spacer()
                
                Button(action: {
                    NotificationCenter.default.post(name: .navigateToInsights, object: nil)
                }) {
                    Text("View Insights")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color.accentColor.opacity(0.05))
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Color.accentColor.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func entriesThisWeek() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        
        return entries.filter { $0.createdAt >= weekAgo }.count
    }
}