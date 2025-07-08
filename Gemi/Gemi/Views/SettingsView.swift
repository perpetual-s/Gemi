import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @State private var showExportSuccess = false
    @State private var showExportError = false
    @State private var showBackupSuccess = false
    @State private var showBackupError = false
    @State private var errorMessage = ""
    let journalStore: JournalStore
    @AppStorage("ollamaHost") private var ollamaHost = OllamaConfiguration.shared.host
    @AppStorage("ollamaPort") private var ollamaPort = OllamaConfiguration.shared.port
    @AppStorage("selectedModel") private var selectedModel = "gemma3n:latest"
    @AppStorage("autoSaveInterval") private var autoSaveInterval = 3.0
    @AppStorage("enableMarkdown") private var enableMarkdown = true
    @AppStorage("defaultFont") private var defaultFont = "System"
    @AppStorage("defaultFontSize") private var defaultFontSize = 14.0
    @AppStorage("sessionTimeout") private var sessionTimeout = 30.0
    @AppStorage("requireAuthentication") private var requireAuthentication = true
    
    private let ollamaService = OllamaService.shared
    @State private var isCheckingConnection = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var availableModels: [String] = []
    @State private var showingDataManagement = false
    @State private var showingAbout = false
    @State private var isLoadingModels = false
    @State private var selectedTabAnimation = false
    
    @Environment(\.dismiss) private var dismiss
    
    enum ConnectionStatus {
        case connected, disconnected, checking, unknown
        
        var color: Color {
            switch self {
            case .connected: return .green
            case .disconnected: return .red
            case .checking: return .orange
            case .unknown: return .gray
            }
        }
        
        var text: String {
            switch self {
            case .connected: return "Connected"
            case .disconnected: return "Disconnected"
            case .checking: return "Checking..."
            case .unknown: return "Unknown"
            }
        }
        
        var icon: String {
            switch self {
            case .connected: return "checkmark.circle.fill"
            case .disconnected: return "xmark.circle.fill"
            case .checking: return "arrow.triangle.2.circlepath"
            case .unknown: return "questionmark.circle"
            }
        }
    }
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case ai = "AI & Models"
        case appearance = "Appearance"
        case security = "Security & Privacy"
        case data = "Data & Sync"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .ai: return "brain"
            case .appearance: return "paintbrush"
            case .security: return "lock.shield"
            case .data: return "externaldrive"
            }
        }
        
        var description: String {
            switch self {
            case .general: return "Configure app behavior and preferences"
            case .ai: return "Manage AI models and connections"
            case .appearance: return "Customize fonts and visual style"
            case .security: return "Privacy settings and authentication"
            case .data: return "Backup and export your journal"
            }
        }
    }
    
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        HSplitView {
            // Premium Sidebar
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Image(systemName: "gear")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                    
                    Text("Settings")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .padding(.bottom, 20)
                }
                
                // Navigation
                VStack(spacing: 2) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        SettingsTabButton(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                    selectedTabAnimation = true
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                
                Spacer()
                
                // Version info
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("Gemi 1.0")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Built for Privacy")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.bottom, 20)
            }
            .frame(width: 260)
            .background(VisualEffectBlur())
            
            // Content Area
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(NSColor.windowBackgroundColor),
                        Color(NSColor.windowBackgroundColor).opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Content Header
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(selectedTab.rawValue)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                
                                Text(selectedTab.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 40)
                        .padding(.bottom, 32)
                        
                        // Tab Content
                        Group {
                            switch selectedTab {
                            case .general:
                                generalSettings
                            case .ai:
                                aiSettings
                            case .appearance:
                                appearanceSettings
                            case .security:
                                securitySettings
                            case .data:
                                dataSettings
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                        .id(selectedTab)
                    }
                    .frame(maxWidth: 700, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 900, height: 650)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            checkConnection()
            loadAvailableModels()
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your journal entries have been exported successfully.")
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Backup Successful", isPresented: $showBackupSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your database has been backed up successfully.")
        }
        .alert("Backup Failed", isPresented: $showBackupError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - General Settings
    
    private var generalSettings: some View {
        VStack(spacing: 24) {
            // Application Settings Card
            PremiumSettingsCard(
                title: "Application",
                icon: "app.badge",
                iconColor: .blue
            ) {
                VStack(spacing: 20) {
                    PremiumToggle(
                        title: "Launch at startup",
                        subtitle: "Start Gemi when you log in",
                        isOn: .constant(false),
                        isDisabled: true
                    )
                    
                    PremiumToggle(
                        title: "Show in menu bar",
                        subtitle: "Quick access from the menu bar",
                        isOn: .constant(false),
                        isDisabled: true
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Auto-save interval")
                                .font(.system(size: 14, weight: .medium))
                            
                            Spacer()
                            
                            Text("\(Int(autoSaveInterval)) seconds")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.blue.opacity(0.1))
                                )
                        }
                        
                        Slider(value: $autoSaveInterval, in: 1...10, step: 1)
                            .tint(.blue)
                    }
                }
            }
            
            // Editor Settings Card
            PremiumSettingsCard(
                title: "Editor",
                icon: "doc.text",
                iconColor: .purple
            ) {
                VStack(spacing: 20) {
                    PremiumToggle(
                        title: "Enable Markdown rendering",
                        subtitle: "Format text with Markdown syntax",
                        isOn: $enableMarkdown
                    )
                    
                    PremiumToggle(
                        title: "Show word count",
                        subtitle: "Display word count in the editor",
                        isOn: .constant(true)
                    )
                    
                    PremiumToggle(
                        title: "Show reading time",
                        subtitle: "Estimate reading time for entries",
                        isOn: .constant(true)
                    )
                }
            }
        }
    }
    
    // MARK: - AI Settings
    
    private var aiSettings: some View {
        VStack(spacing: 24) {
            // Connection Status Card
            PremiumSettingsCard(
                title: "Ollama Connection",
                icon: "network",
                iconColor: connectionStatus.color
            ) {
                VStack(spacing: 24) {
                    // Connection Status Banner
                    HStack(spacing: 16) {
                        Image(systemName: connectionStatus.icon)
                            .font(.system(size: 32))
                            .foregroundColor(connectionStatus.color)
                            .symbolEffect(.pulse, isActive: connectionStatus == .checking)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Connection Status")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(connectionStatus.text)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        Spacer()
                        
                        Button(action: checkConnection) {
                            Label("Test Connection", systemImage: "arrow.clockwise")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(PremiumButtonStyle())
                        .disabled(isCheckingConnection)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(connectionStatus.color.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(connectionStatus.color.opacity(0.2), lineWidth: 1)
                            )
                    )
                    
                    Divider()
                    
                    // Connection Settings
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Host")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            TextField("localhost", text: $ollamaHost)
                                .textFieldStyle(PremiumTextFieldStyle())
                                .frame(width: 200)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Port")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            TextField("11434", value: $ollamaPort, format: .number)
                                .textFieldStyle(PremiumTextFieldStyle())
                                .frame(width: 100)
                        }
                    }
                }
            }
            
            // Model Selection Card
            PremiumSettingsCard(
                title: "AI Model",
                icon: "brain",
                iconColor: .indigo
            ) {
                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Active Model")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Picker("", selection: $selectedModel) {
                                    ForEach(availableModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                                .disabled(isLoadingModels)
                                
                                Button(action: loadAvailableModels) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 14))
                                }
                                .buttonStyle(.plain)
                                .disabled(isLoadingModels)
                                .help("Refresh models")
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Model Info
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                        
                        Text("Recommended: **gemma3n:latest** for optimal performance and privacy")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.05))
                    )
                }
            }
            
            // Installation Help Card
            PremiumSettingsCard(
                title: "Model Installation",
                icon: "arrow.down.circle",
                iconColor: .green
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Install Gemma 3n model")
                        .font(.system(size: 14, weight: .semibold))
                    
                    HStack {
                        Text("ollama pull gemma3n:latest")
                            .font(.system(size: 13, design: .monospaced))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(NSColor.secondarySystemFill))
                            )
                            .textSelection(.enabled)
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("ollama pull gemma3n:latest", forType: .string)
                        }) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .help("Copy to clipboard")
                    }
                    
                    Text("Run this command in Terminal to install the model")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Appearance Settings
    
    private var appearanceSettings: some View {
        VStack(spacing: 24) {
            // Typography Card
            PremiumSettingsCard(
                title: "Typography",
                icon: "textformat",
                iconColor: .orange
            ) {
                VStack(spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Font Family")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $defaultFont) {
                                Text("System").tag("System")
                                Text("San Francisco").tag("SF Pro")
                                Text("New York").tag("New York")
                                Text("Helvetica").tag("Helvetica")
                                Text("Monaco").tag("Monaco")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 180)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Font Size")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Slider(value: $defaultFontSize, in: 11...20, step: 1)
                                    .frame(width: 150)
                                    .tint(.orange)
                                
                                Text("\(Int(defaultFontSize)) pt")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.orange)
                                    .frame(width: 50)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("The quick brown fox jumps over the lazy dog")
                            .font(.system(size: defaultFontSize))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(NSColor.secondarySystemFill))
                            )
                    }
                }
            }
            
            // Theme Card
            PremiumSettingsCard(
                title: "Theme",
                icon: "circle.lefthalf.filled",
                iconColor: .indigo
            ) {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "moon.stars")
                            .font(.system(size: 32))
                            .foregroundColor(.indigo)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Automatic Theme")
                                .font(.system(size: 14, weight: .semibold))
                            
                            Text("Gemi follows your system appearance settings")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Button("Open System Preferences") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.general")!)
                    }
                    .buttonStyle(PremiumButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Security Settings
    
    private var securitySettings: some View {
        VStack(spacing: 24) {
            // Authentication Card
            PremiumSettingsCard(
                title: "Authentication",
                icon: "faceid",
                iconColor: .green
            ) {
                VStack(spacing: 20) {
                    PremiumToggle(
                        title: "Require authentication on launch",
                        subtitle: "Use Face ID, Touch ID, or password to unlock",
                        isOn: $requireAuthentication
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Session timeout")
                                .font(.system(size: 14, weight: .medium))
                            
                            Spacer()
                            
                            Text("\(Int(sessionTimeout)) minutes")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.green.opacity(0.1))
                                )
                        }
                        
                        Slider(value: $sessionTimeout, in: 5...120, step: 5)
                            .tint(.green)
                    }
                    
                    PremiumToggle(
                        title: "Lock when system sleeps",
                        subtitle: "Require authentication after sleep",
                        isOn: .constant(true)
                    )
                }
            }
            
            // Privacy Card
            PremiumSettingsCard(
                title: "Privacy Protection",
                icon: "lock.shield",
                iconColor: .mint
            ) {
                VStack(spacing: 20) {
                    // Encryption Status
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.1))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.green)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your data is encrypted")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("AES-256-GCM encryption protects all journal entries")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.05))
                    )
                    
                    // Privacy Features
                    VStack(spacing: 12) {
                        PrivacyFeatureRow(
                            icon: "icloud.slash",
                            title: "No cloud sync",
                            subtitle: "All data stays on your device"
                        )
                        
                        PrivacyFeatureRow(
                            icon: "eye.slash",
                            title: "No analytics",
                            subtitle: "Zero tracking or telemetry"
                        )
                        
                        PrivacyFeatureRow(
                            icon: "network.slash",
                            title: "Offline-first",
                            subtitle: "Works without internet connection"
                        )
                        
                        PrivacyFeatureRow(
                            icon: "checkmark.seal",
                            title: "Open source",
                            subtitle: "Fully auditable codebase"
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Data Settings
    
    private var dataSettings: some View {
        VStack(spacing: 24) {
            // Storage Overview Card
            PremiumSettingsCard(
                title: "Storage Overview",
                icon: "internaldrive",
                iconColor: .blue
            ) {
                VStack(spacing: 20) {
                    HStack(spacing: 40) {
                        DataMetricView(
                            value: "\(journalStore.entries.count)",
                            label: "Total Entries",
                            icon: "doc.text",
                            color: .blue
                        )
                        
                        DataMetricView(
                            value: formatDatabaseSize(),
                            label: "Database Size",
                            icon: "externaldrive",
                            color: .purple
                        )
                        
                        DataMetricView(
                            value: "\(journalStore.favoriteEntries.count)",
                            label: "Favorites",
                            icon: "star.fill",
                            color: .yellow
                        )
                    }
                    
                    Divider()
                    
                    HStack(spacing: 12) {
                        Button(action: exportEntries) {
                            Label("Export All", systemImage: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(PremiumButtonStyle())
                        
                        Button(action: backupDatabase) {
                            Label("Backup Database", systemImage: "arrow.down.circle")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(PremiumButtonStyle())
                        
                        Spacer()
                        
                        Button(action: { showingDataManagement = true }) {
                            Label("Manage Data", systemImage: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(PremiumButtonStyle(style: .secondary))
                    }
                }
            }
            
            // Automatic Backup Card
            PremiumSettingsCard(
                title: "Automatic Backups",
                icon: "clock.arrow.circlepath",
                iconColor: .orange
            ) {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Coming Soon")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Automatic encrypted backups to your chosen location")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    PremiumToggle(
                        title: "Enable automatic backups",
                        subtitle: "Back up your journal daily",
                        isOn: .constant(false),
                        isDisabled: true
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkConnection() {
        isCheckingConnection = true
        connectionStatus = .checking
        
        Task {
            do {
                let isHealthy = try await ollamaService.checkHealth()
                await MainActor.run {
                    connectionStatus = isHealthy ? .connected : .disconnected
                    isCheckingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionStatus = .disconnected
                    isCheckingConnection = false
                }
            }
        }
    }
    
    private func loadAvailableModels() {
        isLoadingModels = true
        availableModels = ["gemma3n:latest"] // Default
        
        Task {
            // TODO: Implement listLocalModels
            let models: [String] = ["gemma3n:latest"]
            await MainActor.run {
                availableModels = models.isEmpty ? ["gemma3n:latest"] : models
                isLoadingModels = false
            }
        }
    }
    
    private func formatDatabaseSize() -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        // TODO: Get actual database size
        let fileSize: Int64 = 1024 * 1024
        return formatter.string(fromByteCount: fileSize)
    }
    
    private func exportEntries() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "gemi-export-\(Date().ISO8601Format())"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            Task {
                do {
                    let entries = journalStore.entries
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    encoder.dateEncodingStrategy = .iso8601
                    
                    let data = try encoder.encode(entries)
                    try data.write(to: url)
                    
                    showExportSuccess = true
                } catch {
                    errorMessage = error.localizedDescription
                    showExportError = true
                }
            }
        }
    }
    
    private func backupDatabase() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.database]
        savePanel.nameFieldStringValue = "gemi-backup-\(Date().ISO8601Format())"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            Task {
                do {
                    // Get proper application support directory
                    let appSupportURL = try FileManager.default.url(
                        for: .applicationSupportDirectory,
                        in: .userDomainMask,
                        appropriateFor: nil,
                        create: false
                    )
                    let bundleID = Bundle.main.bundleIdentifier ?? "com.gemi.app"
                    let sourceURL = appSupportURL
                        .appendingPathComponent(bundleID)
                        .appendingPathComponent("gemi.db")
                    
                    if FileManager.default.fileExists(atPath: sourceURL.path) {
                        try FileManager.default.copyItem(at: sourceURL, to: url)
                        showBackupSuccess = true
                    } else {
                        errorMessage = "Database file not found"
                        showBackupError = true
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    showBackupError = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct SettingsTabButton: View {
    let tab: SettingsView.SettingsTab
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16))
                    .frame(width: 24)
                
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                
                Spacer()
            }
            .foregroundColor(isSelected ? .primary : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color.gray.opacity(0.08) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct PremiumSettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
            }
            
            content
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

struct PremiumToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var isDisabled: Bool = false
    
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(SwitchToggleStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

struct PremiumButtonStyle: ButtonStyle {
    enum Style {
        case primary, secondary
    }
    
    var style: Style = .primary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(style == .primary ? Color.accentColor : Color.gray.opacity(0.15))
            )
            .foregroundColor(style == .primary ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PremiumTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
    }
}

struct PrivacyFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.mint)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct DataMetricView: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

#Preview {
    SettingsView(journalStore: JournalStore())
}