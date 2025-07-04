//
//  BackupSettingsView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

struct BackupSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var lastBackupDate = Date().addingTimeInterval(-86400) // Yesterday
    @State private var showingExportOptions = false
    
    var body: some View {
        @Bindable var settings = settingsStore
        
        VStack(alignment: .leading, spacing: 24) {
            // Auto backup
            SettingsGroup(title: "Automatic Backup") {
                VStack(spacing: 16) {
                    PremiumToggle(
                        title: "Enable automatic backups",
                        subtitle: "Keep your journal safe with regular backups",
                        isOn: $settings.autoBackup
                    )
                    
                    if settings.autoBackup {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Backup frequency")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            BackupFrequencyPicker(
                                selection: $settings.backupFrequency
                            )
                            
                            Divider()
                                .opacity(0.1)
                            
                            // Backup location
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Backup location")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                
                                BackupLocationSelector(
                                    location: $settings.backupLocation
                                )
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .push(from: .top).combined(with: .opacity),
                            removal: .push(from: .bottom).combined(with: .opacity)
                        ))
                    }
                }
            }
            
            // Backup status
            SettingsGroup(title: "Backup Status") {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last backup")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            Text(lastBackupDate, style: .relative)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        
                        Spacer()
                        
                        Button {
                            // Manual backup
                        } label: {
                            Label("Backup Now", systemImage: "arrow.clockwise")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.orange, .orange.opacity(0.8)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Backup stats
                    BackupStatsView()
                }
            }
            
            // Export options
            SettingsGroup(title: "Export Data") {
                VStack(spacing: 12) {
                    ExportOptionButton(
                        icon: "doc.text",
                        title: "Export as Text",
                        subtitle: "Plain text files organized by date",
                        format: "TXT"
                    ) {
                        // Export as text
                    }
                    
                    ExportOptionButton(
                        icon: "doc.richtext",
                        title: "Export as Markdown",
                        subtitle: "Formatted markdown files with metadata",
                        format: "MD"
                    ) {
                        // Export as markdown
                    }
                    
                    ExportOptionButton(
                        icon: "doc.zipper",
                        title: "Export Complete Archive",
                        subtitle: "Everything including memories and settings",
                        format: "ZIP"
                    ) {
                        // Export archive
                    }
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Backup Frequency Picker

struct BackupFrequencyPicker: View {
    @Binding var selection: BackupFrequency
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(BackupFrequency.allCases, id: \.self) { frequency in
                FrequencyButton(
                    frequency: frequency,
                    isSelected: selection == frequency
                ) {
                    withAnimation(DesignSystem.Animation.quick) {
                        selection = frequency
                    }
                }
            }
        }
    }
}

struct FrequencyButton: View {
    let frequency: BackupFrequency
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(frequency.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isSelected ?
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [
                                    isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.05),
                                    isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
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

// MARK: - Backup Location Selector

struct BackupLocationSelector: View {
    @Binding var location: URL?
    @State private var isHovered = false
    
    var body: some View {
        Button {
            // Open file picker
        } label: {
            HStack {
                Image(systemName: "folder")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)
                
                if let location = location {
                    Text(location.lastPathComponent)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                } else {
                    Text("Choose backup folder...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("Change")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
                    .opacity(isHovered ? 1 : 0.7)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(isHovered ? 0.08 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.orange.opacity(0.2), lineWidth: 0.5)
                    )
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

// MARK: - Backup Stats View

struct BackupStatsView: View {
    var body: some View {
        HStack(spacing: 0) {
            BackupStatItem(
                label: "Total Entries",
                value: "342",
                icon: "doc.text"
            )
            
            Divider()
                .frame(height: 40)
                .opacity(0.1)
            
            BackupStatItem(
                label: "Backup Size",
                value: "14.2 MB",
                icon: "externaldrive"
            )
            
            Divider()
                .frame(height: 40)
                .opacity(0.1)
            
            BackupStatItem(
                label: "Next Backup",
                value: "Tomorrow",
                icon: "clock"
            )
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.orange.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

struct BackupStatItem: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.orange)
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Export Option Button

struct ExportOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let format: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.orange)
                    .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(format)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.1))
                    )
            }
            .padding(12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.orange.opacity(0.05) : Color.clear)
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

// MARK: - Preview

#Preview {
    BackupSettingsView()
        .environment(SettingsStore())
        .padding(40)
        .frame(width: 600)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
}