//
//  WritingFeedbackSettings.swift
//  Gemi
//
//  Settings for controlling writing feedback intensity
//

import SwiftUI

struct WritingFeedbackSettings: View {
    @AppStorage("typingFeedbackEnabled") private var typingFeedbackEnabled = true
    @AppStorage("typingFeedbackIntensity") private var typingIntensity = 0.5
    @AppStorage("celebrationsEnabled") private var celebrationsEnabled = true
    @AppStorage("celebrationIntensity") private var celebrationIntensity = 1.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Writing Feedback")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
            }
            
            Divider()
            
            // Typing Feedback Section
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Typing Feedback", isOn: $typingFeedbackEnabled)
                    .toggleStyle(.switch)
                
                if typingFeedbackEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Intensity")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Subtle")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Slider(value: $typingIntensity, in: 0...1)
                                .controlSize(.small)
                            
                            Text("Vibrant")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 20)
                }
            }
            
            Divider()
            
            // Milestone Celebrations Section
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Milestone Celebrations", isOn: $celebrationsEnabled)
                    .toggleStyle(.switch)
                
                if celebrationsEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Celebration Style")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Minimal")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Slider(value: $celebrationIntensity, in: 0...1)
                                .controlSize(.small)
                            
                            Text("Festive")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 20)
                }
            }
            
            Divider()
            
            // Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("Test Typing") {
                        // Preview available in main editor
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button("Test Milestone") {
                        // Celebration previews in main editor
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .frame(width: 350, height: 400)
    }
}

// MARK: - Menu Item for Settings

struct WritingFeedbackMenuItem: View {
    @State private var showingSettings = false
    
    var body: some View {
        Button {
            showingSettings = true
        } label: {
            Label("Writing Feedback Settings", systemImage: "slider.horizontal.3")
        }
        .sheet(isPresented: $showingSettings) {
            WritingFeedbackSettings()
        }
    }
}