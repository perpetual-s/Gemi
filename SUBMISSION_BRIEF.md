# Gemi Submission Brief

This file is the clean, submission-safe pitch for Gemi. It is meant to help with hackathon forms, demo narration, judge Q and A, repo sharing, and last-minute copywriting.

## Core Positioning

Gemi is a private AI diary for macOS powered by Gemma 3n. It gives people an intelligent journaling companion without sending their most personal writing to a cloud backend.

The strongest angle is not "yet another AI chat app." The strongest angle is:

- personal reflection is deeply private
- most AI journaling products require trust in the cloud
- Gemi removes that tradeoff with local Gemma 3n inference, encrypted local storage, and a thoughtful native writing experience

## Safe Claims To Lead With

- Native macOS diary app built in SwiftUI
- Powered by local Gemma 3n via Ollama
- Journal content stored locally and encrypted with AES-256-GCM
- Local password and biometric protection
- Journal-aware AI chat with contextual memory
- Image-aware multimodal chat support
- AI memory extraction from journal entries
- Writing tools, prompt support, Focus Mode, and Insights
- 20 localized UI languages

## Claims To Avoid Or Qualify

Do not overclaim these in the submission:

- Do not say audio and video are fully supported end to end today
- Do not say there is cloud sync, a mobile app, or collaborative sharing
- Do not describe it as therapy, diagnosis, or a medical product
- Do not imply full offline setup if Ollama and the model still need to be downloaded first

The safe phrasing is:

- runtime journaling and AI use are local once setup is complete
- chat attachments currently support images
- audio-related scaffolding exists, but the current multimodal path is image-first

## Best One-Liner

Gemi is a private AI diary for macOS that uses Gemma 3n locally to turn journaling into a secure, reflective, image-aware personal companion.

## Short Submission Copy

Gemi is a private AI diary built for people who want the benefits of AI reflection without sending intimate writing to the cloud. It runs Gemma 3n locally through Ollama, stores entries in encrypted local storage, and wraps that capability in a native macOS experience with journaling, chat, memory extraction, writing tools, focus mode, and insights.

## Medium Submission Copy

Gemi is a native macOS diary app that uses Gemma 3n locally to make private journaling actually intelligent. Instead of forcing users to upload deeply personal writing to a remote service, Gemi keeps the main experience on-device: journal entries are stored locally, encrypted with AES-256-GCM, protected with Keychain-backed security, and paired with local AI chat through Ollama. Beyond basic chat, Gemi extracts important memories from entries, offers writing assistance, supports image-aware conversations, surfaces mood and writing insights, and provides a polished Focus Mode for distraction-free reflection. The core idea is simple: people should not have to choose between privacy and meaningful AI support.

## Gemma 3n-Specific Answer

Gemma 3n is the core intelligence layer in Gemi. We use it for contextual journal chat, memory extraction, reflective writing assistance, prompt generation, and multimodal responses enriched with image understanding. Gemma 3n is especially valuable here because it makes a privacy-first local experience feasible without reducing the product to a toy demo. The project is not just "using a model"; it is built around what local Gemma unlocks for a sensitive use case.

## Problem And Solution Framing

### Problem

Journaling is one of the most personal forms of writing, but most AI-assisted journaling experiences rely on cloud processing. That creates an immediate trust problem: the more useful the product becomes, the more sensitive the data it sees.

### Solution

Gemi keeps the intelligence close to the user. It runs Gemma 3n locally through Ollama, stores entries in encrypted local storage, and turns journaling into a private reflective workflow with chat, memory, prompts, and insights.

### Why It Matters

If AI is going to help with reflection, self-understanding, and creative expression, it needs a privacy model people can actually believe in. Gemi makes that promise concrete in product form, not just in theory.

## What Makes The Project Feel Complete

- Beautiful onboarding for Gemma and Ollama setup
- Real desktop app, not just a notebook or prototype screen
- Multiple surfaces for value: writing, chat, memories, insights, prompts, focus mode
- Clear privacy architecture
- Localized UI in 20 languages
- Assets already prepared for presentation and demo

## Best Demo Flow

Use this for a 2 to 3 minute demo:

1. Start on onboarding or the home screen and anchor the story around privacy-first AI journaling.
2. Create or open a journal entry and show the native writing experience.
3. Trigger the writing tools with `Cmd+Shift+W` to show continuation, ideas, or improvement.
4. Open chat and ask Gemi to reflect on the entry or connect it to past writing.
5. Drop in an image and show image-aware multimodal context.
6. Open Memories to show extracted personal context.
7. Open Insights to show patterns, mood tracking, or streaks.
8. Close by restating that the experience runs on local Gemma 3n with encrypted local storage.

## Recommended Submission Narrative

If the form is open-ended, center the story in this order:

1. Personal writing is private.
2. AI can genuinely help with reflection.
3. Today, those usually conflict.
4. Gemi uses Gemma 3n to remove that tradeoff on the desktop.
5. The result is a product, not just a model demo.

## Asset Suggestions

Use these repo assets depending on the form:

- `assets/meet-gemi.png`: best cover image
- `assets/gemi-overview.png`: product overview collage
- `assets/intro-gemi-detailed.png`: privacy slide
- `assets/multimodal-architecture.png`: technical architecture
- `assets/more-features.png`: breadth of product
- `assets/magic-command.png`: standout writing assistant feature

## Repo-Grounded Evidence Map

These files back up the main submission claims:

- Local Gemma 3n startup and onboarding: `Gemi/GemiApp.swift`, `Gemi/Views/Onboarding/GemmaOnboardingView.swift`
- Local Ollama integration: `Gemi/Services/OllamaChatService.swift`, `Gemi/Services/OllamaInstaller.swift`, `Gemi/Services/AIService.swift`
- Encrypted local storage: `Gemi/Services/DatabaseManager.swift`
- Local auth and biometrics: `Gemi/Services/AuthenticationManager.swift`
- Memory extraction and journal-aware context: `Gemi/Services/GemiAICoordinator.swift`, `Gemi/Services/MemoryManager.swift`
- Image-aware multimodal support: `Gemi/Services/MultimodalAIService.swift`, `Gemi/Services/LightweightVisionService.swift`, `Gemi/Views/GemiChatView.swift`
- Writing tools and command bar: `Gemi/Views/WritingAssistant/CommandBarAssistant.swift`, `Gemi/Services/WritingAssistanceService.swift`, `Gemi/Views/ProductionComposeView.swift`
- Insights and analytics: `Gemi/Views/InsightsView.swift`, `Gemi/Services/AnalyticsService.swift`
- Focus experience: `Gemi/Views/FocusMode/FocusModeView.swift`
- Localization support: `Gemi/Services/LocalizationManager.swift`, `Gemi/Resources/*.lproj`

## Honest Caveats For Judges

If a judge asks sharp technical questions, these are safe answers:

- Yes, the app depends on Ollama for local Gemma 3n inference.
- Yes, initial setup requires downloading Ollama and the model.
- Yes, the app uses network access for setup and support flows.
- No, the main journal intelligence flow does not rely on a remote AI backend.
- The current multimodal path is strongest for images.

## Strong Final Line

Gemi shows what personal AI should feel like: private by default, useful in everyday life, and powered locally by Gemma 3n where trust matters most.
