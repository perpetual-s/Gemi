import SwiftUI

/// Elegant floating prompt library with intelligent categorization
struct WritersBlockBreaker: View {
    @Binding var isPresented: Bool
    let onPromptSelected: (WritingPrompt) -> Void
    
    @State private var selectedCategory: PromptCategory = .inspiration
    @State private var currentPrompt: WritingPrompt?
    @State private var isGenerating = false
    @State private var showExpandedView = false
    @State private var hoveredCategory: PromptCategory?
    @State private var selectedIndex = 0
    @Namespace private var animation
    
    struct WritingPrompt: Identifiable {
        let id = UUID()
        let category: PromptCategory
        let prompt: String
        let technique: String
        let estimatedTime: Int // minutes
        let difficulty: Difficulty
        
        enum Difficulty: String, CaseIterable {
            case easy = "Easy"
            case medium = "Medium"
            case challenge = "Challenge"
            
            var color: Color {
                switch self {
                case .easy: return .green
                case .medium: return .orange
                case .challenge: return .red
                }
            }
        }
    }
    
    enum PromptCategory: String, CaseIterable {
        case inspiration = "Get Inspired"
        case freeWrite = "Free Write"
        case memory = "Memory Lane"
        case whatIf = "What If..."
        case sensory = "Senses"
        case dialogue = "Inner Dialogue"
        
        var icon: String {
            switch self {
            case .inspiration: return "sparkles"
            case .freeWrite: return "scribble"
            case .memory: return "clock.arrow.circlepath"
            case .whatIf: return "questionmark.bubble"
            case .sensory: return "eye"
            case .dialogue: return "bubble.left.and.bubble.right"
            }
        }
        
        var color: Color {
            switch self {
            case .inspiration: return .purple
            case .freeWrite: return .blue
            case .memory: return .orange
            case .whatIf: return .green
            case .sensory: return .pink
            case .dialogue: return .indigo
            }
        }
        
        var description: String {
            switch self {
            case .inspiration:
                return "Spark creativity with thought-provoking prompts"
            case .freeWrite:
                return "Write continuously without stopping to think"
            case .memory:
                return "Explore memories and past experiences"
            case .whatIf:
                return "Imagine alternative scenarios and possibilities"
            case .sensory:
                return "Focus on sensory details and observations"
            case .dialogue:
                return "Explore internal thoughts and conversations"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Beautiful backdrop blur
            Color.black.opacity(0.3)
                .background(
                    VisualEffectView.frostedGlass
                        .ignoresSafeArea()
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }
            
            // Main floating card
            if showExpandedView {
                expandedPromptView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8, anchor: .center).combined(with: .opacity),
                        removal: .scale(scale: 0.8, anchor: .center).combined(with: .opacity)
                    ))
            } else {
                compactCategoryGrid
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9, anchor: .center).combined(with: .opacity),
                        removal: .scale(scale: 0.9, anchor: .center).combined(with: .opacity)
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            generatePrompt()
        }
        .onKeyPress(.escape) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if showExpandedView {
                    showExpandedView = false
                } else {
                    isPresented = false
                }
            }
            return .handled
        }
    }
    
    // MARK: - Components
    
    private var compactCategoryGrid: some View {
        VStack(spacing: 0) {
            // Elegant header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What would you like to write about?")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Choose a category to get inspired")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            
            // Beautiful grid of categories
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(PromptCategory.allCases, id: \.self) { category in
                    CategoryCard(
                        category: category,
                        isSelected: selectedCategory == category,
                        isHovered: hoveredCategory == category
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedCategory = category
                            generatePrompt()
                            showExpandedView = true
                        }
                    }
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hoveredCategory = hovering ? category : nil
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 480)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var expandedPromptView: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showExpandedView = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                        Text("Categories")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Category indicator
                Label(selectedCategory.rawValue, systemImage: selectedCategory.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedCategory.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(selectedCategory.color.opacity(0.1))
                    )
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            Divider()
            
            // Prompt content
            ScrollView {
                VStack(spacing: 20) {
                    if let prompt = currentPrompt {
                        elegantPromptCard(prompt)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }
                    
                    // Quick tips
                    quickTips
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
            .frame(maxHeight: 400)
        }
        .frame(width: 520)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func elegantPromptCard(_ prompt: WritingPrompt) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Beautiful prompt display
            VStack(alignment: .leading, spacing: 12) {
                Text(prompt.prompt)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundColor(.primary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 16) {
                    // Time estimate
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                        Text("\(prompt.estimatedTime) min")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.secondary)
                    
                    // Difficulty
                    HStack(spacing: 6) {
                        Circle()
                            .fill(prompt.difficulty.color)
                            .frame(width: 6, height: 6)
                        Text(prompt.difficulty.rawValue)
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedCategory.color.opacity(0.05))
            )
            
            // Elegant technique card
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text("Writing Technique")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Text(prompt.technique)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
            )
            
            // Beautiful action buttons
            HStack(spacing: 12) {
                Button {
                    onPromptSelected(prompt)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Start Writing")
                            .font(.system(size: 15, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedCategory.color)
                    )
                }
                .buttonStyle(.plain)
                
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        generatePrompt()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("New Prompt")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var quickTips: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Writing Tips")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                QuickTipCard(
                    icon: "bolt.fill",
                    color: .orange,
                    title: "Start Fast",
                    tip: "Write the first thing that comes to mind"
                )
                
                QuickTipCard(
                    icon: "timer",
                    color: .blue,
                    title: "Time Box",
                    tip: "Set a 5-minute timer and don't stop"
                )
                
                QuickTipCard(
                    icon: "sparkles",
                    color: .purple,
                    title: "Be Curious",
                    tip: "Ask yourself 'What if?' and explore"
                )
                
                QuickTipCard(
                    icon: "heart.fill",
                    color: .pink,
                    title: "Be Gentle",
                    tip: "Write without judging yourself"
                )
            }
        }
    }
    
    
    // MARK: - Helper Methods
    
    private func generatePrompt() {
        // Update immediately without delay
        currentPrompt = WritingPrompt(
            category: selectedCategory,
            prompt: getPromptText(for: selectedCategory),
            technique: getTechnique(for: selectedCategory),
            estimatedTime: Int.random(in: 5...15),
            difficulty: WritingPrompt.Difficulty.allCases.randomElement() ?? .medium
        )
    }
    
    private func getPromptText(for category: PromptCategory) -> String {
        // Use WritingPromptGenerator for dynamic prompts
        let generator = WritingPromptGenerator.shared
        
        switch category {
        case .inspiration:
            return generator.getPrompt(from: .reflection)
        case .freeWrite:
            return "Set a timer for 10 minutes and write continuously about whatever comes to mind. Don't stop to edit or think."
        case .memory:
            return generator.getPrompt(from: .reflection)
        case .whatIf:
            return generator.getPrompt(from: .creativity)
        case .sensory:
            return "Close your eyes and focus on the sounds around you. Write about each sound as if describing it to someone who has never heard before."
        case .dialogue:
            return generator.getPrompt(from: .emotional)
        }
    }
    
    private func getTechnique(for category: PromptCategory) -> String {
        switch category {
        case .inspiration:
            return "Start with a single vivid detail and expand outward. Let one memory lead to another."
        case .freeWrite:
            return "Keep your hand moving. Don't pause to think or edit. Let your subconscious guide you."
        case .memory:
            return "Use all five senses to reconstruct the scene. Small details often unlock bigger memories."
        case .whatIf:
            return "Embrace the absurd. The more unexpected your scenario, the more creative your writing."
        case .sensory:
            return "Use metaphors and similes to describe sensations. Compare unfamiliar experiences to familiar ones."
        case .dialogue:
            return "Write both sides of the conversation. Give each voice a distinct personality and perspective."
        }
    }
}

// MARK: - Supporting Views

struct CategoryCard: View {
    let category: WritersBlockBreaker.PromptCategory
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(category.color.opacity(isHovered ? 0.15 : 0.08))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(category.color)
                        .symbolRenderingMode(.hierarchical)
                }
                
                VStack(spacing: 4) {
                    Text(category.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(getTipCount(for: category))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 140, height: 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(category.color.opacity(isHovered ? 0.3 : 0), lineWidth: 2)
                    )
            )
            .scaleEffect(isHovered ? 1.05 : 1)
            .shadow(color: category.color.opacity(isHovered ? 0.2 : 0), radius: 8)
        }
        .buttonStyle(.plain)
    }
    
    private func getTipCount(for category: WritersBlockBreaker.PromptCategory) -> String {
        switch category {
        case .inspiration: return "15+ prompts"
        case .freeWrite: return "10+ exercises"
        case .memory: return "20+ prompts"
        case .whatIf: return "25+ scenarios"
        case .sensory: return "12+ exercises"
        case .dialogue: return "18+ prompts"
        }
    }
}

struct QuickTipCard: View {
    let icon: String
    let color: Color
    let title: String
    let tip: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Text(tip)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
    }
}