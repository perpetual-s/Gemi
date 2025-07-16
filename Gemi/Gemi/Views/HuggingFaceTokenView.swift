import SwiftUI

struct HuggingFaceTokenView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var token: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var onTokenSaved: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("HuggingFace Token Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Gemma models are gated and require authentication")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            
            // Instructions
            VStack(alignment: .leading, spacing: 16) {
                Label("Get your token from HuggingFace", systemImage: "1.circle.fill")
                    .foregroundColor(.primary)
                
                Link(destination: URL(string: "https://huggingface.co/settings/tokens")!) {
                    HStack {
                        Text("Open HuggingFace Settings")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Label("Create a token with 'read' permission", systemImage: "2.circle.fill")
                    .foregroundColor(.primary)
                
                Label("Paste your token below", systemImage: "3.circle.fill")
                    .foregroundColor(.primary)
            }
            .font(.subheadline)
            .padding(.horizontal)
            
            // Token Input
            VStack(alignment: .leading, spacing: 8) {
                Text("HuggingFace Token")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField("hf_...", text: $token)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            // Action Buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Button("Save Token") {
                    saveToken()
                }
                .buttonStyle(.borderedProminent)
                .disabled(token.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .frame(width: 450)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveToken() {
        // Basic validation
        guard token.starts(with: "hf_") else {
            errorMessage = "Invalid token format. HuggingFace tokens start with 'hf_'"
            showingError = true
            return
        }
        
        do {
            try settingsManager.saveHuggingFaceToken(token)
            onTokenSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    HuggingFaceTokenView()
}