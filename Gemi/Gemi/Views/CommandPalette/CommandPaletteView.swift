//
//  CommandPaletteView.swift
//  Gemi
//

import SwiftUI

struct CommandPaletteView: View {
    @Binding var isShowing: Bool
    @StateObject private var registry = CommandRegistry.shared
    @State private var searchQuery = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFieldFocused: Bool
    
    private var filteredCommands: [Command] {
        registry.search(searchQuery)
    }
    
    var body: some View {
        ZStack {
            // Background dimming
            Color.black
                .opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                }
            
            // Command Palette
            VStack(spacing: 0) {
                // Search Field
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("Type a command or search...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .medium))
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            executeSelectedCommand()
                        }
                    
                    // Clear button
                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                            selectedIndex = 0
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Escape hint
                    Text("esc")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
                
                Divider()
                
                // Results
                if filteredCommands.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.3))
                        
                        Text("No commands found")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("Try searching for \"new\", \"chat\", or \"settings\"")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 1) {
                                ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                                    CommandRow(
                                        command: command,
                                        isSelected: index == selectedIndex,
                                        searchQuery: searchQuery
                                    )
                                    .id(index)
                                    .onTapGesture {
                                        executeCommand(command)
                                    }
                                    .onHover { hovering in
                                        if hovering {
                                            selectedIndex = index
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .frame(maxHeight: 400)
                        .onChange(of: selectedIndex) { _, newValue in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                    }
                }
                
                // Footer with hints
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11))
                        Text("Navigate")
                            .font(.system(size: 11))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "return")
                            .font(.system(size: 11))
                        Text("Select")
                            .font(.system(size: 11))
                    }
                    
                    Spacer()
                    
                    if let selectedCommand = filteredCommands[safe: selectedIndex],
                       let shortcut = selectedCommand.shortcut {
                        HStack(spacing: 4) {
                            Text("Shortcut:")
                                .font(.system(size: 11))
                            Text(shortcut)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                    }
                }
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            }
            .frame(width: 600)
            .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
            .cornerRadius(Theme.cornerRadius * 1.5)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius * 1.5)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .scaleEffect(isShowing ? 1 : 0.95)
            .opacity(isShowing ? 1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isShowing)
        }
        .onAppear {
            isSearchFieldFocused = true
            selectedIndex = 0
        }
        .onDisappear {
            searchQuery = ""
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredCommands.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.escape) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isShowing = false
            }
            return .handled
        }
        .onChange(of: searchQuery) { _, _ in
            selectedIndex = 0
        }
    }
    
    private func executeSelectedCommand() {
        guard let command = filteredCommands[safe: selectedIndex] else { return }
        executeCommand(command)
    }
    
    private func executeCommand(_ command: Command) {
        // Haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .default
        )
        
        // Close palette with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isShowing = false
        }
        
        // Execute command after a brief delay for smooth animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            command.action()
        }
    }
}

struct CommandRow: View {
    let command: Command
    let isSelected: Bool
    let searchQuery: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: command.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    highlightedText(command.title, query: searchQuery)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .primary : .primary.opacity(0.9))
                    
                    Spacer()
                    
                    // Category badge
                    Text(command.category.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                        )
                }
                
                if let subtitle = command.subtitle {
                    highlightedText(subtitle, query: searchQuery)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            // Shortcut
            if let shortcut = command.shortcut {
                Text(shortcut)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.primary.opacity(0.05) : Color.clear)
        )
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private func highlightedText(_ text: String, query: String) -> some View {
        if query.isEmpty {
            Text(text)
        } else {
            let lowercasedText = text.lowercased()
            let lowercasedQuery = query.lowercased()
            
            if let range = lowercasedText.range(of: lowercasedQuery) {
                let startIndex = text.index(text.startIndex, offsetBy: lowercasedText.distance(from: lowercasedText.startIndex, to: range.lowerBound))
                let endIndex = text.index(startIndex, offsetBy: query.count)
                
                let before = String(text[..<startIndex])
                let match = String(text[startIndex..<endIndex])
                let after = String(text[endIndex...])
                
                Text(before) +
                Text(match).foregroundColor(.accentColor).bold() +
                Text(after)
            } else {
                Text(text)
            }
        }
    }
}

// MARK: - Safe Array Access
extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

