import SwiftUI

/// A button that opens the chat with context from a journal entry
struct ChatWithContextButton: View {
    let entry: JournalEntry
    @State private var showingChat = false
    
    var body: some View {
        Button {
            showingChat = true
        } label: {
            Label("Talk to Gemi about this", systemImage: "bubble.left.and.bubble.right")
                .font(Theme.Typography.caption)
        }
        .buttonStyle(.plain)
        .foregroundColor(Theme.Colors.primaryAccent)
        .sheet(isPresented: $showingChat) {
            ChatSheet(journalEntry: entry)
        }
    }
}

/// A sheet view for contextual chat
struct ChatSheet: View {
    let journalEntry: JournalEntry
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var isInitialized = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Talking about your entry")
                        .font(Theme.Typography.headline)
                    Text(journalEntry.createdAt, style: .date)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.spacing)
            
            Divider()
            
            // Chat view (Create a custom view to avoid recursion)
            ChatInterfaceView(viewModel: chatViewModel)
        }
        .frame(minWidth: 600, idealWidth: 700, maxWidth: 900, minHeight: 400, idealHeight: 500, maxHeight: 700)
        .background(Theme.Colors.windowBackground)
        .onAppear {
            if !isInitialized {
                initializeChat()
                isInitialized = true
            }
        }
    }
    
    private func initializeChat() {
        // Extract key context from the journal entry
        let context = extractContext(from: journalEntry)
        
        // Send initial message with context
        Task {
            let initialMessage = """
            I'd like to reflect on my journal entry from \(journalEntry.createdAt.formatted(date: .abbreviated, time: .omitted)). \
            \(context)
            """
            
            // Create memories specific to this entry
            let entryMemory = Memory(
                content: journalEntry.content.prefix(500) + "...",
                sourceEntryID: journalEntry.id,
                category: .personal,
                importance: 5
            )
            
            await chatViewModel.sendMessage(initialMessage, withMemories: [entryMemory])
        }
    }
    
    private func extractContext(from entry: JournalEntry) -> String {
        var context = ""
        
        if let mood = entry.mood {
            context += "I was feeling \(mood). "
        }
        
        if !entry.tags.isEmpty {
            context += "I wrote about \(entry.tags.joined(separator: ", ")). "
        }
        
        // Extract first meaningful sentence
        let sentences = entry.content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if let firstSentence = sentences.first {
            context += "Here's what I wrote: \"\(firstSentence)...\""
        }
        
        return context
    }
}

/// A floating action button for quick chat access
struct ChatFloatingButton: View {
    @Binding var showingChat: Bool
    
    var body: some View {
        Button {
            showingChat = true
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primaryAccent)
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .help("Talk to Gemi")
    }
}