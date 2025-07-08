import SwiftUI
import AppKit

/// A distraction-free writing environment with typewriter scrolling and ambient sounds
struct FocusModeView: View {
    @Binding var entry: JournalEntry
    @Binding var isPresented: Bool
    
    // Editor state
    @State private var wordCount = 0
    @State private var characterCount = 0
    @State private var sessionStartTime = Date()
    @State private var writingPace = 0.0
    @State private var lastSavedContent = ""
    @State private var hasUnsavedChanges = false
    
    // Focus mode settings
    @State private var showingSettings = false
    @State private var selectedAmbientSound: AmbientSound = .none
    @State private var typewriterMode = true
    @State private var wordGoal = 750
    @State private var showProgress = true
    @State private var fontSize: CGFloat = 20
    
    // Animation states
    @State private var fadeInOpacity = 0.0
    @State private var settingsOpacity = 0.0
    @State private var progressOpacity = 0.0
    
    @Environment(\.colorScheme) var colorScheme
    @Namespace private var animation
    
    enum AmbientSound: String, CaseIterable {
        case none = "Silence"
        case rain = "Rain"
        case coffeeshop = "Coffee Shop"
        case ocean = "Ocean Waves"
        case forest = "Forest"
        case fireplace = "Fireplace"
        
        var icon: String {
            switch self {
            case .none: return "speaker.slash"
            case .rain: return "cloud.rain"
            case .coffeeshop: return "cup.and.saucer"
            case .ocean: return "water.waves"
            case .forest: return "leaf"
            case .fireplace: return "flame"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            focusBackground
            
            // Main content
            VStack(spacing: 0) {
                // Minimal header
                focusHeader
                
                // Writing area
                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                // Centering spacer for typewriter mode
                                if typewriterMode {
                                    Spacer()
                                        .frame(height: geometry.size.height / 2 - 100)
                                }
                                
                                // Title input
                                TextField("Untitled", text: $entry.title, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: fontSize + 8, weight: .bold, design: .serif))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1...2)
                                    .padding(.horizontal, 80)
                                    .padding(.bottom, 30)
                                    .opacity(0.9)
                                
                                // Content editor
                                FocusTextEditor(
                                    text: $entry.content,
                                    fontSize: fontSize,
                                    typewriterMode: typewriterMode,
                                    onTextChange: { _ in
                                        updateWordCount()
                                    }
                                )
                                .id("editor")
                                .padding(.horizontal, 80)
                                .frame(minHeight: geometry.size.height - 200)
                                
                                // Bottom spacer for typewriter mode
                                if typewriterMode {
                                    Spacer()
                                        .frame(height: geometry.size.height / 2)
                                }
                            }
                        }
                        .onChange(of: entry.content) { _, _ in
                            if typewriterMode {
                                // Scroll to keep cursor in center
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo("editor", anchor: .center)
                                }
                            }
                        }
                    }
                }
                
                // Writing progress (if enabled)
                if showProgress {
                    focusProgressBar
                        .opacity(progressOpacity)
                        .animation(.easeOut(duration: 0.5), value: progressOpacity)
                }
            }
            .opacity(fadeInOpacity)
            .animation(.easeOut(duration: 0.8), value: fadeInOpacity)
            
            // Settings overlay
            if showingSettings {
                focusSettingsOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            fadeInOpacity = 1
            progressOpacity = 1
            lastSavedContent = entry.content
            updateWordCount()
            
            // Play ambient sound if selected
            if selectedAmbientSound != .none {
                AmbientSoundPlayer.shared.play(sound: selectedAmbientSound)
            }
        }
        .onDisappear {
            AmbientSoundPlayer.shared.stop()
        }
        .onChange(of: entry.content) { oldValue, newValue in
            hasUnsavedChanges = (newValue != lastSavedContent)
        }
        .onKeyPress(.escape) {
            exitFocusMode()
            return .handled
        }
    }
    
    // MARK: - Components
    
    private var focusBackground: some View {
        ZStack {
            // Base color
            Rectangle()
                .fill(colorScheme == .dark ? Color.black : Color(hex: "FAF9F6"))
                .ignoresSafeArea()
            
            // Subtle gradient overlay
            LinearGradient(
                colors: [
                    Color.clear,
                    (colorScheme == .dark ? Color.white : Color.black).opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Ambient animation
            if selectedAmbientSound != .none {
                AmbientVisualEffect(sound: selectedAmbientSound)
                    .ignoresSafeArea()
                    .opacity(0.3)
            }
        }
    }
    
    private var focusHeader: some View {
        HStack {
            // Exit button
            Button {
                exitFocusMode()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Exit Focus")
                        .font(.system(size: 14))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Session timer
            HStack(spacing: 16) {
                // Writing time
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(formatSessionTime())
                        .font(.system(size: 13, design: .monospaced))
                }
                .foregroundColor(.secondary.opacity(0.8))
                
                // Word count
                HStack(spacing: 4) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 12))
                    Text("\(wordCount)")
                        .font(.system(size: 13, design: .monospaced))
                }
                .foregroundColor(.secondary.opacity(0.8))
            }
            
            Spacer()
            
            // Settings button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showingSettings.toggle()
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(showingSettings ? Color.secondary.opacity(0.2) : Color.secondary.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
    }
    
    private var focusProgressBar: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.3)
            
            HStack(spacing: 20) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 3)
                        
                        // Progress
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: progressGradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * min(Double(wordCount) / Double(wordGoal), 1.0), height: 3)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: wordCount)
                    }
                }
                .frame(width: 200, height: 3)
                
                // Goal text
                Text("\(wordCount) / \(wordGoal)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.8))
                
                Spacer()
                
                // Pace indicator
                if writingPace > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 11))
                        Text("\(Int(writingPace)) wpm")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary.opacity(0.8))
                }
                
                // Achievement
                if wordCount >= wordGoal {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                        Text("Goal achieved!")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.8))
    }
    
    private var focusSettingsOverlay: some View {
        VStack(spacing: 0) {
            // Click outside to dismiss
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        showingSettings = false
                    }
                }
            
            // Settings panel
            VStack(spacing: 24) {
                // Title
                HStack {
                    Text("Focus Settings")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Button {
                        withAnimation {
                            showingSettings = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                
                // Typewriter mode toggle
                Toggle(isOn: $typewriterMode) {
                    Label("Typewriter Scrolling", systemImage: "text.cursor")
                        .font(.system(size: 14))
                }
                .toggleStyle(.switch)
                
                // Show progress toggle
                Toggle(isOn: $showProgress) {
                    Label("Show Writing Progress", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14))
                }
                .toggleStyle(.switch)
                .onChange(of: showProgress) { _, newValue in
                    withAnimation {
                        progressOpacity = newValue ? 1 : 0
                    }
                }
                
                // Font size slider
                VStack(alignment: .leading, spacing: 8) {
                    Label("Text Size", systemImage: "textformat.size")
                        .font(.system(size: 14))
                    
                    HStack {
                        Text("A")
                            .font(.system(size: 14))
                        
                        Slider(value: $fontSize, in: 16...28, step: 1)
                        
                        Text("A")
                            .font(.system(size: 20))
                    }
                    .foregroundColor(.secondary)
                }
                
                // Word goal
                VStack(alignment: .leading, spacing: 8) {
                    Label("Writing Goal", systemImage: "target")
                        .font(.system(size: 14))
                    
                    HStack {
                        TextField("Goal", value: $wordGoal, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        
                        Text("words")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Ambient sounds
                VStack(alignment: .leading, spacing: 12) {
                    Label("Ambient Sound", systemImage: "speaker.wave.2")
                        .font(.system(size: 14))
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                        ForEach(AmbientSound.allCases, id: \.self) { sound in
                            AmbientSoundButton(
                                sound: sound,
                                isSelected: selectedAmbientSound == sound,
                                action: {
                                    selectedAmbientSound = sound
                                    if sound == .none {
                                        AmbientSoundPlayer.shared.stop()
                                    } else {
                                        AmbientSoundPlayer.shared.play(sound: sound)
                                    }
                                }
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .frame(width: 400, height: 500)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .scale(scale: 0.9).combined(with: .opacity)
            ))
            
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        showingSettings = false
                    }
                }
        }
        .background(Color.black.opacity(0.3))
        .ignoresSafeArea()
    }
    
    // MARK: - Helper Methods
    
    private var progressGradientColors: [Color] {
        let percentage = Double(wordCount) / Double(wordGoal)
        if percentage < 0.25 {
            return [Color.blue.opacity(0.6), Color.blue]
        } else if percentage < 0.5 {
            return [Color.green.opacity(0.6), Color.green]
        } else if percentage < 0.75 {
            return [Color.orange.opacity(0.6), Color.orange]
        } else {
            return [Color.purple.opacity(0.6), Color.purple]
        }
    }
    
    private func updateWordCount() {
        let words = entry.content.split { $0.isWhitespace || $0.isNewline }
        wordCount = words.filter { !$0.isEmpty }.count
        characterCount = entry.content.count
        
        // Calculate writing pace
        let timeElapsed = Date().timeIntervalSince(sessionStartTime) / 60.0 // minutes
        if timeElapsed > 0 {
            writingPace = Double(wordCount) / timeElapsed
        }
    }
    
    private func formatSessionTime() -> String {
        let elapsed = Date().timeIntervalSince(sessionStartTime)
        let hours = Int(elapsed / 3600)
        let minutes = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(elapsed.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func exitFocusMode() {
        withAnimation(.easeOut(duration: 0.3)) {
            fadeInOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

// MARK: - Supporting Views

struct AmbientSoundButton: View {
    let sound: FocusModeView.AmbientSound
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: sound.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : .secondary)
                
                Text(sound.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.Colors.primaryAccent : Color.secondary.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isHovered ? Theme.Colors.primaryAccent.opacity(0.5) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct FocusTextEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let typewriterMode: Bool
    let onTextChange: (String) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .systemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.drawsBackground = false
        
        // Set line spacing for readability
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = fontSize * 0.8
        paragraphStyle.alignment = typewriterMode ? .center : .left
        textView.defaultParagraphStyle = paragraphStyle
        
        // Note: NSTextView doesn't support placeholders like NSTextField
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Update text only if changed
        if textView.string != text && !context.coordinator.isUpdating {
            context.coordinator.isUpdating = true
            textView.string = text
            context.coordinator.isUpdating = false
        }
        
        // Update font size
        textView.font = .systemFont(ofSize: fontSize, weight: .regular)
        
        // Update paragraph style for typewriter mode
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = fontSize * 0.8
        paragraphStyle.alignment = typewriterMode ? .center : .left
        textView.defaultParagraphStyle = paragraphStyle
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: FocusTextEditor
        var isUpdating = false
        
        init(_ parent: FocusTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdating else { return }
            
            parent.text = textView.string
            parent.onTextChange(textView.string)
        }
    }
}

// MARK: - Ambient Visual Effects

struct AmbientVisualEffect: View {
    let sound: FocusModeView.AmbientSound
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            switch sound {
            case .rain:
                RainEffect(phase: phase)
            case .ocean:
                WaveEffect(phase: phase)
            case .forest:
                ForestEffect(phase: phase)
            case .coffeeshop:
                CoffeeShopEffect(phase: phase)
            case .fireplace:
                FireplaceEffect(phase: phase)
            case .none:
                EmptyView()
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

struct RainEffect: View {
    let phase: CGFloat
    
    var body: some View {
        Canvas { context, size in
            for i in 0..<50 {
                let x = CGFloat.random(in: 0...size.width)
                let y = (CGFloat(i) * 20 + phase * size.height * 2).truncatingRemainder(dividingBy: size.height)
                let opacity = Double.random(in: 0.1...0.3)
                
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x - 2, y: y + 10))
                    },
                    with: .color(.white.opacity(opacity)),
                    lineWidth: 1
                )
            }
        }
    }
}

struct WaveEffect: View {
    let phase: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<3) { i in
                Wave(phase: phase, amplitude: 20 + CGFloat(i) * 10, frequency: 0.01 - CGFloat(i) * 0.002)
                    .stroke(
                        Color.blue.opacity(0.1 - Double(i) * 0.03),
                        lineWidth: 2
                    )
                    .offset(y: geometry.size.height * 0.7 + CGFloat(i) * 30)
            }
        }
    }
}

struct Wave: Shape {
    var phase: CGFloat
    let amplitude: CGFloat
    let frequency: CGFloat
    
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.midY))
            
            for x in stride(from: 0, to: rect.width, by: 2) {
                let y = sin((x + phase * rect.width * 2) * frequency) * amplitude + rect.midY
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
}

struct ForestEffect: View {
    let phase: CGFloat
    
    var body: some View {
        ZStack {
            ForEach(0..<20) { i in
                Circle()
                    .fill(Color.green.opacity(0.05))
                    .frame(width: 50)
                    .offset(
                        x: sin(phase * .pi * 2 + CGFloat(i)) * 100,
                        y: cos(phase * .pi * 2 + CGFloat(i) * 0.5) * 100
                    )
                    .blur(radius: 3)
            }
        }
    }
}

struct CoffeeShopEffect: View {
    let phase: CGFloat
    
    var body: some View {
        ZStack {
            ForEach(0..<15) { i in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.brown.opacity(0.03))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(phase * 360 + Double(i) * 24))
                    .offset(
                        x: cos(phase * .pi * 2 + CGFloat(i) * 0.5) * 150,
                        y: sin(phase * .pi * 2 + CGFloat(i) * 0.3) * 150
                    )
            }
        }
        .blur(radius: 2)
    }
}

struct FireplaceEffect: View {
    let phase: CGFloat
    
    var body: some View {
        ZStack {
            ForEach(0..<30) { i in
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.1), .red.opacity(0.05)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 40, height: 80)
                    .offset(
                        x: sin(phase * .pi * 4 + CGFloat(i)) * 20,
                        y: -phase * 200 + CGFloat(i) * 30
                    )
                    .opacity(1 - phase)
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}