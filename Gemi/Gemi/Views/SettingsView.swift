import SwiftUI
import LocalAuthentication
import AppKit

// Window controller manager to retain window controllers
@MainActor
private final class WindowControllerManager {
    static let shared = WindowControllerManager()
    private var windowControllers: [NSWindowController] = []
    
    func addWindowController(_ controller: NSWindowController) {
        windowControllers.append(controller)
    }
    
    func removeWindowController(_ controller: NSWindowController) {
        windowControllers.removeAll { $0 == controller }
    }
}

struct SettingsView: View {
    @State private var showExportSuccess = false
    @State private var showExportError = false
    @State private var showBackupSuccess = false
    @State private var showBackupError = false
    @State private var errorMessage = ""
    let journalStore: JournalStore
    @AppStorage("aiTemperature") private var aiTemperature = AIConfiguration.shared.temperature
    @AppStorage("aiMaxTokens") private var aiMaxTokens = AIConfiguration.shared.maxTokens
    @AppStorage("selectedModel") private var selectedModel = "gemma-3n-e4b-it"
    @AppStorage("autoSaveInterval") private var autoSaveInterval = 3.0
    @AppStorage("enableMarkdown") private var enableMarkdown = true
    @AppStorage("defaultFont") private var defaultFont = "System"
    @AppStorage("defaultFontSize") private var defaultFontSize = 14.0
    @AppStorage("sessionTimeout") private var sessionTimeout = 30.0
    @AppStorage("requireAuthentication") private var requireAuthentication = true
    @AppStorage("autoLoadModel") private var autoLoadModel = true
    
    private let aiService = AIService.shared
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
            .background(VisualEffectView.sidebar)
            
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
                
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Content Header with scroll anchor
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
                            .id("scrollTop") // Anchor for scrolling
                            
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
                    .onChange(of: selectedTab) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollProxy.scrollTo("scrollTop", anchor: .top)
                        }
                    }
                    .onAppear {
                        // Ensure we start at the top when the view first appears
                        scrollProxy.scrollTo("scrollTop", anchor: .top)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 900, height: 550)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            // Done button in the top-right corner
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor)
                                    .shadow(color: Color.accentColor.opacity(0.3), radius: 6, x: 0, y: 2)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Close Settings (Esc or ⌘↩)")
                    .padding(.trailing, 24)
                    .padding(.top, 20)
                }
                
                Spacer()
            }
            .zIndex(1) // Ensure the button stays on top
        )
        .onAppear {
            checkConnection()
            loadAvailableModels()
        }
        .alert("Success", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Operation completed successfully.")
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
        .sheet(isPresented: $showingDataManagement) {
            DataManagementView(journalStore: journalStore)
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
                        
                        Text("Recommended: **gemma-3n-e4b-it** (Google Gemma 3n E4B model) for optimal performance and privacy")
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
            
            // Gemma 3n Setup Card
            PremiumSettingsCard(
                title: "Gemma 3n Setup",
                icon: "cpu",
                iconColor: .purple
            ) {
                VStack(spacing: 20) {
                    // Status indicator
                    HStack {
                        GemmaModelStatusView(isCompact: true)
                    }
                    
                    Divider()
                    
                    // Setup actions
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Model Management")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Download or update Gemma 3n model")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 12) {
                                Button {
                                    openGemmaSetupWindow()
                                } label: {
                                    Text("Open Setup")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button {
                                    // Reset onboarding state
                                    UserDefaults.standard.set(false, forKey: "hasCompletedGemmaOnboarding")
                                    openGemmaSetupWindow()
                                } label: {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.bordered)
                                .help("Reset onboarding")
                            }
                        }
                        
                        // Manual setup option
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Advanced: Manual Setup")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Model loads automatically when needed")
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(NSColor.tertiarySystemFill))
                                    )
                                    .textSelection(.enabled)
                                
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString("Model loads automatically when needed", forType: .string)
                                }) {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.plain)
                                .help("Copy to clipboard")
                            }
                        }
                    }
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
            
            // Quick Actions Card
            PremiumSettingsCard(
                title: "Quick Actions",
                icon: "bolt.circle",
                iconColor: .orange
            ) {
                VStack(spacing: 20) {
                    // Import/Export Row
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Import & Export")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Transfer entries between devices or backup formats")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button(action: importEntries) {
                                Label("Import", systemImage: "square.and.arrow.down")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(PremiumButtonStyle(style: .secondary))
                            
                            Button(action: exportEntries) {
                                Label("Export", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(PremiumButtonStyle(style: .secondary))
                        }
                    }
                    
                    Divider()
                    
                    // Database Location Row
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Database Location")
                                .font(.system(size: 14, weight: .semibold))
                            Text(getDatabasePath())
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                        
                        Button(action: showDatabaseInFinder) {
                            Label("Show in Finder", systemImage: "folder")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(PremiumButtonStyle(style: .secondary))
                    }
                    
                    Divider()
                    
                    // Backup Reminder
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                        
                        Text("Remember to regularly backup your database to prevent data loss")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.05))
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func importEntries() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.message = "Select a Gemi export file to import"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            Task {
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    
                    let entries = try decoder.decode([JournalEntry].self, from: data)
                    
                    // Import entries
                    for entry in entries {
                        await journalStore.saveEntry(entry)
                    }
                    
                    await MainActor.run {
                        showExportSuccess = true // Reuse for import success
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to import entries: \(error.localizedDescription)"
                        showExportError = true
                    }
                }
            }
        }
    }
    
    private func getDatabasePath() -> String {
        do {
            let appSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let bundleID = Bundle.main.bundleIdentifier ?? "com.gemi.app"
            return appSupportURL
                .appendingPathComponent(bundleID)
                .appendingPathComponent("gemi.db")
                .path
        } catch {
            return "~/Library/Application Support/Gemi/gemi.db"
        }
    }
    
    private func showDatabaseInFinder() {
        do {
            let appSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let bundleID = Bundle.main.bundleIdentifier ?? "com.gemi.app"
            let dbURL = appSupportURL
                .appendingPathComponent(bundleID)
                .appendingPathComponent("gemi.db")
            
            NSWorkspace.shared.selectFile(dbURL.path, inFileViewerRootedAtPath: "")
        } catch {
            // Fallback: just open Application Support folder
            if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                NSWorkspace.shared.open(appSupportURL)
            }
        }
    }
    
    private func openGemmaSetupWindow() {
        // Use AppKit's window management directly to avoid lifecycle issues
        let setupWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure window appearance to match initial setup
        setupWindow.titlebarAppearsTransparent = true
        setupWindow.titleVisibility = .hidden
        setupWindow.isMovableByWindowBackground = true
        setupWindow.backgroundColor = NSColor.black
        
        // Create a window controller to manage the window properly
        let windowController = NSWindowController(window: setupWindow)
        
        // Create and store the delegate to keep it alive
        let windowDelegate = NSWindowDelegateAdapter {
            WindowControllerManager.shared.removeWindowController(windowController)
        }
        
        // Set up window delegate to clean up when closed via X button
        setupWindow.delegate = windowDelegate
        
        // Add to manager to keep it alive
        WindowControllerManager.shared.addWindowController(windowController)
        
        // Store the delegate in the window controller to keep it alive
        objc_setAssociatedObject(windowController, "windowDelegate", windowDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Create the content view with a completion handler that safely closes the window
        let contentView = GemmaOnboardingView {
            // Use the window controller to close the window safely
            DispatchQueue.main.async {
                // First check if window is still valid
                if let window = windowController.window, window.isVisible {
                    windowController.close()
                }
                // Remove from manager after closing
                WindowControllerManager.shared.removeWindowController(windowController)
            }
        }
        .frame(width: 900, height: 700)
        .frame(maxWidth: 900, maxHeight: 700)
        .background(Color.black)
        
        // Set the content view
        setupWindow.contentView = NSHostingView(rootView: contentView)
        
        // Center the window on screen
        setupWindow.center()
        
        // Show the window using the window controller
        windowController.showWindow(nil)
        setupWindow.level = .floating
        
        // Remove the window level after a short delay to allow normal window behavior
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            setupWindow.level = .normal
        }
    }
    
    private func checkConnection() {
        isCheckingConnection = true
        connectionStatus = .checking
        
        Task {
            let isReady = await AIConfiguration.shared.isModelReady()
            
            await MainActor.run {
                isCheckingConnection = false
                if isReady {
                    connectionStatus = .connected
                } else {
                    connectionStatus = .disconnected
                }
            }
        }
    }
    
    private func loadAvailableModels() {
        isLoadingModels = true
        availableModels = ["gemma-3n-e4b-it"] // Default Gemma 3n model
        
        Task {
            // TODO: Implement listLocalModels
            let models: [String] = ["gemma-3n-e4b-it"]
            await MainActor.run {
                availableModels = models.isEmpty ? ["gemma-3n-e4b-it"] : models
                isLoadingModels = false
            }
        }
    }
    
    private func formatDatabaseSize() -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        
        do {
            let appSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let bundleID = Bundle.main.bundleIdentifier ?? "com.gemi.app"
            let dbURL = appSupportURL
                .appendingPathComponent(bundleID)
                .appendingPathComponent("gemi.db")
            
            if let attributes = try? FileManager.default.attributesOfItem(atPath: dbURL.path),
               let fileSize = attributes[.size] as? Int64 {
                return formatter.string(fromByteCount: fileSize)
            }
        } catch {
            // Ignore error
        }
        
        return "Unknown"
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


// MARK: - Data Management View

struct DataManagementView: View {
    let journalStore: JournalStore
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var entriesToDelete: Set<UUID> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manage Data")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("Review and manage your journal entries")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(VisualEffectView.sidebar)
            
            Divider()
            
            // Content
            if journalStore.entries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No entries yet")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(journalStore.entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.displayTitle)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                            
                            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(entry.wordCount) words")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(InsetListStyle())
            }
            
            // Footer
            Divider()
            
            HStack {
                Text("\(journalStore.entries.count) entries")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .background(VisualEffectView.sidebar)
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - Window Delegate Adapter

private class NSWindowDelegateAdapter: NSObject, NSWindowDelegate {
    private let onWindowWillClose: (() -> Void)?
    
    init(onWindowWillClose: (() -> Void)? = nil) {
        self.onWindowWillClose = onWindowWillClose
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        onWindowWillClose?()
    }
}

#Preview {
    SettingsView(journalStore: JournalStore())
}