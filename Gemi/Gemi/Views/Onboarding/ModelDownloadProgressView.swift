import SwiftUI

/// Beautiful download progress view for model installation
struct ModelDownloadProgressView: View {
    let progress: Double
    let downloadState: ModelDownloader.DownloadState
    let currentFile: String
    let bytesDownloaded: Int64
    let totalBytes: Int64
    let downloadStartTime: Date?
    let downloadSpeed: Double
    let onCancel: (() -> Void)?
    
    @State private var showDetails = false
    @State private var pulseAnimation = false
    
    private var formattedBytesDownloaded: String {
        ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)
    }
    
    private var formattedTotalBytes: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    private var timeRemaining: String {
        guard progress > 0 && progress < 1 else { return "" }
        guard totalBytes > 0 && bytesDownloaded >= 0 else { return "Calculating..." }
        
        // Calculate based on download speed
        if downloadSpeed > 0 && bytesDownloaded > 0 {
            let remainingBytes = max(0, totalBytes - bytesDownloaded)
            let remainingSeconds = Double(remainingBytes) / downloadSpeed
            
            // Sanity check - if estimate is unrealistic, fall back to progress-based calculation
            if remainingSeconds > 0 && remainingSeconds < 86400 { // Less than 24 hours
                if remainingSeconds < 60 {
                    return "Less than a minute remaining"
                } else if remainingSeconds < 3600 {
                    let minutes = Int(remainingSeconds / 60)
                    return "\(minutes) minute\(minutes == 1 ? "" : "s") remaining"
                } else {
                    let hours = Int(remainingSeconds / 3600)
                    let minutes = Int((remainingSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
                    if minutes > 0 {
                        return "\(hours)h \(minutes)m remaining"
                    } else {
                        return "\(hours) hour\(hours == 1 ? "" : "s") remaining"
                    }
                }
            }
        }
        
        // Fallback: estimate based on progress and elapsed time
        if let startTime = downloadStartTime, progress > 0.01 { // Need at least 1% progress
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 10 { // Only show after 10 seconds for more accuracy
                let estimatedTotal = elapsed / progress
                let remaining = estimatedTotal - elapsed
                
                // Sanity check
                if remaining > 0 && remaining < 86400 { // Less than 24 hours
                    if remaining < 60 {
                        return "Less than a minute remaining"
                    } else if remaining < 3600 {
                        let minutes = Int(remaining / 60)
                        return "\(minutes) minute\(minutes == 1 ? "" : "s") remaining"
                    } else {
                        let hours = Int(remaining / 3600)
                        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
                        if minutes > 0 {
                            return "\(hours)h \(minutes)m remaining"
                        } else {
                            return "\(hours) hour\(hours == 1 ? "" : "s") remaining"
                        }
                    }
                }
            }
        }
        
        return "Calculating time remaining..."
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Header with status
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    // Animated icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .blur(radius: 15)
                            .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                            .animation(
                                .easeInOut(duration: 2)
                                .repeatForever(autoreverses: true),
                                value: pulseAnimation
                            )
                        
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Downloading Gemma 3n")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("\(formattedBytesDownloaded) of \(formattedTotalBytes)")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Percentage
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                // Time remaining
                if !timeRemaining.isEmpty {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text(timeRemaining)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            
            // Main progress bar
            VStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    // Progress fill with gradient
                    GeometryReader { geometry in
                        if progress > 0 {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.purple,
                                            Color.blue,
                                            Color.purple
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(24, geometry.size.width * CGFloat(progress))) // Minimum 24px for visibility
                                .overlay(
                                    // Shimmer effect
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0),
                                                    Color.white.opacity(0.3),
                                                    Color.white.opacity(0)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .offset(x: pulseAnimation ? geometry.size.width : -geometry.size.width)
                                        .animation(
                                            .linear(duration: 3)
                                            .repeatForever(autoreverses: false),
                                            value: pulseAnimation
                                        )
                                        .mask(
                                            RoundedRectangle(cornerRadius: 12)
                                                .frame(width: max(24, geometry.size.width * CGFloat(progress)))
                                        )
                                )
                                .shadow(color: Color.purple.opacity(0.5), radius: 8, x: 0, y: 4)
                        } else {
                            // Show a subtle pulsing indicator at start when progress is 0
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.purple.opacity(0.3),
                                            Color.blue.opacity(0.3)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 60)
                                .opacity(pulseAnimation ? 0.6 : 0.3)
                                .animation(
                                    .easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true),
                                    value: pulseAnimation
                                )
                        }
                    }
                    .frame(height: 24)
                }
                
                // File details
                if showDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Current file:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text(currentFile)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        // Individual file progress indicators
                        ForEach([
                            "config.json",
                            "tokenizer.json", 
                            "tokenizer_config.json",
                            "model.safetensors.index.json",
                            "model-00001.safetensors",
                            "model-00002.safetensors",
                            "model-00003.safetensors",
                            "model-00004.safetensors"
                        ], id: \.self) { file in
                            FileProgressIndicator(
                                filename: file,
                                isComplete: shouldShowAsComplete(file),
                                isCurrent: currentFile.contains(file)
                            )
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                
                // Toggle details button
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showDetails.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(showDetails ? "Hide details" : "Show details")
                            .font(.system(size: 14, weight: .medium))
                        
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            
            // Tips while downloading
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.yellow.opacity(0.8))
                    
                    Text("While you wait...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("This is a one-time download", systemImage: "checkmark.circle")
                    Label("The download continues if you close this window", systemImage: "checkmark.circle")
                    Label("Gemi will be ready to use once download completes", systemImage: "checkmark.circle")
                }
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            
            // Cancel button
            if let onCancel = onCancel {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel Download")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            pulseAnimation = true
        }
    }
    
    private func shouldShowAsComplete(_ filename: String) -> Bool {
        // More accurate file completion detection based on file sizes
        // Total size is 15.74GB, calculate cumulative progress for each file
        let fileSizes: [(String, Double)] = [
            ("config.json", 4_596),                    // 4.54 KB
            ("tokenizer.json", 35_026_124),            // 33.4 MB
            ("tokenizer_config.json", 1_258_291),      // 1.2 MB  
            ("model.safetensors.index.json", 175_104), // 171 KB
            ("model-00001.safetensors", 3_308_257_280), // 3.06 GB
            ("model-00002.safetensors", 5_338_316_800), // 4.97 GB
            ("model-00003.safetensors", 5_359_288_320), // 4.99 GB
            ("model-00004.safetensors", 2_856_321_024)  // 2.66 GB
        ]
        
        var cumulativeSize: Double = 0
        let totalSize: Double = 16_899_382_539 // Exact total from file sizes as reported by user
        
        for (file, size) in fileSizes {
            cumulativeSize += size
            if filename.contains(file) {
                // File is complete if we've downloaded past its cumulative position
                let fileProgress = cumulativeSize / totalSize
                return progress >= fileProgress
            }
        }
        
        return false
    }
}

// File progress indicator component
struct FileProgressIndicator: View {
    let filename: String
    let isComplete: Bool
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
            } else if isCurrent {
                ProgressView()
                    .controlSize(.small)
                    .tint(.purple)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            Text(filename)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(
                    isComplete ? .green.opacity(0.8) :
                    isCurrent ? .white :
                    .white.opacity(0.5)
                )
                .lineLimit(1)
            
            Spacer()
        }
    }
}

struct ModelDownloadProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            ModelDownloadProgressView(
                progress: 0.45,
                downloadState: .downloading(file: "model-00002-of-00004.safetensors", progress: 0.45),
                currentFile: "model-00002-of-00004.safetensors",
                bytesDownloaded: 7_065_950_208,
                totalBytes: 15_737_835_520,
                downloadStartTime: Date().addingTimeInterval(-300), // 5 minutes ago
                downloadSpeed: 10_000_000, // 10 MB/s
                onCancel: {}
            )
            .padding(40)
        }
        .frame(width: 900, height: 700)
    }
}