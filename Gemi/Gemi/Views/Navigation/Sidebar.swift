import SwiftUI

struct Sidebar: View {
    @Binding var selectedView: NavigationItem
    @State private var searchText = ""
    
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
        .background(Theme.Colors.windowBackground)
    }
    
    private var header: some View {
        HStack {
            Image(systemName: "book.fill")
                .font(.title2)
                .foregroundColor(Theme.Colors.primaryAccent)
            
            Text("Gemi")
                .font(Theme.Typography.title)
            
            Spacer()
            
            Button(action: { selectedView = .compose }) {
                Image(systemName: "square.and.pencil")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("New Entry (⌘N)")
        }
        .padding()
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.Colors.secondaryText)
            
            TextField("Search entries...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.smallCornerRadius)
    }
    
    private var navigationItems: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(NavigationItem.allCases) { item in
                NavigationRow(
                    item: item,
                    isSelected: selectedView == item,
                    action: { selectedView = item }
                )
            }
        }
    }
    
    private var bottomSection: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "gearshape")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Settings (⌘,)")
            
            Spacer()
            
            Text("3 entries today")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.tertiaryText)
        }
        .padding()
    }
}

struct NavigationRow: View {
    let item: NavigationItem
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.body)
                    .frame(width: 20)
                
                Text(item.title)
                    .font(Theme.Typography.body)
                
                Spacer()
                
                if item == .timeline {
                    Text("12")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.divider)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                    .fill(backgroundColor)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
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
    case timeline
    case compose
    case favorites
    case search
    case memories
    case insights
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .timeline: return "Timeline"
        case .compose: return "New Entry"
        case .favorites: return "Favorites"
        case .search: return "Search"
        case .memories: return "Memories"
        case .insights: return "Insights"
        }
    }
    
    var icon: String {
        switch self {
        case .timeline: return "calendar"
        case .compose: return "square.and.pencil"
        case .favorites: return "star"
        case .search: return "magnifyingglass"
        case .memories: return "brain"
        case .insights: return "chart.line.uptrend.xyaxis"
        }
    }
}