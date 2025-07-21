import SwiftUI

/// Simplified model status view for bundled Gemma model
struct SimplifiedModelStatusView: View {
    @StateObject private var modelManager = SimplifiedModelManager()
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon
            
            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text("Gemma 3n Model")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(modelManager.statusMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action button if needed
            if modelManager.showActionButton {
                actionButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .onAppear {
            modelManager.startMonitoring()
        }
    }
    
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: 32, height: 32)
            
            Image(systemName: modelManager.status.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)
        }
    }
    
    private var actionButton: some View {
        Button(action: modelManager.performAction) {
            Text(modelManager.actionButtonTitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var borderColor: Color {
        switch modelManager.status {
        case .ready:
            return Color.green.opacity(0.3)
        case .loading:
            return Color.blue.opacity(0.3)
        case .error:
            return Color.red.opacity(0.3)
        case .checking:
            return Color.gray.opacity(0.2)
        }
    }
    
    private var iconBackgroundColor: Color {
        switch modelManager.status {
        case .ready:
            return Color.green.opacity(0.1)
        case .loading:
            return Color.blue.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        case .checking:
            return Color.gray.opacity(0.1)
        }
    }
    
    private var iconColor: Color {
        switch modelManager.status {
        case .ready:
            return .green
        case .loading:
            return .blue
        case .error:
            return .red
        case .checking:
            return .gray
        }
    }
}

/// Simplified model manager for bundled models
@MainActor
class SimplifiedModelManager: ObservableObject {
    @Published var status: ModelStatus = .checking
    @Published var statusMessage = "Checking model..."
    @Published var showActionButton = false
    @Published var actionButtonTitle = ""
    
    private let chatService = NativeChatService.shared
    private var checkTimer: Timer?
    
    enum ModelStatus {
        case checking
        case loading
        case ready
        case error
        
        var icon: String {
            switch self {
            case .checking:
                return "magnifyingglass"
            case .loading:
                return "arrow.triangle.2.circlepath"
            case .ready:
                return "checkmark.circle.fill"
            case .error:
                return "exclamationmark.triangle.fill"
            }
        }
    }
    
    func startMonitoring() {
        checkModelStatus()
        
        // Set up periodic checking
        checkTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                self.checkModelStatus()
            }
        }
    }
    
    func performAction() {
        if status == .error {
            // Try to load the model
            Task {
                status = .loading
                statusMessage = "Loading model..."
                showActionButton = false
                
                do {
                    try await chatService.loadModel()
                    checkModelStatus()
                } catch {
                    status = .error
                    statusMessage = "Failed to load model"
                    showActionButton = true
                    actionButtonTitle = "Retry"
                }
            }
        }
    }
    
    private func checkModelStatus() {
        Task {
            let health = await chatService.health()
            
            if health.modelLoaded {
                status = .ready
                statusMessage = "Model ready"
                showActionButton = false
            } else {
                // Check if model files exist
                let modelReady = await chatService.checkModelReady()
                if modelReady {
                    status = .error
                    statusMessage = "Model not loaded"
                    showActionButton = true
                    actionButtonTitle = "Load Model"
                } else {
                    status = .error
                    statusMessage = "Model files missing"
                    showActionButton = false
                }
            }
        }
    }
    
    deinit {
        checkTimer?.invalidate()
    }
}