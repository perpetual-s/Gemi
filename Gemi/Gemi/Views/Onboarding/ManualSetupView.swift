import SwiftUI

/// Manual setup instructions for users who want to provide their own model files
struct ManualSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedFeedback = false
    
    private let modelPath = ModelCache.shared.modelPath.path
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Manual Setup")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Download and install the model files manually")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 40)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Step 1: Download files
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Step 1: Download Model Files", systemImage: "1.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Download all files from the Gemma 3n model repository:")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Link(destination: URL(string: "https://huggingface.co/google/gemma-3n-E4B-it/tree/main")!) {
                            HStack {
                                Image(systemName: "link")
                                Text("Open HuggingFace Repository")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                            )
                        }
                        
                        Text("Required files (15.74 GB total):")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach([
                                "config.json (4.54 KB)",
                                "tokenizer.json (33.4 MB)",
                                "tokenizer_config.json (1.2 MB)",
                                "model.safetensors.index.json (171 KB)",
                                "model-00001-of-00004.safetensors (3.06 GB)",
                                "model-00002-of-00004.safetensors (4.97 GB)",
                                "model-00003-of-00004.safetensors (4.99 GB)",
                                "model-00004-of-00004.safetensors (2.66 GB)"
                            ], id: \.self) { file in
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.5))
                                    Text(file)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                    
                    // Step 2: Place files
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Step 2: Place Files in Model Directory", systemImage: "2.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Copy all downloaded files to this directory:")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        HStack {
                            Text(modelPath)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(modelPath, forType: .string)
                                withAnimation(.spring(response: 0.3)) {
                                    showCopiedFeedback = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        showCopiedFeedback = false
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 12))
                                    Text(showCopiedFeedback ? "Copied!" : "Copy")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(showCopiedFeedback ? .green : .blue)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                NSWorkspace.shared.open(URL(fileURLWithPath: modelPath))
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 12))
                                    Text("Open")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                    
                    // Step 3: Restart
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Step 3: Restart Gemi", systemImage: "3.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("After placing all files in the directory, restart Gemi to load the model.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Button {
                            // Restart the app
                            NSApp.terminate(nil)
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Restart Gemi")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Alternative: HuggingFace Token
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "key.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.yellow)
                            Text("Alternative: Use Your Own HuggingFace Token")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        Text("If you have a HuggingFace account with access to the model, you can provide your own token for automatic downloads.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Link(destination: URL(string: "https://huggingface.co/settings/tokens")!) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                Text("Get HuggingFace Token")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.yellow.opacity(0.1))
                            )
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .padding(40)
            }
            
            // Bottom buttons
            HStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 120, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                Button {
                    // Check if files exist and restart
                    Task {
                        if await ModelCache.shared.isModelComplete() {
                            NSApp.terminate(nil)
                        } else {
                            // Show alert that files are missing
                            let alert = NSAlert()
                            alert.messageText = "Model Files Not Found"
                            alert.informativeText = "Please ensure all model files are placed in the correct directory before restarting."
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                    }
                } label: {
                    Text("Check & Restart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 160, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(40)
        }
        .frame(width: 700, height: 800)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}