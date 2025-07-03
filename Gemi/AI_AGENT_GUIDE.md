# AI Agent Guide for Gemi Development

This guide is specifically designed for AI agents (like Claude) working on the Gemi codebase to avoid common confusion points.

## Quick Reference - What to Use

### ✅ USE THESE FILES

**Main App Flow:**
- `GemiApp.swift` - App entry point
- `MainWindowView.swift` - Primary UI (NOT ContentView)
- `TimelineView.swift` - Main timeline
- `FullComposeView.swift` - Editor for new/edit entries
- `FloatingEntryView.swift` - Read-only entry viewer
- `ChatView.swift` - AI chat interface

**Services (in Gemi/Services/):**
- `DatabaseManager.swift` - Database operations
- `OllamaService.swift` - AI integration
- `GemiModelManager.swift` - Model management

### ❌ DO NOT USE THESE FILES

**Deprecated/Experimental:**
- `ContentView.swift` - Old navigation system
- `FloatingComposeView.swift` - Replaced by FullComposeView
- `ComposeView.swift` - Old compose view
- `JournalTimelineView.swift` - Experimental timeline
- `EnhancedChatView.swift` - Experimental chat
- Any files in `./Services/` or `./Stores/` (use `./Gemi/Services/` instead)

## Common Confusion Points

### 1. Entry Point Confusion

**Problem**: Two similar main views (MainWindowView vs ContentView)
**Solution**: ALWAYS use `MainWindowView` - it's the active primary interface

```swift
// CORRECT - In GemiApp.swift
MainWindowView()
    .environment(journalStore)
    // ... other environments

// WRONG - Don't use this
ContentView()
```

### 2. Editor/Compose View Confusion

**Problem**: Multiple editor implementations with similar names
**Solution**: Use this decision tree:

```
Need to create/edit entry?
└── Use FullComposeView (full window experience)

Need to view existing entry?
└── Use FloatingEntryView (read-only floating window)

DON'T USE: FloatingComposeView, ComposeView, JournalEditorView
```

### 3. Navigation State

**Problem**: Multiple navigation approaches
**Solution**: Use NavigationModel with MainWindowView's built-in sidebar

```swift
// CORRECT - NavigationModel is already in MainWindowView
@State private var navigationModel = NavigationModel()

// The model handles:
// - selectedSection (timeline, chat, insights, settings)
// - showingEditor state
// - editingEntry
```

### 4. Swift 6 Observable Pattern

**Problem**: Using old SwiftUI patterns
**Solution**: Use @Observable, NOT @ObservableObject

```swift
// CORRECT
@Observable
final class MyModel {
    var property: String = ""
}

// In view:
@State private var model = MyModel()

// WRONG - Don't use these:
// @ObservableObject, @Published, @StateObject, @EnvironmentObject
```

### 5. File Location Confusion

**Problem**: Duplicate files in different directories
**Solution**: ALWAYS use files in the `Gemi/` subdirectory

```
✅ Gemi/Services/DatabaseManager.swift
❌ Services/DatabaseManager.swift

✅ Gemi/Stores/ConversationStore.swift  
❌ Stores/ConversationStore.swift
```

## Quick Checks Before Making Changes

1. **Am I editing the right view?**
   - For main UI → MainWindowView.swift
   - For timeline → TimelineView.swift
   - For editor → FullComposeView.swift

2. **Am I in the right directory?**
   - All active code is in `Gemi/` subdirectory
   - Ignore root-level Services/ and Stores/

3. **Am I using the right patterns?**
   - @Observable not @ObservableObject
   - @State not @StateObject
   - .environment() not .environmentObject()

4. **Is this component active?**
   - Check ARCHITECTURE.md for component status
   - Look for "Experimental" or "Deprecated" comments

## Common Tasks Reference

### Adding a New Feature to Timeline
Edit: `Gemi/Views/TimelineView.swift`

### Modifying the Editor
Edit: `Gemi/Views/FullComposeView.swift`

### Adding Menu Items
Edit: `Gemi/Services/KeyboardShortcutManager.swift` (GemiKeyboardCommands)

### Changing Sidebar Navigation  
Edit: `Gemi/Views/MainWindowView.swift` (modernSidebar section)

### Modifying AI Chat
Edit: `Gemi/Views/Chat/ChatView.swift`

### Database Operations
Edit: `Gemi/Services/DatabaseManager.swift`

## Git Commit Guidelines

Follow AGENTS.md format:
```
type: brief description

Detailed explanation of changes

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Testing Checklist

Before committing:
- [ ] Build succeeds (⌘B)
- [ ] No duplicate menu items
- [ ] Window size stays consistent
- [ ] New Entry uses full window (not floating)
- [ ] Chat with Gemi visible in sidebar
- [ ] No NavigationModel environment errors

---

Remember: When in doubt, check ARCHITECTURE.md or ask for clarification!