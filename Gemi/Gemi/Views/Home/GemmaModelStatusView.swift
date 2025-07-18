import SwiftUI

/// Beautiful model status view for Gemma 3n integration
/// Shows download progress, setup instructions, and model status
struct GemmaModelStatusView: View {
    @StateObject private var modelManager = GemmaModelManager()
    @State private var isExpanded = false
    @State private var showingDetails = false
    @State private var pulseAnimation = false
    
    var isCompact: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            switch modelManager.status {
            case .notInstalled:
                setupRequiredView
            case .downloading(let progress):
                downloadingView(progress: progress)
            case .ready:
                readyStatusView
            case .error(let message):
                errorView(message: message)
            case .checking:
                checkingView
            }
        }
        .onAppear {
            modelManager.checkStatus()
            startPulseAnimation()
        }
    }
    
    // MARK: - Setup Required View
    
    private var setupRequiredView: some View {
        Group {
            if isCompact {
                compactSetupView
            } else {
                fullSetupView
            }
        }
    }
    
    private var compactSetupView: some View {
        HStack(spacing: 16) {
            // Small icon
            Image(systemName: "cpu.fill")
                .font(.system(size: 24))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Compact text
            VStack(alignment: .leading, spacing: 4) {
                Text("Gemma 3n Not Installed")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Set up required for AI features")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Small setup button
            Button {
                modelManager.startSetup()
            } label: {
                Text("Set Up")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var fullSetupView: some View {
        VStack(spacing: 24) {
            // Header with animated icon
            ZStack {
                // Animated gradient circles
                ForEach(0..<3) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.purple.opacity(0.3 - Double(index) * 0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120 + CGFloat(index * 20), height: 120 + CGFloat(index * 20))
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 2 + Double(index))
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: pulseAnimation
                        )
                }
                
                // Gemma icon
                Image(systemName: "cpu.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.purple.opacity(0.5), radius: 10)
            }
            
            // Title and description
            VStack(spacing: 12) {
                Text("Welcome to Gemi!")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.primary, Color.primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Let's set up Gemma 3n for your private AI experience")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Feature highlights
            VStack(spacing: 16) {
                FeatureRow(
                    icon: "lock.shield.fill",
                    title: "100% Private",
                    description: "Runs entirely on your Mac",
                    color: .green
                )
                
                FeatureRow(
                    icon: "photo.on.rectangle.angled",
                    title: "Multimodal AI",
                    description: "Understands text, images, and audio",
                    color: .blue
                )
                
                FeatureRow(
                    icon: "globe",
                    title: "140+ Languages",
                    description: "Express yourself in any language",
                    color: .orange
                )
                
                FeatureRow(
                    icon: "hare.fill",
                    title: "Optimized Performance",
                    description: "Multimodal AI with efficient memory usage",
                    color: .purple
                )
            }
            .padding(.vertical, 20)
            
            // Action buttons
            VStack(spacing: 12) {
                // Primary download button
                Button {
                    modelManager.startSetup()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Download Gemma 3n")
                                .font(.system(size: 16, weight: .semibold))
                            Text("15.74GB download • One-time setup")
                                .font(.system(size: 12))
                                .opacity(0.8)
                        }
                        
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.purple.opacity(0.3), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
                
                // Learn more button
                Button {
                    showingDetails = true
                } label: {
                    Text("Learn about Gemma 3n")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.05),
                            Color.purple.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.3),
                                    Color.purple.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.purple.opacity(0.1), radius: 20, y: 10)
        .sheet(isPresented: $showingDetails) {
            GemmaDetailsView()
        }
    }
    
    // MARK: - Downloading View
    
    private func downloadingView(progress: Double) -> some View {
        Group {
            if isCompact {
                compactDownloadingView(progress: progress)
            } else {
                fullDownloadingView(progress: progress)
            }
        }
    }
    
    private func compactDownloadingView(progress: Double) -> some View {
        HStack(spacing: 16) {
            // Small progress indicator
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 3)
                    .frame(width: 32, height: 32)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Downloading Gemma 3n")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(modelManager.downloadTimeEstimate)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func fullDownloadingView(progress: Double) -> some View {
        VStack(spacing: 24) {
            // Animated download icon
            ZStack {
                // Progress circle
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)
                
                // Download icon
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(pulseAnimation ? 1.1 : 0.9)
                    .animation(
                        .easeInOut(duration: 1).repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
            }
            
            // Progress info
            VStack(spacing: 12) {
                Text("Downloading Gemma 3n")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(Int(progress * 100))% Complete")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 12)
                            .animation(.spring(response: 0.5), value: progress)
                    }
                }
                .frame(height: 12)
                
                // Time estimate
                Text(modelManager.downloadTimeEstimate)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            // Tips while downloading
            VStack(alignment: .leading, spacing: 12) {
                Text("While you wait...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                TipRow(icon: "cup.and.saucer.fill", text: "Grab a coffee, this is a one-time download")
                TipRow(icon: "wifi", text: "Ensure stable internet connection")
                TipRow(icon: "internaldrive", text: "32GB free space recommended")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.purple.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.Colors.cardBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
        )
    }
    
    // MARK: - Ready Status View
    
    private var readyStatusView: some View {
        HStack(spacing: 16) {
            // Success icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            // Status text
            VStack(alignment: .leading, spacing: 4) {
                Text("Gemma 3n Ready")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Multimodal AI is active and running locally")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Expand button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.05),
                            Color.green.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
        .overlay(alignment: .bottom) {
            if isExpanded {
                expandedDetailsView
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
        }
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Setup Issue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button("Retry") {
                    modelManager.retry()
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.orange)
                
                Button("Get Help") {
                    modelManager.openDocumentation()
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Checking View
    
    private var checkingView: some View {
        HStack(spacing: 16) {
            ProgressView()
                .controlSize(.small)
            
            Text("Checking Gemma 3n status...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    // MARK: - Expanded Details
    
    private var expandedDetailsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .padding(.horizontal, -20)
            
            // Model info
            HStack(spacing: 40) {
                ModelInfoItem(label: "Model", value: "Gemma 3n E4B")
                ModelInfoItem(label: "Size", value: "15.74GB")
                ModelInfoItem(label: "Device", value: modelManager.deviceInfo)
                ModelInfoItem(label: "Status", value: "Active")
            }
            
            // Actions
            HStack(spacing: 12) {
                Button("Open Model Folder") {
                    modelManager.openModelDirectory()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                
                Button("View Logs") {
                    modelManager.viewLogs()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .padding(.top, 60)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.02))
        )
    }
    
    // MARK: - Helper Methods
    
    private func startPulseAnimation() {
        pulseAnimation = true
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.purple)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
    }
}

struct ModelInfoItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Gemma Details View

struct GemmaDetailsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero section
                    VStack(spacing: 16) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Gemma 3n from Google DeepMind")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                        
                        Text("The next generation of on-device, multimodal AI")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    
                    // Key features
                    VStack(alignment: .leading, spacing: 20) {
                        SectionHeader(title: "Key Features")
                        
                        DetailCard(
                            icon: "photo.on.rectangle.angled",
                            title: "True Multimodal Understanding",
                            description: "Process and understand text, images, audio, and video in a single model"
                        )
                        
                        DetailCard(
                            icon: "speedometer",
                            title: "Optimized for Your Mac",
                            description: "Runs efficiently on Apple Silicon with Metal Performance Shaders acceleration"
                        )
                        
                        DetailCard(
                            icon: "lock.shield.fill",
                            title: "Complete Privacy",
                            description: "All processing happens locally. Your data never leaves your device."
                        )
                        
                        DetailCard(
                            icon: "globe",
                            title: "140+ Languages",
                            description: "Express yourself in your native language with excellent multilingual support"
                        )
                    }
                    
                    // Technical specs
                    VStack(alignment: .leading, spacing: 20) {
                        SectionHeader(title: "Technical Specifications")
                        
                        SpecRow(label: "Model Architecture", value: "MatFormer (Matryoshka Transformer)")
                        SpecRow(label: "Parameters", value: "8B (runs like 4B with PLE)")
                        SpecRow(label: "Context Length", value: "32,768 tokens")
                        SpecRow(label: "Download Size", value: "15.74GB")
                        SpecRow(label: "Memory Usage", value: "4-6GB RAM")
                        SpecRow(label: "Required macOS", value: "12.3 or later")
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.05))
                    )
                }
                .padding()
            }
            .navigationTitle("About Gemma 3n")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.primary)
    }
}

struct DetailCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.purple.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct SpecRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Model Manager

@MainActor
class GemmaModelManager: ObservableObject {
    @Published var status: ModelStatus = .checking
    @Published var downloadTimeEstimate = "Calculating..."
    
    private let chatService = NativeChatService.shared
    private let modelDownloader = ModelDownloader()
    private var checkTimer: Timer?
    
    enum ModelStatus: Equatable {
        case checking
        case notInstalled
        case downloading(progress: Double)
        case ready
        case error(message: String)
    }
    
    var deviceInfo: String {
        #if arch(arm64)
        return "Apple Silicon (MPS)"
        #else
        return "Intel Mac"
        #endif
    }
    
    init() {
        startStatusMonitoring()
    }
    
    func checkStatus() {
        Task {
            // Check if model is loaded
            let health = await chatService.health()
            
            let isComplete = await ModelCache.shared.isModelComplete()
            
            await MainActor.run {
                if health.modelLoaded {
                    self.status = .ready
                } else if isComplete {
                    self.status = .downloading(progress: 0.9) // Model exists but loading
                } else {
                    self.status = .notInstalled
                }
            }
        }
    }
    
    func startSetup() {
        Task {
            do {
                // Start model download
                status = .downloading(progress: 0.0)
                try await modelDownloader.startDownload()
                
                // After download, load the model
                try await chatService.loadModel()
                
                // Update status
                status = .ready
            } catch {
                status = .error(message: error.localizedDescription)
            }
        }
        
        // Start monitoring download progress
        startStatusMonitoring()
    }
    
    func retry() {
        status = .checking
        checkStatus()
    }
    
    func openDocumentation() {
        Task {
            // Open documentation URL
            if let url = URL(string: "https://github.com/gemi-app/gemi") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    func openModelDirectory() {
        // Open model directory in Finder
        let modelPath = ModelCache.shared.modelPath
        NSWorkspace.shared.open(modelPath)
    }
    
    func viewLogs() {
        // Open Console app for system logs
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))
    }
    
    private func startStatusMonitoring() {
        checkTimer?.invalidate()
        
        // Monitor download progress
        Task {
            while true {
                await MainActor.run {
                    switch modelDownloader.downloadState {
                    case .downloading(_, let progress):
                        self.status = .downloading(progress: progress)
                        self.downloadTimeEstimate = self.calculateTimeEstimate(progress: progress)
                    case .completed:
                        // Now load the model
                        Task {
                            do {
                                try await chatService.loadModel()
                                await MainActor.run {
                                    self.status = .ready
                                }
                            } catch {
                                await MainActor.run {
                                    self.status = .error(message: error.localizedDescription)
                                }
                            }
                        }
                        return
                    case .failed(let error):
                        self.status = .error(message: error)
                        return
                    default:
                        break
                    }
                }
                
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
    }
    
    private func calculateTimeEstimate(progress: Double) -> String {
        // More realistic time estimate for 15.74GB download
        guard progress > 0.01 else {
            return "Estimating time..."
        }
        
        let remainingProgress = 1.0 - progress
        
        // Estimate based on typical download speeds
        // Assuming 10-50 Mbps average home internet
        // 15.74GB at 25 Mbps = ~84 minutes
        let baseMinutes = 84.0
        let estimatedMinutes = Int(remainingProgress * baseMinutes)
        
        if estimatedMinutes > 60 {
            let hours = estimatedMinutes / 60
            let minutes = estimatedMinutes % 60
            if minutes > 0 {
                return "\(hours)h \(minutes)m remaining"
            } else {
                return "\(hours) hour\(hours > 1 ? "s" : "") remaining"
            }
        } else if estimatedMinutes > 1 {
            return "\(estimatedMinutes) minutes remaining"
        } else if estimatedMinutes == 1 {
            return "1 minute remaining"
        } else {
            return "Almost done..."
        }
    }
    
    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
}