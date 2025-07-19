import Foundation
import Network

/// Comprehensive download diagnostics to identify issues
@MainActor
final class DownloadDiagnostics: ObservableObject {
    
    @Published var diagnosticResults: [DiagnosticResult] = []
    @Published var isRunning = false
    
    struct DiagnosticResult: Identifiable {
        let id = UUID()
        let test: String
        let status: Status
        let detail: String
        let solution: String?
        
        enum Status {
            case success, warning, failure, checking
            
            var icon: String {
                switch self {
                case .success: return "checkmark.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .failure: return "xmark.circle.fill"
                case .checking: return "circle.dotted"
                }
            }
            
            var color: String {
                switch self {
                case .success: return "green"
                case .warning: return "orange"
                case .failure: return "red"
                case .checking: return "gray"
                }
            }
        }
    }
    
    /// Run all diagnostics
    func runDiagnostics() async {
        isRunning = true
        diagnosticResults = []
        
        // Test 1: Internet Connectivity
        await testInternetConnectivity()
        
        // Test 2: DNS Resolution
        await testDNSResolution()
        
        // Test 3: HuggingFace Accessibility
        await testHuggingFaceAccess()
        
        // Test 4: Authentication
        await testAuthentication()
        
        // Test 5: Model Directory
        await testModelDirectory()
        
        // Test 6: Disk Space
        await testDiskSpace()
        
        // Test 7: Network Speed
        await testNetworkSpeed()
        
        // Test 8: Proxy/VPN Detection
        await testProxyVPN()
        
        // Test 9: SSL/TLS
        await testSSLTLS()
        
        // Test 10: Resume Support
        await testResumeSupport()
        
        isRunning = false
    }
    
    // MARK: - Individual Tests
    
    private func testInternetConnectivity() async {
        addResult(test: "Internet Connectivity", status: .checking)
        
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        await withCheckedContinuation { continuation in
            monitor.pathUpdateHandler = { path in
                Task { @MainActor in
                    if path.status == .satisfied {
                        self.updateResult(
                            test: "Internet Connectivity",
                            status: .success,
                            detail: "Connected via \(path.isExpensive ? "Cellular" : "WiFi")",
                            solution: nil
                        )
                    } else {
                        self.updateResult(
                            test: "Internet Connectivity",
                            status: .failure,
                            detail: "No internet connection detected",
                            solution: "Check your network settings and ensure you're connected to the internet"
                        )
                    }
                    continuation.resume()
                }
                monitor.cancel()
            }
            monitor.start(queue: queue)
        }
    }
    
    private func testDNSResolution() async {
        addResult(test: "DNS Resolution", status: .checking)
        
        let hosts = ["huggingface.co", "cdn-lfs.huggingface.co"]
        var allResolved = true
        var details: [String] = []
        
        for host in hosts {
            do {
                let _ = try await URLSession.shared.data(from: URL(string: "https://\(host)")!)
                details.append("✅ \(host)")
            } catch {
                allResolved = false
                details.append("❌ \(host)")
            }
        }
        
        updateResult(
            test: "DNS Resolution",
            status: allResolved ? .success : .warning,
            detail: details.joined(separator: ", "),
            solution: allResolved ? nil : "Try changing DNS servers (e.g., 8.8.8.8 or 1.1.1.1)"
        )
    }
    
    private func testHuggingFaceAccess() async {
        addResult(test: "HuggingFace Access", status: .checking)
        
        do {
            let url = URL(string: "https://huggingface.co/api/models/mlx-community/gemma-3n-E4B-it-4bit")!
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let _ = json["private"] as? Bool ?? false
                        let isGated = json["gated"] as? Bool ?? false
                        
                        if isGated {
                            updateResult(
                                test: "HuggingFace Access",
                                status: .warning,
                                detail: "Model is gated - requires accepting license",
                                solution: "Visit https://huggingface.co/mlx-community/gemma-3n-E4B-it-4bit and accept the license agreement"
                            )
                        } else {
                            updateResult(
                                test: "HuggingFace Access",
                                status: .success,
                                detail: "Model is accessible",
                                solution: nil
                            )
                        }
                    }
                } else {
                    updateResult(
                        test: "HuggingFace Access",
                        status: .failure,
                        detail: "HTTP \(httpResponse.statusCode)",
                        solution: "Check if HuggingFace is down at https://status.huggingface.co"
                    )
                }
            }
        } catch {
            updateResult(
                test: "HuggingFace Access",
                status: .failure,
                detail: error.localizedDescription,
                solution: "Check your internet connection and firewall settings"
            )
        }
    }
    
    private func testAuthentication() async {
        addResult(test: "Authentication", status: .checking)
        
        // mlx-community models don't require authentication
        let modelID = ModelConfiguration.modelID
        
        if modelID.starts(with: "mlx-community/") {
            updateResult(
                test: "Authentication",
                status: .success,
                detail: "✅ Using public mlx-community model - no authentication required",
                solution: nil
            )
        } else {
            // For other models, check if token exists
            var details: [String] = []
            var hasValidToken = false
            
            // Check Keychain
            if SettingsManager.shared.getHuggingFaceToken() != nil {
                details.append("✅ Keychain token found")
                hasValidToken = true
            } else {
                details.append("❌ No token found")
            }
            
            updateResult(
                test: "Authentication",
                status: hasValidToken ? .success : .warning,
                detail: details.joined(separator: ", "),
                solution: hasValidToken ? nil : "Add HuggingFace token via Settings for non-public models"
            )
        }
    }
    
    private func testModelDirectory() async {
        addResult(test: "Model Directory", status: .checking)
        
        let modelPath = ModelCache.shared.modelPath
        var details: [String] = []
        
        // Check existence
        let exists = FileManager.default.fileExists(atPath: modelPath.path)
        details.append(exists ? "✅ Directory exists" : "❌ Directory missing")
        
        // Check permissions
        let isWritable = FileManager.default.isWritableFile(atPath: modelPath.path)
        details.append(isWritable ? "✅ Writable" : "❌ Not writable")
        
        // Check existing files
        if exists {
            do {
                let files = try FileManager.default.contentsOfDirectory(at: modelPath, includingPropertiesForKeys: [.fileSizeKey])
                details.append("📁 \(files.count) files present")
            } catch {
                details.append("❌ Cannot read directory")
            }
        }
        
        updateResult(
            test: "Model Directory",
            status: exists && isWritable ? .success : .failure,
            detail: details.joined(separator: ", "),
            solution: exists && isWritable ? nil : "Reset app permissions or reinstall Gemi"
        )
    }
    
    private func testDiskSpace() async {
        addResult(test: "Disk Space", status: .checking)
        
        do {
            let fileManager = FileManager.default
            let path = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.path
            let attributes = try fileManager.attributesOfFileSystem(forPath: path)
            
            let freeSpace = attributes[.systemFreeSize] as? Int64 ?? 0
            let freeGB = Double(freeSpace) / 1_000_000_000
            
            let requiredGB = 20.0 // 16GB for model + buffer
            
            updateResult(
                test: "Disk Space",
                status: freeGB >= requiredGB ? .success : .failure,
                detail: String(format: "%.1f GB free (%.1f GB required)", freeGB, requiredGB),
                solution: freeGB >= requiredGB ? nil : "Free up disk space by deleting unused files"
            )
        } catch {
            updateResult(
                test: "Disk Space",
                status: .failure,
                detail: "Could not check disk space",
                solution: "Check system storage manually"
            )
        }
    }
    
    private func testNetworkSpeed() async {
        addResult(test: "Network Speed", status: .checking)
        
        // Download a small test file
        let testURL = URL(string: "https://huggingface.co/mlx-community/gemma-3n-E4B-it-4bit/resolve/main/config.json")!
        let startTime = Date()
        
        do {
            let (data, _) = try await URLSession.shared.data(from: testURL)
            let elapsed = Date().timeIntervalSince(startTime)
            let bytesPerSecond = Double(data.count) / elapsed
            let mbps = (bytesPerSecond * 8) / 1_000_000
            
            let status: DiagnosticResult.Status
            let solution: String?
            
            if mbps < 1 {
                status = .failure
                solution = "Your connection is too slow. Consider using Manual Setup."
            } else if mbps < 10 {
                status = .warning
                solution = "Download will take several hours. Consider a faster connection."
            } else {
                status = .success
                solution = nil
            }
            
            updateResult(
                test: "Network Speed",
                status: status,
                detail: String(format: "%.1f Mbps", mbps),
                solution: solution
            )
        } catch {
            updateResult(
                test: "Network Speed",
                status: .failure,
                detail: "Could not test speed",
                solution: "Check your internet connection"
            )
        }
    }
    
    private func testProxyVPN() async {
        addResult(test: "Proxy/VPN Detection", status: .checking)
        
        let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any]
        var details: [String] = []
        var hasProxy = false
        
        if let settings = proxySettings {
            if settings["HTTPEnable"] as? Int == 1 {
                details.append("HTTP Proxy detected")
                hasProxy = true
            }
            if settings["HTTPSEnable"] as? Int == 1 {
                details.append("HTTPS Proxy detected")
                hasProxy = true
            }
        }
        
        updateResult(
            test: "Proxy/VPN Detection",
            status: hasProxy ? .warning : .success,
            detail: hasProxy ? details.joined(separator: ", ") : "No proxy detected",
            solution: hasProxy ? "Proxy/VPN may interfere with downloads. Try disabling if issues occur." : nil
        )
    }
    
    private func testSSLTLS() async {
        addResult(test: "SSL/TLS", status: .checking)
        
        do {
            let url = URL(string: "https://huggingface.co")!
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if response.url?.scheme == "https" {
                updateResult(
                    test: "SSL/TLS",
                    status: .success,
                    detail: "Secure connection established",
                    solution: nil
                )
            } else {
                updateResult(
                    test: "SSL/TLS",
                    status: .warning,
                    detail: "Connection may not be secure",
                    solution: "Check your network security settings"
                )
            }
        } catch {
            updateResult(
                test: "SSL/TLS",
                status: .failure,
                detail: error.localizedDescription,
                solution: "Check date/time settings and SSL certificates"
            )
        }
    }
    
    private func testResumeSupport() async {
        addResult(test: "Resume Support", status: .checking)
        
        do {
            let url = URL(string: "https://huggingface.co/mlx-community/gemma-3n-E4B-it-4bit/resolve/main/model-00001-of-00002.safetensors")!
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 206 { // Partial Content
                    updateResult(
                        test: "Resume Support",
                        status: .success,
                        detail: "Server supports resume",
                        solution: nil
                    )
                } else {
                    updateResult(
                        test: "Resume Support",
                        status: .warning,
                        detail: "Server may not support resume",
                        solution: "Downloads will restart from beginning if interrupted"
                    )
                }
            }
        } catch {
            updateResult(
                test: "Resume Support",
                status: .warning,
                detail: "Could not verify resume support",
                solution: nil
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func addResult(test: String, status: DiagnosticResult.Status) {
        let result = DiagnosticResult(
            test: test,
            status: status,
            detail: "Testing...",
            solution: nil
        )
        diagnosticResults.append(result)
    }
    
    private func updateResult(test: String, status: DiagnosticResult.Status, detail: String, solution: String?) {
        if let index = diagnosticResults.firstIndex(where: { $0.test == test }) {
            diagnosticResults[index] = DiagnosticResult(
                test: test,
                status: status,
                detail: detail,
                solution: solution
            )
        }
    }
    
    /// Generate a diagnostic report
    func generateReport() -> String {
        var report = "# Gemi Download Diagnostics Report\n\n"
        report += "Generated: \(Date())\n\n"
        
        for result in diagnosticResults {
            report += "## \(result.test)\n"
            report += "Status: \(result.status)\n"
            report += "Details: \(result.detail)\n"
            if let solution = result.solution {
                report += "Solution: \(solution)\n"
            }
            report += "\n"
        }
        
        return report
    }
}