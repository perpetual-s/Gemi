import Foundation
import SwiftUI

@MainActor
class DemoDataService {
    static let shared = DemoDataService()
    private init() {}
    
    func createDemoEntries() async throws {
        let database = DatabaseManager.shared
        
        // Create entries spanning from July 1, 2025 onwards
        let entries = [
            // July 1 - Interview nerves
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 1, hour: 20, minute: 30),
                modifiedAt: createDate(year: 2025, month: 7, day: 1, hour: 20, minute: 45),
                title: "Pre-Interview Jitters",
                content: """
                Tomorrow's the big day - my interview with Google. I've been preparing for weeks but still feel those butterflies. 
                
                Spent the evening reviewing system design concepts and practicing behavioral questions. My roommate Jake helped me with mock interviews, and I think I'm getting better at articulating my thoughts clearly.
                
                The position is for their DeepMind team working on Gemma models, which would be a dream come true. Just need to remember to breathe and be myself. Mom called earlier to wish me luck - she could tell I was nervous even over FaceTime.
                """,
                tags: ["anxious", "career", "milestone"],
                mood: .anxious,
                weather: "Sunny, 78°F",
                location: "Irvine, CA"
            ),
            
            // July 2 - Interview day
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 2, hour: 18, minute: 15),
                modifiedAt: createDate(year: 2025, month: 7, day: 2, hour: 18, minute: 30),
                title: "Post-Interview Relief",
                content: """
                I did it! The Google interview went better than expected. The technical rounds were challenging but fair - they asked about my experience with machine learning and my thoughts on making AI more accessible.
                
                The system design portion focused on building a distributed ML training pipeline, which thankfully I had studied. The behavioral interview felt more like a conversation about my passion for privacy-preserving AI and the future of on-device models.
                
                Won't hear back for a week, but regardless of the outcome, I'm proud of how I performed. Celebrated with In-N-Out with Jake and Sarah afterwards.
                """,
                tags: ["accomplished", "career", "milestone"],
                mood: .accomplished,
                weather: "Partly cloudy, 75°F",
                location: "Mountain View, CA"
            ),
            
            // July 5 - Weekend reflection
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 5, hour: 10, minute: 0),
                modifiedAt: createDate(year: 2025, month: 7, day: 5, hour: 10, minute: 15),
                title: "Weekend Thoughts at Laguna Beach",
                content: """
                Needed to clear my head after the interview week. Drove down to Laguna Beach early this morning - the ocean always helps me think clearly.
                
                Been reflecting on where I want to be in 5 years. Whether or not Apple works out, I know I want to work on technology that respects user privacy while still being powerful. Maybe that's why I'm so drawn to this Gemi project idea.
                
                The waves are particularly beautiful today. Sometimes I forget how lucky I am to live in Southern California.
                """,
                tags: ["reflection", "peaceful", "nature"],
                mood: .peaceful,
                weather: "Clear skies, 72°F",
                location: "Laguna Beach, CA"
            ),
            
            // July 8 - UCI project
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 8, hour: 23, minute: 45),
                modifiedAt: createDate(year: 2025, month: 7, day: 9, hour: 0, minute: 5),
                title: "Late Night Coding Session",
                content: """
                Pulled another late night working on my capstone project. We're building an AI-powered mental health companion app - ironically similar to what Gemi could become.
                
                Professor Chen stopped by the lab around 10 PM and we had a great discussion about privacy-preserving ML. She mentioned Google's new Gemma models and how they could enable truly offline AI applications.
                
                Energy drink count: 3. Sleep schedule: non-existent. But the progress feels worth it.
                """,
                tags: ["work", "tired", "productive"],
                mood: .neutral,
                weather: "Night, 68°F",
                location: "UCI Engineering Hall"
            ),
            
            // July 10 - Good news
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 10, hour: 14, minute: 20),
                modifiedAt: createDate(year: 2025, month: 7, day: 10, hour: 14, minute: 35),
                title: "THE CALL!!! 🎉",
                content: """
                I GOT THE JOB AT GOOGLE!!!
                
                Just got off the phone with the recruiter. They're offering me a position on the Google DeepMind team working on next-gen Gemma models starting in September. I literally jumped around my apartment like a kid. Called Mom immediately - she started crying happy tears.
                
                This feels surreal. All those late nights studying, the hackathons, the side projects - they all led to this moment. Jake heard me screaming and came running thinking something was wrong. We're going out to celebrate tonight!
                
                The best part? I'll be working on making AI more accessible and private - exactly what I'm passionate about!
                """,
                tags: ["excited", "career", "milestone", "grateful"],
                mood: .excited,
                weather: "Sunny, 82°F",
                location: "Irvine, CA"
            ),
            
            // July 12 - Family dinner
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 12, hour: 21, minute: 0),
                modifiedAt: createDate(year: 2025, month: 7, day: 12, hour: 21, minute: 20),
                title: "Korean BBQ Celebration",
                content: """
                Parents drove down from LA to celebrate the Google news. We went to our favorite KBBQ place in Irvine - the one where Dad always orders too much meat.
                
                Mom kept telling everyone at nearby tables that her son is going to work at Google. Dad was quieter but I could see the pride in his eyes. They sacrificed so much for my education.
                
                하나님께 감사합니다. 부모님의 사랑과 희생이 없었다면 불가능했을 거예요.
                
                (Thank God. Without my parents' love and sacrifice, this wouldn't have been possible.)
                """,
                tags: ["grateful", "family", "celebration"],
                mood: .grateful,
                weather: "Warm evening, 76°F",
                location: "Irvine, CA"
            ),
            
            // July 15 - Hackathon prep
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 15, hour: 16, minute: 30),
                modifiedAt: createDate(year: 2025, month: 7, day: 15, hour: 17, minute: 0),
                title: "Gemma Hackathon Planning",
                content: """
                Sarah and I decided to enter the Google Gemma 3n hackathon. We're building Gemi - an offline AI diary app that respects user privacy. The idea came from my own journaling habit and concerns about cloud-based AI services.
                
                Spent the afternoon sketching UI designs and planning the architecture. We want to use SwiftUI for a native macOS experience and leverage Gemma's multimodal capabilities.
                
                I'm excited about building something meaningful. Privacy-focused AI feels like the future.
                """,
                tags: ["excited", "project", "creative"],
                mood: .excited,
                weather: "Sunny, 79°F",
                location: "UCI Library"
            ),
            
            // July 18 - Stress
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 18, hour: 23, minute: 55),
                modifiedAt: createDate(year: 2025, month: 7, day: 19, hour: 0, minute: 10),
                title: "Overwhelmed",
                content: """
                Everything's hitting at once. Capstone project deadline, hackathon development, preparing for the Google role, and trying to maintain some semblance of a social life.
                
                Had a mini breakdown earlier. Sarah found me stress-eating in the engineering building and forced me to take a walk. She's right - I need to pace myself.
                
                Sometimes I wonder if I'm taking on too much. But then I remember that this is temporary. In a few months, I'll be at Google, working on AI that can truly help people. Just need to push through.
                """,
                tags: ["anxious", "overwhelmed", "stress"],
                mood: .anxious,
                weather: "Humid night, 71°F",
                location: "Irvine, CA"
            ),
            
            // July 20 - Beach day
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 20, hour: 19, minute: 0),
                modifiedAt: createDate(year: 2025, month: 7, day: 20, hour: 19, minute: 30),
                title: "Sunset Reflections at Newport",
                content: """
                Forced myself to take a break and went to Newport Beach. Sometimes you need to step away from the computer screen and remember there's a world outside.
                
                Watched the sunset while journaling on paper (old school!). Been thinking about how Gemi could help people like me - those who need a private space to process thoughts without worrying about data breaches or AI training on personal content.
                
                The ocean reminds me that some things are bigger than deadlines and job stress. Feeling more centered now.
                """,
                tags: ["peaceful", "reflection", "nature"],
                mood: .peaceful,
                weather: "Perfect sunset, 74°F",
                location: "Newport Beach, CA"
            ),
            
            // July 23 - Technical breakthrough
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 23, hour: 2, minute: 30),
                modifiedAt: createDate(year: 2025, month: 7, day: 23, hour: 2, minute: 45),
                title: "2 AM Breakthrough!",
                content: """
                FINALLY got Gemma 3n running locally with Ollama! We've been struggling with MLX-Swift compatibility for days, and the solution was right there - Ollama handles all the complexity.
                
                Sarah's asleep on the lab couch, but I had to document this moment. The model is generating responses at 50+ tokens/second on my MacBook. The writing assistance features are working beautifully.
                
                We might actually have a shot at winning this hackathon. More importantly, we're building something that could genuinely help people.
                """,
                tags: ["excited", "breakthrough", "coding"],
                mood: .excited,
                weather: "Late night, 65°F",
                location: "UCI Lab"
            ),
            
            // July 25 - Present day
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 25, hour: 14, minute: 0),
                modifiedAt: createDate(year: 2025, month: 7, day: 25, hour: 14, minute: 15),
                title: "Demo Day Prep",
                content: """
                Today's the day we record our hackathon demo video. Gemi is looking incredible - the UI is polished, the AI responses are thoughtful, and the privacy features are rock solid.
                
                Running through the script one more time. We want to show:
                - The offline capability (airplane mode demo)
                - Multilingual support (Korean and Spanish examples)
                - The memories feature that creates continuity
                - Writing tools that actually help
                
                Win or lose, I'm proud of what we built. This could be the start of something bigger.
                """,
                tags: ["excited", "milestone", "presentation"],
                mood: .excited,
                weather: "Clear and bright, 77°F",
                location: "Irvine, CA"
            ),
            
            // July 7 - Fitness goals
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 7, hour: 6, minute: 30),
                modifiedAt: createDate(year: 2025, month: 7, day: 7, hour: 6, minute: 45),
                title: "Morning Run Thoughts",
                content: """
                Woke up early for a run around Aldrich Park. There's something magical about campus at 6 AM - quiet, peaceful, just me and my thoughts.
                
                Been trying to get back into shape after all the stress eating during interview prep. Running helps clear my mind and I always get my best ideas during these morning sessions.
                
                Today I realized that Gemi could help people track not just thoughts but patterns - like how I feel more creative after exercise. Maybe we should add mood analytics in a future version.
                
                5 miles done. Feeling accomplished already and it's not even 7 AM!
                """,
                tags: ["healthy", "morning", "reflection"],
                mood: .accomplished,
                weather: "Cool morning, 65°F",
                location: "UCI Campus"
            ),
            
            // July 14 - Coffee shop coding
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 14, hour: 15, minute: 20),
                modifiedAt: createDate(year: 2025, month: 7, day: 14, hour: 15, minute: 35),
                title: "Afternoon at Philz",
                content: """
                Found my perfect coding spot at Philz Coffee. The Mint Mojito iced coffee is keeping me energized while I work through the Gemi UI designs.
                
                There's a good vibe here - other students coding, soft indie music, and the smell of fresh coffee. Sometimes I code better with ambient noise than in complete silence.
                
                Just had a breakthrough on the glass morphism effects. The key is subtle layering and the right amount of blur. Sarah's going to love this when she sees it tomorrow.
                
                Days like this remind me why I love being a developer. Creating something from nothing, one line at a time.
                """,
                tags: ["productive", "coding", "creative"],
                mood: .happy,
                weather: "Warm afternoon, 81°F",
                location: "Philz Coffee, Irvine"
            ),
            
            // July 17 - Family video call
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 17, hour: 19, minute: 0),
                modifiedAt: createDate(year: 2025, month: 7, day: 17, hour: 19, minute: 20),
                title: "Weekly Family Call",
                content: """
                Just finished our weekly family video call. My little sister Emma is learning Python! She's only 16 but already writing her first programs. I promised to mentor her this summer.
                
                Mom's been bragging to all her friends about my Google job. It's embarrassing but also heartwarming. Dad asked if I'm eating well - typical Korean parent concern. I assured him the occasional In-N-Out burger counts as a balanced meal.
                
                할머니 (grandma) joined the call from Seoul. Even at 85, she's sharp as ever. She said she's proud that I'm working on technology that helps people. That hit differently.
                
                These calls ground me. No matter how stressful things get, family is what matters.
                """,
                tags: ["family", "grateful", "connection"],
                mood: .grateful,
                weather: "Evening, 73°F",
                location: "My Apartment"
            ),
            
            // July 21 - Technical reading
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 21, hour: 22, minute: 15),
                modifiedAt: createDate(year: 2025, month: 7, day: 21, hour: 22, minute: 30),
                title: "Deep Dive into Privacy Tech",
                content: """
                Spent the evening reading papers on differential privacy and federated learning. The more I learn, the more I realize how important our work on Gemi is.
                
                People share their deepest thoughts in diaries. That data is sacred. The fact that we can provide AI assistance without that data ever leaving their device feels revolutionary.
                
                Found an interesting paper on homomorphic encryption. Maybe overkill for Gemi v1, but fascinating possibilities for the future. Imagine AI that can work with encrypted data without ever decrypting it.
                
                My brain is full but inspired. This is why I chose tech - to solve problems that matter.
                """,
                tags: ["learning", "technical", "inspired"],
                mood: .excited,
                weather: "Night, 70°F",
                location: "Home Office"
            ),
            
            // July 24 - Pre-demo nerves
            JournalEntry(
                id: UUID(),
                createdAt: createDate(year: 2025, month: 7, day: 24, hour: 23, minute: 55),
                modifiedAt: createDate(year: 2025, month: 7, day: 25, hour: 0, minute: 10),
                title: "Can't Sleep",
                content: """
                It's almost midnight and I can't sleep. Tomorrow we record the demo that could validate a month of hard work.
                
                I keep running through the script in my head. What if Ollama crashes? What if the AI gives a weird response? What if... what if... what if...
                
                But then I remember - we built something real. Something that helps people. Whether we win or not, Gemi exists and it works. We created an AI companion that respects privacy. That's already a win.
                
                Sarah texted "We got this! 💪" and somehow that made me feel better. Time to try sleeping again. Big day tomorrow.
                """,
                tags: ["anxious", "hopeful", "reflection"],
                mood: .anxious,
                weather: "Late night, 68°F",
                location: "Bedroom"
            )
        ]
        
        // Preload encryption key to prevent repeated keychain prompts
        try await database.preloadEncryptionKey()
        
        // Save all entries using batch operation
        try await database.saveEntries(entries)
        
        // Create and save memories for each entry
        var allMemories: [MemoryData] = []
        for entry in entries {
            let memories = createMemoriesForEntry(entry)
            allMemories.append(contentsOf: memories)
        }
        
        // Save all memories in batch
        for memory in allMemories {
            try await database.saveMemory(memory)
        }
        
        print("Demo entries and memories created successfully!")
    }
    
    private func createDate(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(identifier: "America/Los_Angeles")
        
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private func createMemoriesForEntry(_ entry: JournalEntry) -> [MemoryData] {
        var memories: [MemoryData] = []
        
        // Extract memories based on entry content
        switch entry.title {
        case "Pre-Interview Jitters":
            memories.append(MemoryData(
                content: "I have an interview scheduled with Google for their DeepMind team working on Gemma models.",
                sourceEntryID: entry.id
            ))
            memories.append(MemoryData(
                content: "Jake is my roommate who helps with mock interviews.",
                sourceEntryID: entry.id
            ))
            
        case "Post-Interview Relief":
            memories.append(MemoryData(
                content: "I successfully completed the Google interview, which included technical rounds, system design (distributed ML training pipeline), and discussions about privacy-preserving AI.",
                sourceEntryID: entry.id
            ))
            memories.append(MemoryData(
                content: "Sarah is one of my close friends who celebrated with me after the interview.",
                sourceEntryID: entry.id
            ))
            
        case "THE CALL!!! 🎉":
            memories.append(MemoryData(
                content: "I got the job at Google! I'll be joining the DeepMind team working on next-gen Gemma models starting in September.",
                sourceEntryID: entry.id
            ))
            memories.append(MemoryData(
                content: "My mother cried happy tears when I shared the news about getting the Google job.",
                sourceEntryID: entry.id
            ))
            
        case "Korean BBQ Celebration":
            memories.append(MemoryData(
                content: "My parents live in LA and drove down to Irvine to celebrate my Google job offer.",
                sourceEntryID: entry.id
            ))
            memories.append(MemoryData(
                content: "I am deeply grateful for my parents' sacrifices that made my education possible.",
                sourceEntryID: entry.id
            ))
            
        case "Gemma Hackathon Planning":
            memories.append(MemoryData(
                content: "Sarah and I are building Gemi - an offline AI diary app for the Google Gemma 3n hackathon.",
                sourceEntryID: entry.id
            ))
            memories.append(MemoryData(
                content: "I am passionate about privacy-focused AI and believe it's the future of technology.",
                sourceEntryID: entry.id
            ))
            
        case "Late Night Coding Session":
            memories.append(MemoryData(
                content: "Professor Chen is my professor at UCI who is interested in privacy-preserving ML.",
                sourceEntryID: entry.id
            ))
            memories.append(MemoryData(
                content: "I'm working on a capstone project at UCI - an AI-powered mental health companion app.",
                sourceEntryID: entry.id
            ))
            
        case "2 AM Breakthrough!":
            memories.append(MemoryData(
                content: "Sarah and I successfully got Gemma 3n running locally with Ollama, achieving 50+ tokens/second on my MacBook.",
                sourceEntryID: entry.id
            ))
            
        case "Demo Day Prep":
            memories.append(MemoryData(
                content: "Gemi features include offline capability, multilingual support, memories feature, and writing tools.",
                sourceEntryID: entry.id
            ))
            
        default:
            // For other entries, extract general context if needed
            if entry.title == "Weekend Thoughts at Laguna Beach" {
                memories.append(MemoryData(
                    content: "I find peace and clarity at the beach, especially Laguna Beach.",
                    sourceEntryID: entry.id
                ))
            } else if entry.title == "Weekly Family Call" {
                memories.append(MemoryData(
                    content: "My little sister Emma is 16 and learning Python. I promised to mentor her this summer.",
                    sourceEntryID: entry.id
                ))
                memories.append(MemoryData(
                    content: "My grandmother (할머니) is 85 years old and lives in Seoul. She's proud that I'm working on technology that helps people.",
                    sourceEntryID: entry.id
                ))
            } else if entry.title == "Morning Run Thoughts" {
                memories.append(MemoryData(
                    content: "I run around Aldrich Park at UCI early in the mornings. Exercise helps me think more clearly.",
                    sourceEntryID: entry.id
                ))
            } else if entry.title == "Afternoon at Philz" {
                memories.append(MemoryData(
                    content: "Philz Coffee is my favorite coding spot. The Mint Mojito iced coffee helps me focus.",
                    sourceEntryID: entry.id
                ))
            }
        }
        
        return memories
    }
}