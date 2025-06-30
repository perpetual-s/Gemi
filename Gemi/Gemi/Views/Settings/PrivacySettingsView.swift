//
//  PrivacySettingsView.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

struct PrivacySettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var showingDataLocation = false
    
    var body: some View {
        @Bindable var settings = settingsStore
        
        VStack(alignment: .leading, spacing: 24) {
            // Privacy promise banner
            PrivacyBanner()
            
            // Authentication settings
            SettingsGroup(title: "Authentication") {
                VStack(spacing: 16) {
                    PremiumToggle(
                        title: "Require authentication on launch",
                        subtitle: "Use Face ID or password to access your journal",
                        isOn: $settings.requireAuthOnLaunch
                    )
                    
                    if settings.requireAuthOnLaunch {
                        Divider()
                            .opacity(0.1)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Auto-lock after")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            LockTimeSelector(
                                selectedMinutes: $settings.lockAfterMinutes
                            )
                        }
                        .transition(.asymmetric(
                            insertion: .push(from: .top).combined(with: .opacity),
                            removal: .push(from: .bottom).combined(with: .opacity)
                        ))
                    }
                }
            }
            
            // Data storage
            SettingsGroup(title: "Data Storage") {
                VStack(spacing: 16) {
                    // Location info
                    HStack {
                        Image(systemName: "lock.doc")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.green)
                            .frame(width: 32, height: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("All data is stored locally")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                            
                            Text("Your journal entries never leave your device")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            showingDataLocation.toggle()
                        } label: {
                            Text("Show Location")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.green)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showingDataLocation {
                        DataLocationView()
                            .transition(.asymmetric(
                                insertion: .push(from: .top).combined(with: .opacity),
                                removal: .push(from: .bottom).combined(with: .opacity)
                            ))
                    }
                }
            }
            
            // Analytics
            SettingsGroup(title: "Analytics") {
                VStack(spacing: 12) {
                    PremiumToggle(
                        title: "Share anonymous usage data",
                        subtitle: "Help improve Gemi by sharing crash reports and usage patterns",
                        isOn: $settings.enableAnalytics
                    )
                    
                    if settings.enableAnalytics {
                        InfoBox(
                            icon: "info.circle",
                            text: "Only app crashes and feature usage are collected. Your journal content is never shared.",
                            color: .blue
                        )
                    }
                }
            }
            
            // Security actions
            SettingsGroup(title: "Security") {
                VStack(spacing: 12) {
                    SecurityActionButton(
                        icon: "key.fill",
                        title: "Change Password",
                        subtitle: "Update your authentication password",
                        color: .blue
                    ) {
                        // Change password
                    }
                    
                    Divider()
                        .opacity(0.1)
                    
                    SecurityActionButton(
                        icon: "trash.fill",
                        title: "Delete All Data",
                        subtitle: "Permanently remove all journal entries",
                        color: .red,
                        isDestructive: true
                    ) {
                        // Delete data
                    }
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Privacy Banner

struct PrivacyBanner: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .green.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Your privacy is our priority")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text("Gemi never sends your data to any server. Everything stays on your Mac.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.1),
                            Color.green.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Lock Time Selector

struct LockTimeSelector: View {
    @Binding var selectedMinutes: Int
    
    let options = [1, 5, 15, 30, 60]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { minutes in
                LockTimeButton(
                    minutes: minutes,
                    isSelected: selectedMinutes == minutes
                ) {
                    withAnimation(DesignSystem.Animation.quick) {
                        selectedMinutes = minutes
                    }
                }
            }
        }
    }
}

struct LockTimeButton: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text(minutes == 1 ? "min" : "mins")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isSelected ?
                        Color.green.gradient :
                        (isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.05)).gradient
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

// MARK: - Data Location View

struct DataLocationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Database Location", systemImage: "folder")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            Text("~/Library/Application Support/Gemi/journal.sqlite")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.05))
                )
            
            HStack(spacing: 12) {
                Button {
                    // Open in Finder
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                
                Text("•")
                    .foregroundStyle(.tertiary)
                
                Text("Encrypted with AES-256-GCM")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.green.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Info Box

struct InfoBox: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Security Action Button

struct SecurityActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var isDestructive: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var showingConfirmation = false
    
    var body: some View {
        Button {
            if isDestructive {
                showingConfirmation = true
            } else {
                action()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
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
                    .fill(isHovered ? color.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.quick) {
                isHovered = hovering
            }
        }
        .alert("Delete All Data?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: action)
        } message: {
            Text("This will permanently delete all your journal entries. This action cannot be undone.")
        }
    }
}

// MARK: - Preview

#Preview {
    PrivacySettingsView()
        .environment(SettingsStore())
        .padding(40)
        .frame(width: 600)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
}