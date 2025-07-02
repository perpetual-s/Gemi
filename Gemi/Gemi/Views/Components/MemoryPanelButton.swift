//
//  MemoryPanelButton.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import SwiftUI

/// A button to access Gemi's memory panel
struct MemoryPanelButton: View {
    @State private var showingMemoryPanel = false
    @State private var memoryCount = 0
    @State private var isHovered = false
    
    var body: some View {
        Button {
            showingMemoryPanel = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "brain")
                    .font(.system(size: 16, weight: .medium))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Memories")
                        .font(.system(size: 14, weight: .medium))
                    
                    if memoryCount > 0 {
                        Text("\(memoryCount) stored")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.primary.opacity(isHovered ? 0.3 : 0.1),
                                        DesignSystem.Colors.primary.opacity(isHovered ? 0.2 : 0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .help("View and manage Gemi's memories")
        .sheet(isPresented: $showingMemoryPanel) {
            MemoryPanelView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .task {
            await loadMemoryCount()
        }
    }
    
    private func loadMemoryCount() async {
        do {
            memoryCount = try await DatabaseManager.shared().getMemoryCount()
        } catch {
            // Handle error silently
        }
    }
}

// MARK: - Compact Version

struct CompactMemoryPanelButton: View {
    @State private var showingMemoryPanel = false
    @State private var isHovered = false
    
    var body: some View {
        Button {
            showingMemoryPanel = true
        } label: {
            Image(systemName: "brain")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isHovered ? DesignSystem.Colors.primary : .secondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isHovered ? DesignSystem.Colors.primary.opacity(0.1) : Color.clear)
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .help("View and manage Gemi's memories")
        .sheet(isPresented: $showingMemoryPanel) {
            MemoryPanelView()
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}

// MARK: - Preview

#Preview("Memory Panel Button") {
    VStack(spacing: 20) {
        MemoryPanelButton()
        
        CompactMemoryPanelButton()
    }
    .padding(40)
    .background(Color(red: 0.96, green: 0.95, blue: 0.94))
}