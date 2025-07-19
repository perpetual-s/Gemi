import Foundation

/// Generates impressive demo content for hackathon presentation
@MainActor
final class DemoContentGenerator {
    
    static let shared = DemoContentGenerator()
    private let databaseManager = DatabaseManager.shared
    
    /// Demo entries that showcase Gemi's capabilities
    private let demoEntries: [(title: String, content: String, mood: Mood?, daysAgo: Int)] = [
        (
            title: "🌅 Morning Reflections",
            content: """
            Woke up early today to watch the sunrise from my balcony. There's something magical about those quiet moments before the world wakes up. The sky painted itself in shades of coral and gold, reminding me why I love starting my days with gratitude.
            
            Three things I'm grateful for today:
            1. The warmth of my morning coffee
            2. Messages from friends checking in
            3. This private space where I can be completely honest with myself
            
            Sometimes I wonder if anyone else feels this sense of possibility in the early morning hours. It's like the universe is whispering that today could be different, today could be extraordinary.
            """,
            mood: .peaceful,
            daysAgo: 0
        ),
        (
            title: "💡 Breakthrough at Work",
            content: """
            Finally cracked the problem that's been haunting me for weeks! The solution came to me during my walk - isn't it funny how stepping away from the screen often brings the clearest insights?
            
            The key was simplifying the approach. I was overcomplicating things, trying to build a perfect system instead of starting with something that just works. MVP mindset for the win!
            
            Celebrated with the team over video call. Even through screens, their excitement was contagious. Days like these remind me why I love what I do.
            
            Note to future self: When stuck, take a walk. The answers often come when you stop forcing them.
            """,
            mood: .excited,
            daysAgo: 1
        ),
        (
            title: "🌧️ Rainy Day Thoughts",
            content: """
            The rain against my window sounds like nature's white noise machine. Perfect background for introspection.
            
            Had a difficult conversation with Mom today. We finally talked about things we've been avoiding for years. It wasn't easy, but there's a lightness now where there used to be weight.
            
            Family relationships are complex tapestries - threads of love, disappointment, hope, and history all woven together. Today we added some new threads, stronger ones.
            
            Gemi helped me prepare for this conversation. Looking back at past entries, I could see my patterns, my triggers, my growth. Having an AI that remembers my journey is like having a wise friend who's been there through it all.
            """,
            mood: nil,
            daysAgo: 3
        ),
        (
            title: "🎯 Setting New Goals",
            content: """
            Spent the evening planning the next chapter of my life. It's time for some bold moves.
            
            Goals for the next 6 months:
            - Launch the side project I've been dreaming about
            - Learn Spanish (at least conversational level)
            - Run my first half marathon
            - Strengthen my meditation practice
            - Travel somewhere that scares me a little
            
            What I love about writing these down here is that Gemi will remember them. In six months, we can look back together and see how far I've come. No judgment, just honest reflection.
            
            The future feels bright and full of possibility.
            """,
            mood: .accomplished,
            daysAgo: 5
        ),
        (
            title: "🌙 Late Night Vulnerability",
            content: """
            Can't sleep. The kind of night where thoughts spin like a carousel that won't stop.
            
            I've been pretending everything is fine, but honestly? I'm scared. Scared of failing, scared of succeeding, scared of being seen for who I really am.
            
            But here's what I'm learning: vulnerability isn't weakness. It's the birthplace of courage, creativity, and change. Every time I write these raw, honest thoughts, I feel a little braver.
            
            Thank you, Gemi, for being a safe space where I can drop the mask. Where I can admit that I don't have it all figured out, and that's okay.
            
            Tomorrow, I'll face the world again. But tonight, I'm just human, beautifully imperfect and trying my best.
            """,
            mood: .anxious,
            daysAgo: 7
        ),
        (
            title: "🎨 Creative Breakthrough",
            content: """
            Something shifted today. After weeks of creative block, the ideas started flowing like water breaking through a dam.
            
            Started painting again - just abstract colors and emotions on canvas. No plan, no perfection, just pure expression. My hands remembered what my mind had forgotten.
            
            Maybe that's the secret: stop trying so hard. Let creativity be play, not performance.
            
            Attached a photo of today's painting. It's messy and imperfect and absolutely perfect in its imperfection. Just like life.
            """,
            mood: .happy,
            daysAgo: 10
        ),
        (
            title: "💪 Small Victories",
            content: """
            Today I:
            - Woke up without hitting snooze
            - Had a difficult conversation I'd been avoiding
            - Chose salad over fries (miracle!)
            - Replied to all my emails
            - Took a real lunch break
            - Said no to something that didn't serve me
            
            None of these will make headlines, but together they paint a picture of someone trying to be a little better each day.
            
            Progress isn't always dramatic. Sometimes it's just showing up, making slightly better choices, being a bit kinder to yourself.
            
            Celebrating these small victories because they matter. They're the building blocks of the life I'm creating.
            """,
            mood: .accomplished,
            daysAgo: 14
        ),
        (
            title: "🌍 Perspective Shift",
            content: """
            Watched a documentary about the universe tonight. Feeling simultaneously insignificant and infinite.
            
            We're on a tiny rock floating through endless space, and yet every emotion we feel, every connection we make, every moment of joy or sorrow - it all matters profoundly.
            
            This paradox used to trouble me. Now it liberates me. If we're cosmically small, then our mistakes are too. If life is brief, then every moment of happiness is precious.
            
            Going to bed feeling grateful to be alive, grateful to feel, grateful to be part of this mysterious, beautiful existence.
            
            What a gift it is to be human.
            """,
            mood: .peaceful,
            daysAgo: 21
        )
    ]
    
    /// Demo memories that showcase AI understanding
    private let demoMemories: [String] = [
        "User finds peace in early morning solitude and practices daily gratitude",
        "Walking helps user solve complex problems - breakthrough came during a walk",
        "Had meaningful but difficult conversation with mother about long-avoided topics",
        "Setting ambitious 6-month goals including launching side project and learning Spanish",
        "Experiences late-night vulnerability and uses journaling as safe space for authenticity",
        "Rediscovered painting as outlet for creativity after weeks of creative block",
        "Values celebrating small daily victories as building blocks of personal growth",
        "Finds liberation in cosmic perspective - our smallness makes mistakes less significant"
    ]
    
    /// Generate demo content for presentation
    func generateDemoContent() async {
        // Clear existing entries for clean demo
        await clearExistingContent()
        
        // Generate entries with realistic timestamps
        for (index, demo) in demoEntries.enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: -demo.daysAgo, to: Date()) ?? Date()
            
            let entry = JournalEntry(
                id: UUID(),
                createdAt: date,
                modifiedAt: date,
                title: demo.title,
                content: demo.content,
                mood: demo.mood,
                isFavorite: index < 3 // Favorite the most recent ones
            )
            
            do {
                try await databaseManager.saveEntry(entry)
            } catch {
                print("Failed to save entry: \(error)")
            }
            
            // Small delay to ensure proper ordering
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Generate memories
        for memoryContent in demoMemories {
            // For demo memories, we'll use a dummy source entry ID
            let memoryData = MemoryData(
                content: memoryContent,
                sourceEntryID: UUID()
            )
            
            do {
                try await databaseManager.saveMemory(memoryData)
            } catch {
                print("Failed to save memory: \(error)")
            }
        }
        
        // Create sample conversations
        await generateSampleConversations()
    }
    
    /// Generate sample AI conversations
    private func generateSampleConversations() async {
        // For now, we'll skip generating sample conversations since Chat type is not available
        // This would need to be integrated with the actual chat storage system
        /*
        let sampleChats = [
            Chat(
                id: UUID(),
                messages: [
                    ChatHistoryMessage(
                        id: UUID(),
                        role: .user,
                        content: "I've been feeling stuck creatively lately. Any suggestions?",
                        images: nil,
                        timestamp: Date()
                    ),
                    ChatHistoryMessage(
                        id: UUID(),
                        role: .assistant,
                        content: """
                        I noticed from your entries that walking has helped you breakthrough problems before - like when you solved that work challenge! 
                        
                        You also mentioned rediscovering painting helped with creative blocks. Maybe it's time to pick up those brushes again? Sometimes our hands remember what our minds forget.
                        
                        What if you combined both - take a walk to your favorite art supply store? The journey itself might spark something. 🎨
                        """,
                        images: nil,
                        timestamp: Date()
                    )
                ],
                createdAt: Date(),
                lastActive: Date()
            ),
            Chat(
                id: UUID(),
                messages: [
                    ChatHistoryMessage(
                        id: UUID(),
                        role: .user,
                        content: "Help me prepare for a difficult conversation I need to have",
                        images: nil,
                        timestamp: Date()
                    ),
                    ChatHistoryMessage(
                        id: UUID(),
                        role: .assistant,
                        content: """
                        I remember you recently had a breakthrough conversation with your mom. You mentioned feeling lighter afterward, even though it was difficult.
                        
                        Based on what worked then:
                        1. **Be honest about your feelings** - vulnerability created connection
                        2. **Listen without defending** - understanding came from truly hearing each other
                        3. **Focus on the future** - you added "stronger threads" to your relationship
                        
                        What specific conversation are you preparing for? I'm here to help you think through it.
                        """,
                        images: nil,
                        timestamp: Date()
                    )
                ],
                createdAt: Date(),
                lastActive: Date()
            )
        ]
        
        // Store conversations
        for chat in sampleChats {
            // Save to whatever chat storage mechanism is used
            print("Demo chat created: \(chat.id)")
        }
        */
    }
    
    /// Clear existing content for clean demo
    private func clearExistingContent() async {
        // Only clear if running in demo mode
        guard UserDefaults.standard.bool(forKey: "isDemoMode") else { return }
        
        // Load existing entries and memories
        do {
            let entries = try await databaseManager.loadEntries()
            for entry in entries {
                try await databaseManager.deleteEntry(entry.id)
            }
            
            let memories = try await databaseManager.loadAllMemories()
            for memory in memories {
                try await databaseManager.deleteMemoryByID(memory.id)
            }
        } catch {
            print("Error clearing content: \(error)")
        }
    }
    
    /// Generate a compelling demo script
    func getDemoScript() -> String {
        """
        🎬 GEMI DEMO SCRIPT - Google Gemma 3n Hackathon
        
        [OPENING - 10 seconds]
        "What if your diary could remember everything and truly understand you?"
        
        [PRIVACY FIRST - 20 seconds]
        ✅ Show Gemi running completely offline
        ✅ Demonstrate no network requests
        ✅ Emphasize: "Your thoughts never leave your device"
        
        [CORE FEATURES - 60 seconds]
        
        1. INTELLIGENT JOURNALING
        - Create new entry with voice
        - Show mood selection and auto-save
        - Demonstrate rich text and image support
        
        2. AI THAT REMEMBERS
        - Open chat and reference past entries
        - Show how Gemi recalls specific details
        - "Remember when I was struggling with creativity?"
        
        3. INSIGHTS & PATTERNS
        - Show timeline with mood visualization
        - Demonstrate search across entries
        - Display AI-generated insights
        
        [MULTIMODAL MAGIC - 30 seconds]
        - Drag & drop image into entry
        - Record voice note
        - Show how Gemi understands context
        
        [MULTILINGUAL - 20 seconds]
        - Switch to Spanish/Korean entry
        - Show Gemi responding in same language
        
        [CLOSING - 10 seconds]
        "Gemi: Your private AI diary. Every thought protected, every moment understood."
        
        TOTAL: 2 minutes 30 seconds
        """
    }
}

// MARK: - Demo Mode Toggle

extension DemoContentGenerator {
    
    /// Enable demo mode with sample content
    func enableDemoMode() async {
        UserDefaults.standard.set(true, forKey: "isDemoMode")
        UserDefaults.standard.set("Gemma", forKey: "userName")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        await generateDemoContent()
        
        print("""
        
        ✨ DEMO MODE ENABLED ✨
        
        Sample content has been generated.
        Ready for hackathon presentation!
        
        \(getDemoScript())
        
        """)
    }
    
    /// Disable demo mode
    func disableDemoMode() {
        UserDefaults.standard.set(false, forKey: "isDemoMode")
        print("Demo mode disabled")
    }
}