//
//  ProfileView.swift
//  Gemi
//
//  Created by Chaeho Shin on 7/2/25.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName = ""
    @AppStorage("userEmail") private var userEmail = ""
    @AppStorage("profileImage") private var profileImageData: Data?
    
    @State private var editingName = false
    @State private var tempName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // Profile image
                    profileImageSection
                    
                    // User info
                    userInfoSection
                    
                    // Stats
                    quickStats
                    
                    Spacer(minLength: ModernDesignSystem.Spacing.xl)
                }
                .padding(ModernDesignSystem.Spacing.lg)
            }
        }
        .frame(width: 500, height: 600)
        .background(ModernDesignSystem.Colors.backgroundPrimary)
        .onAppear {
            tempName = userName
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("Profile")
                .font(ModernDesignSystem.Typography.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(ModernDesignSystem.Colors.textTertiary)
                    .background(Circle().fill(.clear))
            }
            .buttonStyle(.plain)
        }
        .padding(ModernDesignSystem.Spacing.md)
    }
    
    // MARK: - Profile Image
    
    private var profileImageSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.sm) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            ModernDesignSystem.Colors.primary,
                            ModernDesignSystem.Colors.primary.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    Text(userName.isEmpty ? "?" : String(userName.prefix(1)))
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(.white)
                )
            
            Text("Profile Picture")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundStyle(ModernDesignSystem.Colors.textSecondary)
        }
    }
    
    // MARK: - User Info
    
    private var userInfoSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            // Name field
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text("Name")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundStyle(ModernDesignSystem.Colors.textSecondary)
                
                HStack {
                    if editingName {
                        TextField("Enter your name", text: $tempName)
                            .textFieldStyle(.plain)
                            .font(ModernDesignSystem.Typography.body)
                            .onSubmit {
                                userName = tempName
                                editingName = false
                            }
                    } else {
                        Text(userName.isEmpty ? "Add your name" : userName)
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundStyle(userName.isEmpty ? ModernDesignSystem.Colors.textTertiary : ModernDesignSystem.Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    Button {
                        if editingName {
                            userName = tempName
                            editingName = false
                        } else {
                            editingName = true
                        }
                    } label: {
                        Text(editingName ? "Save" : "Edit")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundStyle(ModernDesignSystem.Colors.primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(ModernDesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusXS)
                        .fill(ModernDesignSystem.Colors.backgroundSecondary)
                )
            }
        }
    }
    
    // MARK: - Quick Stats
    
    private var quickStats: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Quick Stats")
                .font(ModernDesignSystem.Typography.headline)
                .foregroundStyle(ModernDesignSystem.Colors.textPrimary)
            
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                ProfileStatCard(
                    icon: "book.fill",
                    value: "Coming Soon",
                    label: "Total Entries"
                )
                
                ProfileStatCard(
                    icon: "calendar",
                    value: "Coming Soon",
                    label: "Days Active"
                )
            }
            
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                ProfileStatCard(
                    icon: "flame.fill",
                    value: "Coming Soon",
                    label: "Current Streak"
                )
                
                ProfileStatCard(
                    icon: "star.fill",
                    value: "Coming Soon",
                    label: "Longest Streak"
                )
            }
        }
    }
}

// MARK: - Stat Card

struct ProfileStatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(ModernDesignSystem.Colors.primary)
            
            Text(value)
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundStyle(ModernDesignSystem.Colors.textPrimary)
            
            Text(label)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundStyle(ModernDesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.Components.radiusSM)
                .fill(ModernDesignSystem.Colors.backgroundSecondary)
        )
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
}