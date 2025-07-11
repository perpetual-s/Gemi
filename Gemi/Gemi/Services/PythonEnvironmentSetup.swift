import Foundation
import AppKit

/// Manages Python environment setup for Gemma 3n using UV
@MainActor
class PythonEnvironmentSetup: ObservableObject {
    @Published var currentStep: SetupStep = .checkingEnvironment
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = "Initializing..."
    @Published var isComplete: Bool = false
    @Published var error: SetupError?
    
    enum SetupStep: String, CaseIterable {
        case checkingEnvironment = "Checking Environment"
        case installingUV = "Installing UV"
        case creatingProject = "Creating Project"
        case installingDependencies = "Installing Dependencies"
        case creatingServer = "Creating Server"
        case launchingServer = "Launching Server"
        case downloadingModel = "Downloading Model"
        case complete = "Complete"
        
        var description: String {
            switch self {
            case .checkingEnvironment:
                return "Checking for UV installation..."
            case .installingUV:
                return "Installing UV package manager..."
            case .creatingProject:
                return "Setting up Python project with UV..."
            case .installingDependencies:
                return "Installing PyTorch, Transformers, and dependencies..."
            case .creatingServer:
                return "Creating inference server files..."
            case .launchingServer:
                return "Starting the AI server..."
            case .downloadingModel:
                return "Downloading Gemma 3n model from HuggingFace..."
            case .complete:
                return "Setup complete! Gemma 3n is ready."
            }
        }
        
        var icon: String {
            switch self {
            case .checkingEnvironment: return "magnifyingglass"
            case .installingUV: return "bolt.fill"
            case .creatingProject: return "folder.badge.plus"
            case .installingDependencies: return "puzzlepiece.extension"
            case .creatingServer: return "server.rack"
            case .launchingServer: return "play.circle"
            case .downloadingModel: return "icloud.and.arrow.down"
            case .complete: return "checkmark.circle.fill"
            }
        }
    }
    
    enum SetupError: LocalizedError {
        case uvInstallFailed
        case projectCreationFailed
        case dependencyInstallFailed
        case serverCreationFailed
        case launchFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .uvInstallFailed:
                return "Failed to install UV package manager"
            case .projectCreationFailed:
                return "Failed to create UV project"
            case .dependencyInstallFailed:
                return "Failed to install required packages"
            case .serverCreationFailed:
                return "Failed to create inference server"
            case .launchFailed(let reason):
                return "Failed to launch server: \(reason)"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .uvInstallFailed:
                return "Try installing UV manually: curl -LsSf https://astral.sh/uv/install.sh | sh"
            case .projectCreationFailed:
                return "Check disk space and permissions in the project directory"
            case .dependencyInstallFailed:
                return "Check internet connection and try: uv sync --refresh"
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
            // Step 1: Check if UV is installed
            try await checkEnvironment()
            
            // Step 2: Install UV if needed
            if !isUVInstalled() {
                try await installUV()
            }
            
            // Step 3: Create project with pyproject.toml
            try await createUVProject()
            
            // Step 4: Install dependencies with UV
            try await installDependencies()
            
            // Step 5: Create server files
            try await createServerFiles()
            
            // Step 6: Launch server
            try await launchServer()
            
            // Step 7: Model downloads on first run
            currentStep = .downloadingModel
            statusMessage = "Gemma 3n model downloading (one-time)..."
            progress = 0.9
            
            // Wait a bit for model to start downloading
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            
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
        statusMessage = "Checking for UV installation..."
        progress = 0.05
        
        // UV handles Python automatically, so we just check for UV
        progress = 0.1
    }
    
    private func isUVInstalled() -> Bool {
        let uvPaths = [
            "/usr/local/bin/uv",
            "/opt/homebrew/bin/uv",
            NSHomeDirectory() + "/.cargo/bin/uv",
            NSHomeDirectory() + "/.local/bin/uv",
            "/usr/bin/uv"
        ]
        
        for path in uvPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        return false
    }
    
    private func installUV() async throws {
        currentStep = .installingUV
        statusMessage = "Installing UV package manager..."
        progress = 0.15
        
        // Install UV using the official installer script
        let script = """
        #!/bin/bash
        curl -LsSf https://astral.sh/uv/install.sh | sh
        """
        
        let scriptPath = NSTemporaryDirectory() + "install_uv.sh"
        try script.write(to: URL(fileURLWithPath: scriptPath), atomically: true, encoding: .utf8)
        
        // Make script executable
        let chmodProcess = Process()
        chmodProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProcess.arguments = ["+x", scriptPath]
        try chmodProcess.run()
        chmodProcess.waitUntilExit()
        
        // Run installer
        let installProcess = Process()
        installProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        installProcess.arguments = [scriptPath]
        
        try installProcess.run()
        installProcess.waitUntilExit()
        
        if installProcess.terminationStatus != 0 {
            throw SetupError.uvInstallFailed
        }
        
        // Clean up
        try? FileManager.default.removeItem(atPath: scriptPath)
        
        // Wait a moment for UV to be fully installed
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        progress = 0.2
        statusMessage = "UV installed successfully!"
    }
    
    private func createUVProject() async throws {
        currentStep = .creatingProject
        statusMessage = "Setting up Python project..."
        progress = 0.25
        
        // Create server directory if it doesn't exist
        try FileManager.default.createDirectory(
            atPath: serverPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Create pyproject.toml
        let pyprojectContent = """
        [project]
        name = "gemi-inference-server"
        version = "1.0.0"
        requires-python = ">=3.11"
        dependencies = [
            "torch>=2.0.0",
            "torchvision",
            "torchaudio",
            "transformers>=4.53.0",
            "accelerate",
            "fastapi",
            "uvicorn",
            "pillow",
            "soundfile",
            "librosa",
            "python-multipart",
            "sse-starlette",
        ]
        
        [tool.uv]
        dev-dependencies = []
        """
        
        let pyprojectPath = serverPath + "/pyproject.toml"
        try pyprojectContent.write(
            to: URL(fileURLWithPath: pyprojectPath),
            atomically: true,
            encoding: .utf8
        )
        
        progress = 0.3
        statusMessage = "Project created successfully!"
    }
    
    private func installDependencies() async throws {
        currentStep = .installingDependencies
        statusMessage = "Installing PyTorch and dependencies..."
        progress = 0.35
        
        // Find UV path - check if it exists first
        guard let uvPath = findUVPath() else {
            throw SetupError.uvInstallFailed
        }
        
        // Verify UV executable exists
        guard FileManager.default.fileExists(atPath: uvPath) else {
            throw SetupError.uvInstallFailed
        }
        
        // Change to server directory
        let syncProcess = Process()
        syncProcess.executableURL = URL(fileURLWithPath: uvPath)
        syncProcess.arguments = ["sync"]
        syncProcess.currentDirectoryURL = URL(fileURLWithPath: serverPath)
        
        statusMessage = "Installing all dependencies (this is fast with UV!)..."
        
        try syncProcess.run()
        syncProcess.waitUntilExit()
        
        if syncProcess.terminationStatus != 0 {
            throw SetupError.dependencyInstallFailed
        }
        
        progress = 0.6
        statusMessage = "Dependencies installed successfully!"
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
            to: URL(fileURLWithPath: serverPath + "/simple_server.py"),
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
    
    private func findUVPath() -> String? {
        let uvPaths = [
            NSHomeDirectory() + "/.local/bin/uv", // UV installer default location
            "/usr/local/bin/uv",
            "/opt/homebrew/bin/uv",
            NSHomeDirectory() + "/.cargo/bin/uv",
            "/usr/bin/uv"
        ]
        
        for path in uvPaths {
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
        let uvPath = findUVPath() ?? NSHomeDirectory() + "/.local/bin/uv"
        
        return """
        #!/bin/bash
        # Gemi Inference Server Launch Script - UV Edition
        
        set -e  # Exit on error
        
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        
        echo "🚀 Gemi AI Server (UV Edition)"
        echo "=============================="
        echo ""
        
        # Add UV to PATH in case it's not there
        export PATH="$HOME/.local/bin:$PATH"
        
        # Set environment variables
        export PYTORCH_ENABLE_MPS_FALLBACK=1
        export TOKENIZERS_PARALLELISM=false
        export HF_HOME=~/.cache/huggingface
        export HF_HUB_DISABLE_SYMLINKS_WARNING=1
        
        # Check if UV exists
        if ! command -v uv &> /dev/null && ! [ -f "\(uvPath)" ]; then
            echo "❌ UV not found!"
            echo "Please install UV first:"
            echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
            exit 1
        fi
        
        # Use UV command or explicit path
        if command -v uv &> /dev/null; then
            UV_CMD="uv"
        else
            UV_CMD="\(uvPath)"
        fi
        
        # Sync dependencies with UV (ultra-fast!)
        echo "📦 Syncing dependencies with UV..."
        cd "$SCRIPT_DIR"
        $UV_CMD sync
        echo "✓ Dependencies ready!"
        
        # Check if model is already downloaded
        if [ -d "$HF_HOME/hub/models--google--gemma-3n-e4b-it" ]; then
            echo "✓ Model already cached locally"
        else
            echo "⚠️  First run will download Gemma 3n model (~8GB)"
            echo "   This is a one-time download (10-30 minutes)"
            echo ""
        fi
        
        # Launch server
        echo "Starting server at http://127.0.0.1:11435"
        echo "Press Ctrl+C to stop"
        echo ""
        
        # Run with UV - no activation needed!
        $UV_CMD run python simple_server.py
        """
    }
}