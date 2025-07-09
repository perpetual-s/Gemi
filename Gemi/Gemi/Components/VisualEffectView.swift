import SwiftUI
import AppKit

/// Advanced SwiftUI wrapper for NSVisualEffectView with dynamic material switching and enhanced effects
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let isEmphasized: Bool
    let vibrancy: Double
    let maskImage: NSImage?
    let appearance: NSAppearance?
    
    init(
        material: NSVisualEffectView.Material = .contentBackground,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        isEmphasized: Bool = false,
        vibrancy: Double = 1.0,
        maskImage: NSImage? = nil,
        appearance: NSAppearance? = nil
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.isEmphasized = isEmphasized
        self.vibrancy = vibrancy
        self.maskImage = maskImage
        self.appearance = appearance
    }
    
    func makeNSView(context: Context) -> EnhancedVisualEffectView {
        let view = EnhancedVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = isEmphasized
        view.autoresizingMask = [.width, .height]
        view.vibrancy = vibrancy
        
        if let appearance = appearance {
            view.appearance = appearance
        }
        
        if let maskImage = maskImage {
            view.maskImage = maskImage
        }
        
        return view
    }
    
    func updateNSView(_ nsView: EnhancedVisualEffectView, context: Context) {
        nsView.animateChanges {
            nsView.material = material
            nsView.blendingMode = blendingMode
            nsView.isEmphasized = isEmphasized
            nsView.vibrancy = vibrancy
            
            if let appearance = appearance {
                nsView.appearance = appearance
            }
            
            if let maskImage = maskImage {
                nsView.maskImage = maskImage
            }
        }
    }
}

/// Enhanced NSVisualEffectView with additional capabilities
class EnhancedVisualEffectView: NSVisualEffectView {
    var vibrancy: Double = 1.0 {
        didSet {
            updateVibrancy()
        }
    }
    
    private var vibrancyLayer: CALayer?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupVibrancyLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupVibrancyLayer()
    }
    
    private func setupVibrancyLayer() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        let layer = CALayer()
        layer.backgroundColor = NSColor.clear.cgColor
        self.layer?.addSublayer(layer)
        vibrancyLayer = layer
    }
    
    private func updateVibrancy() {
        vibrancyLayer?.opacity = Float(1.0 - vibrancy)
    }
    
    func animateChanges(_ changes: () -> Void) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            changes()
        }
    }
    
    override func updateLayer() {
        super.updateLayer()
        vibrancyLayer?.frame = bounds
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
    
    /// Glass morphism effect
    static var glassMorphism: VisualEffectView {
        VisualEffectView(
            material: .hudWindow,
            blendingMode: .behindWindow,
            vibrancy: 0.8
        )
    }
    
    /// Liquid glass effect
    static var liquidGlass: VisualEffectView {
        VisualEffectView(
            material: .underPageBackground,
            blendingMode: .behindWindow,
            vibrancy: 0.6
        )
    }
    
    /// Frosted glass overlay
    static var frostedGlass: VisualEffectView {
        VisualEffectView(
            material: .popover,
            blendingMode: .withinWindow,
            isEmphasized: true,
            vibrancy: 0.9
        )
    }
    
    /// Dynamic material that adapts to content
    static func adaptive(for colorScheme: ColorScheme) -> VisualEffectView {
        VisualEffectView(
            material: colorScheme == .dark ? .underPageBackground : .contentBackground,
            blendingMode: .behindWindow,
            appearance: NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        )
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