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
    }
    
    private enum SettingsTab: String, CaseIterable {
        case general = "General"
        case ai = "AI & Models"
        case appearance = "Appearance"
        case security = "Security & Privacy"
        case data = "Data & Sync"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .ai: return "cpu"
            case .appearance: return "paintbrush"
            case .security: return "lock.shield"
            case .data: return "externaldrive"
            }
        }
    }
    
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        HSplitView {
            // Sidebar
            VStack(spacing: 0) {
                List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
                .listStyle(SidebarListStyle())
                .frame(width: 200)
            }
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
                .padding(32)
                .frame(maxWidth: 600, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 800, height: 600)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
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
        VStack(alignment: .leading, spacing: 24) {
            Text("General")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Launch at startup", isOn: .constant(false))
                        .disabled(true)
                        .help("Coming soon")
                    
                    Toggle("Show in menu bar", isOn: .constant(false))
                        .disabled(true)
                        .help("Coming soon")
                    
                    HStack {
                        Text("Auto-save interval:")
                        Slider(value: $autoSaveInterval, in: 1...10, step: 1)
                            .frame(width: 200)
                        Text("\(Int(autoSaveInterval)) seconds")
                            .monospacedDigit()
                    }
                }
                .padding()
            } label: {
                Label("Application", systemImage: "app")
                    .font(.headline)
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Enable Markdown rendering", isOn: $enableMarkdown)
                    
                    Toggle("Show word count", isOn: .constant(true))
                    
                    Toggle("Show reading time", isOn: .constant(true))
                }
                .padding()
            } label: {
                Label("Editor", systemImage: "doc.text")
                    .font(.headline)
            }
        }
    }
    
    // MARK: - AI Settings
    
    private var aiSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("AI & Models")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ollama Host:")
                            TextField("Host", text: $ollamaHost)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Port:")
                            TextField("Port", value: $ollamaPort, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status:")
                            HStack {
                                Circle()
                                    .fill(connectionStatus.color)
                                    .frame(width: 8, height: 8)
                                Text(connectionStatus.text)
                                    .font(.caption)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Test Connection") {
                            checkConnection()
                        }
                        .disabled(isCheckingConnection)
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Model:")
                            Picker("", selection: $selectedModel) {
                                ForEach(availableModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 200)
                            .disabled(isLoadingModels)
                        }
                        
                        Button(action: loadAvailableModels) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isLoadingModels)
                        .help("Refresh models")
                    }
                    
                    Text("Recommended: gemma3n:latest for best performance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } label: {
                Label("Ollama Configuration", systemImage: "server.rack")
                    .font(.headline)
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Model not installed?")
                        .font(.headline)
                    
                    Text("Run this command in Terminal:")
                        .font(.caption)
                    
                    HStack {
                        Text("ollama pull gemma3n:latest")
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .background(Color(NSColor.secondarySystemFill))
                            .cornerRadius(4)
                            .textSelection(.enabled)
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("ollama pull gemma3n:latest", forType: .string)
                        }) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .help("Copy to clipboard")
                    }
                }
                .padding()
            } label: {
                Label("Model Installation", systemImage: "arrow.down.circle")
                    .font(.headline)
            }
        }
    }
    
    // MARK: - Appearance Settings
    
    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Appearance")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Font:")
                        Picker("", selection: $defaultFont) {
                            Text("System").tag("System")
                            Text("San Francisco").tag("SF Pro")
                            Text("New York").tag("New York")
                            Text("Helvetica").tag("Helvetica")
                            Text("Monaco").tag("Monaco")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                    
                    HStack {
                        Text("Font size:")
                        Slider(value: $defaultFontSize, in: 11...20, step: 1)
                            .frame(width: 200)
                        Text("\(Int(defaultFontSize)) pt")
                            .monospacedDigit()
                    }
                    
                    HStack {
                        Text("Preview:")
                        Text("The quick brown fox jumps over the lazy dog")
                            .font(.system(size: defaultFontSize))
                            .padding(8)
                            .background(Color(NSColor.secondarySystemFill))
                            .cornerRadius(4)
                    }
                }
                .padding()
            } label: {
                Label("Typography", systemImage: "textformat")
                    .font(.headline)
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Theme follows your system appearance settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Open System Preferences") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.general")!)
                    }
                }
                .padding()
            } label: {
                Label("Theme", systemImage: "circle.lefthalf.filled")
                    .font(.headline)
            }
        }
    }
    
    // MARK: - Security Settings
    
    private var securitySettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Security & Privacy")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Require authentication on launch", isOn: $requireAuthentication)
                    
                    HStack {
                        Text("Session timeout:")
                        Slider(value: $sessionTimeout, in: 5...120, step: 5)
                            .frame(width: 200)
                        Text("\(Int(sessionTimeout)) minutes")
                            .monospacedDigit()
                    }
                    
                    Toggle("Lock when system sleeps", isOn: .constant(true))
                }
                .padding()
            } label: {
                Label("Authentication", systemImage: "faceid")
                    .font(.headline)
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                            .font(.largeTitle)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your data is encrypted")
                                .font(.headline)
                            Text("All journal entries are encrypted with AES-256-GCM and stored locally on your device")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("No cloud sync", systemImage: "icloud.slash")
                        Label("No analytics or tracking", systemImage: "eye.slash")
                        Label("No external API calls (except local Ollama)", systemImage: "network.slash")
                        Label("Open source and auditable", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    .font(.caption)
                }
                .padding()
            } label: {
                Label("Privacy", systemImage: "hand.raised.shield")
                    .font(.headline)
            }
        }
    }
    
    // MARK: - Data Settings
    
    private var dataSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Data & Sync")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total entries:")
                            Text("\(journalStore.entries.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("Database size:")
                            Text(formatDatabaseSize())
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Button("Export All Entries") {
                            exportEntries()
                        }
                        
                        Button("Backup Database") {
                            backupDatabase()
                        }
                        
                        Spacer()
                        
                        Button("Manage Data") {
                            showingDataManagement = true
                        }
                    }
                }
                .padding()
            } label: {
                Label("Data Management", systemImage: "externaldrive")
                    .font(.headline)
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Automatic backups")
                        .font(.headline)
                    
                    Toggle("Enable automatic backups", isOn: .constant(false))
                        .disabled(true)
                    
                    Text("Coming soon: Automatic encrypted backups to a location of your choice")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } label: {
                Label("Backups", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
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

#Preview {
    SettingsView(journalStore: JournalStore())
}