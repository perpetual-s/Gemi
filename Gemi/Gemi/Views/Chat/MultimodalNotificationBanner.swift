import SwiftUI

/// Banner that notifies users when multimodal features aren't supported
struct MultimodalNotificationBanner: View {
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main banner
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Multimodal Not Supported")
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Current model doesn't support images or audio. Attachments will be ignored.")
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
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Expandable details
            if showDetails {
                VStack(alignment: .leading, spacing: 16) {
                    Text("About Multimodal Support")
                        .font(Theme.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Gemma 3n is designed to support images, audio, and video inputs. However, the current Ollama implementation only supports text.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To use multimodal features:")
                            .font(Theme.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("1.")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.tertiaryText)
                            
                            Text("Wait for Ollama to update Gemma 3n with multimodal support")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("2.")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.tertiaryText)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Or use a different model that supports images:")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.secondaryText)
                                
                                HStack(spacing: 8) {
                                    ForEach(["llava", "bakllava", "llama3.2-vision"], id: \.self) { model in
                                        Text(model)
                                            .font(Theme.Typography.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(Theme.Colors.primaryAccent.opacity(0.1))
                                            )
                                            .foregroundColor(Theme.Colors.primaryAccent)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Model switcher button
                    Button {
                        // Future: Open model selection dialog
                        NSWorkspace.shared.open(URL(string: "https://ollama.com/library")!)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14))
                            
                            Text("Browse Available Models")
                                .font(Theme.Typography.body)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.Colors.primaryAccent)
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