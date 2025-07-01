//
//  WindowStateManager.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI
import AppKit

/// Manages window state restoration and behavior for a premium Mac app experience
@Observable
final class WindowStateManager {
    
    // MARK: - Properties
    
    /// Window frame for state restoration
    private(set) var windowFrame: CGRect = CGRect(x: 100, y: 100, width: 1200, height: 800)
    
    /// Tracks if window is in full screen mode
    private(set) var isFullScreen = false
    
    /// Minimum window size for content
    let minWindowSize = CGSize(width: 1000, height: 600)
    
    /// Ideal window size
    let idealWindowSize = CGSize(width: 1200, height: 800)
    
    /// User defaults key for window state
    private let windowStateKey = "GemiWindowState"
    
    // MARK: - Initialization
    
    init() {
        restoreWindowState()
    }
    
    // MARK: - Window State Management
    
    /// Saves the current window state to UserDefaults
    func saveWindowState(frame: CGRect? = nil) {
        if let frame = frame {
            windowFrame = frame
        }
        
        let state = WindowState(
            frame: windowFrame,
            isFullScreen: isFullScreen
        )
        
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: windowStateKey)
        }
    }
    
    /// Restores window state from UserDefaults
    private func restoreWindowState() {
        guard let data = UserDefaults.standard.data(forKey: windowStateKey),
              let state = try? JSONDecoder().decode(WindowState.self, from: data) else {
            // Use default window position
            centerWindowOnScreen()
            return
        }
        
        windowFrame = state.frame
        isFullScreen = state.isFullScreen
    }
    
    /// Centers the window on the main screen
    private func centerWindowOnScreen() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - idealWindowSize.width / 2
        let y = screenFrame.midY - idealWindowSize.height / 2
        
        windowFrame = CGRect(
            x: x,
            y: y,
            width: idealWindowSize.width,
            height: idealWindowSize.height
        )
    }
    
    /// Updates full screen state
    func setFullScreen(_ fullScreen: Bool) {
        isFullScreen = fullScreen
        saveWindowState()
    }
}

// MARK: - Window State Model

private struct WindowState: Codable {
    let frame: CGRect
    let isFullScreen: Bool
}

// MARK: - Window Style Modifier

struct PremiumWindowStyle: ViewModifier {
    let minWidth: CGFloat
    let minHeight: CGFloat
    
    init(minWidth: CGFloat = 1000, minHeight: CGFloat = 600) {
        self.minWidth = minWidth
        self.minHeight = minHeight
    }
    
    func body(content: Content) -> some View {
        content
            .frame(
                minWidth: minWidth,
                minHeight: minHeight
            )
            .background(WindowAccessor())
    }
}

// MARK: - Window Accessor

private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configureWindow(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            configureWindow(window)
        }
    }
    
    private func configureWindow(_ window: NSWindow) {
        // Premium window appearance
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        
        // Smooth resizing
        window.animationBehavior = .documentWindow
        
        // Traffic light button positioning
        window.standardWindowButton(.closeButton)?.setFrameOrigin(NSPoint(x: 20, y: 24))
        window.standardWindowButton(.miniaturizeButton)?.setFrameOrigin(NSPoint(x: 40, y: 24))
        window.standardWindowButton(.zoomButton)?.setFrameOrigin(NSPoint(x: 60, y: 24))
        
        // Enable full screen
        window.collectionBehavior = [.fullScreenPrimary, .managed]
        
        // Smooth animations
        window.hasShadow = true
        window.backgroundColor = .clear
        window.isOpaque = false
    }
}

// MARK: - View Extension

extension View {
    func premiumWindowStyle(minWidth: CGFloat = 1000, minHeight: CGFloat = 600) -> some View {
        self.modifier(PremiumWindowStyle(minWidth: minWidth, minHeight: minHeight))
    }
}