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
            do script "echo 'First, we need to install UV (Python package manager):'" in newWindow
            do script "echo ''" in newWindow
            do script "echo 'Step 1: Install UV by running this command:'" in newWindow
            do script "echo '   curl -LsSf https://astral.sh/uv/install.sh | sh'" in newWindow
            do script "echo ''" in newWindow
            do script "echo 'Step 2: After UV installs, close and reopen Terminal'" in newWindow
            do script "echo ''" in newWindow
            do script "echo 'Step 3: Then run these commands:'" in newWindow
            do script "echo '   cd ~/Documents/project-Gemi/python-inference-server'" in newWindow
            do script "echo '   ./launch_server.sh'" in newWindow
            do script "echo ''" in newWindow
            do script "echo 'Press ENTER to install UV now...'" in newWindow
            do script "read -p ''" in newWindow
            
            -- Install UV
            do script "curl -LsSf https://astral.sh/uv/install.sh | sh" in newWindow
            do script "echo ''" in newWindow
            do script "echo 'After UV finishes installing, please:'" in newWindow
            do script "echo '1. Close this Terminal window'" in newWindow
            do script "echo '2. Return to Gemi and click Retry Setup'" in newWindow
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
        
        if let pythonError = error as? PythonServerError {
            switch pythonError {
            case .serverNotFound:
                return """
                The inference server directory wasn't found.
                
                Make sure the python-inference-server folder exists in your project directory.
                
                Click "Open Terminal" below for manual setup.
                """
                
            case .launchScriptNotFound:
                return """
                The launch script is missing.
                
                The file 'launch_server.sh' should be in the python-inference-server directory.
                
                Click "Open Terminal" below for manual setup.
                """
                
            case .failedToLaunch(let reason):
                return """
                Failed to launch the server: \(reason)
                
                This might be a permission issue. Try running the setup manually.
                
                Click "Open Terminal" below for manual setup.
                """
                
            case .startupTimeout:
                return """
                The server is taking longer than expected to start.
                
                This usually means the model is still downloading. The download can take 10-20 minutes depending on your internet speed.
                
                Click "Open Terminal" to check the download progress.
                """
            }
        }
        
        return """
        An unexpected error occurred: \(error.localizedDescription)
        
        Click "Open Terminal" below for manual setup.
        """
    }
}