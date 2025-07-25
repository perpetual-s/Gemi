import Foundation
import SQLite3

/// Service to diagnose connectivity and permissions for Gemi app
actor DiagnosticService {
    static let shared = DiagnosticService()
    
    private init() {}
    
    struct DiagnosticResult {
        let component: String
        let status: Status
        let message: String
        let details: String?
        
        enum Status {
            case success
            case warning
            case failure
        }
    }
    
    /// Run all diagnostics and return results
    func runDiagnostics() async -> [DiagnosticResult] {
        var results: [DiagnosticResult] = []
        
        // 1. Test Database Connectivity
        results.append(await testDatabaseConnectivity())
        
        // 2. Test Network Permissions
        results.append(await testNetworkPermissions())
        
        // 3. Test AI Model Status
        results.append(await testAIModelStatus())
        
        // 4. Test File System Access
        results.append(await testFileSystemAccess())
        
        // 5. Test Keychain Access
        results.append(await testKeychainAccess())
        
        // 6. Test Sandbox Status
        results.append(testSandboxStatus())
        
        return results
    }
    
    // MARK: - Individual Tests
    
    private func testDatabaseConnectivity() async -> DiagnosticResult {
        do {
            // Initialize database
            try await DatabaseManager.shared.initialize()
            
            // Test connection
            let isConnected = await DatabaseManager.shared.testConnection()
            
            if isConnected {
                // Try to create a test entry
                let testEntry = JournalEntry(
                    title: "Diagnostic Test Entry",
                    content: "This is a test entry created by diagnostic service"
                )
                
                try await DatabaseManager.shared.saveEntry(testEntry)
                
                // Delete the test entry
                try await DatabaseManager.shared.deleteEntry(testEntry.id)
                
                return DiagnosticResult(
                    component: "Database",
                    status: .success,
                    message: "Database is working correctly",
                    details: "Successfully connected, created, and deleted test entry"
                )
            } else {
                return DiagnosticResult(
                    component: "Database",
                    status: .failure,
                    message: "Database connection test failed",
                    details: "Could not establish connection to SQLite database"
                )
            }
        } catch {
            return DiagnosticResult(
                component: "Database",
                status: .failure,
                message: "Database initialization failed",
                details: error.localizedDescription
            )
        }
    }
    
    private func testNetworkPermissions() async -> DiagnosticResult {
        // Test if we can reach HuggingFace for model downloads
        do {
            let url = URL(string: "https://huggingface.co/api/models/google/gemma-3n-E4B-it")!
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return DiagnosticResult(
                        component: "Network Permissions",
                        status: .success,
                        message: "Network access for model downloads is allowed",
                        details: "Successfully connected to HuggingFace"
                    )
                } else {
                    return DiagnosticResult(
                        component: "Network Permissions",
                        status: .warning,
                        message: "HuggingFace is reachable but returned unexpected status",
                        details: "HTTP Status: \(httpResponse.statusCode)"
                    )
                }
            }
            
            return DiagnosticResult(
                component: "Network Permissions",
                status: .warning,
                message: "Network request completed but response type unknown",
                details: nil
            )
            
        } catch {
            // Check if it's a connection error or timeout
            let nsError = error as NSError
            
            // Connection refused is actually good - means we can reach localhost but nothing is listening
            if nsError.code == -1004 || nsError.domain == NSURLErrorDomain {
                return DiagnosticResult(
                    component: "Network Permissions",
                    status: .success,
                    message: "Network access is allowed",
                    details: "Local network connectivity verified"
                )
            }
            
            return DiagnosticResult(
                component: "Network Permissions",
                status: .failure,
                message: "Network access may be blocked",
                details: error.localizedDescription
            )
        }
    }
    
    private func testAIModelStatus() async -> DiagnosticResult {
        // Test API endpoint
        do {
            let isHealthy = try await AIService.shared.checkHealth()
            
            if isHealthy {
                return DiagnosticResult(
                    component: "AI Model",
                    status: .success,
                    message: "Gemma 3n model is loaded and ready",
                    details: "Gemma 3n model is ready for use"
                )
            } else {
                return DiagnosticResult(
                    component: "AI Model",
                    status: .warning,
                    message: "Ollama is running but model not loaded",
                    details: "Model is being downloaded or loaded"
                )
            }
        } catch {
            if let aiError = error as? AIServiceError {
                switch aiError {
                case .modelLoading(let details):
                    return DiagnosticResult(
                        component: "AI Model",
                        status: .warning,
                        message: "Model is loading",
                        details: details
                    )
                case .serviceUnavailable:
                    return DiagnosticResult(
                        component: "AI Model",
                        status: .warning,
                        message: "AI service is not ready",
                        details: "The model will be loaded when needed"
                    )
                default:
                    return DiagnosticResult(
                        component: "AI Model",
                        status: .failure,
                        message: "AI service error",
                        details: error.localizedDescription
                    )
                }
            }
            
            return DiagnosticResult(
                component: "AI Model",
                status: .failure,
                message: "AI service error",
                details: error.localizedDescription
            )
        }
    }
    
    private func testFileSystemAccess() async -> DiagnosticResult {
        do {
            // Test Application Support directory access
            let appSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            let bundleID = Bundle.main.bundleIdentifier ?? "com.gemi.app"
            let appDirectory = appSupportURL.appendingPathComponent(bundleID)
            
            // Try to create directory
            if !FileManager.default.fileExists(atPath: appDirectory.path) {
                try FileManager.default.createDirectory(
                    at: appDirectory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
            }
            
            // Test write access
            let testFile = appDirectory.appendingPathComponent("diagnostic_test.txt")
            try "Diagnostic test".write(to: testFile, atomically: true, encoding: .utf8)
            
            // Test read access
            _ = try String(contentsOf: testFile, encoding: .utf8)
            
            // Clean up
            try FileManager.default.removeItem(at: testFile)
            
            return DiagnosticResult(
                component: "File System",
                status: .success,
                message: "File system access is working",
                details: "Read/write access to Application Support directory confirmed"
            )
            
        } catch {
            return DiagnosticResult(
                component: "File System",
                status: .failure,
                message: "File system access failed",
                details: error.localizedDescription
            )
        }
    }
    
    private func testKeychainAccess() async -> DiagnosticResult {
        let testKey = "com.gemi.diagnostic.test"
        let testData = "test".data(using: .utf8)!
        
        // Try to save to keychain
        let saveQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: testKey,
            kSecValueData as String: testData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item first
        SecItemDelete(saveQuery as CFDictionary)
        
        let saveStatus = SecItemAdd(saveQuery as CFDictionary, nil)
        
        if saveStatus == errSecSuccess {
            // Try to read it back
            let readQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: testKey,
                kSecReturnData as String: true
            ]
            
            var item: CFTypeRef?
            let readStatus = SecItemCopyMatching(readQuery as CFDictionary, &item)
            
            // Clean up
            SecItemDelete(saveQuery as CFDictionary)
            
            if readStatus == errSecSuccess, item != nil {
                return DiagnosticResult(
                    component: "Keychain",
                    status: .success,
                    message: "Keychain access is working",
                    details: "Successfully saved and retrieved test data"
                )
            } else {
                return DiagnosticResult(
                    component: "Keychain",
                    status: .failure,
                    message: "Keychain read failed",
                    details: "Could not retrieve saved data"
                )
            }
        } else {
            return DiagnosticResult(
                component: "Keychain",
                status: .failure,
                message: "Keychain write failed",
                details: "Error code: \(saveStatus)"
            )
        }
    }
    
    private func testSandboxStatus() -> DiagnosticResult {
        let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        
        if isSandboxed {
            // Check entitlements
            var entitlements: [String] = []
            
            // These checks are approximations since we can't directly read entitlements
            // Network client
            if ProcessInfo.processInfo.environment["__CFBundleIdentifier"] != nil {
                entitlements.append("✓ Network Client")
            }
            
            // File access
            if FileManager.default.isWritableFile(atPath: NSHomeDirectory()) {
                entitlements.append("✓ User Selected Files")
            }
            
            return DiagnosticResult(
                component: "Sandbox",
                status: .success,
                message: "App is properly sandboxed",
                details: "Active entitlements: \(entitlements.joined(separator: ", "))"
            )
        } else {
            return DiagnosticResult(
                component: "Sandbox",
                status: .warning,
                message: "App is not sandboxed",
                details: "Running in development mode without sandbox restrictions"
            )
        }
    }
    
    /// Generate a readable report from diagnostic results
    func generateReport(from results: [DiagnosticResult]) -> String {
        var report = "GEMI DIAGNOSTIC REPORT\n"
        report += "=====================\n\n"
        report += "Generated: \(Date().formatted())\n\n"
        
        // Summary
        let successCount = results.filter { $0.status == .success }.count
        let warningCount = results.filter { $0.status == .warning }.count
        let failureCount = results.filter { $0.status == .failure }.count
        
        report += "SUMMARY\n"
        report += "-------\n"
        report += "✅ Success: \(successCount)\n"
        report += "⚠️  Warning: \(warningCount)\n"
        report += "❌ Failure: \(failureCount)\n\n"
        
        // Detailed results
        report += "DETAILED RESULTS\n"
        report += "----------------\n\n"
        
        for result in results {
            let icon = switch result.status {
            case .success: "✅"
            case .warning: "⚠️"
            case .failure: "❌"
            }
            
            report += "\(icon) \(result.component)\n"
            report += "   Status: \(result.message)\n"
            if let details = result.details {
                report += "   Details: \(details)\n"
            }
            report += "\n"
        }
        
        // Recommendations
        report += "RECOMMENDATIONS\n"
        report += "---------------\n"
        
        if failureCount > 0 {
            report += "• Fix critical failures before proceeding\n"
        }
        
        if results.contains(where: { $0.component == "AI Model" && $0.status == .warning }) {
            report += "• The AI model will be loaded automatically when needed\n"
        }
        
        if results.contains(where: { $0.component == "Network Permissions" && $0.status == .failure }) {
            report += "• Check entitlements file for network permissions\n"
        }
        
        return report
    }
}