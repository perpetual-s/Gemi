import AVFoundation
import SwiftUI

/// Manages ambient sound playback for Focus Mode
@MainActor
final class AmbientSoundPlayer {
    static let shared = AmbientSoundPlayer()
    
    private var audioPlayer: AVAudioPlayer?
    private var currentSound: FocusModeView.AmbientSound = .none
    private var whiteNoiseGenerator: WhiteNoiseGenerator?
    
    private init() {
        // No audio session setup needed on macOS
    }
    
    func play(sound: FocusModeView.AmbientSound) {
        guard sound != .none else {
            stop()
            return
        }
        
        // If already playing the same sound, don't restart
        if currentSound == sound && audioPlayer?.isPlaying == true {
            return
        }
        
        currentSound = sound
        
        // For now, we'll use system sounds as placeholders
        // In a production app, you'd include actual ambient sound files
        let soundFile = getSoundFile(for: sound)
        
        guard let url = Bundle.main.url(forResource: soundFile, withExtension: "m4a") else {
            // Fallback to system sound if custom file not found
            playSystemSound(for: sound)
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.3 // Ambient volume
            audioPlayer?.prepareToPlay()
            
            // Fade in
            audioPlayer?.volume = 0
            audioPlayer?.play()
            audioPlayer?.setVolume(0.3, fadeDuration: 2.0)
        } catch {
            print("Failed to play ambient sound: \(error)")
            playSystemSound(for: sound)
        }
    }
    
    func stop() {
        // Stop white noise generator if active
        whiteNoiseGenerator?.stop()
        whiteNoiseGenerator = nil
        
        // Stop audio player if active
        if let player = audioPlayer {
            // Fade out
            player.setVolume(0, fadeDuration: 1.0)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.audioPlayer?.stop()
                self?.audioPlayer = nil
                self?.currentSound = .none
            }
        } else {
            currentSound = .none
        }
    }
    
    private func getSoundFile(for sound: FocusModeView.AmbientSound) -> String {
        switch sound {
        case .rain: return "rain-ambient"
        case .coffeeshop: return "coffeeshop-ambient"
        case .ocean: return "ocean-ambient"
        case .forest: return "forest-ambient"
        case .fireplace: return "fireplace-ambient"
        case .none: return ""
        }
    }
    
    // Fallback: Create ambient sounds using system capabilities
    private func playSystemSound(for sound: FocusModeView.AmbientSound) {
        // For demo purposes, we'll create simple ambient effects
        // In production, you'd want actual recorded ambient sounds
        
        switch sound {
        case .rain:
            createWhiteNoise(frequency: 8000, volume: 0.15)
        case .ocean:
            createWhiteNoise(frequency: 4000, volume: 0.2)
        case .forest:
            createWhiteNoise(frequency: 2000, volume: 0.1)
        case .coffeeshop:
            createWhiteNoise(frequency: 6000, volume: 0.12)
        case .fireplace:
            createWhiteNoise(frequency: 1000, volume: 0.18)
        case .none:
            break
        }
    }
    
    private func createWhiteNoise(frequency: Float, volume: Float) {
        // Stop any existing generator
        whiteNoiseGenerator?.stop()
        
        // Create and start new generator
        whiteNoiseGenerator = WhiteNoiseGenerator()
        whiteNoiseGenerator?.start(frequency: frequency, volume: volume)
    }
}

// MARK: - Placeholder White Noise Generator
// This is a simplified implementation for demonstration
// In production, use actual ambient sound recordings

@MainActor
private class WhiteNoiseGenerator {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var mixerNode: AVAudioMixerNode?
    
    func start(frequency: Float, volume: Float) {
        // Create audio engine and nodes
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        mixerNode = AVAudioMixerNode()
        
        guard let engine = audioEngine,
              let player = playerNode,
              let mixer = mixerNode else { return }
        
        // Attach nodes
        engine.attach(player)
        engine.attach(mixer)
        
        // Get the audio format
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = Float(outputFormat.sampleRate)
        
        // Create a format that's compatible
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: outputFormat.channelCount) else { return }
        
        // Connect nodes
        engine.connect(player, to: mixer, format: format)
        engine.connect(mixer, to: engine.mainMixerNode, format: format)
        
        // Set mixer volume
        mixer.outputVolume = volume * 0.3 // Scale down for ambient volume
        
        do {
            // Start the engine
            try engine.start()
            
            // Generate white noise buffer
            let bufferSize = AVAudioFrameCount(sampleRate * 0.1) // 100ms buffer
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize) else { return }
            buffer.frameLength = bufferSize
            
            // Access the buffer's audio data
            guard let channelData = buffer.floatChannelData else { return }
            
            // Fill buffer with filtered noise based on frequency parameter
            let cutoff = frequency / sampleRate
            for channel in 0..<Int(format.channelCount) {
                for frame in 0..<Int(bufferSize) {
                    // Simple low-pass filtered noise
                    var sample = Float.random(in: -1...1)
                    sample *= cutoff // Simple frequency shaping
                    channelData[channel][frame] = sample * 0.2 // Scale for comfortable volume
                }
            }
            
            // Schedule buffer to loop
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func stop() {
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        mixerNode = nil
    }
}