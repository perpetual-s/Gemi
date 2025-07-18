import SwiftUI

/// Beautiful setup progress view for Gemma 3n installation
struct GemmaSetupProgressView: View {
    @StateObject private var setupManager = ModelSetupService()
    @StateObject private var settingsManager = SettingsManager.shared
    let onComplete: () -> Void
    let onSkip: () -> Void
    
    @State private var showingError = false
    @State private var pulseAnimation = false
    @State private var hasCalledCompletion = false
    @State private var contentOpacity: Double = 0.0
    @State private var hasStartedSetup = false
    @State private var showContent = false
    // @State private var showingTokenView = false // No longer needed - embedded token
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            if let error = setupManager.error {
                // Use our beautiful error view instead of basic alert
                errorView(for: error)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            } else {
                if showContent && hasStartedSetup {
                    contentView
                        .opacity(contentOpacity)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            pulseAnimation = true
            // Smooth fade-in to prevent flash of initial state
            Task {
                // Small delay to ensure view is fully rendered
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // Show content container
                withAnimation(.easeIn(duration: 0.01)) {
                    showContent = true
                }
                
                // Wait a bit more for the container to be ready
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // Fade in content
                withAnimation(.easeIn(duration: 0.3)) {
                    contentOpacity = 1.0
                }
                
                // Start setup after content is visible
                if !hasStartedSetup {
                    hasStartedSetup = true
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    setupManager.startSetup()
                }
            }
        }
        .animation(.spring(response: 0.5), value: setupManager.error != nil)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.05, blue: 0.2),
                Color(red: 0.05, green: 0.05, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var contentView: some View {
        VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Text("Setting Up Gemma 3n")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(setupManager.currentStep.rawValue)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [currentStepColor(), currentStepColor().opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                // Progress section
                VStack(spacing: 24) {
                    // Status indicator with animation
                    HStack(spacing: 12) {
                        // Animated progress indicator
                        if !setupManager.isComplete && setupManager.error == nil {
                            ZStack {
                                Circle()
                                    .stroke(lineWidth: 3)
                                    .foregroundColor(.white.opacity(0.1))
                                    .frame(width: 28, height: 28)
                                
                                Circle()
                                    .trim(from: 0, to: 0.8)
                                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .foregroundColor(currentStepColor())
                                    .frame(width: 28, height: 28)
                                    .rotationEffect(.degrees(pulseAnimation ? 360 : 0))
                                    .animation(
                                        .linear(duration: 1.5)
                                        .repeatForever(autoreverses: false),
                                        value: pulseAnimation
                                    )
                            }
                        } else if setupManager.isComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.green)
                        } else if setupManager.error != nil {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.orange)
                        }
                    }
                    .frame(maxWidth: 600)
                    
                    // Show beautiful progress bar when downloading
                    if setupManager.currentStep == .downloadingModel && setupManager.downloaderState.isDownloading {
                        ModelDownloadProgressView(
                            progress: setupManager.downloadProgress,
                            downloadState: setupManager.downloaderState,
                            currentFile: setupManager.currentDownloadFile,
                            bytesDownloaded: setupManager.downloadedBytes,
                            totalBytes: setupManager.totalDownloadBytes,
                            downloadStartTime: setupManager.downloadStartTime,
                            downloadSpeed: setupManager.downloadSpeed,
                            onCancel: {
                                setupManager.modelDownloader.cancelDownload()
                            }
                        )
                        .padding(.top, 20)
                    } else if setupManager.currentStep == .downloadingModel && setupManager.downloaderState == .preparing {
                        // Show loading state when preparing download
                        OnboardingLoadingView(
                            title: "Preparing Download",
                            subtitle: "Setting up secure connection..."
                        )
                        .frame(maxWidth: 400)
                    } else if case .cancelled = setupManager.downloaderState {
                        // Cancelled state UI
                        VStack(spacing: 20) {
                            Text("cancelled")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            VStack(spacing: 16) {
                                Image(systemName: "pause.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.orange, Color.orange.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                VStack(spacing: 8) {
                                    Text("Download Paused")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("The model download has been paused. You can resume it anytime.")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: 400)
                                }
                                
                                // Progress info
                                if setupManager.downloadedBytes > 0 {
                                    HStack {
                                        Image(systemName: "arrow.down.circle")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.5))
                                        
                                        Text("\(ByteCountFormatter.string(fromByteCount: setupManager.downloadedBytes, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: setupManager.totalDownloadBytes, countStyle: .file)) downloaded")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            .padding(32)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            .frame(maxWidth: 500)
                        }
                    } else if setupManager.currentStep == .loadingModel {
                        // Use beautiful loading view for model loading
                        OnboardingLoadingView(
                            title: "Loading Model",
                            subtitle: "Initializing Gemma 3n in memory..."
                        )
                        .frame(maxWidth: 400)
                    } else {
                        // Status message for other steps
                        Text(setupManager.statusMessage)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .frame(minHeight: 40)
                            .animation(.easeInOut, value: setupManager.statusMessage)
                    }
                    
                    // Step indicators (hide when showing download progress or cancelled state)
                    if !(setupManager.currentStep == .downloadingModel && setupManager.downloaderState.isDownloading) && 
                       setupManager.downloaderState != .cancelled {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(ModelSetupService.SetupStep.allCases.filter { $0 != .complete }, id: \.self) { step in
                                StepIndicator(
                                    step: step,
                                    currentStep: setupManager.currentStep,
                                    isComplete: setupManager.currentStep.ordinalValue > step.ordinalValue
                                )
                            }
                        }
                        .frame(maxWidth: 500)
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                }
                
                Spacer()
                    .frame(minHeight: 10, maxHeight: 20)
                
                // Action buttons
                HStack(spacing: 16) {
                    if setupManager.isComplete {
                        OnboardingButton(
                            "Start Using Gemi",
                            icon: "checkmark.circle.fill",
                            action: {
                                guard !hasCalledCompletion else { return }
                                hasCalledCompletion = true
                                onComplete()
                            }
                        )
                        .transition(.scale.combined(with: .opacity))
                    } else if case .cancelled = setupManager.downloaderState {
                        // Cancelled state buttons
                        OnboardingButton(
                            "Resume Download",
                            icon: "play.fill",
                            action: {
                                Task {
                                    await setupManager.resumeDownload()
                                }
                            }
                        )
                        
                        OnboardingButton(
                            "Set up later",
                            style: .text,
                            action: {
                                guard !hasCalledCompletion else { return }
                                hasCalledCompletion = true
                                onSkip()
                            }
                        )
                    } else if setupManager.error != nil {
                        // Error buttons moved to errorView
                    }
                    
                    if !setupManager.isComplete && setupManager.downloaderState != .cancelled {
                        OnboardingButton(
                            "Set up later",
                            style: .text,
                            action: {
                                guard !hasCalledCompletion else { return }
                                hasCalledCompletion = true
                                onSkip()
                            }
                        )
                    }
                }
            }
        .padding(.horizontal, 40)
        .padding(.vertical, 50)
    }
    
    private func currentStepColor() -> Color {
        if setupManager.isComplete {
            return .green
        } else if setupManager.error != nil {
            return .orange
        }
        
        switch setupManager.currentStep {
        case .checkingModel:
            return .blue
        case .downloadingModel:
            return .indigo
        case .loadingModel:
            return .purple
        case .complete:
            return .green
        }
    }
    
    // MARK: - Error View
    
    @ViewBuilder
    private func errorView(for error: ModelSetupService.SetupError) -> some View {
        VStack(spacing: 40) {
            Spacer()
            
            switch error {
            case .downloadFailed(let reason):
                if reason.contains("401") || reason.contains("403") || reason.contains("authentication") {
                    // Authentication error
                    OnboardingErrorView(
                        title: "Authentication Required",
                        message: "The model requires authentication to download. This has been configured incorrectly.",
                        primaryAction: (
                            title: "Contact Support",
                            action: {
                                NSWorkspace.shared.open(URL(string: "https://github.com/yourusername/gemi/issues")!)
                            }
                        ),
                        secondaryAction: (
                            title: "Try Again",
                            action: {
                                setupManager.error = nil
                                setupManager.startSetup()
                            }
                        )
                    )
                } else if reason.contains("network") || reason.contains("connection") {
                    // Network error
                    OnboardingErrorView(
                        title: "Connection Failed",
                        message: "Unable to connect to download the model. Please check your internet connection.",
                        primaryAction: (
                            title: "Retry Download",
                            action: {
                                setupManager.error = nil
                                setupManager.startSetup()
                            }
                        ),
                        secondaryAction: (
                            title: "Manual Setup",
                            action: {
                                ModelSetupHelper.openManualSetup()
                            }
                        )
                    )
                } else {
                    // Generic download error
                    OnboardingErrorView(
                        title: "Download Failed",
                        message: reason,
                        primaryAction: (
                            title: "Retry Setup",
                            action: {
                                setupManager.error = nil
                                setupManager.startSetup()
                            }
                        ),
                        secondaryAction: (
                            title: "Manual Setup",
                            action: {
                                ModelSetupHelper.openManualSetup()
                            }
                        )
                    )
                }
                
            case .loadFailed(let reason):
                // Model loading error
                OnboardingErrorView(
                    title: "Loading Failed",
                    message: "Unable to load the model: \(reason)\n\nThis might be due to insufficient memory.",
                    primaryAction: (
                        title: "Try Again",
                        action: {
                            setupManager.error = nil
                            setupManager.startSetup()
                        }
                    ),
                    secondaryAction: (
                        title: "Skip for Now",
                        action: {
                            guard !hasCalledCompletion else { return }
                            hasCalledCompletion = true
                            onSkip()
                        }
                    )
                )
                
            case .modelNotFound:
                // Model not found error
                OnboardingErrorView(
                    title: "Model Not Found",
                    message: "The Gemma 3n model needs to be downloaded.",
                    primaryAction: (
                        title: "Download Now",
                        action: {
                            setupManager.error = nil
                            setupManager.startSetup()
                        }
                    ),
                    secondaryAction: (
                        title: "Set up Later",
                        action: {
                            guard !hasCalledCompletion else { return }
                            hasCalledCompletion = true
                            onSkip()
                        }
                    )
                )
                
            case .authenticationRequired:
                // Configuration error
                OnboardingErrorView(
                    title: "Configuration Error",
                    message: "There was a problem with the download configuration. Please try again.",
                    primaryAction: (
                        title: "Retry",
                        action: {
                            setupManager.error = nil
                            setupManager.startSetup()
                        }
                    ),
                    secondaryAction: (
                        title: "Skip Setup",
                        action: {
                            guard !hasCalledCompletion else { return }
                            hasCalledCompletion = true
                            onSkip()
                        }
                    )
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Supporting Views

struct StepIndicator: View {
    let step: ModelSetupService.SetupStep
    let currentStep: ModelSetupService.SetupStep
    let isComplete: Bool
    
    var isActive: Bool {
        step == currentStep
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        isComplete ? Color.green.opacity(0.2) :
                        isActive ? Color.purple.opacity(0.2) :
                        Color.white.opacity(0.05)
                    )
                    .frame(width: 40, height: 40)
                
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: step.icon)
                        .font(.system(size: 18))
                        .foregroundColor(
                            isActive ? .purple : .white.opacity(0.3)
                        )
                }
            }
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(step.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(
                        isComplete ? .green :
                        isActive ? .white :
                        .white.opacity(0.5)
                    )
                
                if isActive {
                    if step == .downloadingModel {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.description)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                            Text("Model size: 15.74 GB")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    } else {
                        Text(step.description)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Status
            if isActive && !isComplete {
                ProgressView()
                    .controlSize(.small)
                    .tint(.purple)
            }
        }
        .animation(.easeInOut, value: isActive)
    }
}

// Extension to get ordinal value for steps
extension ModelSetupService.SetupStep {
    var ordinalValue: Int {
        switch self {
        case .checkingModel: return 0
        case .downloadingModel: return 1
        case .loadingModel: return 2
        case .complete: return 3
        }
    }
}

struct GemmaSetupProgressView_Previews: PreviewProvider {
    static var previews: some View {
        GemmaSetupProgressView(onComplete: {}, onSkip: {})
            .frame(width: 900, height: 600)
    }
}