import Foundation

/// Generates intelligent writing prompts based on time, user history, and context
@MainActor
final class WritingPromptGenerator {
    static let shared = WritingPromptGenerator()
    
    private init() {}
    
    enum PromptCategory {
        case morning
        case afternoon
        case evening
        case night
        case weekend
        case reflection
        case gratitude
        case creativity
        case emotional
        
        var prompts: [String] {
            switch self {
            case .morning:
                return [
                    "What are you looking forward to today?",
                    "How did you sleep? What dreams do you remember?",
                    "What's one thing you're grateful for this morning?",
                    "What intention will you set for today?",
                    "Describe your perfect morning routine.",
                    "What small win would make today successful?"
                ]
            case .afternoon:
                return [
                    "How has your day been so far?",
                    "What surprised you today?",
                    "What's been on your mind lately?",
                    "Describe a moment that made you smile today.",
                    "What challenge did you overcome today?",
                    "What's something new you learned?"
                ]
            case .evening:
                return [
                    "How are you feeling as the day winds down?",
                    "What was the highlight of your day?",
                    "What would you do differently today?",
                    "Who made a positive impact on your day?",
                    "What accomplishment are you proud of?",
                    "How did you grow today?"
                ]
            case .night:
                return [
                    "What thoughts are keeping you up?",
                    "Write a letter to tomorrow's you.",
                    "What are you grateful for today?",
                    "Describe today in three words.",
                    "What do you want to dream about?",
                    "What would make tomorrow better?"
                ]
            case .weekend:
                return [
                    "How do you want to spend your free time?",
                    "What adventures await this weekend?",
                    "What have you been putting off that you could do today?",
                    "How can you recharge this weekend?",
                    "What would make this weekend memorable?",
                    "Who would you like to connect with?"
                ]
            case .reflection:
                return [
                    "What patterns have you noticed in your life lately?",
                    "How have you changed in the last year?",
                    "What advice would you give your younger self?",
                    "What belief about yourself has shifted recently?",
                    "What chapter of your life are you in right now?",
                    "What legacy do you want to leave?"
                ]
            case .gratitude:
                return [
                    "List five things you're grateful for right now.",
                    "Who in your life deserves a thank you?",
                    "What simple pleasure brought you joy recently?",
                    "What ability or skill are you thankful for?",
                    "What mistake taught you something valuable?",
                    "What ordinary moment felt extraordinary?"
                ]
            case .creativity:
                return [
                    "If your life was a movie, what would today's scene be?",
                    "Describe your ideal day in vivid detail.",
                    "What would you do with unlimited resources?",
                    "Write a haiku about your current mood.",
                    "If you could have dinner with anyone, who and why?",
                    "What superpower would help you most right now?"
                ]
            case .emotional:
                return [
                    "What emotion are you avoiding right now?",
                    "How does your body feel in this moment?",
                    "What would you say to a friend feeling like you do?",
                    "What boundary do you need to set?",
                    "What are you ready to let go of?",
                    "How can you show yourself compassion today?"
                ]
            }
        }
    }
    
    /// Get a contextual prompt based on current time and conditions
    func getCurrentPrompt() -> String {
        let category = determineCategory()
        let prompts = category.prompts
        
        // Use date as seed for consistent daily prompt
        let today = Calendar.current.startOfDay(for: Date())
        let seed = Int(today.timeIntervalSince1970)
        let index = abs(seed) % prompts.count
        
        return prompts[index]
    }
    
    /// Get a random prompt from a specific category
    func getPrompt(from category: PromptCategory) -> String {
        category.prompts.randomElement() ?? getCurrentPrompt()
    }
    
    /// Get multiple prompts for carousel display
    func getPromptRotation(count: Int = 3) -> [String] {
        let categories = PromptCategory.allCases.shuffled()
        var prompts: [String] = []
        
        for i in 0..<min(count, categories.count) {
            if let prompt = categories[i].prompts.randomElement() {
                prompts.append(prompt)
            }
        }
        
        return prompts
    }
    
    private func determineCategory() -> PromptCategory {
        let hour = Calendar.current.component(.hour, from: Date())
        let weekday = Calendar.current.component(.weekday, from: Date())
        let isWeekend = weekday == 1 || weekday == 7
        
        if isWeekend {
            return .weekend
        }
        
        switch hour {
        case 5..<10:
            return .morning
        case 10..<15:
            return .afternoon
        case 15..<20:
            return .evening
        case 20..<24, 0..<5:
            return .night
        default:
            return .reflection
        }
    }
}

extension WritingPromptGenerator.PromptCategory: CaseIterable {}

/// Inspirational quotes for empty states
struct InspirationQuotes {
    static let quotes = [
        (text: "The life of every man is a diary in which he means to write one story, and writes another.", author: "J.M. Barrie"),
        (text: "Journal writing is a voyage to the interior.", author: "Christina Baldwin"),
        (text: "Fill your paper with the breathings of your heart.", author: "William Wordsworth"),
        (text: "Writing is the painting of the voice.", author: "Voltaire"),
        (text: "There is no greater agony than bearing an untold story inside you.", author: "Maya Angelou"),
        (text: "Start writing, no matter what. The water does not flow until the faucet is turned on.", author: "Louis L'Amour"),
        (text: "You can't use up creativity. The more you use, the more you have.", author: "Maya Angelou"),
        (text: "Write what should not be forgotten.", author: "Isabel Allende"),
        (text: "The scariest moment is always just before you start.", author: "Stephen King"),
        (text: "Either write something worth reading or do something worth writing.", author: "Benjamin Franklin")
    ]
    
    static func random() -> (text: String, author: String) {
        quotes.randomElement() ?? quotes[0]
    }
}