import Foundation
import AppKit

/// Manages Python environment setup for Gemma 3n
@MainActor
class PythonEnvironmentSetup: ObservableObject {
    @Published var currentStep: SetupStep = .checkingEnvironment
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = "Initializing..."
    @Published var isComplete: Bool = false
    @Published var error: SetupError?
    
    enum SetupStep: String, CaseIterable {
        case checkingEnvironment = "Checking Environment"
        case installingConda = "Installing Conda"
        case creatingEnvironment = "Creating Environment"
        case installingDependencies = "Installing Dependencies"
        case downloadingModel = "Downloading Model"
        case creatingServer = "Creating Server"
        case launchingServer = "Launching Server"
        case complete = "Complete"
        
        var description: String {
            switch self {
            case .checkingEnvironment:
                return "Checking for Python and Conda installation..."
            case .installingConda:
                return "Installing Miniconda for Python environment management..."
            case .creatingEnvironment:
                return "Creating isolated Python environment for Gemi..."
            case .installingDependencies:
                return "Installing PyTorch, Transformers, and other dependencies..."
            case .downloadingModel:
                return "Downloading Gemma 3n model from HuggingFace..."
            case .creatingServer:
                return "Setting up inference server..."
            case .launchingServer:
                return "Starting the AI server..."
            case .complete:
                return "Setup complete! Gemma 3n is ready."
            }
        }
        
        var icon: String {
            switch self {
            case .checkingEnvironment: return "magnifyingglass"
            case .installingConda: return "square.and.arrow.down"
            case .creatingEnvironment: return "folder.badge.plus"
            case .installingDependencies: return "puzzlepiece.extension"
            case .downloadingModel: return "icloud.and.arrow.down"
            case .creatingServer: return "server.rack"
            case .launchingServer: return "play.circle"
            case .complete: return "checkmark.circle.fill"
            }
        }
    }
    
    enum SetupError: LocalizedError {
        case pythonNotFound
        case condaInstallFailed
        case environmentCreationFailed
        case dependencyInstallFailed
        case modelDownloadFailed
        case serverCreationFailed
        case launchFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .pythonNotFound:
                return "Python is not installed on your system"
            case .condaInstallFailed:
                return "Failed to install Conda"
            case .environmentCreationFailed:
                return "Failed to create Python environment"
            case .dependencyInstallFailed:
                return "Failed to install required packages"
            case .modelDownloadFailed:
                return "Failed to download Gemma 3n model"
            case .serverCreationFailed:
                return "Failed to create inference server"
            case .launchFailed(let reason):
                return "Failed to launch server: \(reason)"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .pythonNotFound:
                return "Please install Python 3.9 or later from python.org"
            case .condaInstallFailed:
                return "Try installing Miniconda manually from conda.io/miniconda"
            case .environmentCreationFailed:
                return "Check disk space and permissions"
            case .dependencyInstallFailed:
                return "Check internet connection and try again"
            case .modelDownloadFailed:
                return "Ensure you have ~20GB free disk space and stable internet"
            case .serverCreationFailed:
                return "Check file permissions in the project directory"
            case .launchFailed:
                return "Check Terminal output for detailed error messages"
            }
        }
    }
    
    private let projectPath = NSHomeDirectory() + "/Documents/project-Gemi"
    private let serverPath = NSHomeDirectory() + "/Documents/project-Gemi/python-inference-server"
    private var currentProcess: Process?
    private var downloadTask: URLSessionDownloadTask?
    
    func startSetup() {
        Task {
            await performSetup()
        }
    }
    
    private func performSetup() async {
        do {
            // Step 1: Check environment
            try await checkEnvironment()
            
            // Step 2: Install Conda if needed
            if !isCondaInstalled() {
                try await installConda()
            }
            
            // Step 3: Create conda environment
            try await createCondaEnvironment()
            
            // Step 4: Install dependencies
            try await installDependencies()
            
            // Step 5: Create server files
            try await createServerFiles()
            
            // Step 6: Download model (this happens on first server launch)
            currentStep = .downloadingModel
            statusMessage = "Model will download on first launch..."
            progress = 0.8
            
            // Step 7: Launch server
            try await launchServer()
            
            // Complete
            currentStep = .complete
            statusMessage = "Setup complete!"
            progress = 1.0
            isComplete = true
            
        } catch let setupError as SetupError {
            self.error = setupError
            statusMessage = setupError.localizedDescription
        } catch {
            self.error = .launchFailed(error.localizedDescription)
            statusMessage = error.localizedDescription
        }
    }
    
    private func checkEnvironment() async throws {
        currentStep = .checkingEnvironment
        statusMessage = "Checking Python installation..."
        progress = 0.05
        
        // Check if Python is installed
        let pythonCheck = Process()
        pythonCheck.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        pythonCheck.arguments = ["python3", "--version"]
        
        do {
            try pythonCheck.run()
            pythonCheck.waitUntilExit()
            
            if pythonCheck.terminationStatus != 0 {
                throw SetupError.pythonNotFound
            }
        } catch {
            throw SetupError.pythonNotFound
        }
        
        progress = 0.1
    }
    
    private func isCondaInstalled() -> Bool {
        let condaPaths = [
            NSHomeDirectory() + "/miniconda3/bin/conda",
            "/opt/miniconda3/bin/conda",
            "/usr/local/miniconda3/bin/conda",
            "/opt/homebrew/Caskroom/miniconda/base/bin/conda"
        ]
        
        for path in condaPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        return false
    }
    
    private func installConda() async throws {
        currentStep = .installingConda
        statusMessage = "Downloading Miniconda installer..."
        progress = 0.15
        
        // Download Miniconda installer
        let installerURL: URL
        #if arch(arm64)
        installerURL = URL(string: "https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh")!
        #else
        installerURL = URL(string: "https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh")!
        #endif
        
        let installerPath = NSTemporaryDirectory() + "miniconda_installer.sh"
        
        // Download installer
        let (downloadURL, _) = try await URLSession.shared.download(from: installerURL)
        try FileManager.default.moveItem(at: downloadURL, to: URL(fileURLWithPath: installerPath))
        
        progress = 0.25
        statusMessage = "Installing Miniconda..."
        
        // Run installer
        let installProcess = Process()
        installProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        installProcess.arguments = [installerPath, "-b", "-p", NSHomeDirectory() + "/miniconda3"]
        
        try installProcess.run()
        installProcess.waitUntilExit()
        
        if installProcess.terminationStatus != 0 {
            throw SetupError.condaInstallFailed
        }
        
        // Clean up
        try? FileManager.default.removeItem(atPath: installerPath)
        
        progress = 0.3
    }
    
    private func createCondaEnvironment() async throws {
        currentStep = .creatingEnvironment
        statusMessage = "Creating Gemi Python environment..."
        progress = 0.35
        
        // Find conda executable
        let condaPath = findCondaPath()
        guard let condaPath = condaPath else {
            throw SetupError.environmentCreationFailed
        }
        
        // Create environment with Python 3.11
        let createEnvProcess = Process()
        createEnvProcess.executableURL = URL(fileURLWithPath: condaPath)
        createEnvProcess.arguments = ["create", "-n", "gemi", "python=3.11", "-y"]
        
        try createEnvProcess.run()
        createEnvProcess.waitUntilExit()
        
        if createEnvProcess.terminationStatus != 0 {
            throw SetupError.environmentCreationFailed
        }
        
        progress = 0.4
    }
    
    private func installDependencies() async throws {
        currentStep = .installingDependencies
        statusMessage = "Installing PyTorch and dependencies..."
        progress = 0.45
        
        let condaPath = findCondaPath()!
        let condaDir = URL(fileURLWithPath: condaPath).deletingLastPathComponent().deletingLastPathComponent()
        let pipPath = condaDir.appendingPathComponent("envs/gemi/bin/pip").path
        
        // Install packages
        let packages = [
            "torch",
            "torchvision",
            "transformers>=4.53.0",
            "accelerate",
            "fastapi",
            "uvicorn",
            "pillow",
            "soundfile",
            "librosa",
            "python-multipart",
            "sse-starlette"
        ]
        
        for (index, package) in packages.enumerated() {
            statusMessage = "Installing \(package)..."
            progress = 0.45 + (0.25 * Double(index) / Double(packages.count))
            
            let installProcess = Process()
            installProcess.executableURL = URL(fileURLWithPath: pipPath)
            installProcess.arguments = ["install", package]
            
            try installProcess.run()
            installProcess.waitUntilExit()
            
            if installProcess.terminationStatus != 0 {
                throw SetupError.dependencyInstallFailed
            }
        }
        
        progress = 0.7
    }
    
    private func createServerFiles() async throws {
        currentStep = .creatingServer
        statusMessage = "Creating inference server..."
        progress = 0.75
        
        // Create server directory
        try FileManager.default.createDirectory(
            atPath: serverPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Create inference server Python file
        let serverCode = generateServerCode()
        try serverCode.write(
            to: URL(fileURLWithPath: serverPath + "/inference_server.py"),
            atomically: true,
            encoding: .utf8
        )
        
        // Create launch script
        let launchScript = generateLaunchScript()
        try launchScript.write(
            to: URL(fileURLWithPath: serverPath + "/launch_server.sh"),
            atomically: true,
            encoding: .utf8
        )
        
        // Make launch script executable
        let chmodProcess = Process()
        chmodProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProcess.arguments = ["+x", serverPath + "/launch_server.sh"]
        try chmodProcess.run()
        chmodProcess.waitUntilExit()
        
        progress = 0.8
    }
    
    private func launchServer() async throws {
        currentStep = .launchingServer
        statusMessage = "Starting Gemma 3n server..."
        progress = 0.85
        
        // Launch server in Terminal
        let script = """
        tell application "Terminal"
            activate
            set newWindow to do script "cd '\(serverPath)' && ./launch_server.sh"
            set custom title of first window to "Gemi AI Server"
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                throw SetupError.launchFailed(error.description)
            }
        }
        
        // Wait for server to start
        statusMessage = "Waiting for server to initialize..."
        
        var attempts = 0
        while attempts < 30 {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            if await checkServerHealth() {
                progress = 1.0
                return
            }
            
            attempts += 1
            progress = 0.85 + (0.15 * Double(attempts) / 30.0)
        }
        
        throw SetupError.launchFailed("Server startup timeout")
    }
    
    private func checkServerHealth() async -> Bool {
        do {
            let healthURL = URL(string: "http://127.0.0.1:11435/api/health")!
            let (_, response) = try await URLSession.shared.data(from: healthURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            // Server not ready yet
        }
        
        return false
    }
    
    private func findCondaPath() -> String? {
        let condaPaths = [
            NSHomeDirectory() + "/miniconda3/bin/conda",
            "/opt/miniconda3/bin/conda",
            "/usr/local/miniconda3/bin/conda",
            "/opt/homebrew/Caskroom/miniconda/base/bin/conda"
        ]
        
        for path in condaPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
    
    private func generateServerCode() -> String {
        return """
        import torch
        from transformers import AutoProcessor, AutoModelForConditionalGeneration
        from fastapi import FastAPI, HTTPException
        from fastapi.responses import StreamingResponse, JSONResponse
        from pydantic import BaseModel
        import base64
        import io
        from PIL import Image
        import asyncio
        import json
        from typing import List, Optional
        import logging
        import os
        
        # Configure logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('gemi_inference_server.log'),
                logging.StreamHandler()
            ]
        )
        logger = logging.getLogger(__name__)
        
        # Initialize FastAPI app
        app = FastAPI(title="Gemi Inference Server", version="1.0.0")
        
        # Global model variables
        model = None
        processor = None
        device = None
        download_progress = 0.0
        
        class ChatMessage(BaseModel):
            role: str
            content: str
            images: Optional[List[str]] = None
        
        class ChatRequest(BaseModel):
            model: str
            messages: List[ChatMessage]
            stream: bool = True
        
        def load_model():
            \"\"\"Load Gemma 3n model with MPS support\"\"\"
            global model, processor, device, download_progress
            
            # Check for MPS availability
            if torch.backends.mps.is_available():
                device = torch.device("mps")
                logger.info("Using MPS (Metal Performance Shaders) for acceleration")
            else:
                device = torch.device("cpu")
                logger.info("MPS not available, using CPU")
            
            # Load the model
            logger.info("Loading gemma-3n-E4B-it model...")
            download_progress = 0.1
            
            try:
                model_id = "google/gemma-3n-e4b-it"
                
                # Load processor
                processor = AutoProcessor.from_pretrained(model_id)
                download_progress = 0.3
                
                # Load model
                model = AutoModelForConditionalGeneration.from_pretrained(
                    model_id,
                    device_map="auto",
                    torch_dtype=torch.bfloat16 if device.type == "mps" else torch.float32,
                )
                model.eval()
                download_progress = 1.0
                
                logger.info("Model loaded successfully!")
            except Exception as e:
                logger.error(f"Failed to load model: {e}")
                download_progress = 0.0
                raise
        
        @app.on_event("startup")
        async def startup_event():
            \"\"\"Load model on server startup\"\"\"
            try:
                load_model()
            except Exception as e:
                logger.error(f"Startup failed: {e}")
        
        @app.get("/api/health")
        async def health_check():
            \"\"\"Health check endpoint\"\"\"
            return {
                "status": "healthy" if model is not None else "loading",
                "model_loaded": model is not None,
                "device": str(device) if device else "unknown",
                "mps_available": torch.backends.mps.is_available(),
                "download_progress": download_progress
            }
        
        @app.post("/api/chat")
        async def chat(request: ChatRequest):
            \"\"\"Chat endpoint with streaming support\"\"\"
            if model is None:
                raise HTTPException(status_code=503, detail="Model not loaded")
            
            # Extract the last user message and images
            user_message = None
            images = []
            
            for msg in request.messages:
                if msg.role == "user":
                    user_message = msg.content
                    if msg.images:
                        # Decode base64 images
                        for img_base64 in msg.images:
                            img_data = base64.b64decode(img_base64)
                            img = Image.open(io.BytesIO(img_data))
                            images.append(img)
            
            if not user_message:
                raise HTTPException(status_code=400, detail="No user message found")
            
            # Prepare inputs
            inputs = processor(
                text=user_message,
                images=images if images else None,
                return_tensors="pt"
            ).to(device)
            
            # Generate response
            with torch.no_grad():
                outputs = model.generate(
                    **inputs,
                    max_new_tokens=1024,
                    temperature=0.7,
                    do_sample=True
                )
            
            generated_text = processor.decode(outputs[0], skip_special_tokens=True)
            
            if request.stream:
                return StreamingResponse(
                    generate_stream(generated_text, request.model),
                    media_type="text/event-stream"
                )
            else:
                return {
                    "model": request.model,
                    "message": {
                        "role": "assistant",
                        "content": generated_text
                    },
                    "done": True
                }
        
        async def generate_stream(text: str, model_name: str):
            \"\"\"Generate streaming response\"\"\"
            # Simulate streaming by chunking the response
            chunk_size = 10  # characters per chunk
            for i in range(0, len(text), chunk_size):
                chunk = text[i:i + chunk_size]
                response = {
                    "model": model_name,
                    "message": {
                        "role": "assistant",
                        "content": chunk
                    },
                    "done": i + chunk_size >= len(text)
                }
                yield f"data: {json.dumps(response)}\\n\\n"
                await asyncio.sleep(0.01)  # Small delay for streaming effect
        
        @app.get("/api/tags")
        async def list_models():
            \"\"\"List available models (Ollama compatibility)\"\"\"
            return {
                "models": [
                    {
                        "name": "gemma-3n-e4b-it",
                        "modified_at": "2025-07-11T00:00:00Z",
                        "size": 8000000000,  # 8B parameters
                        "digest": "gemma3n-multimodal"
                    }
                ]
            }
        
        if __name__ == "__main__":
            import uvicorn
            uvicorn.run(app, host="127.0.0.1", port=11435)
        """
    }
    
    private func generateLaunchScript() -> String {
        let condaPath = findCondaPath() ?? "~/miniconda3/bin/conda"
        let condaDir = URL(fileURLWithPath: condaPath).deletingLastPathComponent().deletingLastPathComponent().path
        
        return """
        #!/bin/bash
        
        # Gemi Inference Server Launch Script
        
        echo "=== Gemi AI Server ==="
        echo "Starting Gemma 3n inference server..."
        echo ""
        
        # Activate conda environment
        source "\(condaDir)/etc/profile.d/conda.sh"
        conda activate gemi
        
        # Set environment variables
        export PYTORCH_ENABLE_MPS_FALLBACK=1
        export TOKENIZERS_PARALLELISM=false
        export HF_HOME=~/.cache/huggingface
        
        # Check if model is already downloaded
        if [ -d "$HF_HOME/hub/models--google--gemma-3n-e4b-it" ]; then
            echo "Model already downloaded, starting server..."
        else
            echo "First time setup - downloading Gemma 3n model (~8GB)"
            echo "This is a one-time download that may take 10-20 minutes..."
            echo ""
        fi
        
        # Run the server
        python inference_server.py
        """
    }
}