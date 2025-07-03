# Gemi App Architecture Guide

This document provides a comprehensive overview of the Gemi app's architecture to prevent confusion between similar components and clarify the app's structure.

## Overview

Gemi is a privacy-focused, offline-first AI-powered journaling app built with SwiftUI for macOS. It uses the Gemma 3n model via Ollama for AI features.

## App Entry Flow

```
GemiApp.swift (@main)
    ├── Initializes Dependencies
    │   ├── JournalStore
    │   ├── AuthenticationManager (disabled)
    │   ├── OnboardingState
    │   ├── SettingsStore
    │   └── PerformanceOptimizer
    │
    └── MainWindowView.swift (Primary UI)
        ├── Modern Sidebar (30% width)
        │   ├── Timeline
        │   ├── Chat with Gemi
        │   ├── Memories (placeholder)
        │   └── Settings
        │
        └── Content Area (70% width)
            ├── TimelineView
            ├── ChatView
            ├── InsightsView
            └── FullComposeView
```

## Key Components and Their Purposes

### Main Entry Points

| File | Purpose | Status |
|------|---------|--------|
| `GemiApp.swift` | Main app entry point, dependency injection | **Active** |
| `MainWindowView.swift` | Primary window with coffee shop aesthetic | **Active** |
| `ContentView.swift` | Alternative simplified navigation | **Deprecated** - DO NOT USE |

### Timeline Components

| File | Purpose | When to Use |
|------|---------|-------------|
| `TimelineView.swift` | Main timeline display | **Primary timeline component** |
| `TimelineCardView.swift` | Individual entry card | Used by TimelineView |
| `JournalTimelineView.swift` | Feature-rich timeline | **Experimental** - Not in use |

### Editor/Compose Views

| File | Purpose | When to Use |
|------|---------|-------------|
| `FullComposeView.swift` | Full window editor | **Primary editor** (New Entry) |
| `FloatingEntryView.swift` | Read-only floating viewer | View existing entries |
| `FloatingComposeView.swift` | Floating editor | **Deprecated** - Use FullComposeView |
| `ComposeView.swift` | Basic compose | **Deprecated** |
| `JournalEditorView.swift` | Alternative editor | **Experimental** - Not in use |
| `EnhancedJournalEditor.swift` | Enhanced editor | **Experimental** - Not in use |

### Chat Components

| File | Purpose | When to Use |
|------|---------|-------------|
| `ChatView.swift` | Main chat interface | **Primary chat component** |
| `EnhancedChatView.swift` | Enhanced chat | **Experimental** - Not in use |

### Navigation

| Component | Purpose | Location |
|-----------|---------|----------|
| `NavigationModel` | Main navigation state | `Models/NavigationModel.swift` |
| `SimplifiedSidebar` | Simplified navigation | Used by ContentView (deprecated) |
| Modern Sidebar | Primary navigation | Built into MainWindowView |

## Service Layer

### Core Services

```
Gemi/Services/
├── DatabaseManager.swift        # SQLite database operations
├── OllamaService.swift         # Gemma 3n AI integration
├── GemiModelManager.swift      # AI model management
├── KeyboardShortcutManager.swift # Keyboard shortcuts
├── BackupService.swift         # Backup functionality
├── EncryptionService.swift     # AES-256-GCM encryption
└── ExportService.swift         # Export functionality
```

### AI/RAG Services

```
Gemi/Services/JournalRAGService/
├── JournalRAGService.swift     # RAG orchestration
├── EmbeddingService.swift      # Text embeddings
├── ContextRetriever.swift      # Context retrieval
└── JournalChunker.swift        # Text chunking
```

### Important: Duplicate Files Issue

The following files exist in duplicate locations - **USE ONLY THE ONES IN `Gemi/` DIRECTORY**:
- ❌ `./Services/*` - Old location
- ✅ `./Gemi/Services/*` - Correct location
- ❌ `./Stores/*` - Old location  
- ✅ `./Gemi/Stores/*` - Correct location

## State Management

The app uses Swift 6's `@Observable` pattern:

```swift
// Correct pattern
@Observable
final class SomeModel {
    var property: Type
}

// DO NOT USE these patterns:
// @ObservableObject, @StateObject, @EnvironmentObject
```

## Current App Flow

1. **App Launch**: `GemiApp` → `MainWindowView`
2. **Default View**: Timeline showing journal entries
3. **New Entry**: Opens `FullComposeView` in main content area
4. **View Entry**: Opens `FloatingEntryView` as sheet
5. **Chat**: Opens `ChatView` as modal sheet
6. **Settings**: Opens `SettingsView` in content area

## Menu Structure

```
Gemi Menu
├── Chat with Gemma 3n (⌘T)
├── Show Memories (⌘⇧M) - placeholder
└── View Insights (⌘⇧I)

File Menu
├── New Entry (⌘N)
└── Export Entry (⌘⇧E)

View Menu  
├── Toggle Sidebar (⌘⌥S)
├── Go to Today (⌘⇧T)
└── Text Size controls
```

## Key Design Decisions

1. **No Authentication**: Authentication was removed per user request - app launches directly
2. **Local-Only**: All data stored locally with encryption
3. **Offline-First**: Works without internet, AI features require local Ollama
4. **Privacy-Focused**: No telemetry, no cloud sync
5. **Coffee Shop Aesthetic**: Warm, inviting UI with generous spacing

## Common Pitfalls to Avoid

1. **Don't use ContentView** - It's deprecated in favor of MainWindowView
2. **Don't use @StateObject/@ObservableObject** - Use @State/@Observable
3. **Don't create new floating windows** - Use sheets or full window views
4. **Don't use experimental views** - Stick to primary components listed above
5. **Always check for duplicate files** - Use only files in `Gemi/` directory

## Testing the App

1. Build and run: `⌘R`
2. Create new entry: `⌘N` or click "New Entry"
3. Chat with AI: `⌘T` or click "Chat with Gemi"
4. View insights: Navigate to Insights in sidebar
5. Test keyboard shortcuts per `KeyboardShortcuts` struct

## Future Enhancements

The following features are placeholders for future development:
- Memories section
- Advanced search
- Voice input
- Calendar integration
- Multi-window support

---

Last Updated: January 2025
Hackathon: Google DeepMind Gemma 3n