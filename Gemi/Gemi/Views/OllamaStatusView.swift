import SwiftUI

/// View to display Ollama connection status and handle errors
struct OllamaStatusView: View {
    @StateObject private var statusMonitor = OllamaStatusMonitor()
    @State private var showingSetupGuide = false
    
    var body: some View {
        Group {
            switch statusMonitor.connectionStatus {
            case .checking:
                HStack(spacing: Theme.smallSpacing) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Checking Ollama connection...")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(Theme.smallSpacing)
                
            case .connected:
                EmptyView()
                
            case .disconnected:
                errorBanner
                
            case .modelNotFound:
                modelNotFoundBanner
                
            case .notInstalled:
                notInstalledBanner
                
            case .starting:
                startingBanner
            }
        }
        .onAppear {
            statusMonitor.startMonitoring()
        }
        .onDisappear {
            statusMonitor.cleanup()
        }
    }
    
    private var errorBanner: some View {
        VStack(spacing: Theme.smallSpacing) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("Ollama is not running")
                    .font(Theme.Typography.headline)
                
                Spacer()
                
                Button("Setup Guide") {
                    showingSetupGuide = true
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.Colors.primaryAccent)
            }
            
            Text("To use AI features, please start Ollama by running 'ollama serve' in Terminal")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.spacing)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(Theme.smallCornerRadius)
        .padding(.horizontal, Theme.spacing)
        .sheet(isPresented: $showingSetupGuide) {
            OllamaSetupGuide()
        }
    }
    
    private var modelNotFoundBanner: some View {
        VStack(spacing: Theme.smallSpacing) {
            HStack {
                Image(systemName: "cpu.fill")
                    .foregroundColor(.orange)
                
                Text("Gemma 3n model not found")
                    .font(Theme.Typography.headline)
                
                Spacer()
                
                Button {
                    Task {
                        await statusMonitor.installModel()
                    }
                } label: {
                    if statusMonitor.isInstallingModel {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Install Model")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.Colors.primaryAccent)
                .disabled(statusMonitor.isInstallingModel)
            }
            
            if statusMonitor.isInstallingModel {
                ProgressView(value: statusMonitor.installProgress)
                    .progressViewStyle(.linear)
                
                Text("Downloading Gemma 3n... This may take a few minutes.")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            } else {
                Text("The Gemma 3n model is required for AI features. Click 'Install Model' to download it.")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Theme.spacing)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(Theme.smallCornerRadius)
        .padding(.horizontal, Theme.spacing)
    }
    
    private var notInstalledBanner: some View {
        VStack(spacing: Theme.smallSpacing) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.red)
                
                Text("Ollama not installed")
                    .font(Theme.Typography.headline)
                
                Spacer()
                
                Button("Download Ollama") {
                    statusMonitor.installOllama()
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.Colors.primaryAccent)
            }
            
            Text("Ollama is required for AI features. Click 'Download Ollama' to install it.")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.spacing)
        .background(Color.red.opacity(0.1))
        .cornerRadius(Theme.smallCornerRadius)
        .padding(.horizontal, Theme.spacing)
    }
    
    private var startingBanner: some View {
        VStack(spacing: Theme.smallSpacing) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                
                Text("Starting Ollama...")
                    .font(Theme.Typography.headline)
                
                Spacer()
            }
            
            if !statusMonitor.statusMessage.isEmpty {
                Text(statusMonitor.statusMessage)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Theme.spacing)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(Theme.smallCornerRadius)
        .padding(.horizontal, Theme.spacing)
    }
}

/// Monitor for Ollama connection status
@MainActor
final class OllamaStatusMonitor: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .checking
    @Published var isInstallingModel = false
    @Published var installProgress: Double = 0.0
    @Published var statusMessage = ""
    
    private var timer: Timer?
    private let ollamaService = OllamaService.shared
    private let processManager = OllamaProcessManager.shared
    private var notificationObservers: [NSObjectProtocol] = []
    
    enum ConnectionStatus {
        case checking
        case connected
        case disconnected
        case modelNotFound
        case notInstalled
        case starting
    }
    
    init() {
        setupNotificationObservers()
    }
    
    func cleanup() {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
        stopMonitoring()
    }
    
    private func setupNotificationObservers() {
        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .ollamaStatusChanged,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    self.checkConnection()
                }
            }
        )
        
        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .ollamaModelDownloading,
                object: nil,
                queue: .main
            ) { notification in
                if let status = notification.userInfo?["status"] as? String {
                    Task { @MainActor in
                        self.statusMessage = status
                        self.isInstallingModel = true
                    }
                }
            }
        )
        
        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .ollamaModelReady,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    self.isInstallingModel = false
                    self.connectionStatus = .connected
                }
            }
        )
    }
    
    func startMonitoring() {
        checkConnection()
        
        // Check every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                self.checkConnection()
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkConnection() {
        Task {
            // First check if Ollama is installed
            let isInstalled = await processManager.isOllamaInstalled()
            if !isInstalled {
                connectionStatus = .notInstalled
                return
            }
            
            // Check if server is running
            let isRunning = await processManager.isOllamaServerRunning()
            if !isRunning {
                connectionStatus = .starting
                statusMessage = "Starting Ollama..."
                
                // Try to start it
                do {
                    try await processManager.ensureOllamaRunning()
                    // Will be updated via notification when ready
                } catch {
                    connectionStatus = .disconnected
                    statusMessage = error.localizedDescription
                }
                return
            }
            
            // Check model availability
            do {
                let isHealthy = try await ollamaService.checkHealth()
                connectionStatus = isHealthy ? .connected : .modelNotFound
            } catch {
                connectionStatus = .disconnected
            }
        }
    }
    
    func installModel() async {
        isInstallingModel = true
        installProgress = 0.0
        statusMessage = "Preparing to download Gemma 3n..."
        
        do {
            // Ensure Ollama is running first
            try await processManager.ensureOllamaRunning()
            
            // Model installation will be handled by the process manager
            // via notifications
            
        } catch {
            print("Failed to start Ollama: \(error)")
            connectionStatus = .disconnected
            statusMessage = error.localizedDescription
            isInstallingModel = false
        }
    }
    
    func installOllama() {
        Task {
            await processManager.openOllamaDownloadPage()
        }
    }
}

/// Setup guide for Ollama
struct OllamaSetupGuide: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.largeSpacing) {
            HStack {
                Text("Ollama Setup Guide")
                    .font(Theme.Typography.largeTitle)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
            }
            
            VStack(alignment: .leading, spacing: Theme.spacing) {
                setupStep(1, "Install Ollama", "Visit ollama.ai and download Ollama for macOS")
                setupStep(2, "Start Ollama", "Run 'ollama serve' in Terminal or start the Ollama app")
                setupStep(3, "Install Gemma 3n", "Run 'ollama pull gemma3n' in Terminal")
                setupStep(4, "Restart Gemi", "Once Ollama is running, restart Gemi to enable AI features")
            }
            
            VStack(alignment: .leading, spacing: Theme.smallSpacing) {
                Text("Troubleshooting")
                    .font(Theme.Typography.headline)
                
                Text("• Make sure Ollama is running on port 11434 (default)")
                    .font(Theme.Typography.body)
                Text("• Check if 'ollama list' shows gemma3n:latest")
                    .font(Theme.Typography.body)
                Text("• Try running 'ollama run gemma3n' to test the model")
                    .font(Theme.Typography.body)
            }
            .padding()
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.cornerRadius)
            
            Spacer()
        }
        .padding(Theme.largeSpacing)
        .frame(width: 500, height: 400)
        .background(Theme.Colors.windowBackground)
    }
    
    private func setupStep(_ number: Int, _ title: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: Theme.spacing) {
            Text("\(number)")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.primaryAccent)
                .frame(width: 30, height: 30)
                .background(Theme.Colors.primaryAccent.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.headline)
                Text(description)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
    }
}