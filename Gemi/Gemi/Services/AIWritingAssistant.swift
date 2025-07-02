//
//  AIWritingAssistant.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class AIWritingAssistant {
    var currentSuggestion: String = ""
    var isGenerating: Bool = false
    var detectedMood: MoodIndicator.Mood?
    var smartPrompts: [SmartPrompt] = []
    
    private let ollamaService = OllamaService.shared
    
    struct SmartPrompt {
        let id = UUID()
        let text: String
        let icon: String
        let category: Category
        
        enum Category {
            case timeOfDay
            case weather
            case continuation
            case reflection
            case gratitude
        }
    }
    
    func generateSmartPrompts(for date: Date) async {
        let hour = Calendar.current.component(.hour, from: date)
        var prompts: [SmartPrompt] = []
        
        switch hour {
        case 5...9:
            prompts.append(SmartPrompt(
                text: "What are you grateful for this morning?",
                icon: "sun.max",
                category: .timeOfDay
            ))
            prompts.append(SmartPrompt(
                text: "What's your main intention for today?",
                icon: "target",
                category: .timeOfDay
            ))
        case 10...14:
            prompts.append(SmartPrompt(
                text: "How has your day been so far?",
                icon: "clock",
                category: .timeOfDay
            ))
            prompts.append(SmartPrompt(
                text: "What's on your mind right now?",
                icon: "bubble.left",
                category: .reflection
            ))
        case 15...18:
            prompts.append(SmartPrompt(
                text: "What was the highlight of your day?",
                icon: "star",
                category: .timeOfDay
            ))
            prompts.append(SmartPrompt(
                text: "Any challenges you faced today?",
                icon: "exclamationmark.triangle",
                category: .reflection
            ))
        case 19...23:
            prompts.append(SmartPrompt(
                text: "How are you feeling as the day winds down?",
                icon: "moon",
                category: .timeOfDay
            ))
            prompts.append(SmartPrompt(
                text: "What are three things that went well today?",
                icon: "list.number",
                category: .gratitude
            ))
        default:
            prompts.append(SmartPrompt(
                text: "Can't sleep? What's on your mind?",
                icon: "moon.stars",
                category: .timeOfDay
            ))
        }
        
        prompts.append(SmartPrompt(
            text: "Continue from where you left off...",
            icon: "arrow.right.circle",
            category: .continuation
        ))
        
        smartPrompts = prompts
    }
    
    func generateCompletion(for text: String, cursorPosition: Int) async {
        isGenerating = true
        defer { isGenerating = false }
        
        let contextWindow = 200
        let startIndex = max(0, cursorPosition - contextWindow)
        let endIndex = min(text.count, cursorPosition)
        
        guard startIndex < endIndex else { return }
        
        let range = text.index(text.startIndex, offsetBy: startIndex)..<text.index(text.startIndex, offsetBy: endIndex)
        let context = String(text[range])
        
        let prompt = """
        You are an AI writing assistant helping someone with their personal journal. 
        Complete the following text in a natural, personal way. 
        Only provide the completion text, nothing else.
        Keep it brief (1-2 sentences max).
        Match the tone and style of the existing text.
        
        Text: \(context)
        """
        
        var fullResponse = ""
        let stream = ollamaService.chatCompletion(prompt: prompt)
        
        do {
            for try await chunk in stream {
                fullResponse += chunk
            }
            currentSuggestion = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Failed to generate completion: \(error)")
            currentSuggestion = ""
        }
    }
    
    func detectMood(from text: String) async {
        guard text.count > 50 else { return }
        
        let prompt = """
        Analyze the mood of this journal entry and respond with ONLY ONE of these words:
        happy, calm, energetic, anxious, melancholic, frustrated, grateful, hopeful, excited, reflective
        
        Text: \(text)
        """
        
        var fullResponse = ""
        let stream = ollamaService.chatCompletion(prompt: prompt)
        
        do {
            for try await chunk in stream {
                fullResponse += chunk
            }
            let moodString = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            switch moodString {
            case "happy": detectedMood = .happy
            case "calm": detectedMood = .calm
            case "energetic": detectedMood = .energetic
            case "anxious": detectedMood = .anxious
            case "melancholic": detectedMood = .melancholic
            case "frustrated": detectedMood = .frustrated
            case "grateful": detectedMood = .grateful
            case "hopeful": detectedMood = .hopeful
            case "excited": detectedMood = .excited
            case "reflective": detectedMood = .reflective
            default: detectedMood = nil
            }
        } catch {
            print("Failed to detect mood: \(error)")
            detectedMood = nil
        }
    }
    
    func generateContinuation(for text: String) async -> String {
        let prompt = """
        You are helping someone continue their journal entry. 
        Based on what they've written, suggest a natural continuation.
        Keep it personal and authentic.
        Provide 2-3 sentences that flow naturally from their text.
        
        Their journal entry so far:
        \(text)
        
        Continuation:
        """
        
        var fullResponse = ""
        let stream = ollamaService.chatCompletion(prompt: prompt)
        
        do {
            for try await chunk in stream {
                fullResponse += chunk
            }
            return fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Failed to generate continuation: \(error)")
            return ""
        }
    }
    
    func checkGrammar(for text: String) async -> [GrammarSuggestion] {
        var suggestions: [GrammarSuggestion] = []
        return suggestions
    }
    
    func generateSummary(for text: String) async -> String {
        guard text.count > 200 else { return "" }
        
        let prompt = """
        Create a brief, thoughtful summary of this journal entry in 1-2 sentences.
        Capture the main theme or feeling without being too clinical.
        
        Journal entry:
        \(text)
        
        Summary:
        """
        
        var fullResponse = ""
        let stream = ollamaService.chatCompletion(prompt: prompt)
        
        do {
            for try await chunk in stream {
                fullResponse += chunk
            }
            return fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Failed to generate summary: \(error)")
            return ""
        }
    }
}

struct GrammarSuggestion {
    let range: NSRange
    let suggestion: String
    let explanation: String
}

struct AIWritingAssistantView: View {
    @State private var assistant = AIWritingAssistant()
    let onPromptSelected: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Writing Prompts")
                .font(ModernDesignSystem.Typography.headline)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            if assistant.smartPrompts.isEmpty {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, ModernDesignSystem.Spacing.md)
            } else {
                VStack(spacing: ModernDesignSystem.Spacing.xs) {
                    ForEach(assistant.smartPrompts, id: \.id) { prompt in
                        Button {
                            onPromptSelected(prompt.text)
                        } label: {
                            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                                Image(systemName: prompt.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(ModernDesignSystem.Colors.primary)
                                    .frame(width: 24)
                                
                                Text(prompt.text)
                                    .font(ModernDesignSystem.Typography.body)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(ModernDesignSystem.Colors.textTertiary)
                            }
                            .padding(ModernDesignSystem.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                                    .fill(ModernDesignSystem.Colors.backgroundSecondary)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusMD)
                .fill(.regularMaterial)
                .shadow(radius: 8, y: 2)
        )
        .task {
            await assistant.generateSmartPrompts(for: Date())
        }
    }
}