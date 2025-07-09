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
        // Create scroll view manually
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.borderType = .noBorder
        
        // Create text container and text view
        let contentSize = scrollView.contentSize
        let textContainer = NSTextContainer(size: contentSize)
        textContainer.widthTracksTextView = true
        textContainer.containerSize = CGSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        
        let textView = FocusTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.minSize = CGSize(width: 0, height: 0)
        textView.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        
        // Setup text view properties
        textView.setupView()
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
        textView.isEditable = true  // Enable editing
        textView.isSelectable = true  // Enable text selection
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        
        // Set initial text
        if text.isEmpty {
            textView.string = ""
        }
        
        // Set line spacing for readability
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = fontSize * 0.6
        paragraphStyle.alignment = .left
        textView.defaultParagraphStyle = paragraphStyle
        
        // Store reference for cursor operations
        context.coordinator.textView = textView
        onCoordinatorReady?(context.coordinator)
        
        // Set up the scroll view
        scrollView.documentView = textView
        
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
        
        // Skip focus highlighting for now to fix editing issues
        // TODO: Implement proper focus highlighting without breaking text input
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