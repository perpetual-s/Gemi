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
                    "What small win would make today successful?",
                    "How do you want to feel by the end of today?",
                    "What's the first thing that made you smile this morning?",
                    "If today had a theme song, what would it be?",
                    "What energy are you bringing into the world today?",
                    "What would make today meaningful for you?",
                    "How can you be kind to yourself today?",
                    "What's one thing you'll do differently today?",
                    "What color represents your mood this morning?",
                    "If you could have breakfast with anyone, who would it be?",
                    "What habit would you like to start today?",
                    "What are three words to guide your day?",
                    "How will you make someone else's day better?",
                    "What challenge are you ready to face today?",
                    "What would your ideal morning look like?"
                ]
            case .afternoon:
                return [
                    "How has your day been so far?",
                    "What surprised you today?",
                    "What's been on your mind lately?",
                    "Describe a moment that made you smile today.",
                    "What challenge did you overcome today?",
                    "What's something new you learned?",
                    "How's your energy level right now?",
                    "What conversation stuck with you today?",
                    "What task are you procrastinating on?",
                    "How are you different from who you were this morning?",
                    "What small victory can you celebrate?",
                    "What's the most interesting thing you've seen today?",
                    "How have you grown since lunch?",
                    "What would you tell your morning self?",
                    "What pattern have you noticed today?",
                    "What's working well in your life right now?",
                    "How can you make the rest of your day count?",
                    "What memory from today do you want to keep?",
                    "What assumption did you question today?",
                    "How did you surprise yourself today?"
                ]
            case .evening:
                return [
                    "How are you feeling as the day winds down?",
                    "What was the highlight of your day?",
                    "What would you do differently today?",
                    "Who made a positive impact on your day?",
                    "What accomplishment are you proud of?",
                    "How did you grow today?",
                    "What moment from today deserves to be remembered?",
                    "How did you take care of yourself today?",
                    "What made you laugh today?",
                    "What wisdom did today bring you?",
                    "How were you brave today?",
                    "What beauty did you notice today?",
                    "What are you leaving unfinished, and is that okay?",
                    "How did you make a difference today?",
                    "What story from today would you tell a friend?",
                    "What did you learn about yourself today?",
                    "How did today surprise you?",
                    "What are you most grateful for this evening?",
                    "What would you like to remember about today in a year?",
                    "How did you honor your values today?"
                ]
            case .night:
                return [
                    "What thoughts are keeping you up?",
                    "Write a letter to tomorrow's you.",
                    "What are you grateful for today?",
                    "Describe today in three words.",
                    "What do you want to dream about?",
                    "What would make tomorrow better?",
                    "What are you ready to release before sleep?",
                    "How can you be gentle with yourself right now?",
                    "What peace can you find in this moment?",
                    "What did today teach you about yourself?",
                    "If today was a chapter, what would you title it?",
                    "What are you looking forward to tomorrow?",
                    "How did you show love today?",
                    "What worry can you set down tonight?",
                    "What would you whisper to the stars?",
                    "How has your heart changed today?",
                    "What blessing did today bring?",
                    "What question will you sleep on tonight?",
                    "How can tomorrow be a fresh start?",
                    "What comfort do you need right now?"
                ]
            case .weekend:
                return [
                    "How do you want to spend your free time?",
                    "What adventures await this weekend?",
                    "What have you been putting off that you could do today?",
                    "How can you recharge this weekend?",
                    "What would make this weekend memorable?",
                    "Who would you like to connect with?",
                    "What's your definition of a perfect weekend?",
                    "How can you practice self-care today?",
                    "What hobby have you been neglecting?",
                    "Where would you go if you could teleport anywhere?",
                    "What would you do with no obligations today?",
                    "How can you bring more joy into your weekend?",
                    "What local adventure could you embark on?",
                    "Who haven't you talked to in a while?",
                    "What would your ideal Sunday morning include?",
                    "How can you disconnect from work today?",
                    "What creative project calls to you?",
                    "What would make you feel accomplished by Sunday night?",
                    "How can you romanticize your weekend?",
                    "What spontaneous thing could you do today?"
                ]
            case .reflection:
                return [
                    "What patterns have you noticed in your life lately?",
                    "How have you changed in the last year?",
                    "What advice would you give your younger self?",
                    "What belief about yourself has shifted recently?",
                    "What chapter of your life are you in right now?",
                    "What legacy do you want to leave?",
                    "What old version of yourself are you ready to release?",
                    "How are you becoming who you want to be?",
                    "What truth have you been avoiding?",
                    "What would your future self thank you for?",
                    "How has your definition of success evolved?",
                    "What fear no longer serves you?",
                    "What parts of your story need rewriting?",
                    "How have your priorities shifted lately?",
                    "What would you tell someone going through what you've experienced?",
                    "What life lesson keeps appearing for you?",
                    "How are you different from who you were five years ago?",
                    "What role are you ready to step into?",
                    "What have you outgrown?",
                    "How can you honor both who you were and who you're becoming?"
                ]
            case .gratitude:
                return [
                    "List five things you're grateful for right now.",
                    "Who in your life deserves a thank you?",
                    "What simple pleasure brought you joy recently?",
                    "What ability or skill are you thankful for?",
                    "What mistake taught you something valuable?",
                    "What ordinary moment felt extraordinary?",
                    "What part of your daily routine do you appreciate?",
                    "How has someone shown you kindness lately?",
                    "What challenge are you grateful for?",
                    "What memory always makes you smile?",
                    "What aspect of your health do you appreciate?",
                    "What freedom do you enjoy that others might not?",
                    "What technology makes your life easier?",
                    "What natural beauty have you witnessed recently?",
                    "What comfort do you often take for granted?",
                    "What opportunity are you thankful for?",
                    "What book, song, or movie has impacted you positively?",
                    "What quality in yourself are you grateful for?",
                    "What coincidence turned out to be a blessing?",
                    "What small act of kindness touched your heart?"
                ]
            case .creativity:
                return [
                    "If your life was a movie, what would today's scene be?",
                    "Describe your ideal day in vivid detail.",
                    "What would you do with unlimited resources?",
                    "Write a haiku about your current mood.",
                    "If you could have dinner with anyone, who and why?",
                    "What superpower would help you most right now?",
                    "Design your dream home in words.",
                    "What would your autobiography be titled?",
                    "If you were a color today, which would you be and why?",
                    "Create a menu for a dinner party reflecting your life.",
                    "What would you invent to make life better?",
                    "Describe your perfect creative workspace.",
                    "If you could master any skill instantly, what would it be?",
                    "Write a love letter to your favorite place.",
                    "What mythical creature best represents you?",
                    "Design a new holiday and how to celebrate it.",
                    "What would your personal logo look like?",
                    "If you could soundtrack your day, what songs would you choose?",
                    "Describe the view from your ideal writing spot.",
                    "What would you name your boat, and where would you sail?"
                ]
            case .emotional:
                return [
                    "What emotion are you avoiding right now?",
                    "How does your body feel in this moment?",
                    "What would you say to a friend feeling like you do?",
                    "What boundary do you need to set?",
                    "What are you ready to let go of?",
                    "How can you show yourself compassion today?",
                    "What does your inner child need to hear?",
                    "Where do you feel tension in your body?",
                    "What emotion have you been carrying too long?",
                    "How can you validate your feelings right now?",
                    "What would it feel like to forgive yourself?",
                    "What does emotional safety mean to you?",
                    "How do you want to be comforted?",
                    "What feeling are you ready to express?",
                    "What would acceptance look like in this situation?",
                    "How can you create space for all your emotions?",
                    "What does your heart need right now?",
                    "What emotional weight can you set down?",
                    "How has vulnerability served you?",
                    "What healing are you ready to receive?"
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
        (text: "Either write something worth reading or do something worth writing.", author: "Benjamin Franklin"),
        (text: "I can shake off everything as I write; my sorrows disappear, my courage is reborn.", author: "Anne Frank"),
        (text: "The unexamined life is not worth living.", author: "Socrates"),
        (text: "Writing is a way of talking without being interrupted.", author: "Jules Renard"),
        (text: "In the journal I do not just express myself more openly than I could to any person; I create myself.", author: "Susan Sontag"),
        (text: "The best time to plant a tree was 20 years ago. The second best time is now.", author: "Chinese Proverb"),
        (text: "Writing is the only way I have to explain my own life to myself.", author: "Pat Conroy"),
        (text: "A journal is your completely unaltered voice.", author: "Lucy Dacus"),
        (text: "Document the moments you feel most in love with yourself.", author: "Warsan Shire"),
        (text: "Writing is medicine. It is an appropriate antidote to injury.", author: "Julia Cameron"),
        (text: "The journal is a vehicle for my sense of selfhood.", author: "Joan Didion"),
        (text: "In order to write about life first you must live it.", author: "Ernest Hemingway"),
        (text: "We write to taste life twice, in the moment and in retrospect.", author: "Anaïs Nin"),
        (text: "Your journal is like your best friend, only better.", author: "Sandra Magsamen"),
        (text: "Writing is thinking on paper.", author: "William Zinsser"),
        (text: "The act of writing is the act of discovering what you believe.", author: "David Hare"),
        (text: "Journal writing gives us insights into who we are.", author: "Robin Sharma"),
        (text: "Writing in a journal reminds you of your goals and of your learning in life.", author: "Robin Sharma"),
        (text: "Keeping a journal will change your life in ways that you'd never imagine.", author: "Oprah Winfrey"),
        (text: "Writing is a form of therapy.", author: "Graham Greene"),
        (text: "The pen is the tongue of the mind.", author: "Miguel de Cervantes")
    ]
    
    static func random() -> (text: String, author: String) {
        quotes.randomElement() ?? quotes[0]
    }
}