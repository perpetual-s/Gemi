//
//  JournalChunker.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import Foundation
import os.log

struct JournalChunker {
    private let logger = Logger(subsystem: "com.chaehoshin.Gemi", category: "JournalChunker")
    
    // Configuration
    private let maxChunkSize = 1000 // characters
    private let minChunkSize = 100
    private let overlapSize = 100
    
    struct ChunkedEntry {
        let entryId: UUID
        let chunks: [Chunk]
        let metadata: EntryMetadata
    }
    
    struct Chunk {
        let id: UUID
        let content: String
        let position: Int
        let metadata: ChunkMetadata
    }
    
    struct EntryMetadata {
        let date: Date
        let mood: String?
        let tags: [String]
        let wordCount: Int
    }
    
    struct ChunkMetadata {
        let startOffset: Int
        let endOffset: Int
        let isFirstChunk: Bool
        let isLastChunk: Bool
        let sentenceCount: Int
    }
    
    // MARK: - Main Chunking Function
    
    func splitEntry(_ entry: JournalEntry) -> ChunkedEntry {
        logger.info("Chunking entry \(entry.id) with \(entry.content.count) characters")
        
        let chunks = createSemanticChunks(from: entry.content)
        let metadata = EntryMetadata(
            date: entry.createdAt,
            mood: entry.mood,
            tags: [],
            wordCount: entry.content.split(separator: " ").count
        )
        
        logger.info("Created \(chunks.count) chunks for entry \(entry.id)")
        
        return ChunkedEntry(
            entryId: entry.id,
            chunks: chunks,
            metadata: metadata
        )
    }
    
    // MARK: - Semantic Chunking
    
    private func createSemanticChunks(from content: String) -> [Chunk] {
        // First, try to split by paragraphs
        let paragraphs = content.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        
        var chunks: [Chunk] = []
        var currentOffset = 0
        
        for (index, paragraph) in paragraphs.enumerated() {
            if paragraph.count <= maxChunkSize {
                // Paragraph fits in a single chunk
                chunks.append(createChunk(
                    content: paragraph,
                    position: chunks.count,
                    startOffset: currentOffset,
                    endOffset: currentOffset + paragraph.count,
                    isFirst: index == 0,
                    isLast: index == paragraphs.count - 1 && paragraph.count <= maxChunkSize
                ))
                currentOffset += paragraph.count + 2 // +2 for \n\n
            } else {
                // Paragraph needs to be split further
                let subChunks = splitLongParagraph(paragraph, startOffset: currentOffset)
                chunks.append(contentsOf: subChunks)
                currentOffset += paragraph.count + 2
            }
        }
        
        // If no paragraphs or single paragraph, fall back to sentence-based chunking
        if chunks.isEmpty {
            chunks = splitBySentences(content)
        }
        
        return chunks
    }
    
    private func splitLongParagraph(_ paragraph: String, startOffset: Int) -> [Chunk] {
        let sentences = splitIntoSentences(paragraph)
        var chunks: [Chunk] = []
        var currentChunk = ""
        var chunkStartOffset = startOffset
        var sentenceOffsetInParagraph = 0
        
        for (_, sentence) in sentences.enumerated() {
            let potentialChunk = currentChunk.isEmpty ? sentence : currentChunk + " " + sentence
            
            if potentialChunk.count <= maxChunkSize {
                currentChunk = potentialChunk
            } else {
                // Save current chunk
                if !currentChunk.isEmpty {
                    chunks.append(createChunk(
                        content: currentChunk,
                        position: chunks.count,
                        startOffset: chunkStartOffset,
                        endOffset: chunkStartOffset + currentChunk.count,
                        isFirst: false,
                        isLast: false
                    ))
                    chunkStartOffset += currentChunk.count + 1
                }
                currentChunk = sentence
            }
            
            sentenceOffsetInParagraph += sentence.count + 1
        }
        
        // Don't forget the last chunk
        if !currentChunk.isEmpty {
            chunks.append(createChunk(
                content: currentChunk,
                position: chunks.count,
                startOffset: chunkStartOffset,
                endOffset: chunkStartOffset + currentChunk.count,
                isFirst: false,
                isLast: false
            ))
        }
        
        return chunks
    }
    
    private func splitBySentences(_ content: String) -> [Chunk] {
        let sentences = splitIntoSentences(content)
        var chunks: [Chunk] = []
        var currentChunk = ""
        var currentOffset = 0
        var chunkStartOffset = 0
        
        for (_, sentence) in sentences.enumerated() {
            let potentialChunk = currentChunk.isEmpty ? sentence : currentChunk + " " + sentence
            
            if potentialChunk.count <= maxChunkSize {
                currentChunk = potentialChunk
            } else {
                // Save current chunk with overlap
                if !currentChunk.isEmpty {
                    chunks.append(createChunk(
                        content: currentChunk,
                        position: chunks.count,
                        startOffset: chunkStartOffset,
                        endOffset: currentOffset,
                        isFirst: chunks.isEmpty,
                        isLast: false
                    ))
                    
                    // Add overlap from end of current chunk
                    let overlapText = extractOverlap(from: currentChunk)
                    currentChunk = overlapText + " " + sentence
                    chunkStartOffset = currentOffset - overlapText.count
                } else {
                    currentChunk = sentence
                    chunkStartOffset = currentOffset
                }
            }
            
            currentOffset += sentence.count + 1 // +1 for space
        }
        
        // Don't forget the last chunk
        if !currentChunk.isEmpty {
            chunks.append(createChunk(
                content: currentChunk,
                position: chunks.count,
                startOffset: chunkStartOffset,
                endOffset: currentOffset,
                isFirst: chunks.isEmpty,
                isLast: true
            ))
        }
        
        return chunks
    }
    
    // MARK: - Helper Functions
    
    private func splitIntoSentences(_ text: String) -> [String] {
        // Simple sentence splitting using regex
        let pattern = #"[.!?]+[\s]+"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        
        var sentences: [String] = []
        var lastIndex = text.startIndex
        
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match else { return }
            let matchRange = Range(match.range, in: text)!
            let sentence = String(text[lastIndex..<matchRange.lowerBound])
            sentences.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
            lastIndex = matchRange.upperBound
        }
        
        // Add the last sentence
        if lastIndex < text.endIndex {
            let lastSentence = String(text[lastIndex...])
            sentences.append(lastSentence.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return sentences.filter { !$0.isEmpty }
    }
    
    private func extractOverlap(from text: String) -> String {
        let words = text.split(separator: " ")
        let overlapWordCount = min(20, words.count / 3) // Take last 20 words or 1/3 of chunk
        return words.suffix(overlapWordCount).joined(separator: " ")
    }
    
    private func createChunk(
        content: String,
        position: Int,
        startOffset: Int,
        endOffset: Int,
        isFirst: Bool,
        isLast: Bool
    ) -> Chunk {
        let sentenceCount = splitIntoSentences(content).count
        
        return Chunk(
            id: UUID(),
            content: content,
            position: position,
            metadata: ChunkMetadata(
                startOffset: startOffset,
                endOffset: endOffset,
                isFirstChunk: isFirst,
                isLastChunk: isLast,
                sentenceCount: sentenceCount
            )
        )
    }
    
    // MARK: - Context Preservation
    
    func preserveContext(for chunk: Chunk, from entry: ChunkedEntry) -> String {
        var contextualContent = ""
        
        // Add metadata context
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        contextualContent += "Journal entry from \(dateFormatter.string(from: entry.metadata.date))"
        
        if let mood = entry.metadata.mood {
            contextualContent += ", mood: \(mood)"
        }
        
        if !entry.metadata.tags.isEmpty {
            contextualContent += ", tags: \(entry.metadata.tags.joined(separator: ", "))"
        }
        
        contextualContent += ":\n\n"
        
        // Add the chunk content
        contextualContent += chunk.content
        
        // Add position context if not first/last chunk
        if !chunk.metadata.isFirstChunk && !chunk.metadata.isLastChunk {
            contextualContent += "\n\n[Excerpt from middle of entry]"
        } else if chunk.metadata.isFirstChunk {
            contextualContent += "\n\n[Beginning of entry]"
        } else if chunk.metadata.isLastChunk {
            contextualContent += "\n\n[End of entry]"
        }
        
        return contextualContent
    }
    
    // MARK: - Long Entry Handling
    
    func handleLongEntries(_ content: String) -> [String] {
        // For very long entries, create multiple embeddings
        var segments: [String] = []
        let maxEmbeddingLength = 8000 // Leave room for context
        
        if content.count <= maxEmbeddingLength {
            return [content]
        }
        
        // Split into segments with overlap
        var currentIndex = 0
        while currentIndex < content.count {
            let endIndex = min(currentIndex + maxEmbeddingLength, content.count)
            let segment = String(content[content.index(content.startIndex, offsetBy: currentIndex)..<content.index(content.startIndex, offsetBy: endIndex)])
            segments.append(segment)
            
            // Move forward with overlap
            currentIndex += maxEmbeddingLength - overlapSize
        }
        
        logger.info("Split long entry into \(segments.count) segments for embedding")
        return segments
    }
}