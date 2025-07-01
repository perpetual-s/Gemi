//
//  AICoordinatorSettingsView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/1/25.
//

import SwiftUI
import os.log

/// Comprehensive AI system settings managed by GemiAICoordinator
struct AICoordinatorSettingsView: View {
    @StateObject private var coordinator = GemiAICoordinator.shared
    @State private var settings = AISettings()
    @State private var showingModelUpdate = false
    @State private var showingModelReset = false
    @State private var isUpdatingModel = false
    
    private let logger = Logger(subsystem: "com.chaehoshin.Gemi", category: "AICoordinatorSettingsView")
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status overview
                aiStatusSection
                
                // Model management
                modelManagementSection
                
                // AI behavior settings
                aiBehaviorSection
                
                // Memory settings
                memorySettingsSection
                
                // Performance settings
                performanceSection
                
                // Advanced settings
                advancedSettingsSection
            }
            .padding(20)
        }
        .navigationTitle("AI System Settings")
        .task {
            loadSettings()
        }
    }
    
    // MARK: - AI Status Section
    
    private var aiStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("System Status")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                StatusIndicator(status: coordinator.aiStatus)
            }
            
            VStack(spacing: 12) {
                // Overall status
                StatusDetailRow(
                    icon: "cpu",
                    title: "AI System",
                    value: coordinator.aiStatus.displayText,
                    color: statusColor(for: coordinator.aiStatus)
                )
                
                // Current model
                if let model = coordinator.currentModel {
                    StatusDetailRow(
                        icon: "sparkles",
                        title: "Model",
                        value: model.name,
                        color: .purple
                    )
                }
                
                // Performance
                if coordinator.averageResponseTime > 0 {
                    StatusDetailRow(
                        icon: "timer",
                        title: "Response Time",
                        value: String(format: "%.1fs avg", coordinator.averageResponseTime),
                        color: .blue
                    )
                }
                
                // Background tasks
                if coordinator.backgroundTasksActive > 0 {
                    StatusDetailRow(
                        icon: "gearshape.2",
                        title: "Background Tasks",
                        value: "\(coordinator.backgroundTasksActive) active",
                        color: .orange
                    )
                }
                
                // Memory usage
                if coordinator.memoryUsageMB > 0 {
                    StatusDetailRow(
                        icon: "memorychip",
                        title: "Memory Usage",
                        value: String(format: "%.1f MB", coordinator.memoryUsageMB),
                        color: .green
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Model Management Section
    
    private var modelManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Model Management")
                .font(.system(size: 18, weight: .semibold))
            
            VStack(spacing: 12) {
                // Model info card
                if let model = coordinator.currentModel {
                    ModelInfoCard(model: model)
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    // Update model
                    ActionButton(
                        title: "Update Model",
                        icon: "arrow.clockwise",
                        color: .blue,
                        isLoading: isUpdatingModel,
                        action: {
                            showingModelUpdate = true
                        }
                    )
                    .disabled(coordinator.aiStatus == .offline(""))
                    
                    // Health check
                    ActionButton(
                        title: "Health Check",
                        icon: "heart.text.square",
                        color: .green,
                        action: {
                            Task {
                                await performHealthCheck()
                            }
                        }
                    )
                    
                    // Reset model
                    ActionButton(
                        title: "Reset",
                        icon: "arrow.uturn.backward",
                        color: .orange,
                        action: {
                            showingModelReset = true
                        }
                    )
                }
            }
        }
        .confirmationDialog(
            "Update Custom Model",
            isPresented: $showingModelUpdate,
            titleVisibility: .visible
        ) {
            Button("Update Model") {
                Task {
                    await updateModel()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will recreate the custom Gemi model. The process may take a few minutes.")
        }
        .confirmationDialog(
            "Reset to Base Model",
            isPresented: $showingModelReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                Task {
                    await coordinator.rollbackModel()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete the custom model and use the base Gemma model.")
        }
    }
    
    // MARK: - AI Behavior Section
    
    private var aiBehaviorSection: some View {
        SettingsCard(title: "AI Behavior", icon: "brain") {
            VStack(spacing: 20) {
                // Temperature
                SliderSetting(
                    title: "Temperature",
                    value: $settings.modelTemperature,
                    range: 0.1...1.0,
                    step: 0.1,
                    format: "%.1f",
                    description: "Higher values make responses more creative"
                )
                
                // Creativity
                SliderSetting(
                    title: "Creativity",
                    value: $settings.creativityLevel,
                    range: 0.0...1.0,
                    step: 0.1,
                    format: creativityLevelText,
                    description: "How imaginative Gemi's responses are"
                )
            }
        }
        .onChange(of: settings) { _, _ in
            saveSettings()
        }
    }
    
    // MARK: - Memory Settings Section
    
    private var memorySettingsSection: some View {
        SettingsCard(title: "Memory System", icon: "brain.head.profile") {
            VStack(spacing: 20) {
                // Auto extraction
                ToggleSetting(
                    title: "Automatic Memory Extraction",
                    isOn: $settings.automaticMemoryExtraction,
                    description: "Extract important information from conversations"
                )
                
                // Context window
                SegmentedSetting(
                    title: "Context Window",
                    selection: $settings.maxContextTokens,
                    options: [
                        (4096, "4K"),
                        (8192, "8K"),
                        (16384, "16K")
                    ],
                    description: "Larger windows allow longer conversations"
                )
                
                // History limit
                StepperSetting(
                    title: "Conversation History",
                    value: $settings.conversationHistoryLimit,
                    range: 5...50,
                    step: 5,
                    format: "Keep last %d messages"
                )
            }
        }
    }
    
    // MARK: - Performance Section
    
    private var performanceSection: some View {
        SettingsCard(title: "Performance", icon: "speedometer") {
            VStack(spacing: 20) {
                // Batch size
                StepperSetting(
                    title: "Embedding Batch Size",
                    value: $settings.embeddingBatchSize,
                    range: 1...20,
                    step: 1,
                    format: "Process %d at once"
                )
                
                // Cache size
                SliderSetting(
                    title: "Cache Size",
                    value: Binding(
                        get: { Double(settings.cacheSize) },
                        set: { settings.cacheSize = Int($0) }
                    ),
                    range: 50...500,
                    step: 50,
                    format: "%.0f MB",
                    description: "Memory allocated for caching"
                )
                
                // Queue status
                if coordinator.embeddingQueueSize > 0 {
                    QueueStatusView(queueSize: coordinator.embeddingQueueSize)
                }
            }
        }
    }
    
    // MARK: - Advanced Settings Section
    
    private var advancedSettingsSection: some View {
        SettingsCard(title: "Advanced", icon: "gearshape.2") {
            VStack(spacing: 20) {
                // Cleanup
                StepperSetting(
                    title: "Conversation Cleanup",
                    value: $settings.cleanupOldConversationsDays,
                    range: 7...90,
                    step: 7,
                    format: "After %d days"
                )
                
                // Debug info
                DisclosureGroup("Debug Information") {
                    DebugInfoView(coordinator: coordinator)
                        .padding(.top, 12)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var creativityLevelText: String {
        switch settings.creativityLevel {
        case 0..<0.3: return "Conservative"
        case 0.3..<0.7: return "Balanced"
        case 0.7...1.0: return "Creative"
        default: return "Balanced"
        }
    }
    
    private func statusColor(for status: AISystemStatus) -> Color {
        switch status {
        case .ready: return .green
        case .degraded: return .orange
        case .offline, .updating: return .red
        case .initializing: return .blue
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "aiSettings"),
           let decoded = try? JSONDecoder().decode(AISettings.self, from: data) {
            settings = decoded
        }
    }
    
    private func saveSettings() {
        coordinator.updateSettings(settings)
    }
    
    private func updateModel() async {
        isUpdatingModel = true
        defer { isUpdatingModel = false }
        
        do {
            try await coordinator.updateCustomModel()
        } catch {
            logger.error("Model update failed: \(error)")
        }
    }
    
    private func performHealthCheck() async {
        let healthy = await coordinator.modelHealthCheck()
        logger.info("Health check: \(healthy ? "passed" : "failed")")
    }
}

// MARK: - Supporting Views

struct StatusIndicator: View {
    let status: AISystemStatus
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 8)
                        .scaleEffect(status == .ready ? 1.8 : 1.0)
                        .opacity(status == .ready ? 0 : 1)
                        .animation(
                            status == .ready ?
                            Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false) :
                            .default,
                            value: status
                        )
                )
            
            Text(status.displayText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
                .overlay(
                    Capsule()
                        .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
    
    private var color: Color {
        switch status {
        case .ready: return .green
        case .degraded: return .orange
        case .offline, .updating: return .red
        case .initializing: return .blue
        }
    }
}

struct StatusDetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
        }
    }
}

struct ModelInfoCard: View {
    let model: ModelInfo
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .purple.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.system(size: 16, weight: .semibold))
                
                Text("Version \(model.version)")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                
                Text("Created \(model.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.purple.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var isLoading = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.system(size: 18, weight: .semibold))
            
            content
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.03))
                )
        }
    }
}

struct SliderSetting: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Text(String(format: format, value))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Slider(value: $value, in: range, step: step)
                .tint(DesignSystem.Colors.primary)
            
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
    }
}

struct ToggleSetting: View {
    let title: String
    @Binding var isOn: Bool
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: $isOn)
                .font(.system(size: 14, weight: .medium))
            
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
    }
}

struct SegmentedSetting: View {
    let title: String
    @Binding var selection: Int
    let options: [(Int, String)]
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
            
            Picker("", selection: $selection) {
                ForEach(options, id: \.0) { value, label in
                    Text(label).tag(value)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
    }
}

struct StepperSetting: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let format: String
    
    var body: some View {
        Stepper(
            String(format: format, value),
            value: $value,
            in: range,
            step: step
        )
        .font(.system(size: 14))
    }
}

struct QueueStatusView: View {
    let queueSize: Int
    
    var body: some View {
        HStack {
            Label("\(queueSize) items in embedding queue", systemImage: "arrow.up.arrow.down.circle")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
            
            Spacer()
            
            ProgressView()
                .scaleEffect(0.7)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
    }
}

struct DebugInfoView: View {
    @ObservedObject var coordinator: GemiAICoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DebugRow(label: "Embedding Queue", value: "\(coordinator.embeddingQueueSize)")
            DebugRow(label: "Active Tasks", value: "\(coordinator.backgroundTasksActive)")
            DebugRow(label: "Memory Usage", value: String(format: "%.1f MB", coordinator.memoryUsageMB))
            
            if let error = coordinator.lastError {
                DebugRow(
                    label: "Last Error",
                    value: error.localizedDescription,
                    isError: true
                )
            }
        }
        .font(.system(size: 12, design: .monospaced))
    }
}

struct DebugRow: View {
    let label: String
    let value: String
    var isError = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(isError ? .red : .primary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AICoordinatorSettingsView()
    }
    .frame(width: 700, height: 900)
}