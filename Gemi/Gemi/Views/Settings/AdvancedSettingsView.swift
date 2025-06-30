//
//  AdvancedSettingsView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

struct AdvancedSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var showingResetConfirmation = false
    @State private var showingDiagnostics = false
    
    var body: some View {
        @Bindable var settings = settingsStore
        
        VStack(alignment: .leading, spacing: 24) {
            // Developer options
            SettingsGroup(title: "Developer Options") {
                VStack(spacing: 12) {
                    DeveloperToggle(
                        icon: "terminal",
                        title: "Enable debug logging",
                        subtitle: "Write detailed logs to ~/Library/Logs/Gemi",
                        isOn: .constant(false)
                    )
                    
                    DeveloperToggle(
                        icon: "doc.text.magnifyingglass",
                        title: "Show database inspector",
                        subtitle: "View raw database contents (read-only)",
                        isOn: .constant(false)
                    )
                    
                    DeveloperToggle(
                        icon: "network",
                        title: "Show network activity",
                        subtitle: "Monitor Ollama API calls",
                        isOn: .constant(false)
                    )
                }
            }
            
            // Performance
            SettingsGroup(title: "Performance") {
                VStack(spacing: 16) {
                    // Cache settings
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Image cache size")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("52.3 MB")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        
                        HStack(spacing: 12) {
                            Button {
                                // Clear cache
                            } label: {
                                Text("Clear Cache")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.gray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.gray.opacity(0.1))
                                            .overlay(
                                                Capsule()
                                                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 0.5)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            
                            Text("Free up space by clearing cached images")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Divider()
                        .opacity(0.1)
                    
                    // Memory usage
                    MemoryUsageView()
                }
            }
            
            // Diagnostics
            SettingsGroup(title: "Diagnostics") {
                VStack(spacing: 12) {
                    DiagnosticButton(
                        icon: "stethoscope",
                        title: "Run Diagnostics",
                        subtitle: "Check system health and database integrity"
                    ) {
                        showingDiagnostics = true
                    }
                    
                    DiagnosticButton(
                        icon: "doc.badge.gearshape",
                        title: "Export Logs",
                        subtitle: "Save diagnostic logs for troubleshooting"
                    ) {
                        // Export logs
                    }
                }
            }
            
            // Reset
            SettingsGroup(title: "Reset") {
                VStack(spacing: 16) {
                    InfoBox(
                        icon: "exclamationmark.triangle",
                        text: "Resetting to defaults will restore all settings but won't delete your journal entries.",
                        color: .orange
                    )
                    
                    Button {
                        showingResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("Reset All Settings to Defaults")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [.red, .red.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
        }
        .alert("Reset Settings?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                settings.resetToDefaults()
            }
        } message: {
            Text("This will restore all settings to their default values. Your journal entries will not be affected.")
        }
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsView()
        }
    }
}

// MARK: - Developer Toggle

struct DeveloperToggle: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.gray)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(PremiumToggleStyle())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Memory Usage View

struct MemoryUsageView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Memory usage")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("142 MB / 8 GB")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            
            // Usage bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.1))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.gray, .gray.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.02)
                }
            }
            .frame(height: 8)
            
            Text("Gemi is using minimal system resources")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Diagnostic Button

struct DiagnosticButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.gray)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .opacity(isHovered ? 1 : 0.5)
            }
            .padding(12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.gray.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Diagnostics View

struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRunning = false
    @State private var results: [DiagnosticResult] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("System Diagnostics")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            Divider()
                .opacity(0.1)
            
            // Content
            if isRunning {
                VStack(spacing: 20) {
                    CircularProgressIndicator()
                    
                    Text("Running diagnostics...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !results.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(results) { result in
                            DiagnosticResultRow(result: result)
                        }
                    }
                    .padding(20)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.gray)
                    
                    Text("Ready to check system health")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    
                    Button {
                        runDiagnostics()
                    } label: {
                        Text("Run Diagnostics")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.gray)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 500, height: 400)
    }
    
    private func runDiagnostics() {
        isRunning = true
        
        // Simulate diagnostics
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            results = [
                DiagnosticResult(
                    title: "Database Connection",
                    status: .success,
                    message: "Connected successfully"
                ),
                DiagnosticResult(
                    title: "Ollama Service",
                    status: .success,
                    message: "Running on port 11434"
                ),
                DiagnosticResult(
                    title: "Encryption Keys",
                    status: .success,
                    message: "Valid and accessible"
                ),
                DiagnosticResult(
                    title: "Storage Space",
                    status: .warning,
                    message: "14.2 GB available"
                ),
                DiagnosticResult(
                    title: "Memory Usage",
                    status: .success,
                    message: "142 MB (1.8% of system)"
                )
            ]
            isRunning = false
        }
    }
}

struct DiagnosticResult: Identifiable {
    let id = UUID()
    let title: String
    let status: DiagnosticStatus
    let message: String
}

enum DiagnosticStatus {
    case success
    case warning
    case error
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct DiagnosticResultRow: View {
    let result: DiagnosticResult
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.status.icon)
                .font(.system(size: 20))
                .foregroundStyle(result.status.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text(result.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(result.status.color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(result.status.color.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    AdvancedSettingsView()
        .environment(SettingsStore())
        .padding(40)
        .frame(width: 600)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
}