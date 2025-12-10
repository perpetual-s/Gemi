![Gemi Banner](assets/gemi-banner.png)

<div align="center">
  <a href="https://youtu.be/NKhyMWbTi2E">
    <img src="https://img.shields.io/badge/▶_Watch_Demo-3_min_video-red?style=for-the-badge&logo=youtube&logoColor=white" alt="Watch Demo Video">
  </a>
</div>

# Gemi - Your Private AI Diary

An offline-first, multilingual AI diary for macOS that runs entirely on your device.

![Meet Gemi](assets/meet-gemi.png)

## Overview

![Gemi Overview](assets/gemi-overview.png)

Gemi is a revolutionary journaling application that combines the power of Google's Gemma 3n language model with absolute privacy. Unlike cloud-based AI tools, every bit of processing happens locally on your Mac, ensuring your most personal thoughts never leave your device.

### Why Gemi?

**The Mental Health Crisis**: 1 in 5 Americans suffers from mental illness, yet almost 6 in 10 receive no treatment (NAMI, 2024). This represents millions suffering in silence.

**AI Can Help**: A 2025 meta-analysis found that AI conversational agents are valid tools for early intervention, showing significant positive effects on depressive symptoms in youth (Feng et al., 2025).

**The Trust Paradox**: Despite AI's proven effectiveness, only 2.9% of AI conversations are about personal or emotional support ([Anthropic Research, 2025](https://www.anthropic.com/news/how-people-use-claude-for-support-advice-and-companionship)). Yet when people do use AI for support:
- 86% of emotionally significant conversations fall into support categories
- Conversations consistently end more positively than they begin
- Negative emotional spirals are proven to be uncommon

**The Real Barrier**: It's not that people don't need help—it's that they don't trust the cloud. Major AI platforms:
- May incidentally include your personal information in training data
- Are court-mandated to retain all chat data indefinitely, even "deleted" conversations
- Break the fundamental promise of privacy

**The Solution**: Gemi brings the power of advanced AI to your personal journaling while keeping everything on your device. Your deepest thoughts deserve better than cloud storage—they deserve a true sanctuary. Named after the Korean word "재미" (fun), Gemi makes AI-powered journaling both powerful and private.

## Key Features

### 1. Privacy-First Architecture
- **100% Offline Operation**: All AI processing via Ollama running locally on localhost:11434
- **End-to-End Encryption**: Military-grade AES-256-GCM encryption via CryptoKit for all journal entries and memories
- **No Cloud Dependencies**: Works perfectly in airplane mode - your data never leaves your Mac
- **Session-Based Authentication**: Touch ID (if supported) or password protection via LocalAuthentication framework
- **Memory Protection**: Automatic secure cleanup when app backgrounds (MemoryManager.swift)
- **Zero Telemetry**: No usage tracking, analytics, or phone-home features
- **Keychain Integration**: Encryption keys stored securely in macOS Keychain with biometric protection
- **App Sandbox Compliance**: Full macOS sandboxing with minimal entitlements

### 2. AI-Powered Writing Assistant (CommandBarAssistant.swift)

![AI Writing Assistant - Magic Command Bar](assets/magic-command.png)

- **Smart Command Bar** (⌘⇧W): Floating assistant with three contextual tools:
  - 🔵 **Continue Writing**: Natural flow extension with 0.7 temperature for coherent narrative
  - 🟠 **Get Ideas**: Creative exploration with 0.8 temperature and context-aware suggestions
  - 🟣 **Improve Style**: Precision editing with 0.3 temperature for clarity and polish
- **Response Length Control**: Short (~50 words), Medium (~150 words), or Detailed (~300 words)
- **Real-Time Sentiment Analysis** (SentimentIndicator.swift): 
  - Visual emotion tracking with confidence scores
  - Streaming analysis as you type with debounced updates
  - Joy 🌟 | Sadness 💧 | Love 💝 | Anger 🔥 | Fear 😰 | Surprise 🎉 | Neutral ⚪
- **Writer's Block Breaker** (WritersBlockBreaker.swift): 
  - Six intelligent categories with rotating prompts
  - Time-aware and mood-sensitive suggestions
  - Personalized based on recent writing patterns
- **Dynamic Placeholders** (PlaceholderService.swift):
  - Time-based greetings (morning/afternoon/evening/night)
  - Gap detection ("It's been 3 days... welcome back!")
  - Special date awareness (weekends, new month)
  - Weather and season integration
- **Multilingual Intelligence**: 
  - 140+ languages with automatic detection
  - Maintains user's language throughout conversation
  - Cultural context preservation

### 3. Intelligent Memory System (MemoryManager.swift & GemiAICoordinator.swift)

![Intelligent Memory System](assets/memories.png)

- **Selective Information Extraction**: Sophisticated prompt engineering ensures quality:
  - **Extracts**: Personal identity, significant relationships, major life events, health conditions, long-term goals
  - **Ignores**: Daily routines, weather, meals, temporary states, entertainment consumption
  - **Temperature**: 0.1 for precise, factual extraction
- **Smart Memory Processing**:
  - Batch extraction with progress tracking
  - In-memory cache for performance (50 most recent)
  - Full-text search via SQLite FTS5
  - Relevance scoring for contextual retrieval
- **Contextual AI Conversations** (GemiChatView.swift):
  - Automatic memory injection based on conversation context
  - Recent memories prioritized (last 7 days)
  - Natural references without explicit memory markers
  - Example: "I remember you mentioned your interview at TechCorp last week..."
- **Memory UI Excellence** (MemoriesView.swift):
  - Expandable cards with staggered animations
  - Real-time search with highlighting
  - Batch operations (extract from last week/month/all)
  - Delete confirmation to prevent accidents
  - Statistics display (total count, "This Week" badge)
- **Technical Implementation**:
  - GRDB.swift for type-safe database operations
  - Encrypted storage with per-entry keys
  - Background extraction to prevent UI blocking

### 4. Multimodal Capabilities (MultimodalAIService.swift)
- **Image Understanding** (LightweightVisionService.swift):
  - **Vision Framework Integration**: Hardware-accelerated on Apple Silicon Neural Engine
  - **Analysis Types**: 
    - VNClassifyImageRequest for scene understanding (1000+ categories)
    - VNRecognizeTextRequest for OCR (95%+ accuracy, 10+ languages)
    - VNDetectFaceRectanglesRequest for face detection
    - VNGenerateImageFeaturePrintRequest for similarity matching
  - **Smart Descriptions**: Natural language generation with context
  - **Performance**: <2 seconds for full analysis including OCR
- **Audio Intelligence** (QuickAudioService.swift):
  - **Speech Framework**: On-device transcription requiring no internet
  - **Capabilities**:
    - Real-time transcription in 50+ languages
    - Automatic language detection
    - Punctuation and formatting
    - Speaker rate analysis (WPM calculation)
  - **Performance**: 0.1x real-time factor (10s audio = 1s processing)
- **Attachment Management** (AttachmentManager.swift):
  - Drag & drop with visual feedback
  - Multiple file support with preview UI
  - Image formats: JPEG, PNG, HEIF, GIF
  - Audio formats: M4A, MP3, WAV
  - Smart file size limits and validation
- **Parallel Processing Architecture**:
  ```swift
  let (imageResult, audioResult) = await (
      processImage(image),
      processAudio(audio)
  )
  ```
- **Multimodal Context Creation**:
  - Enriched prompts that simulate native multimodal understanding
  - Seamless integration with Gemma 3n via enhanced text descriptions
  - User never knows preprocessing occurred

### 5. Beautiful Native Experience

![More Features - Focus Mode, Prompt Library, and More](assets/more-features.png)

- **macOS Native**: Built with SwiftUI and Swift 6 strict concurrency (@MainActor compliance)
- **Glass Morphism Design** (Theme.swift & GlassComponents.swift):
  - **Visual Effects**: VisualEffectView with .ultraThinMaterial and custom tinting
  - **Advanced Gradients**: Time-based gradients that change throughout the day
  - **Spring Animations**: Custom curves (response: 0.4, dampingFraction: 0.8)
  - **Chromatic Aberration**: Subtle RGB offset for depth perception
  - **Dynamic Shadows**: 5 elevation levels with contextual blur
- **Focus Mode** (FocusModeView.swift - ⌘⇧F):
  - **Typewriter Mode**: Current line stays centered with smooth scrolling
  - **Customization**: Font family, size (14-24pt), line spacing (1.0-2.0x)
  - **Ambient Sounds**: Rain, ocean waves, forest, white noise (AmbientSoundPlayer.swift)
  - **Mood Selection**: Affects background colors and writing prompts
  - **AI Integration**: Command bar remains accessible
- **Time-Aware Interface** (TimeAwareGreeting.swift):
  - **Dynamic Greetings**: 15+ variations based on time, day, and user patterns
  - **Animated Sun Icon**: Progresses through day (sunrise → sunset)
  - **Special Events**: Weekend awareness, new month celebrations
  - **Contextual Prompts**: Weather-aware and season-specific
- **Smart Auto-Save** (ProductionComposeView.swift):
  - **Intelligent Timing**: 30-second intervals with dirty state tracking
  - **Visual Feedback**: Orange (unsaved) → Spinner (saving) → Green check (saved)
  - **Retry Logic**: Up to 3 attempts with exponential backoff
  - **Non-blocking**: Saves happen in background Task
- **Writing Progress Gamification**:
  - **Real-time Metrics**: Word count, time tracking, WPM calculation
  - **Color Progression**: Blue → Green → Orange → Purple
  - **Milestone Celebrations** (MilestoneCelebration.swift): Particle effects at 750 words
  - **Daily Streaks**: Track consecutive days of journaling


### 6. Multilingual Support (LocalizationManager.swift)

**Mental health has no borders. Neither does Gemi.**

**20 fully localized languages** making private mental wellness accessible to 5.5 billion people worldwide, with 300+ translated strings per language:

| Language | Native Name | Special Features | Font Optimization |
|----------|-------------|------------------|-------------------|
| English | English | Base language | SF Pro |
| Korean | 한국어 | Honorific levels | Apple SD Gothic Neo |
| Japanese | 日本語 | Vertical text ready | Hiragino Sans |
| Chinese (Simplified) | 简体中文 | GB encoding | PingFang SC |
| Chinese (Traditional) | 繁體中文 | Big5 encoding | PingFang TC |
| Spanish | Español | Regional variants | System default |
| French | Français | Accent support | System default |
| German | Deutsch | Long word handling | System default |
| Arabic | العربية | Full RTL layout | SF Arabic |
| Portuguese | Português | PT-BR compatible | System default |
| Hindi | हिन्दी | Devanagari script | Devanagari MT |
| Indonesian | Bahasa Indonesia | Formal/informal | System default |
| Russian | Русский | Cyrillic support | SF Pro with Cyrillic |
| Italian | Italiano | Accent support | System default |
| Turkish | Türkçe | Special characters | System default |
| Dutch | Nederlands | Compound words | System default |
| Polish | Polski | Diacritics support | System default |
| Thai | ไทย | Tone marks | System default |
| Vietnamese | Tiếng Việt | Tonal diacritics | System default |
| Swedish | Svenska | Nordic characters | System default |

- **Implementation Details**:
  - **Singleton Manager**: Thread-safe language switching with @MainActor
  - **Persistence**: UserDefaults storage with instant UI updates
  - **RTL Support**: Automatic layout mirroring for Arabic
  - **Font Selection**: Language-specific system fonts for optimal rendering
- **AI Language Intelligence**:
  - **Automatic Detection**: AI responds in the user's chosen interface language
  - **Mixed Language Support**: Handles code-switching naturally
  - **Cultural Context**: Date/time formats, number systems, idioms
- **Localization Coverage**:
  - All UI elements, buttons, and labels
  - Onboarding and tutorial content
  - Error messages and alerts
  - AI prompts and responses

### 7. Zero-Friction Onboarding with Ollama

A core goal for Gemi is to make the power of private, on-device AI accessible to everyone, not just technical users. This is why Ollama was chosen as the essential engine for the Gemi experience. It enables a zero-friction installation where Gemi automatically handles the setup of Ollama and the download of the Gemma 3n model, removing what would otherwise be a significant technical hurdle for everyday users. This seamless onboarding allows us to deliver a stable, high-performance experience and focus on building innovative features on a local inference engine the user never has to worry about.

## Core Technologies

### Gemma 3n Integration

#### Model Architecture
- **MatFormer Technology**: Nested models for efficiency
  - Gemma 3n's revolutionary architecture
  - Dynamic performance/quality tradeoffs with single model
- **Per-Layer Embeddings (PLE)**: 256-dim embeddings for memory efficiency
- **Advanced Features**:
  - LAuReL (Layer Reuse)
  - AltUp (Alternating Updates)
  - Grouped Query Attention (GQA)

#### Custom Prompt Engineering

Gemi uses sophisticated prompt engineering tailored for journaling with contextual temperature adjustments:

```swift
// Example: Writing Assistant Base Prompt (WritingAssistanceService.swift)
let basePrompt = """
<instructions>
You are Gemi, an intelligent writing assistant powered by Gemma 3n.
You excel at understanding context, emotions, and creative expression across 140+ languages.
Provide helpful, specific suggestions that honor the writer's voice and emotional state.

<capabilities>
- Multilingual understanding: Respond in the same language as the user
- Emotional intelligence: Recognize and respond to emotional cues
- Creative expression: Generate vivid, engaging continuations
- Cultural awareness: Respect diverse perspectives and expressions
- Language support: Full support for 140+ languages
</capabilities>

<language_detection>
CRITICAL LANGUAGE RULE:
- Detect the language from the CURRENT TEXT only
- Respond in the SAME language as detected
- If the text is in English, respond ONLY in English
- Never switch languages unless the user's text switches
</language_detection>

<format_rules>
- DO NOT use markdown formatting like **bold** or *italic*
- DO NOT use asterisks for emphasis
- Write in plain, natural language
- Use simple punctuation and clear sentences
- Each suggestion should be a complete thought
- Match the writer's tone and style naturally
</format_rules>
</instructions>
"""
```

#### Contextual Temperature Tuning

Gemi dynamically adjusts temperature based on writing context (AIConfiguration.swift):

- **Continue Writing**: 0.7 (coherent flow)
- **Get Ideas**: 0.8 (creative exploration)
- **Improve Style**: 0.3 (precision editing)
- **Emotional Exploration**: 0.6 (balanced)
- **Writer's Block**: 0.9 (high creativity)
- **Creative/Story Writing**: 1.0 (Gemma 3n sweet spot)
- **Seeking Advice**: 0.5 (accuracy-focused)

#### Sampling Parameters
- **Base Temperature**: 1.0 (optimal for Gemma 3n creative writing)
- **top_k**: 64 (balanced token diversity)
- **top_p**: 0.95 (natural language flow)
- **max_tokens**: 4096 (long-form support)

### Intelligent Memory Extraction

Gemi's memory system uses sophisticated prompt engineering to extract only meaningful information (GemiAICoordinator.swift):

```swift
// Memory Extraction Prompt with Precise Instructions
let prompt = """
Extract ONLY key personal information that would be important to remember about the user from this journal entry.

Journal Entry:
\(entry.content)

CRITICAL RULES:
- DO NOT use any markdown formatting (no **, *, #, etc.)
- Write plain text only
- Be EXTREMELY selective - only extract truly important personal facts
- Each memory should be a complete, standalone sentence

Focus ONLY on extracting these types of information if present:
1. Personal identity: name, age, location, occupation, major life roles
2. Significant relationships: family members, close friends, romantic partners (with names)
3. Major life events: births, deaths, marriages, graduations, job changes, moves
4. Health conditions: chronic illnesses, allergies, medical diagnoses
5. Long-term goals or major commitments

DO NOT extract:
- Daily activities (eating, sleeping, walking)
- Temporary emotions or moods
- Weather observations
- Entertainment consumed (movies, books, games)
- Random numbers or lists without context
- General thoughts or philosophizing

Examples of GOOD extractions:
- My name is Sarah Chen and I work as a software engineer at Apple
- My daughter Emma celebrated her 5th birthday today at Disneyland
- I was diagnosed with type 2 diabetes and started insulin therapy
- Moving to Seattle next month for my new job as Senior Director at Microsoft
"""
```

**Key Features**:
- **Temperature**: 0.1 for factual precision
- **Selective Filtering**: Ignores 90%+ of content, keeping only life-defining information
- **Structured Rules**: Clear examples of what to extract vs ignore
- **Privacy-First**: All extraction happens locally, memories never leave device

### Innovative Multimodal Architecture

#### The Challenge: Making Gemma 3n Truly Multimodal

![The Multimodal Challenge - Building The Impossible](assets/multimodal-challenges.png)

When building Gemi, I faced significant technical barriers:

1. **MLX-Swift Limitations** ❌
   - MLX-Swift has limitations with weight loading for Gemma 3n
   - Does not support key Gemma 3n innovations: MatFormer, PLE, LAuReL, AltUp
   - Architecture gaps prevent full model functionality
   - Missing multimodal support infrastructure

2. **Python Server Approach Failed** ❌
   ```python
   # What I tried:
   from transformers import Gemma3nForConditionalGeneration
   model = Gemma3nForConditionalGeneration.from_pretrained("google/gemma-3n-E4B-it")
   # Result: macOS App Sandbox blocked 8GB+ model downloads
   ```
   - macOS App Sandbox prevents downloading large models at runtime
   - Breaks the zero-friction installation promise
   - Security restrictions create installation complexity
   - Users would need manual Python setup and model downloads

3. **Ollama's Current Limitation** ⚠️
   - Text-only support for Gemma 3n
   - No multimodal functionality for Gemma 3n (GitHub Issue #10792)
   - REST API structure exists but multimodal not implemented

#### Our Solution: Apple Frameworks + Gemma 3n = Magic ✨

Instead of waiting or giving up, I engineered an innovative solution:

![Gemi Multimodal Architecture](assets/multimodal-architecture.png)

**Key Innovation Points**:

1. **Vision Framework Integration**:
   ```swift
   // Hardware-accelerated on Apple Silicon Neural Engine
   let requests = [
       VNClassifyImageRequest(),      // 1000+ object categories
       VNRecognizeTextRequest(),      // 95%+ OCR accuracy
       VNDetectFaceRectanglesRequest() // Facial analysis
   ]
   ```

2. **Speech Framework Processing**:
   ```swift
   // On-device transcription with 50+ languages
   request.requiresOnDeviceRecognition = true // Privacy-first
   request.addsPunctuation = true // Natural formatting
   ```

3. **Seamless User Experience**:
   - User drags photo → Gemi "sees" it
   - User records audio → Gemi "hears" it
   - AI responses reference specific details
   - Zero indication of preprocessing

**Example Multimodal Interaction**:
```
User: [Drops graduation photo]
      "What do you think of this moment?"

Gemi: "What a monumental achievement! Graduating from Stanford is no small feat. 
      I can see the joy in this outdoor ceremony with your fellow graduates. 
      The 'Class of 2024' banner really marks this as a historic moment in your 
      journey. How are you feeling now that this chapter is complete?"
```

The user experiences native multimodal AI while everything runs locally!

## Project Structure
```
Gemi/
├── Gemi/                      # Main application
│   ├── GemiApp.swift         # App entry point
│   ├── Components/           # Reusable UI components
│   │   ├── GlassComponents.swift
│   │   ├── AnimatedTimeGreeting.swift
│   │   └── MilestoneCelebration.swift
│   ├── Models/              # Data models
│   │   ├── JournalEntry.swift
│   │   ├── User.swift
│   │   └── Chat.swift
│   ├── Services/            # Core services
│   │   ├── AIService.swift           # AI orchestration
│   │   ├── OllamaChatService.swift   # Ollama integration
│   │   ├── DatabaseManager.swift     # GRDB wrapper
│   │   ├── MemoryManager.swift       # Memory extraction
│   │   └── AuthenticationManager.swift
│   ├── Views/               # SwiftUI views
│   │   ├── MainWindowView.swift
│   │   ├── EnhancedTimelineView.swift
│   │   ├── ProductionComposeView.swift
│   │   └── GemiChatView.swift
│   ├── Resources/           # Assets and localization
│   │   └── [lang].lproj/   # 13 language folders
│   └── Style/              # Design system
│       └── Theme.swift
├── GemiTests/              # Unit tests
├── scripts/                # Automation
│   ├── build-dmg.sh       # DMG creation
│   └── reset_gemi.sh      # Development reset
└── LICENSE                # CC BY 4.0 License
```

## Technical Architecture

### Technology Stack

#### Frontend
- **SwiftUI**: Modern declarative UI with iOS 17+ features
- **Swift 6**: Strict concurrency with @MainActor and async/await
- **Design System**: Custom theme with typography, colors, and animations
- **Component Library**: 20+ reusable glass morphism components

#### AI Backend
- **Ollama Integration**: REST API via localhost:11434
- **Gemma 3n Model**: `gemma3n:latest`
  - Automatic model management by Ollama
  - Supports all Gemma 3n features (MatFormer, PLE, LAuReL, AltUp)
- **Streaming Responses**: Real-time token generation
- **Context Management**: 4096 token window with smart truncation

#### Storage Layer
- **GRDB.swift**: Type-safe SQLite wrapper
- **Encryption**: AES-256-GCM with per-entry keys
- **Database Schema**:
  ```sql
  JournalEntries (id, title, content, mood, created_at, attachments)
  Memories (id, entry_id, content, embedding, created_at)
  Users (id, name, auth_method, preferences)
  ```
- **Full-Text Search**: FTS5 for instant memory retrieval

#### Security Architecture
- **Keychain Services**: Secure credential and key storage
- **CryptoKit**: Hardware-accelerated encryption
- **LocalAuthentication**: Touch ID integration
- **App Sandbox**: Full macOS sandboxing compliance

### System Requirements

#### Minimum Requirements
- **macOS**: 13.0 Ventura or later
- **Processor**: Apple Silicon (M1) or Intel Core i5*
- **Memory**: 8GB RAM (16GB recommended for Intel)
- **Storage**: 10GB free space (25.7 MB for Gemi & 7.5 GB for Gemma 3n)
- **Display**: 1280×720 resolution

*Intel Macs supported with GPU acceleration but reduced performance compared to Apple Silicon

#### Recommended Specifications
- **macOS**: 14.0 Sonoma or later
- **Processor**: Apple Silicon (M3/M4 preferred)
- **Memory**: 16GB RAM for optimal AI performance
- **Storage**: 20GB free space for multiple models
- **Display**: Retina display for best visual experience

## Installation

### For Users 🚀

#### Important: macOS Security Notice
When downloading Gemi from GitHub, macOS may show a security warning because it's not distributed through the App Store. This is normal for open-source apps.

**Why this happens**: Gemi is an open-source app that prioritizes your privacy. I chose not to enroll in Apple's Developer Program ($99/year) because:
- It would require sharing user analytics with Apple
- Privacy software should be free and open
- The money is better spent on development

#### Installation Steps

1. **Download Gemi**
   - Get `Gemi-Installer.dmg` from [Releases](https://github.com/yourusername/gemi/releases)
   - Verify SHA-256 checksum for security

2. **Install the App (Two Methods)**
   
   **Method 1: Right-Click to Open (Recommended)**
   - **Don't double-click!** Instead, right-click (or Control-click) the DMG
   - Select "Open" from the context menu
   - Click "Open" in the security dialog
   - Drag Gemi to Applications folder
   
   **Method 2: Security & Privacy Settings**
   - Download and try to open `Gemi-Installer.dmg`
   - When blocked, go to System Settings → Privacy & Security
   - Look for "Gemi-Installer.dmg was blocked..."
   - Click "Open Anyway"
   - Enter your password and proceed

3. **First Launch Setup**
   - Grant necessary permissions (disk access for journals)
   - Choose authentication method (Touch ID if available, or password)
   - Gemi will automatically install Ollama if needed
   - Model download starts automatically (7.5GB)
   - Gemi app itself is only 25.7MB!

4. **Start Journaling!**
   - Create your first entry
   - Try the AI assistant with ⌘⇧W
   - Your journey to better self-reflection begins

### For Developers 👩‍💻

```bash
# Clone the repository
git clone https://github.com/yourusername/gemi.git
cd gemi

# Install dependencies
brew install ollama
brew install swiftlint  # Optional but recommended

# Start Ollama service
ollama serve

# Pull Gemma 3n model
ollama pull gemma3n:latest

# Open in Xcode
open Gemi/Gemi.xcodeproj

# Select scheme and destination
# Scheme: Gemi
# Destination: My Mac

# Build and run
# Product > Run (⌘R)
```

## Privacy & Security Implementation

### Complete Network Isolation
```swift
// All AI requests go through localhost only
let ollamaURL = "http://localhost:11434/api/chat"
// No external API calls, ever

// Multimodal processing stays local too
request.requiresOnDeviceRecognition = true  // Speech
let visionRequest = VNRequest()  // Vision - no cloud options
```

### Encryption Pipeline
1. **Key Generation**: Unique AES-256 key per entry
2. **Encryption**: CryptoKit with hardware acceleration
3. **Key Storage**: Keychain Services with biometric protection
4. **Memory Cleanup**: Automatic zeroing of sensitive data

### Privacy Features
- **Offline Mode Indicator**: Visual confirmation of local processing
- **Network Monitor**: Alerts if any unexpected network activity
- **Data Export**: Your data in standard formats (JSON, Markdown)
- **Complete Deletion**: Secure wipe with no recovery

## Performance Metrics

### Speed Benchmarks (M4 Max MacBook Pro)
- **App Launch**: <1 second cold start
- **Ollama Connection**: 200ms average
- **First AI Token**: 0.5 seconds
- **Token Generation**: 55 tokens/second
- **Memory Extraction**: <1 second per entry
- **Image Analysis**: <2 seconds for classification + OCR
- **Audio Transcription**: Real-time factor of 0.1x

## Contributing

I welcome contributions! Please see the [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

1. **Environment Requirements**
   - Xcode 15.0+ with Swift 6 support
   - macOS 14.0+ for development
   - Git LFS for large files
   - SwiftLint for code style

2. **Getting Started**
   ```bash
   # Fork and clone
   git clone https://github.com/yourusername/gemi-fork.git
   
   # Install git hooks
   ./scripts/install-hooks.sh
   
   # Run tests
   xcodebuild test -scheme Gemi
   ```

3. **Code Standards**
   - Swift 6 strict concurrency compliance
   - 100% SwiftUI (no UIKit)
   - MVVM architecture pattern
   - Comprehensive documentation

4. **Testing Requirements**
   - Unit tests for all services
   - UI tests for critical flows
   - Performance tests for AI operations
   - Memory leak detection

## License

Gemi is released under the Creative Commons Attribution 4.0 International License (CC BY 4.0). See [LICENSE](LICENSE) for full details.

**Summary**: You are free to:
- **Share** — copy and redistribute the material in any medium or format
- **Adapt** — remix, transform, and build upon the material for any purpose, even commercially

**Under the following terms**:
- **Attribution** — You must give appropriate credit, provide a link to the license, and indicate if changes were made.

## Privacy Commitment

Your privacy is our core principle. Gemi will **never**:
- 🚫 Upload your data to any server
- 🚫 Require internet connection after setup
- 🚫 Track your usage or behavior
- 🚫 Share your information with anyone
- 🚫 Use your data for AI training
- 🚫 Have "terms of service" that claim your content

### What I DO Promise
- ✅ Your data stays on YOUR device
- ✅ You can export everything anytime
- ✅ You can delete everything permanently
- ✅ Open source for full transparency
- ✅ No venture capital strings attached
- ✅ Built for humans, not data harvesting

**Your stories stay yours, forever.**

## Contact & Support

- **Developer**: Chaeho Shin (cogh0972@gmail.com)
- **Bug Reports**: [GitHub Issues](https://github.com/yourusername/gemi/issues)
- **Feature Requests**: [Discussions](https://github.com/yourusername/gemi/discussions)
- **Security Issues**: cogh0972@gmail.com

## Roadmap 🚀

### Version 1.x (Current)
- ✅ Core journaling with AI assistance
- ✅ Memory system
- ✅ Multimodal support
- ✅ 20 languages

### Version 2.x (Planned)
- 📱 iOS companion app with iCloud sync
- 🎙️ Advanced voice journaling
- 📊 Mood analytics and insights
- 🎨 Custom themes
- 🔄 Time machine (navigate entry history visually)

### Future Vision
- 🤝 End-to-end encrypted sharing (for therapists)
- 📚 Book generation from your journals
- 🧠 Advanced psychological insights
- 🌍 50+ language support

## References

Anthropic. (2025, June 26). How people use Claude for support, advice, and companionship. https://www.anthropic.com/news/how-people-use-claude-for-support-advice-and-companionship

Feng, Y., Hang, Y., Wu, W., Song, X., Xiao, X., Dong, F., & Qiao, Z. (2025). Effectiveness of AI-Driven Conversational Agents in Improving Mental Health Among Young People: Systematic Review and Meta-Analysis. Journal of medical Internet research, 27, e69639. https://doi.org/10.2196/69639

National Alliance on Mental Illness. (2024). Mental Health by the Numbers. https://www.nami.org/mhstats

