# Gemi Codebase Cleanup Plan

## Overview
This document outlines files to remove and code to consolidate to make Gemi's codebase cleaner and more maintainable.

## Files to Remove (Definitely Unused)

### 1. Duplicate Compose Views
- **❌ ComposeView.swift** - Basic version, completely unused
- **❌ EnhancedComposeView.swift** - AI-enhanced version, not integrated (features already ported)

### 2. Duplicate Timeline Views  
- **❌ TimelineView.swift** - Old implementation replaced by EnhancedTimelineView

### 3. Duplicate UI Components
- **❌ EmojiPicker.swift** - Replaced by QuickEmojiPicker
- **❌ ChatInterfaceView.swift** - Generic component replaced by GemiChatView

### 4. Template/Boilerplate Files
- **❌ ContentView.swift** - Default SwiftUI template, not used

## Files to Investigate (Possibly Unused)

### 1. Ollama Setup Views
- **? OllamaSetupView.swift** - Check if still needed for initial setup
- **? OllamaStatusView.swift** - Check if status monitoring is used

### 2. Reading Views
- **? EntryReadingView.swift** - May be duplicate of EnhancedEntryReadingView
- **? EnhancedEntryReadingView.swift** - Check actual usage

### 3. Diagnostic/Debug Views
- **? DiagnosticView.swift** - Check if needed for debugging

### 4. Chat Components
- **? ChatWithContextButton.swift** - Check if used anywhere
- **? EnhancedMessageRow.swift** - Check if used in chat views

## Code to Consolidate

### 1. AI Features
- Port any valuable AI features from EnhancedComposeView to ProductionComposeView
- Currently most are placeholders, so likely nothing to port

### 2. Reading Mode
- Consolidate entry reading views into single implementation
- Use the one with AI insights integration

### 3. Settings
- SettingsView.swift appears to be new and untested
- Verify it's properly integrated

## Recommended Actions

1. **Phase 1: Remove Definitely Unused Files**
   - Delete the 6 files marked with ❌
   - Run build to ensure nothing breaks

2. **Phase 2: Investigate Possibly Unused**
   - Check imports and usage for files marked with ?
   - Remove if truly unused

3. **Phase 3: Organize Structure**
   - Create subdirectories: Timeline/, Compose/, Chat/, Settings/
   - Move related files together

4. **Phase 4: Documentation**
   - Add README in Views folder explaining active components
   - Mark any experimental features clearly

## Benefits of Cleanup

1. **Clarity**: New developers won't be confused by multiple implementations
2. **Maintainability**: Fewer files to update when making changes
3. **Performance**: Smaller app bundle without unused code
4. **Focus**: Clear which components are production vs experimental

## Files Summary

### Keep (Core Functionality)
- ProductionComposeView.swift ✅
- EnhancedTimelineView.swift ✅
- GemiChatView.swift ✅
- QuickEmojiPicker.swift ✅
- MainWindowView.swift ✅
- Sidebar.swift ✅
- FavoritesView.swift ✅
- SearchView.swift ✅
- MemoriesView.swift ✅
- InsightsView.swift ✅
- AIInsightsView.swift ✅
- AuthenticationView.swift ✅
- InitialSetupView.swift ✅

### Remove (Duplicates/Unused)
- ComposeView.swift ❌
- EnhancedComposeView.swift ❌
- TimelineView.swift ❌
- EmojiPicker.swift ❌
- ChatInterfaceView.swift ❌
- ContentView.swift ❌

### Investigate Further
- OllamaSetupView.swift ?
- OllamaStatusView.swift ?
- EntryReadingView.swift ?
- EnhancedEntryReadingView.swift ?
- DiagnosticView.swift ?
- ChatWithContextButton.swift ?
- EnhancedMessageRow.swift ?
- SettingsView.swift ?