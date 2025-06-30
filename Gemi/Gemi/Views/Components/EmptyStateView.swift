//
//  EmptyStateView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

// MARK: - Generic Empty State View

struct EmptyStateView: View {
    let illustration: AnyView
    let title: String
    let message: String
    let primaryAction: EmptyStateAction?
    let secondaryAction: EmptyStateAction?
    
    @State private var isAnimating = false
    
    init(
        illustration: AnyView,
        title: String,
        message: String,
        primaryAction: EmptyStateAction? = nil,
        secondaryAction: EmptyStateAction? = nil
    ) {
        self.illustration = illustration
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Illustration
            illustration
                .scaleEffect(isAnimating ? 1 : 0.8)
                .opacity(isAnimating ? 1 : 0)
            
            // Text content
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
                
                Text(message)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
            }
            
            // Actions
            if primaryAction != nil || secondaryAction != nil {
                HStack(spacing: 16) {
                    if let secondary = secondaryAction {
                        Button(action: secondary.action) {
                            Text(secondary.title)
                                .font(DesignSystem.Typography.callout)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if let primary = primaryAction {
                        Button(action: primary.action) {
                            HStack(spacing: 8) {
                                if let icon = primary.icon {
                                    Image(systemName: icon)
                                }
                                Text(primary.title)
                            }
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                DesignSystem.Colors.primary,
                                                DesignSystem.Colors.secondary
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 20)
            }
        }
        .padding(40)
        .onAppear {
            animateIn()
        }
    }
    
    private func animateIn() {
        withAnimation(DesignSystem.Animation.smooth.delay(0.1)) {
            isAnimating = true
        }
    }
}

// MARK: - Empty State Action

struct EmptyStateAction {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
}

// MARK: - Predefined Empty States

extension EmptyStateView {
    static func noEntries(
        onNewEntry: @escaping () -> Void,
        onChat: @escaping () -> Void
    ) -> EmptyStateView {
        EmptyStateView(
            illustration: AnyView(JournalIllustration(size: 140)),
            title: "Your journal awaits",
            message: "Start capturing your thoughts, feelings, and memories. Every entry is a step towards understanding yourself better.",
            primaryAction: EmptyStateAction(
                title: "Write First Entry",
                icon: "square.and.pencil",
                action: onNewEntry
            ),
            secondaryAction: EmptyStateAction(
                title: "Chat with Gemi",
                action: onChat
            )
        )
    }
    
    static func noSearchResults(query: String) -> EmptyStateView {
        EmptyStateView(
            illustration: AnyView(
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Color.gray.opacity(0.3))
            ),
            title: "No results found",
            message: "We couldn't find any entries matching \"\(query)\". Try a different search term or browse your timeline."
        )
    }
    
    static func noMemories() -> EmptyStateView {
        EmptyStateView(
            illustration: AnyView(AISparkleIllustration(size: 100)),
            title: "Memories will appear here",
            message: "As you write more entries and chat with Gemi, important moments and insights will be remembered here.",
            primaryAction: EmptyStateAction(
                title: "Start Writing",
                icon: "square.and.pencil",
                action: {}
            )
        )
    }
    
    static func error(
        message: String,
        onRetry: @escaping () -> Void
    ) -> EmptyStateView {
        EmptyStateView(
            illustration: AnyView(
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Color.orange)
            ),
            title: "Something went wrong",
            message: message,
            primaryAction: EmptyStateAction(
                title: "Try Again",
                icon: "arrow.clockwise",
                action: onRetry
            )
        )
    }
}

// MARK: - Preview

#Preview("No Entries") {
    EmptyStateView.noEntries(
        onNewEntry: {},
        onChat: {}
    )
    .frame(width: 600, height: 500)
    .background(Color.gray.opacity(0.05))
}

#Preview("No Search Results") {
    EmptyStateView.noSearchResults(query: "happiness")
        .frame(width: 600, height: 500)
        .background(Color.gray.opacity(0.05))
}

#Preview("Error State") {
    EmptyStateView.error(
        message: "Unable to load your entries. Please check your connection and try again.",
        onRetry: {}
    )
    .frame(width: 600, height: 500)
    .background(Color.gray.opacity(0.05))
}