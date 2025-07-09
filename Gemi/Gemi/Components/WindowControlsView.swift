//
//  WindowControlsView.swift
//  Gemi
//
//  Custom window controls overlay for integrated design
//

import SwiftUI
import AppKit

struct WindowControlsView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        // We need to access the window's title bar buttons
        DispatchQueue.main.async {
            if let window = view.window {
                // Get the standard window button references
                let closeButton = window.standardWindowButton(.closeButton)
                let miniaturizeButton = window.standardWindowButton(.miniaturizeButton)
                let zoomButton = window.standardWindowButton(.zoomButton)
                
                // Move them to our custom location
                if let closeButton = closeButton,
                   let miniaturizeButton = miniaturizeButton,
                   let zoomButton = zoomButton {
                    
                    // Remove from their current superview
                    closeButton.removeFromSuperview()
                    miniaturizeButton.removeFromSuperview()
                    zoomButton.removeFromSuperview()
                    
                    // Add to our view
                    view.addSubview(closeButton)
                    view.addSubview(miniaturizeButton)
                    view.addSubview(zoomButton)
                    
                    // Position the buttons
                    closeButton.frame = NSRect(x: 8, y: 4, width: 14, height: 14)
                    miniaturizeButton.frame = NSRect(x: 28, y: 4, width: 14, height: 14)
                    zoomButton.frame = NSRect(x: 48, y: 4, width: 14, height: 14)
                }
            }
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// Alternative approach using a custom NSWindow
class UnifiedWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: backingStoreType,
            defer: flag
        )
        
        // Make the title bar transparent
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.standardWindowButton(.closeButton)?.superview?.superview?.alphaValue = 0
    }
}

// SwiftUI Window Customization View Modifier
struct UnifiedWindowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .ignoresSafeArea()
            .background(WindowAccessor { window in
                window?.titlebarAppearsTransparent = true
                window?.titleVisibility = .hidden
                window?.toolbar = nil
                window?.isMovableByWindowBackground = true
                window?.styleMask.insert(.fullSizeContentView)
                
                // Remove any title bar separator
                window?.titlebarSeparatorStyle = .none
                
                // Style the window buttons
                if let closeButton = window?.standardWindowButton(.closeButton),
                   let _ = window?.standardWindowButton(.miniaturizeButton),
                   let _ = window?.standardWindowButton(.zoomButton) {
                    
                    let buttonSuperview = closeButton.superview
                    
                    // Keep buttons in their default position but ensure they're above content
                    buttonSuperview?.wantsLayer = true
                    buttonSuperview?.layer?.zPosition = 999
                }
            })
    }
}

// Window Accessor to get NSWindow reference
struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            self.callback(nsView.window)
        }
    }
}

extension View {
    func unifiedWindowStyle() -> some View {
        modifier(UnifiedWindowStyle())
    }
}