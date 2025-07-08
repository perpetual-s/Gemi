import SwiftUI
import AppKit

/// Advanced text editor with focus highlighting capabilities
struct FocusTextEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let textColor: Color
    let focusLevel: FocusModeSettings.FocusLevel
    let highlightIntensity: Double
    let typewriterMode: Bool
    let onTextChange: (String) -> Void
    var onCoordinatorReady: ((Coordinator) -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = FocusTextView.scrollableTextView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        
        let textView = scrollView.documentView as! FocusTextView
        textView.setupView() // Call setup here where it's safe
        textView.focusDelegate = context.coordinator
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .systemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = NSColor(textColor)
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.drawsBackground = false
        textView.focusLevel = focusLevel
        textView.highlightIntensity = highlightIntensity
        
        // Set line spacing for readability
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = fontSize * 0.6
        paragraphStyle.alignment = .left
        textView.defaultParagraphStyle = paragraphStyle
        
        // Store reference for cursor operations
        context.coordinator.textView = textView
        onCoordinatorReady?(context.coordinator)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? FocusTextView else { return }
        
        // Update text only if changed
        if textView.string != text && !context.coordinator.isUpdating {
            context.coordinator.isUpdating = true
            textView.string = text
            context.coordinator.isUpdating = false
        }
        
        // Update appearance
        textView.font = .systemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = NSColor(textColor)
        textView.focusLevel = focusLevel
        textView.highlightIntensity = highlightIntensity
        
        // Update paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = fontSize * 0.6
        paragraphStyle.alignment = .left
        textView.defaultParagraphStyle = paragraphStyle
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate, FocusTextViewDelegate {
        var parent: FocusTextEditor
        var isUpdating = false
        weak var textView: FocusTextView?
        
        init(_ parent: FocusTextEditor) {
            self.parent = parent
            super.init()
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdating else { return }
            
            parent.text = textView.string
            parent.onTextChange(textView.string)
        }
        
        nonisolated func textViewDidChangeSelection(_ notification: Notification) {
            // Trigger redraw for focus highlighting
            Task { @MainActor [weak textView] in
                textView?.needsDisplay = true
            }
        }
        
        @MainActor
        func insertTextAtCursor(_ text: String) {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange()
            
            if textView.shouldChangeText(in: selectedRange, replacementString: text) {
                textView.replaceCharacters(in: selectedRange, with: text)
                textView.didChangeText()
                
                let newCursorPosition = selectedRange.location + text.count
                textView.setSelectedRange(NSRange(location: newCursorPosition, length: 0))
            }
        }
    }
}

// MARK: - Custom TextView with Focus Highlighting

protocol FocusTextViewDelegate: AnyObject {
    func textViewDidChangeSelection(_ notification: Notification)
}

class FocusTextView: NSTextView {
    weak var focusDelegate: FocusTextViewDelegate?
    var focusLevel: FocusModeSettings.FocusLevel = .none {
        didSet { needsDisplay = true }
    }
    var highlightIntensity: Double = 0.4 {
        didSet { needsDisplay = true }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        Task { @MainActor in
            setupView()
        }
    }
    
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        // Setup will be called in makeNSView
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        // Setup will be called in makeNSView
    }
    
    func setupView() {
        // Enable smooth drawing
        wantsLayer = true
        layer?.drawsAsynchronously = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard focusLevel != .none,
              let textStorage = textStorage else { return }
        
        // Get current cursor position
        let cursorLocation = selectedRange().location
        
        // Apply dimming based on focus level
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let activeRanges = getActiveRanges(for: cursorLocation, in: textStorage.string)
        
        // Create a mutable attributed string for temporary display
        let tempStorage = NSMutableAttributedString(attributedString: textStorage)
        
        // First, dim everything
        let dimmedColor = (textColor ?? .labelColor).withAlphaComponent(1.0 - highlightIntensity)
        tempStorage.addAttribute(.foregroundColor, value: dimmedColor, range: fullRange)
        
        // Then highlight active ranges
        let activeColor = textColor ?? .labelColor
        for range in activeRanges {
            if range.location + range.length <= tempStorage.length {
                tempStorage.addAttribute(.foregroundColor, value: activeColor, range: range)
            }
        }
        
        // Apply the temporary attributes for drawing
        textStorage.setAttributedString(tempStorage)
    }
    
    private func getActiveRanges(for cursorLocation: Int, in text: String) -> [NSRange] {
        switch focusLevel {
        case .none:
            return []
            
        case .line:
            return getRangesForLines(around: cursorLocation, in: text)
            
        case .sentence:
            return getRangesForSentences(around: cursorLocation, in: text)
            
        case .paragraph:
            return getRangesForParagraphs(around: cursorLocation, in: text)
        }
    }
    
    private func getRangesForLines(around location: Int, in text: String) -> [NSRange] {
        let nsString = text as NSString
        var lineStart = 0
        var lineEnd = 0
        
        nsString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: nil, for: NSRange(location: location, length: 0))
        
        return [NSRange(location: lineStart, length: lineEnd - lineStart)]
    }
    
    private func getRangesForSentences(around location: Int, in text: String) -> [NSRange] {
        let nsString = text as NSString
        var ranges: [NSRange] = []
        
        // Find sentence containing cursor
        let options: NSString.EnumerationOptions = [.bySentences]
        var foundRange: NSRange?
        
        nsString.enumerateSubstrings(in: NSRange(location: 0, length: nsString.length), options: options) { _, range, _, stop in
            if range.contains(location) {
                foundRange = range
                stop.pointee = true
            }
            return
        }
        
        if let range = foundRange {
            ranges.append(range)
        }
        
        return ranges
    }
    
    private func getRangesForParagraphs(around location: Int, in text: String) -> [NSRange] {
        let nsString = text as NSString
        var ranges: [NSRange] = []
        
        // Find paragraph containing cursor
        let options: NSString.EnumerationOptions = [.byParagraphs]
        var foundRange: NSRange?
        
        nsString.enumerateSubstrings(in: NSRange(location: 0, length: nsString.length), options: options) { _, range, _, stop in
            if range.contains(location) {
                foundRange = range
                stop.pointee = true
            }
            return
        }
        
        if let range = foundRange {
            ranges.append(range)
        }
        
        return ranges
    }
    
    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }
    
    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelecting)
        needsDisplay = true
        
        // Notify delegate
        focusDelegate?.textViewDidChangeSelection(Notification(name: .init("FocusTextViewSelectionChanged"), object: self))
    }
}

extension NSRange {
    func contains(_ location: Int) -> Bool {
        return location >= self.location && location <= self.location + self.length
    }
}