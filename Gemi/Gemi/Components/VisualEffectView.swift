import SwiftUI
import AppKit

/// A SwiftUI wrapper for NSVisualEffectView to add macOS vibrancy and transparency effects
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let isEmphasized: Bool
    
    init(
        material: NSVisualEffectView.Material = .contentBackground,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        isEmphasized: Bool = false
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.isEmphasized = isEmphasized
    }
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = isEmphasized
        view.autoresizingMask = [.width, .height]
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.isEmphasized = isEmphasized
    }
}

/// Pre-configured visual effect styles for common use cases
extension VisualEffectView {
    /// Sidebar vibrancy effect
    static var sidebar: VisualEffectView {
        VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
    }
    
    /// Content background vibrancy
    static var contentBackground: VisualEffectView {
        VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
    }
    
    /// Header view vibrancy
    static var headerView: VisualEffectView {
        VisualEffectView(material: .headerView, blendingMode: .withinWindow)
    }
    
    /// Ultra thin material for overlays
    static var ultraThin: VisualEffectView {
        VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
    }
    
    /// Window background vibrancy
    static var windowBackground: VisualEffectView {
        VisualEffectView(material: .windowBackground, blendingMode: .behindWindow)
    }
    
    /// Emphasized sidebar for focused state
    static var emphasizedSidebar: VisualEffectView {
        VisualEffectView(material: .sidebar, blendingMode: .behindWindow, isEmphasized: true)
    }
}

/// View modifier for easy application of visual effects
struct VisualEffectModifier: ViewModifier {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let isEmphasized: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                VisualEffectView(
                    material: material,
                    blendingMode: blendingMode,
                    isEmphasized: isEmphasized
                )
                .ignoresSafeArea()
            )
    }
}

extension View {
    /// Apply visual effect background to any view
    func visualEffect(
        material: NSVisualEffectView.Material = .contentBackground,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        isEmphasized: Bool = false
    ) -> some View {
        modifier(VisualEffectModifier(
            material: material,
            blendingMode: blendingMode,
            isEmphasized: isEmphasized
        ))
    }
}