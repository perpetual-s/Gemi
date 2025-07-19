import SwiftUI

/// A comprehensive diagnostics view for download issues
struct DownloadDiagnosticsView: View {
    @State private var diagnosticResults: [DiagnosticResult] = []
    @State private var isRunning = false
    @State private var currentTest = ""
    @State private var overallStatus: DiagnosticStatus = .notStarted
    
    let onDismiss: () -> Void
    let onRetry: () -> Void
    
    struct DiagnosticResult: Identifiable {
        let id = UUID()
        let name: String
        let status: DiagnosticStatus
        let message: String
        let solution: String?
    }
    
    enum DiagnosticStatus {
        case notStarted
        case running
        case passed
        case warning
        case failed
        
        var icon: String {
            switch self {
            case .notStarted: return "circle"
            case .running: return "circle.dotted"
            case .passed: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .notStarted: return .gray
            case .running: return .blue
            case .passed: return .green
            case .warning: return .orange
            case .failed: return .red
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Download Diagnostics")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Running tests to identify the issue")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            Divider()
            
            // Diagnostic Results
            ScrollView {
                VStack(spacing: 16) {
                    // Overall Status
                    if overallStatus != .notStarted {
                        overallStatusView
                            .padding(.bottom, 8)
                    }
                    
                    // Individual Tests
                    ForEach(diagnosticResults) { result in
                        DiagnosticItemView(result: result)
                    }
                    
                    if isRunning && !currentTest.isEmpty {
                        HStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Testing: \(currentTest)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Actions
            HStack(spacing: 12) {
                if !isRunning {
                    Button {
                        runDiagnostics()
                    } label: {
                        Label("Run Diagnostics", systemImage: "stethoscope")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                }
                
                Button {
                    onRetry()
                } label: {
                    Label("Retry Download", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)
            }
            .padding(20)
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 20)
        .onAppear {
            runDiagnostics()
        }
    }
    
    @ViewBuilder
    private var overallStatusView: some View {
        VStack(spacing: 12) {
            Image(systemName: overallStatus.icon)
                .font(.system(size: 48))
                .foregroundStyle(overallStatus.color)
                .symbolRenderingMode(.multicolor)
            
            Text(overallStatusMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if let suggestion = overallSuggestion {
                Text(suggestion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(overallStatus.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var overallStatusMessage: String {
        switch overallStatus {
        case .notStarted:
            return "Diagnostics not started"
        case .running:
            return "Running diagnostics..."
        case .passed:
            return "All tests passed! 🎉"
        case .warning:
            return "Some issues detected"
        case .failed:
            return "Critical issues found"
        }
    }
    
    private var overallSuggestion: String? {
        switch overallStatus {
        case .passed:
            return "Your system is ready. The download should work now."
        case .warning:
            return "The download might work, but some issues could affect performance."
        case .failed:
            return "Please address the critical issues before retrying."
        default:
            return nil
        }
    }
    
    private func runDiagnostics() {
        isRunning = true
        diagnosticResults = []
        currentTest = ""
        
        Task {
            // Test 1: Internet Connectivity
            await runTest(
                name: "Internet Connection",
                test: testInternetConnection
            )
            
            // Test 2: HuggingFace Access
            await runTest(
                name: "HuggingFace Access",
                test: testHuggingFaceAccess
            )
            
            // Test 3: Model URL Access
            await runTest(
                name: "Model File Access",
                test: testModelAccess
            )
            
            // Test 4: Disk Space
            await runTest(
                name: "Disk Space",
                test: testDiskSpace
            )
            
            // Test 5: Network Speed
            await runTest(
                name: "Network Speed",
                test: testNetworkSpeed
            )
            
            // Test 6: Firewall/Proxy
            await runTest(
                name: "Firewall & Proxy",
                test: testFirewallProxy
            )
            
            // Calculate overall status
            updateOverallStatus()
            isRunning = false
            currentTest = ""
        }
    }
    
    private func runTest(name: String, test: @escaping () async -> DiagnosticResult) async {
        await MainActor.run {
            currentTest = name
        }
        
        let result = await test()
        
        await MainActor.run {
            diagnosticResults.append(result)
        }
    }
    
    private func testInternetConnection() async -> DiagnosticResult {
        do {
            let url = URL(string: "https://www.apple.com")!
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                return DiagnosticResult(
                    name: "Internet Connection",
                    status: .passed,
                    message: "Connected to the internet",
                    solution: nil
                )
            }
        } catch {
            // Error occurred
        }
        
        return DiagnosticResult(
            name: "Internet Connection",
            status: .failed,
            message: "No internet connection detected",
            solution: "Check your network settings and ensure you're connected to the internet"
        )
    }
    
    private func testHuggingFaceAccess() async -> DiagnosticResult {
        do {
            let url = URL(string: "https://huggingface.co")!
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                return DiagnosticResult(
                    name: "HuggingFace Access",
                    status: .passed,
                    message: "Can access HuggingFace servers",
                    solution: nil
                )
            }
        } catch {
            // Error occurred
        }
        
        return DiagnosticResult(
            name: "HuggingFace Access",
            status: .failed,
            message: "Cannot reach HuggingFace servers",
            solution: "HuggingFace might be blocked by your firewall or network. Try using a VPN or different network."
        )
    }
    
    private func testModelAccess() async -> DiagnosticResult {
        let testURL = "https://huggingface.co/mlx-community/gemma-3n-E4B-it-4bit/resolve/main/config.json"
        
        do {
            var request = URLRequest(url: URL(string: testURL)!)
            request.httpMethod = "HEAD"
            request.setValue("Gemi/1.0", forHTTPHeaderField: "User-Agent")
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return DiagnosticResult(
                        name: "Model File Access",
                        status: .passed,
                        message: "Model files are accessible",
                        solution: nil
                    )
                } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    return DiagnosticResult(
                        name: "Model File Access",
                        status: .warning,
                        message: "Model might require authentication",
                        solution: "The mlx-community model should be public. This might be a temporary issue."
                    )
                }
            }
        } catch {
            // Error occurred
        }
        
        return DiagnosticResult(
            name: "Model File Access",
            status: .failed,
            message: "Cannot access model files",
            solution: "Check if HuggingFace is experiencing issues or if your network blocks large file downloads"
        )
    }
    
    private func testDiskSpace() async -> DiagnosticResult {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: documentsPath.path)
            if let freeSpace = attributes[.systemFreeSize] as? Int64 {
                let requiredSpace: Int64 = 10 * 1024 * 1024 * 1024 // 10GB for safety
                let freeSpaceGB = Double(freeSpace) / (1024 * 1024 * 1024)
                
                if freeSpace > requiredSpace {
                    return DiagnosticResult(
                        name: "Disk Space",
                        status: .passed,
                        message: String(format: "%.1f GB available", freeSpaceGB),
                        solution: nil
                    )
                } else {
                    return DiagnosticResult(
                        name: "Disk Space",
                        status: .failed,
                        message: String(format: "Only %.1f GB available", freeSpaceGB),
                        solution: "Free up at least 10GB of disk space for the model download"
                    )
                }
            }
        } catch {
            // Error occurred
        }
        
        return DiagnosticResult(
            name: "Disk Space",
            status: .warning,
            message: "Could not check disk space",
            solution: "Ensure you have at least 10GB free space"
        )
    }
    
    private func testNetworkSpeed() async -> DiagnosticResult {
        let testURL = "https://huggingface.co/mlx-community/gemma-3n-E4B-it-4bit/resolve/main/generation_config.json"
        
        do {
            let start = Date()
            let (data, _) = try await URLSession.shared.data(from: URL(string: testURL)!)
            let elapsed = Date().timeIntervalSince(start)
            
            let bytesPerSecond = Double(data.count) / elapsed
            let mbps = (bytesPerSecond * 8) / (1024 * 1024)
            
            if mbps > 10 {
                return DiagnosticResult(
                    name: "Network Speed",
                    status: .passed,
                    message: String(format: "Good speed: %.1f Mbps", mbps),
                    solution: nil
                )
            } else if mbps > 2 {
                return DiagnosticResult(
                    name: "Network Speed",
                    status: .warning,
                    message: String(format: "Slow speed: %.1f Mbps", mbps),
                    solution: "Download will work but may take longer. Consider using a faster connection."
                )
            } else {
                return DiagnosticResult(
                    name: "Network Speed",
                    status: .failed,
                    message: String(format: "Very slow: %.1f Mbps", mbps),
                    solution: "Your connection is too slow. Try a different network or ethernet connection."
                )
            }
        } catch {
            return DiagnosticResult(
                name: "Network Speed",
                status: .warning,
                message: "Could not measure speed",
                solution: "Network might be unstable"
            )
        }
    }
    
    private func testFirewallProxy() async -> DiagnosticResult {
        // Check for common proxy environment variables
        let proxyVars = ["HTTP_PROXY", "HTTPS_PROXY", "http_proxy", "https_proxy"]
        let hasProxy = proxyVars.contains { ProcessInfo.processInfo.environment[$0] != nil }
        
        if hasProxy {
            return DiagnosticResult(
                name: "Firewall & Proxy",
                status: .warning,
                message: "Proxy detected",
                solution: "Proxy settings might interfere with downloads. Consider disabling if possible."
            )
        }
        
        // Test direct vs system connection
        var request = URLRequest(url: URL(string: "https://huggingface.co")!)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                return DiagnosticResult(
                    name: "Firewall & Proxy",
                    status: .passed,
                    message: "No firewall issues detected",
                    solution: nil
                )
            }
        } catch {
            // Error might indicate firewall
        }
        
        return DiagnosticResult(
            name: "Firewall & Proxy",
            status: .warning,
            message: "Possible firewall restrictions",
            solution: "Check if your firewall or antivirus is blocking downloads"
        )
    }
    
    private func updateOverallStatus() {
        let failedCount = diagnosticResults.filter { $0.status == .failed }.count
        let warningCount = diagnosticResults.filter { $0.status == .warning }.count
        
        if failedCount > 0 {
            overallStatus = .failed
        } else if warningCount > 0 {
            overallStatus = .warning
        } else {
            overallStatus = .passed
        }
    }
}

struct DiagnosticItemView: View {
    let result: DownloadDiagnosticsView.DiagnosticResult
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: result.status.icon)
                    .font(.title3)
                    .foregroundStyle(result.status.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name)
                        .font(.headline)
                    
                    Text(result.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if result.solution != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if isExpanded, let solution = result.solution {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .frame(width: 16, alignment: .center)
                            .offset(y: 2)
                        
                        Text(solution)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }
        }
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// Preview
struct DownloadDiagnosticsView_Previews: PreviewProvider {
    static var previews: some View {
        DownloadDiagnosticsView(
            onDismiss: {},
            onRetry: {}
        )
        .previewLayout(.sizeThatFits)
    }
}