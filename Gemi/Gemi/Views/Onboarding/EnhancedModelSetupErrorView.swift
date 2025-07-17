import SwiftUI

/// Enhanced error view with better guidance for download failures
struct EnhancedModelSetupErrorView: View {
    let error: ModelSetupService.SetupError
    let onRetry: () -> Void
    let onManualSetup: () -> Void
    let onSkip: () -> Void
    
    @State private var showDetails = false
    @State private var showDiagnostics = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Error icon with animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.3), Color.red.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse)
            }
            
            // Error message
            VStack(spacing: 16) {
                Text("Download Failed")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(getMainErrorMessage())
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            
            // Quick actions
            VStack(spacing: 16) {
                // Primary action - Retry
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        onRetry()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Retry Setup")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(width: 280, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                    )
                }
                .buttonStyle(.plain)
                
                // Secondary actions
                HStack(spacing: 16) {
                    Button {
                        onManualSetup()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.gearshape")
                                .font(.system(size: 14))
                            Text("Manual Setup")
                        }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        showDiagnostics.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "stethoscope")
                                .font(.system(size: 14))
                            Text("Diagnostics")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Helpful tips
            if !showDiagnostics {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow.opacity(0.8))
                        
                        Text("Common Solutions")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(getSolutionSteps(), id: \.self) { step in
                            Label(step, systemImage: "checkmark.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .frame(maxWidth: 600)
            }
            
            // Diagnostics panel
            if showDiagnostics {
                DiagnosticsPanel(error: error)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }
            
            // Show details toggle
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showDetails.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(showDetails ? "Hide technical details" : "Show technical details")
                        .font(.system(size: 14, weight: .medium))
                    
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            
            // Technical details
            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Error Details")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(error.localizedDescription)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.3))
                        )
                }
                .frame(maxWidth: 600)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.5), value: showDetails)
        .animation(.spring(response: 0.5), value: showDiagnostics)
    }
    
    private func getMainErrorMessage() -> String {
        switch error {
        case .downloadFailed(let reason):
            if reason.contains("too small") || reason.contains("171423 bytes") {
                return "The model files appear to be corrupted or incomplete."
            } else if reason.contains("401") || reason.contains("403") {
                return "Authentication issue. The model access may have changed."
            } else if reason.contains("timeout") {
                return "The download timed out. Your internet connection may be too slow."
            } else if reason.contains("network") {
                return "Network error. Please check your internet connection."
            } else {
                return "The model download encountered an issue."
            }
        case .authenticationRequired:
            return "Model access requires authentication."
        case .modelNotFound:
            return "Model files could not be found."
        case .loadFailed:
            return "The model could not be loaded into memory."
        }
    }
    
    private func getSolutionSteps() -> [String] {
        switch error {
        case .downloadFailed(let reason):
            if reason.contains("too small") || reason.contains("171423 bytes") {
                return [
                    "Check your internet connection stability",
                    "Try using a different network (WiFi vs cellular)",
                    "Disable VPN or proxy if using one",
                    "Clear download cache and retry"
                ]
            } else if reason.contains("timeout") {
                return [
                    "Use a faster internet connection",
                    "Close other apps using bandwidth",
                    "Try downloading during off-peak hours",
                    "Consider manual setup for slow connections"
                ]
            } else {
                return [
                    "Check your internet connection",
                    "Restart Gemi and try again",
                    "Try again in a few minutes",
                    "Contact support if issue persists"
                ]
            }
        case .authenticationRequired:
            return [
                "Ensure you have a HuggingFace account",
                "Accept the model license agreement",
                "Try manual setup with your own token",
                "Contact support for assistance"
            ]
        default:
            return [
                "Restart Gemi and try again",
                "Check available disk space",
                "Ensure you have 20GB free space",
                "Try manual setup as alternative"
            ]
        }
    }
}

// Diagnostics panel for advanced troubleshooting
struct DiagnosticsPanel: View {
    let error: ModelSetupService.SetupError
    @State private var diagnosticResults: [DiagnosticResult] = []
    
    struct DiagnosticResult: Identifiable {
        let id = UUID()
        let test: String
        let status: Status
        let detail: String
        
        enum Status {
            case success, warning, failure, checking
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "stethoscope")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("System Diagnostics")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(diagnosticResults) { result in
                    HStack(spacing: 12) {
                        // Status icon
                        Group {
                            switch result.status {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            case .warning:
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                            case .failure:
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            case .checking:
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.test)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text(result.detail)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Spacer()
                    }
                }
            }
            
            Button {
                runDiagnostics()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                    Text("Run Diagnostics")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: 600)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            runDiagnostics()
        }
    }
    
    private func runDiagnostics() {
        diagnosticResults = []
        
        Task {
            // Check internet connectivity
            await addDiagnostic(
                test: "Internet Connection",
                check: {
                    let url = URL(string: "https://huggingface.co")!
                    let (_, response) = try await URLSession.shared.data(from: url)
                    return (response as? HTTPURLResponse)?.statusCode == 200
                },
                successDetail: "Connected to internet",
                failureDetail: "No internet connection"
            )
            
            // Check HuggingFace availability
            await addDiagnostic(
                test: "HuggingFace Access",
                check: {
                    let url = URL(string: "https://huggingface.co/api/models/google/gemma-3n-E4B-it")!
                    let (_, response) = try await URLSession.shared.data(from: url)
                    return (response as? HTTPURLResponse)?.statusCode == 200
                },
                successDetail: "HuggingFace API accessible",
                failureDetail: "Cannot reach HuggingFace"
            )
            
            // Check disk space
            await addDiagnostic(
                test: "Disk Space",
                check: {
                    let fileManager = FileManager.default
                    let path = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.path
                    let attributes = try fileManager.attributesOfFileSystem(forPath: path)
                    let freeSpace = attributes[.systemFreeSize] as? Int64 ?? 0
                    return freeSpace > 20_000_000_000 // 20GB
                },
                successDetail: "Sufficient disk space available",
                failureDetail: "Insufficient disk space (need 20GB)"
            )
            
            // Check model directory permissions
            await addDiagnostic(
                test: "File Permissions",
                check: {
                    let modelPath = ModelCache.shared.modelPath
                    return FileManager.default.isWritableFile(atPath: modelPath.path)
                },
                successDetail: "Model directory is writable",
                failureDetail: "Cannot write to model directory"
            )
        }
    }
    
    private func addDiagnostic(
        test: String,
        check: () async throws -> Bool,
        successDetail: String,
        failureDetail: String
    ) async {
        await MainActor.run {
            diagnosticResults.append(
                DiagnosticResult(
                    test: test,
                    status: .checking,
                    detail: "Checking..."
                )
            )
        }
        
        do {
            let success = try await check()
            await MainActor.run {
                if let index = diagnosticResults.firstIndex(where: { $0.test == test }) {
                    diagnosticResults[index] = DiagnosticResult(
                        test: test,
                        status: success ? .success : .failure,
                        detail: success ? successDetail : failureDetail
                    )
                }
            }
        } catch {
            await MainActor.run {
                if let index = diagnosticResults.firstIndex(where: { $0.test == test }) {
                    diagnosticResults[index] = DiagnosticResult(
                        test: test,
                        status: .failure,
                        detail: error.localizedDescription
                    )
                }
            }
        }
    }
}