import Foundation

/// Configuration manager for AI inference server settings
@MainActor
final class AIConfiguration: ObservableObject {
    static let shared = AIConfiguration()
    
    // MARK: - Published Properties
    @Published var host: String {
        didSet {
            UserDefaults.standard.set(host, forKey: Keys.host)
        }
    }
    
    @Published var port: Int {
        didSet {
            UserDefaults.standard.set(port, forKey: Keys.port)
        }
    }
    
    @Published var useCustomURL: Bool {
        didSet {
            UserDefaults.standard.set(useCustomURL, forKey: Keys.useCustomURL)
        }
    }
    
    // MARK: - Constants
    private enum Keys {
        static let host = "com.gemi.ai.host"
        static let port = "com.gemi.ai.port"
        static let useCustomURL = "com.gemi.ai.useCustomURL"
    }
    
    private enum Defaults {
        static let host = "127.0.0.1"
        static let port = 11435  // Python inference server port
        static let useCustomURL = false
    }
    
    // MARK: - Computed Properties
    var baseURL: String {
        if useCustomURL {
            return "http://\(host):\(port)"
        } else {
            return "http://\(Defaults.host):\(Defaults.port)"
        }
    }
    
    var apiHealthURL: String {
        return "\(baseURL)/api/health"
    }
    
    var apiChatURL: String {
        return "\(baseURL)/api/chat"
    }
    
    var apiTagsURL: String {
        return "\(baseURL)/api/tags"
    }
    
    var apiPullURL: String {
        return "\(baseURL)/api/pull"
    }
    
    var apiShowURL: String {
        return "\(baseURL)/api/show"
    }
    
    // MARK: - Initialization
    private init() {
        self.host = UserDefaults.standard.string(forKey: Keys.host) ?? Defaults.host
        self.port = UserDefaults.standard.integer(forKey: Keys.port) > 0 
            ? UserDefaults.standard.integer(forKey: Keys.port) 
            : Defaults.port
        self.useCustomURL = UserDefaults.standard.bool(forKey: Keys.useCustomURL)
    }
    
    // MARK: - Methods
    func resetToDefaults() {
        host = Defaults.host
        port = Defaults.port
        useCustomURL = Defaults.useCustomURL
    }
    
    func validateURL() -> Bool {
        // Basic validation
        guard !host.isEmpty else { return false }
        guard port > 0 && port <= 65535 else { return false }
        
        // Check if host is valid IP or hostname
        let ipPattern = #"^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"#
        let hostnamePattern = #"^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$"#
        
        let isValidIP = host.range(of: ipPattern, options: .regularExpression) != nil
        let isValidHostname = host == "localhost" || host.range(of: hostnamePattern, options: .regularExpression) != nil
        
        return isValidIP || isValidHostname
    }
    
    /// Test connection to AI server
    func testConnection() async -> (success: Bool, error: String?) {
        let url = URL(string: apiHealthURL)!
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // Server is responding
                return (true, nil)
            } else {
                return (false, "Invalid response from server")
            }
        } catch {
            return (false, "Server not running. Run './launch_server.sh' in python-inference-server directory")
        }
    }
}

