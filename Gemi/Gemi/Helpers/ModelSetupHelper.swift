import Foundation
import AppKit

/// Helper for Gemma 3n model setup and debugging
struct ModelSetupHelper {
    
    /// Open Terminal with manual setup instructions
    static func openManualSetup() {
        let script = """
        tell application "Terminal"
            activate
            
            -- Create new window
            set newWindow to do script ""
            
            -- Set custom title
            tell first window
                set custom title to "Gemi - Gemma 3n Setup"
            end tell
            
            -- Clear and show instructions
            do script "clear" in newWindow
            do script "echo '=== Gemi - Gemma 3n Setup ==='" in newWindow
            do script "echo ''" in newWindow
            do script "echo '=== Two-Step Setup Process ==='" in newWindow
            do script "echo ''" in newWindow
            do script "echo 'STEP 1: HuggingFace Authentication (Required for Gemma 3n)'" in newWindow
            do script "echo '--------------------------------------------------------'" in newWindow
            do script "echo '1. Go to: https://huggingface.co/google/gemma-3n-e4b-it'" in newWindow
            do script "echo '2. Click \"Access repository\" and accept the terms'" in newWindow
            do script "echo '3. Get your token from: https://huggingface.co/settings/tokens'" in newWindow
            do script "echo '4. Run: huggingface-cli login'" in newWindow
            do script "echo '   (Enter your token when prompted)'" in newWindow
            do script "echo ''" in newWindow
            do script "echo 'STEP 2: Install UV & Launch Server'" in newWindow
            do script "echo '-----------------------------------'" in newWindow
            do script "echo '1. Install UV: curl -LsSf https://astral.sh/uv/install.sh | sh'" in newWindow
            do script "echo '2. Close and reopen Terminal after UV installs'" in newWindow
            do script "echo '3. Launch server: cd ~/Documents/project-Gemi/python-inference-server && ./launch_server.sh'" in newWindow
            do script "echo ''" in newWindow
            do script "echo 'Press ENTER to start the setup process...'" in newWindow
            do script "read -p ''" in newWindow
            
            -- First, check if UV is installed
            do script "if command -v uv &> /dev/null; then echo 'UV is already installed!'; else echo 'Installing UV...'; curl -LsSf https://astral.sh/uv/install.sh | sh; fi" in newWindow
        end tell
        """
        
        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                print("Failed to open Terminal: \(error)")
            }
        }
    }
    
    /// Check if python server directory exists
    static func checkServerDirectory() -> Bool {
        let path = NSHomeDirectory() + "/Documents/project-Gemi/python-inference-server"
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// Get helpful error message based on the issue
    static func getSetupErrorMessage(for error: Error) -> String {
        if !checkServerDirectory() {
            return """
            The Python server directory is missing.
            
            Please ensure you have the complete Gemi project with the python-inference-server folder.
            
            You can also set it up manually by clicking "Open Terminal" below.
            """
        }
        
        if let serverError = error as? ServerError {
            switch serverError {
            case .serverNotFound:
                return """
                GemiServer.app not found.
                
                Please reinstall Gemi from the DMG installer.
                
                The AI server should be installed alongside Gemi in your Applications folder.
                """
                
            case .launchFailed(let reason):
                return """
                Failed to launch the AI server: \(reason)
                
                Try restarting Gemi or check if port 11435 is in use.
                
                Click "Open Terminal" for troubleshooting.
                """
                
            case .connectionFailed(let reason):
                return """
                Cannot connect to the AI server: \(reason)
                
                The server may still be starting up. Please wait a moment and try again.
                
                Click "Open Terminal" to check server status.
                """
            }
        }
        
        return """
        An unexpected error occurred: \(error.localizedDescription)
        
        Click "Open Terminal" below for manual setup.
        """
    }
}