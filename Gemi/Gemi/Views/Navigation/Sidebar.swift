import SwiftUI

struct Sidebar: View {
    @Binding var selectedView: NavigationItem
    @ObservedObject var journalStore: JournalStore
    @State private var searchText = ""
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            ScrollView {
                VStack(spacing: Theme.spacing) {
                    searchBar
                    navigationItems
                    Spacer()
                }
                .padding()
            }
            
            Divider()
            
            bottomSection
        }
        .frame(width: Theme.sidebarWidth)
        .background(
            VisualEffectView.sidebar
                .ignoresSafeArea()
        )
        .sheet(isPresented: $showingSettings) {
            SettingsView(journalStore: journalStore)
        }
    }
    
    private var header: some View {
        HStack {
            ZStack {
                // Gradient background for icon
                Circle()
                    .fill(Theme.Gradients.primary)
                    .frame(width: 36, height: 36)
                    .shadow(color: Theme.Colors.primaryAccent.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Image(systemName: "book.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text("Gemi")
                .font(Theme.Typography.title)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: { selectedView = .compose }) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primaryAccent.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Colors.primaryAccent)
                }
            }
            .buttonStyle(.plain)
            .help("New Entry (⌘N)")
            .scaleEffect(1.0)
            .onHover { hovering in
                withAnimation(Theme.bounceAnimation) {
                    // Animation is handled by button style
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Theme.Colors.windowBackground,
                    Theme.Colors.windowBackground.opacity(0.8)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.Colors.secondaryText)
            
            TextField("Search entries...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(
            ZStack {
                Theme.Colors.cardBackground.opacity(0.5)
                VisualEffectView.ultraThin
            }
        )
        .cornerRadius(Theme.smallCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 0.5)
        )
    }
    
    private var navigationItems: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(NavigationItem.allCases) { item in
                NavigationRow(
                    item: item,
                    isSelected: selectedView == item,
                    action: { selectedView = item },
                    entryCount: item == .timeline ? journalStore.entries.count : nil
                )
            }
        }
    }
    
    private var bottomSection: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.3)
            
            HStack {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.Colors.secondaryText)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Theme.Colors.hoverBackground)
                                .opacity(0.01)
                        )
                }
                .buttonStyle(.plain)
                .help("Settings (⌘,)")
                .keyboardShortcut(",", modifiers: .command)
                .onHover { hovering in
                    withAnimation(Theme.quickAnimation) {
                        // Hover effect handled by button
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("3 entries")
                        .font(Theme.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.Colors.primaryAccent)
                    
                    Text("today")
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.tertiaryText)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Theme.Colors.primaryAccent.opacity(0.1))
                )
            }
            .padding()
        }
        .background(
            VisualEffectView.ultraThin
                .opacity(0.5)
        )
    }
}

struct NavigationRow: View {
    let item: NavigationItem
    let isSelected: Bool
    let action: () -> Void
    let entryCount: Int?
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.body)
                    .frame(width: 20)
                    .foregroundColor(isSelected ? Theme.Colors.primaryAccent : (isHovered ? Theme.Colors.primaryAccent.opacity(0.8) : Theme.Colors.secondaryText))
                    .scaleEffect(isHovered ? 1.1 : 1.0)
                    .animation(Theme.bounceAnimation, value: isHovered)
                
                Text(item.title)
                    .font(Theme.Typography.body)
                
                Spacer()
                
                if let count = entryCount {
                    Text("\(count)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Theme.Colors.primaryAccent.opacity(0.2) : Theme.Colors.divider)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                        .fill(backgroundColor)
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                            .stroke(Theme.Colors.primaryAccent.opacity(0.3), lineWidth: 1)
                    }
                }
            )
            .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Theme.quickAnimation) {
                isHovered = hovering
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Theme.Colors.selectedBackground
        } else if isHovered {
            return Theme.Colors.hoverBackground
        } else {
            return Color.clear
        }
    }
}

enum NavigationItem: String, CaseIterable, Identifiable {
    case home
    case timeline
    case compose
    case chat
    case favorites
    case search
    case memories
    case insights
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .timeline: return "Timeline"
        case .compose: return "New Entry"
        case .chat: return "Chat with Gemi"
        case .favorites: return "Favorites"
        case .search: return "Search"
        case .memories: return "Memories"
        case .insights: return "Insights"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house"
        case .timeline: return "calendar"
        case .compose: return "square.and.pencil"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .favorites: return "star"
        case .search: return "magnifyingglass"
        case .memories: return "brain"
        case .insights: return "chart.line.uptrend.xyaxis"
        }
    }
}