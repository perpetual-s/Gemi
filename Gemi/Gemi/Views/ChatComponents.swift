import SwiftUI

/// Chat-related UI components used throughout the app

/// A sheet view for contextual chat with journal entries
struct ChatSheet: View {
    let journalEntry: JournalEntry
    @Environment(\.dismiss) private var dismiss
    
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
            
            // Chat view - GemiChatView handles context internally
            GemiChatView(contextEntry: journalEntry)
        }
        .frame(minWidth: 600, idealWidth: 700, maxWidth: 900, minHeight: 400, idealHeight: 500, maxHeight: 700)
        .background(Theme.Colors.windowBackground)
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