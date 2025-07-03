//
//  OllamaSetupView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import SwiftUI

/// View for guiding users through Ollama setup
struct OllamaSetupView: View {
    @Binding var isPresented: Bool
    @State private var ollamaService: OllamaService
    @State private var isCheckingStatus: Bool = false
    @State private var setupPhase: SetupPhase = .checking
    @State private var showCopyConfirmation: Bool = false
    @State private var pulseAnimation: Bool = false
    
    init(isPresented: Binding<Bool>, ollamaService: OllamaService) {
        self._isPresented = isPresented
        self._ollamaService = State(initialValue: ollamaService)
    }
    
    enum SetupPhase {
        case checking
        case notRunning
        case notInstalled
        case downloading
        case ready
        case error(String)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
                .opacity(0.1)
            
            // Content
            ScrollView {
                VStack(spacing: 32) {
                    // Status illustration
                    statusIllustration
                    
                    // Status message
                    statusMessage
                    
                    // Action area
                    actionArea
                }
                .padding(40)
            }
        }
        .frame(width: 600, height: 500)
        .background(DesignSystem.Colors.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Components.radiusFloating))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusFloating)
                .stroke(DesignSystem.Colors.divider.opacity(0.5), lineWidth: 0.5)
        )
        .gemiFloatingPanel(isMainPanel: true)
        .onAppear {
            checkOllamaStatus()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primary.opacity(0.15),
                                DesignSystem.Colors.primary.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Image(systemName: "cpu")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Setup")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("Configure your local AI assistant")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            // Close button
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.hover)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    // MARK: - Status Illustration
    
    @ViewBuilder
    private var statusIllustration: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.primary.opacity(0.1),
                            DesignSystem.Colors.primary.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                .opacity(pulseAnimation ? 0.5 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 2)
                        .repeatForever(autoreverses: true),
                    value: pulseAnimation
                )
            
            // Icon based on status
            Group {
                switch setupPhase {
                case .checking:
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                    
                case .notRunning, .notInstalled:
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.warning)
                    
                case .downloading:
                    ZStack {
                        Circle()
                            .stroke(DesignSystem.Colors.divider, lineWidth: 4)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: ollamaService.downloadProgress)
                            .stroke(
                                DesignSystem.Colors.primary,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(ollamaService.downloadProgress * 100))%")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.primary)
                    }
                    
                case .ready:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.success)
                    
                case .error:
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 60, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.error)
                }
            }
        }
        .onAppear {
            pulseAnimation = true
        }
    }
    
    // MARK: - Status Message
    
    @ViewBuilder
    private var statusMessage: some View {
        VStack(spacing: 12) {
            Group {
                switch setupPhase {
                case .checking:
                    Text("Checking AI Status")
                        .font(DesignSystem.Typography.title3)
                    Text("Looking for Ollama on your system...")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    
                case .notRunning:
                    Text("Ollama Not Running")
                        .font(DesignSystem.Typography.title3)
                    Text("Ollama is installed but not currently running")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    
                case .notInstalled:
                    Text("Model Not Installed")
                        .font(DesignSystem.Typography.title3)
                    Text("The Gemma AI model needs to be downloaded")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    
                case .downloading:
                    Text("Downloading Model")
                        .font(DesignSystem.Typography.title3)
                    Text(ollamaService.statusMessage)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    
                case .ready:
                    Text("AI Ready!")
                        .font(DesignSystem.Typography.title3)
                    Text("Your local AI assistant is ready to help")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    
                case .error(let message):
                    Text("Setup Error")
                        .font(DesignSystem.Typography.title3)
                    Text(message)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Action Area
    
    @ViewBuilder
    private var actionArea: some View {
        VStack(spacing: 16) {
            switch setupPhase {
            case .checking:
                EmptyView()
                
            case .notRunning:
                instructionBox(
                    title: "Start Ollama",
                    steps: [
                        "Open Terminal app",
                        "Run: ollama serve",
                        "Keep Terminal open while using Gemi"
                    ]
                )
                
                Button("Check Again") {
                    checkOllamaStatus()
                }
                .gemiPrimaryButton()
                
            case .notInstalled:
                instructionBox(
                    title: "Install Required Models",
                    steps: [
                        "Open Terminal app",
                        "Run: ollama pull \(ModelNameHelper.normalize("gemma3n"))",
                        "Run: ollama pull \(ModelNameHelper.normalize("nomic-embed-text"))",
                        "Wait for downloads to complete"
                    ]
                )
                
                HStack(spacing: 12) {
                    Button("Copy Commands") {
                        copyCommands()
                    }
                    .gemiSecondaryButton()
                    
                    Button("Check Again") {
                        checkOllamaStatus()
                    }
                    .gemiPrimaryButton()
                }
                
            case .downloading:
                Button("Cancel Download") {
                    ollamaService.cancelActiveOperations()
                    setupPhase = .notInstalled
                }
                .gemiSecondaryButton()
                
            case .ready:
                Button("Get Started") {
                    isPresented = false
                }
                .gemiPrimaryButton()
                
            case .error:
                Button("Try Again") {
                    checkOllamaStatus()
                }
                .gemiPrimaryButton()
            }
            
            if showCopyConfirmation {
                Text("Commands copied to clipboard!")
                    .font(DesignSystem.Typography.footnote)
                    .foregroundStyle(DesignSystem.Colors.success)
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }
    
    // MARK: - Instruction Box
    
    private func instructionBox(title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(DesignSystem.Typography.footnote)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(DesignSystem.Colors.hover)
                            )
                        
                        Text(step)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                .fill(DesignSystem.Colors.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                        .stroke(DesignSystem.Colors.divider.opacity(0.5), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Methods
    
    private func checkOllamaStatus() {
        isCheckingStatus = true
        setupPhase = .checking
        
        Task {
            // Check if Ollama is running
            let isRunning = await ollamaService.checkOllamaStatus()
            
            if !isRunning {
                await MainActor.run {
                    setupPhase = .notRunning
                    isCheckingStatus = false
                }
                return
            }
            
            // Check if models are installed
            await ollamaService.checkModelStatus()
            
            await MainActor.run {
                if ollamaService.isModelInstalled {
                    setupPhase = .ready
                } else {
                    setupPhase = .notInstalled
                }
                isCheckingStatus = false
            }
        }
    }
    
    private func copyCommands() {
        let commands = """
        ollama pull \(ModelNameHelper.normalize("gemma3n"))
        ollama pull \(ModelNameHelper.normalize("nomic-embed-text"))
        """
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(commands, forType: .string)
        
        withAnimation(.spring(response: 0.3)) {
            showCopyConfirmation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3)) {
                showCopyConfirmation = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isPresented = true
    
    OllamaSetupView(
        isPresented: $isPresented,
        ollamaService: OllamaService()
    )
    .frame(width: 800, height: 600)
    .background(DesignSystem.Colors.canvasBackground)
}