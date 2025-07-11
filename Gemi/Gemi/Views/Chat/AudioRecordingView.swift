import SwiftUI
import AVFoundation

/// Beautiful audio recording interface with waveform visualization
struct AudioRecordingView: View {
    @StateObject private var audioRecorder = AttachmentManager.AudioRecorder()
    @ObservedObject var attachmentManager: AttachmentManager
    @Binding var isPresented: Bool
    
    @State private var isAnimating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Voice Recording")
                    .font(Theme.Typography.sectionHeader)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    stopAndDiscard()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Theme.Colors.secondaryText)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
                .opacity(0.5)
            
            // Recording interface
            VStack(spacing: 24) {
                // Waveform visualization
                WaveformView(audioLevels: audioRecorder.audioLevels)
                    .frame(height: 100)
                    .padding(.horizontal)
                
                // Time display
                Text(audioRecorder.formattedTime)
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                
                // Recording controls
                HStack(spacing: 32) {
                    // Cancel button
                    Button {
                        stopAndDiscard()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                    .buttonStyle(.plain)
                    .opacity(audioRecorder.isRecording ? 1 : 0.5)
                    .disabled(!audioRecorder.isRecording)
                    
                    // Record/Stop button
                    Button {
                        if audioRecorder.isRecording {
                            stopAndSave()
                        } else {
                            startRecording()
                        }
                    } label: {
                        ZStack {
                            // Background circle
                            Circle()
                                .fill(
                                    audioRecorder.isRecording ?
                                    Color.red :
                                    Theme.Colors.primaryAccent
                                )
                                .frame(width: 80, height: 80)
                                .shadow(
                                    color: audioRecorder.isRecording ?
                                        Color.red.opacity(0.5) :
                                        Theme.Colors.primaryAccent.opacity(0.5),
                                    radius: audioRecorder.isRecording ? 15 : 10,
                                    x: 0,
                                    y: 4
                                )
                            
                            // Icon
                            if audioRecorder.isRecording {
                                // Stop icon (square)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                            } else {
                                // Microphone icon
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            }
                            
                            // Pulse animation when recording
                            if audioRecorder.isRecording {
                                Circle()
                                    .stroke(Color.red, lineWidth: 2)
                                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                                    .opacity(isAnimating ? 0 : 1)
                                    .animation(
                                        .easeOut(duration: 1.5)
                                        .repeatForever(autoreverses: false),
                                        value: isAnimating
                                    )
                                    .frame(width: 80, height: 80)
                            }
                        }
                        .scaleEffect(audioRecorder.isRecording ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: audioRecorder.isRecording)
                    }
                    .buttonStyle(.plain)
                    
                    // Spacer for symmetry
                    Color.clear
                        .frame(width: 56, height: 56)
                }
                
                // Status text
                Text(audioRecorder.isRecording ? "Tap to stop recording" : "Tap to start recording")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(.vertical, 32)
        }
        .frame(width: 450, height: 400)
        .background(Theme.Colors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            if audioRecorder.isRecording {
                isAnimating = true
            }
        }
        .alert("Recording Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Actions
    
    private func startRecording() {
        Task {
            do {
                try await audioRecorder.startRecording()
                withAnimation {
                    isAnimating = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func stopAndSave() {
        guard let audioURL = audioRecorder.stopRecording() else {
            errorMessage = "Failed to save recording"
            showError = true
            return
        }
        
        isAnimating = false
        
        // Add to attachments
        Task {
            do {
                try await attachmentManager.addAttachment(from: audioURL)
                await MainActor.run {
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func stopAndDiscard() {
        _ = audioRecorder.stopRecording()
        isAnimating = false
        isPresented = false
    }
}

// MARK: - Waveform Visualization

struct WaveformView: View {
    let audioLevels: [Float]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<audioLevels.count, id: \.self) { index in
                    WaveformBar(
                        level: CGFloat(audioLevels[index]),
                        maxHeight: geometry.size.height
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct WaveformBar: View {
    let level: CGFloat
    let maxHeight: CGFloat
    
    private var barHeight: CGFloat {
        max(4, level * maxHeight)
    }
    
    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Theme.Colors.primaryAccent,
                        Theme.Colors.primaryAccent.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4, height: barHeight)
            .animation(.easeOut(duration: 0.1), value: barHeight)
    }
}

// MARK: - Audio Recording Button

struct AudioRecordingButton: View {
    @Binding var showRecorder: Bool
    
    var body: some View {
        Button {
            showRecorder = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14))
                
                Text("Record Audio")
                    .font(Theme.Typography.body)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Theme.Colors.primaryAccent.opacity(0.1))
                    .overlay(
                        Capsule()
                            .strokeBorder(Theme.Colors.primaryAccent.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(Theme.Colors.primaryAccent)
        }
        .buttonStyle(.plain)
    }
}