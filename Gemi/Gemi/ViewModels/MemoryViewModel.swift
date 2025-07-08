import Foundation
import SwiftUI

/// View model for managing and displaying memories in the UI
@MainActor
final class MemoryViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var sortOrder: SortOrder = .byDate
    
    private let memoryManager = MemoryManager.shared
    
    enum SortOrder: String, CaseIterable {
        case byDate = "Date"
        case alphabetical = "A-Z"
    }
    
    var filteredMemories: [Memory] {
        var filtered = memoryManager.memories
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.content.localizedCaseInsensitiveContains(searchText) 
            }
        }
        
        // Sort
        switch sortOrder {
        case .byDate:
            filtered.sort { $0.extractedAt > $1.extractedAt }
        case .alphabetical:
            filtered.sort { $0.content.localizedStandardCompare($1.content) == .orderedAscending }
        }
        
        return filtered
    }
    
    func deleteMemory(_ memory: Memory) {
        memoryManager.deleteMemory(memory)
    }
}