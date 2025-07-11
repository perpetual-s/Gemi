import SwiftUI

/// Beautiful setup progress view for Gemma 3n installation
struct GemmaSetupProgressView: View {
    @StateObject private var setupManager = PythonEnvironmentSetup()
    let onComplete: () -> Void
    let onSkip: () -> Void
    
    @State private var showingError = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Content
            VStack(spacing: 40) {
                Spacer()
                    .frame(height: 40)
                
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
                    // Overall progress bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Overall Progress")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("\(Int(setupManager.progress * 100))%")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [currentStepColor(), currentStepColor().opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 16)
                                
                                // Progress
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [currentStepColor(), currentStepColor().opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * setupManager.progress, height: 16)
                                    .animation(.spring(response: 0.5), value: setupManager.progress)
                                
                                // Shimmer effect
                                if !setupManager.isComplete {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.clear,
                                                    Color.white.opacity(0.3),
                                                    Color.clear
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 100, height: 16)
                                        .offset(x: geometry.size.width * setupManager.progress - 50)
                                        .animation(
                                            .linear(duration: 1.5)
                                            .repeatForever(autoreverses: false),
                                            value: pulseAnimation
                                        )
                                }
                            }
                        }
                        .frame(height: 16)
                    }
                    .frame(maxWidth: 600)
                    
                    // Status message
                    Text(setupManager.statusMessage)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 40)
                        .animation(.easeInOut, value: setupManager.statusMessage)
                    
                    // Step indicators
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(PythonEnvironmentSetup.SetupStep.allCases.filter { $0 != .complete }, id: \.self) { step in
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
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    if setupManager.isComplete {
                        Button {
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
                            setupManager.startSetup()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry Setup")
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
                            onSkip()
                        } label: {
                            Text("Set up later")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
        .onAppear {
            pulseAnimation = true
            setupManager.startSetup()
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
    
    private func currentStepColor() -> Color {
        if setupManager.isComplete {
            return .green
        } else if setupManager.error != nil {
            return .orange
        }
        
        switch setupManager.currentStep {
        case .checkingEnvironment, .installingUV:
            return .blue
        case .installingDependencies:
            return .purple
        case .launchingServer:
            return .indigo
        case .downloadingModel, .complete:
            return .green
        }
    }
}

// MARK: - Supporting Views

struct StepIndicator: View {
    let step: PythonEnvironmentSetup.SetupStep
    let currentStep: PythonEnvironmentSetup.SetupStep
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
                    Text(step.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
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
extension PythonEnvironmentSetup.SetupStep {
    var ordinalValue: Int {
        switch self {
        case .checkingEnvironment: return 0
        case .installingUV: return 1
        case .installingDependencies: return 2
        case .launchingServer: return 3
        case .downloadingModel: return 4
        case .complete: return 5
        }
    }
}

struct GemmaSetupProgressView_Previews: PreviewProvider {
    static var previews: some View {
        GemmaSetupProgressView(onComplete: {}, onSkip: {})
            .frame(width: 900, height: 600)
    }
}