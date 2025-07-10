import SwiftUI

/// Writer's block breaker that provides intelligent prompts and exercises
struct WritersBlockBreaker: View {
    @Binding var isPresented: Bool
    let onPromptSelected: (WritingPrompt) -> Void
    
    @State private var selectedCategory: PromptCategory = .inspiration
    @State private var currentPrompt: WritingPrompt?
    @State private var isGenerating = false
    @State private var showingAllPrompts = false
    
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
        case sensory = "Sensory Details"
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
        VStack(spacing: 0) {
            // Header
            header
            
            // Category selector
            categorySelector
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            
            Divider()
            
            // Main content
            ScrollView {
                VStack(spacing: 20) {
                    // Current prompt
                    if let prompt = currentPrompt {
                        currentPromptCard(prompt)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }
                    
                    // Quick exercises
                    quickExercises
                        .padding(.horizontal, 20)
                        .padding(.top, currentPrompt == nil ? 20 : 0)
                    
                    // All prompts
                    if showingAllPrompts {
                        allPromptsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                }
            }
            
            // Footer actions
            footerActions
        }
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            generatePrompt()
        }
    }
    
    // MARK: - Components
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Writing Prompt Library")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("Explore prompts and exercises to inspire your writing")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(VisualEffectView.windowBackground)
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PromptCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        // Use simpler animation to prevent glitching
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                        // Generate prompt after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            generatePrompt()
                        }
                    }
                }
            }
        }
    }
    
    private func currentPromptCard(_ prompt: WritingPrompt) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label(prompt.category.rawValue, systemImage: prompt.category.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(prompt.category.color)
                
                Spacer()
                
                // Difficulty badge
                Text(prompt.difficulty.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(prompt.difficulty.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(prompt.difficulty.color.opacity(0.15))
                    )
            }
            
            // Prompt text
            Text(prompt.prompt)
                .font(.system(size: 16, weight: .regular))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // Technique tip
            VStack(alignment: .leading, spacing: 8) {
                Label("Technique", systemImage: "lightbulb")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(prompt.technique)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.05))
            )
            
            // Actions
            HStack(spacing: 12) {
                Button {
                    onPromptSelected(prompt)
                    isPresented = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Start Writing")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(prompt.category.color)
                    )
                }
                .buttonStyle(.plain)
                
                Button {
                    generatePrompt()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("New Prompt")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Time estimate
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text("\(prompt.estimatedTime) min")
                        .font(.system(size: 13))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
        )
    }
    
    private var quickExercises: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Exercises")
                .font(.system(size: 16, weight: .semibold))
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickExerciseCard(
                    title: "Word Association",
                    icon: "link",
                    color: .blue,
                    duration: "2 min"
                ) {
                    // Start word association
                }
                
                QuickExerciseCard(
                    title: "Stream of Consciousness",
                    icon: "waveform",
                    color: .purple,
                    duration: "5 min"
                ) {
                    // Start stream writing
                }
                
                QuickExerciseCard(
                    title: "Picture Prompt",
                    icon: "photo",
                    color: .green,
                    duration: "3 min"
                ) {
                    // Show random image
                }
                
                QuickExerciseCard(
                    title: "Music & Mood",
                    icon: "music.note",
                    color: .orange,
                    duration: "10 min"
                ) {
                    // Start music writing
                }
            }
        }
    }
    
    private var allPromptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All \(selectedCategory.rawValue) Prompts")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Button {
                    withAnimation {
                        showingAllPrompts.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .rotationEffect(.degrees(showingAllPrompts ? 0 : 180))
                }
                .buttonStyle(.plain)
            }
            
            // Prompt list would go here
        }
    }
    
    private var footerActions: some View {
        HStack {
            Button {
                withAnimation {
                    showingAllPrompts.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showingAllPrompts ? "chevron.up" : "chevron.down")
                    Text(showingAllPrompts ? "Hide All" : "Show All Prompts")
                }
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            if isGenerating {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.8)
            }
        }
        .padding(20)
        .background(VisualEffectView.windowBackground)
    }
    
    // MARK: - Helper Methods
    
    private func generatePrompt() {
        isGenerating = true
        
        // Simulate AI generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Update state without nested animations
            currentPrompt = WritingPrompt(
                category: selectedCategory,
                prompt: getPromptText(for: selectedCategory),
                technique: getTechnique(for: selectedCategory),
                estimatedTime: Int.random(in: 5...15),
                difficulty: WritingPrompt.Difficulty.allCases.randomElement() ?? .medium
            )
            isGenerating = false
        }
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

struct CategoryButton: View {
    let category: WritersBlockBreaker.PromptCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? category.color : Color.secondary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                
                Text(category.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? category.color : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
            }
            .scaleEffect(isSelected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
    }
}

struct QuickExerciseCard: View {
    let title: String
    let icon: String
    let color: Color
    let duration: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    Text(duration)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(isHovered ? 0.15 : 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color.opacity(isHovered ? 0.3 : 0), lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.01 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}