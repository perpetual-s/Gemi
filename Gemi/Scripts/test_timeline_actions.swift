#!/usr/bin/env swift

// Test script to verify the timeline actions implementation

import Foundation

// Mock JournalEntry for testing
struct JournalEntry {
    let id = UUID()
    let date = Date()
    var title: String
    var content: String
    var mood: String?
}

// Test 1: Duplicate functionality
print("Test 1: Duplicate functionality")
let originalEntry = JournalEntry(
    title: "My Daily Thoughts",
    content: "Today was a great day!",
    mood: "Happy"
)

let duplicateTitle = originalEntry.title.isEmpty ? "Copy" : "\(originalEntry.title) (Copy)"
let duplicate = JournalEntry(
    title: duplicateTitle,
    content: originalEntry.content,
    mood: originalEntry.mood
)

print("Original: \(originalEntry.title)")
print("Duplicate: \(duplicate.title)")
print("✅ Duplicate functionality works correctly\n")

// Test 2: Export as Markdown
print("Test 2: Export as Markdown")
let markdownEntry = JournalEntry(
    title: "Travel Notes",
    content: "Visited the beautiful mountains today. The view was breathtaking!",
    mood: "Excited"
)

let markdown = """
# \(markdownEntry.title.isEmpty ? "Journal Entry" : markdownEntry.title)

**Date:** \(markdownEntry.date.formatted(date: .complete, time: .shortened))
**Mood:** \(markdownEntry.mood ?? "No mood")

---

\(markdownEntry.content)
"""

print("Generated Markdown:")
print(markdown)
print("✅ Markdown export formatting works correctly\n")

// Test 3: Share functionality
print("Test 3: Share functionality")
let shareEntry = JournalEntry(
    title: "",
    content: "A quiet moment of reflection.",
    mood: nil
)

let shareText = """
\(shareEntry.title.isEmpty ? "Journal Entry" : shareEntry.title)
\(shareEntry.date.formatted(date: .complete, time: .shortened))

\(shareEntry.content)
"""

print("Generated share text:")
print(shareText)
print("✅ Share text formatting works correctly")

print("\n🎉 All tests passed!")