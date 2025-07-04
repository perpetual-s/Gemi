# Timeline Actions Implementation

## Summary
Implemented the missing functionality for export, share, and duplicate buttons in TimelineCardView and TimelineView.

## Changes Made

### 1. TimelineView.swift
Added implementation for three empty closures in the `timelineCard` function:

#### onDuplicate
- Creates a copy of the selected journal entry
- Appends "(Copy)" to the title (or uses "Copy" if original title is empty)
- Preserves the original content and mood
- Saves the duplicate entry to the journal store asynchronously

#### onExport
- Generates a markdown-formatted version of the entry
- Includes title, date, mood, and content
- Opens a save panel allowing users to choose location
- Saves as a .md file with appropriate naming

#### onShare
- Creates a plain text version of the entry
- Uses macOS native NSSharingServicePicker
- Allows sharing via email, messages, or other installed services
- Properly handles window positioning for the share picker

### 2. Required Imports
Added necessary imports to TimelineView.swift:
- `import AppKit` - For NSSavePanel and NSSharingServicePicker
- `import UniformTypeIdentifiers` - For file type specifications

## Implementation Details

### Duplicate Feature
```swift
onDuplicate: {
    Task {
        let duplicateTitle = entry.title.isEmpty ? "Copy" : "\(entry.title) (Copy)"
        let duplicate = JournalEntry(
            title: duplicateTitle,
            content: entry.content,
            mood: entry.mood
        )
        try? await journalStore.addEntry(duplicate)
    }
}
```

### Export Feature
- Uses NSSavePanel for file selection
- Formats entry as markdown with proper headers
- Handles empty titles gracefully
- Sets appropriate default filename

### Share Feature
- Uses NSSharingServicePicker for native macOS sharing
- Formats entry as plain text
- Properly positions the share picker relative to the current window

## Testing
Created test script at `Scripts/test_timeline_actions.swift` that verifies:
- Duplicate title generation logic
- Markdown formatting
- Share text formatting

All tests pass successfully.

## Notes
- The implementation follows the existing patterns in FloatingEntryView.swift
- Error handling is done with try? to prevent crashes
- All operations are performed asynchronously where appropriate
- The context menu in ContextMenus.swift already had the export functionality, but the TimelineView callbacks were not implemented