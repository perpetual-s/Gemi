import SwiftUI

struct MemoriesView: View {
    var body: some View {
        VStack(spacing: Theme.spacing) {
            Image(systemName: "brain")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.tertiaryText)
            
            Text("AI Memories")
                .font(Theme.Typography.title)
            
            Text("Coming soon: AI-powered insights from your journal")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.windowBackground)
    }
}