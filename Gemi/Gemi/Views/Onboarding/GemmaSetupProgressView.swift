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
    @State private var showingTokenView = false
    
    var body: some View {
        ZStack {
            backgroundGradient
            contentView
        }
        .onAppear {
            pulseAnimation = true
            // Check for HuggingFace token before starting setup
            // If we have an environment token or user token, start setup immediately
            if settingsManager.hasHuggingFaceToken || settingsManager.hasEnvironmentToken {
                setupManager.startSetup()
            } else {
                showingTokenView = true
            }
        }
        .sheet(isPresented: $showingTokenView) {
            HuggingFaceTokenView {
                // Token saved callback
                showingTokenView = false
                setupManager.startSetup()
            }
        }
        .alert("Setup Error", isPresented: .init(
            get: { setupManager.error != nil },
            set: { _ in setupManager.error = nil }
        )) {
            Button("OK") { }
        } message: {
            if let error = setupManager.error {
                Text(error.localizedDescription)
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                }
            }
        }
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
                            onCancel: {
                                setupManager.modelDownloader.cancelDownload()
                            }
                        )
                        .padding(.top, 20)
                    } else {
                        // Status message for other steps
                        Text(setupManager.statusMessage)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .frame(minHeight: 40)
                            .animation(.easeInOut, value: setupManager.statusMessage)
                    }
                    
                    // Step indicators (hide when showing download progress)
                    if !(setupManager.currentStep == .downloadingModel && setupManager.downloaderState.isDownloading) {
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
                        Button {
                            guard !hasCalledCompletion else { return }
                            hasCalledCompletion = true
                            onComplete()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Start Using Gemi")
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 280, height: 56)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                                    .shadow(color: .white.opacity(0.3), radius: 20, y: 10)
                            )
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    } else if setupManager.error != nil {
                        Button {
                            // Check if authentication error - show token view
                            if case .authenticationRequired = setupManager.error {
                                showingTokenView = true
                            } else {
                                setupManager.startSetup()
                            }
                        } label: {
                            HStack {
                                Image(systemName: setupManager.error == .authenticationRequired ? "key.fill" : "arrow.clockwise")
                                Text(setupManager.error == .authenticationRequired ? "Add Token" : "Retry Setup")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            ModelSetupHelper.openManualSetup()
                        } label: {
                            HStack {
                                Image(systemName: "terminal")
                                Text("Manual Setup")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if !setupManager.isComplete {
                        Button {
                            guard !hasCalledCompletion else { return }
                            hasCalledCompletion = true
                            onSkip()
                        } label: {
                            Text("Set up later")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
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
                            Text("Model size: 15.7 GB")
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