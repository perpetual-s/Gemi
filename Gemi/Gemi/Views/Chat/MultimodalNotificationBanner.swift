import SwiftUI

/// Banner that shows multimodal capabilities status
struct MultimodalNotificationBanner: View {
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main banner
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Multimodal AI Active")
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Gemma 3n is processing your images and text together")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showDetails.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Learn more")
                            .font(Theme.Typography.caption)
                        
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(Theme.Colors.primaryAccent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Expandable details
            if showDetails {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Multimodal Capabilities")
                        .font(Theme.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Gemma 3n from Google DeepMind can understand and process images, text, audio, and video in a single conversation.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What you can do:")
                            .font(Theme.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                            
                            Text("Add images to your journal entries for visual context")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "waveform")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                            
                            Text("Record voice memos (coming soon)")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "globe")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                            
                            Text("Express yourself in 140+ languages")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                    }
                    
                    // Learn more button
                    Button {
                        NSWorkspace.shared.open(URL(string: "https://huggingface.co/\(ModelConfiguration.modelID)")!)
                    } label: {
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                            
                            Text("Learn about Gemma 3n")
                                .font(Theme.Typography.body)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green)
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.Colors.cardBackground.opacity(0.5))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
    }
}