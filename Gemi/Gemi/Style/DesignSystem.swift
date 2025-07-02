//
//  DesignSystem.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/29/25.
//

import SwiftUI

/// Gemi's comprehensive design system for creating a beautiful, Notes.app-inspired interface.
/// This follows the specifications outlined in the PRD for calm, focused, and elegantly functional design.
enum DesignSystem {
    
    // MARK: - Personal Diary Typography - Warm & Handwritten Feel
    
    enum Typography {
        /// Large display text for app title and major moments (40pt) - SF Pro Display
        static let display = Font.system(size: 40, weight: .light, design: .default)
            .leading(.tight)
        
        /// Primary headings for entry titles (28pt) - SF Pro Display
        static let title1 = Font.system(size: 28, weight: .medium, design: .default)
        
        /// Secondary headings for sections (22pt) - SF Pro Display
        static let title2 = Font.system(size: 22, weight: .regular, design: .default)
        
        /// Section headings for organization (20pt) - SF Pro Rounded
        static let title3 = Font.system(size: 20, weight: .medium, design: .rounded)
        
        /// Emphasized body text for highlights (17pt) - SF Pro Rounded
        static let headline = Font.system(size: 17, weight: .medium, design: .rounded)
        
        /// Primary body text for diary entries (17pt) - SF Pro Rounded
        static let body = Font.system(size: 17, weight: .regular, design: .rounded)
        
        /// Secondary body text for descriptions (15pt) - SF Pro Rounded
        static let callout = Font.system(size: 15, weight: .regular, design: .rounded)
        
        /// Tertiary text for metadata (13pt) - SF Pro Rounded
        static let subheadline = Font.system(size: 13, weight: .regular, design: .rounded)
        
        /// Small text for timestamps (12pt) - SF Pro Rounded
        static let footnote = Font.system(size: 12, weight: .light, design: .rounded)
        
        /// Captions and subtle labels (11pt) - SF Pro Rounded
        static let caption1 = Font.system(size: 11, weight: .light, design: .rounded)
        
        /// Smallest text for fine details (10pt) - SF Pro Rounded
        static let caption2 = Font.system(size: 10, weight: .ultraLight, design: .rounded)
        
        /// Monospaced for technical elements - warmer mono
        static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
        
        // MARK: - Specialized Diary Typography
        
        /// For the main diary editor - New York font for personal handwriting feel
        static let diaryBody = Font.custom("New York", size: 18).weight(.regular)
        
        /// For diary entry dates - elegant and personal
        static let diaryDate = Font.custom("New York", size: 14).weight(.light)
        
        /// For entry previews in timeline - inviting glimpse with New York
        static let diaryPreview = Font.custom("New York", size: 15).weight(.light)
        
        /// For AI chat responses - friendly conversation with SF Pro Rounded
        static let chatResponse = Font.system(size: 16, weight: .regular, design: .rounded)
        
        /// For prompts and inspiration - gentle guidance with New York
        static let prompt = Font.custom("New York", size: 16).weight(.light)
    }
    
    /// Alias for Typography to maintain compatibility
    typealias Fonts = Typography
    
    // MARK: - Sophisticated Color Palette
    
    enum Colors {
        // MARK: Brand Colors - Cozy Coffee Shop Aesthetic
        
        /// Primary brand color - Google DeepMind inspired pastel blue (#5B9BD5)
        static let primary: Color = {
            #if os(macOS)
            return Color(NSColor(name: "PrimaryPastelBlue") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.40, green: 0.58, blue: 0.78, alpha: 1.0) // Muted pastel blue for dark mode
                } else {
                    return NSColor(red: 0.36, green: 0.61, blue: 0.84, alpha: 1.0) // Google DeepMind pastel blue for light mode
                }
            })
            #else
            return Color(red: 0.36, green: 0.61, blue: 0.84)
            #endif
        }()
        
        /// Secondary brand accent - warmer companion to primary
        static let secondary: Color = {
            #if os(macOS)
            return Color(NSColor(name: "SecondaryWarmBlue") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.48, green: 0.60, blue: 0.72, alpha: 1.0) // Darker muted warm blue for dark mode
                } else {
                    return NSColor(red: 0.59, green: 0.78, blue: 0.91, alpha: 0.8) // Lighter warm blue for light mode
                }
            })
            #else
            return Color(red: 0.59, green: 0.78, blue: 0.91)
            #endif
        }()
        
        /// Brand color alias
        static let brand = primary
        
        /// Background color alias
        static let background = backgroundPrimary
        
        /// Success states - warm sage green
        static let success: Color = {
            #if os(macOS)
            return Color(NSColor(name: "SuccessWarmGreen") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.67, green: 0.82, blue: 0.73, alpha: 1.0) // Warm sage for dark mode
                } else {
                    return NSColor(red: 0.52, green: 0.74, blue: 0.58, alpha: 1.0) // Warm sage for light mode
                }
            })
            #else
            return Color(red: 0.52, green: 0.74, blue: 0.58)
            #endif
        }()
        
        /// Warning states - warm amber
        static let warning: Color = {
            #if os(macOS)
            return Color(NSColor(name: "WarningWarmAmber") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.94, green: 0.82, blue: 0.61, alpha: 1.0) // Warm amber for dark mode
                } else {
                    return NSColor(red: 0.89, green: 0.71, blue: 0.42, alpha: 1.0) // Warm amber for light mode
                }
            })
            #else
            return Color(red: 0.89, green: 0.71, blue: 0.42)
            #endif
        }()
        
        /// Error states - warm terracotta
        static let error: Color = {
            #if os(macOS)
            return Color(NSColor(name: "ErrorWarmTerracotta") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.89, green: 0.65, blue: 0.61, alpha: 1.0) // Warm terracotta for dark mode
                } else {
                    return NSColor(red: 0.82, green: 0.52, blue: 0.47, alpha: 1.0) // Warm terracotta for light mode
                }
            })
            #else
            return Color(red: 0.82, green: 0.52, blue: 0.47)
            #endif
        }()
        
        // MARK: Text Colors - Warm and Inviting
        
        /// Primary text - rich but soft black (#2C2C2C)
        static let textPrimary: Color = {
            #if os(macOS)
            return Color(NSColor(name: "TextPrimaryRich") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.92, green: 0.89, blue: 0.85, alpha: 1.0) // Warm cream for dark mode
                } else {
                    return NSColor(red: 0.17, green: 0.17, blue: 0.17, alpha: 1.0) // Rich but soft black for light mode
                }
            })
            #else
            return Color(red: 0.17, green: 0.17, blue: 0.17)
            #endif
        }()
        
        /// Secondary text - warm taupe
        static let textSecondary: Color = {
            #if os(macOS)
            return Color(NSColor(name: "TextSecondaryWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.78, green: 0.74, blue: 0.68, alpha: 1.0) // Warm beige for dark mode
                } else {
                    return NSColor(red: 0.45, green: 0.42, blue: 0.38, alpha: 1.0) // Warm taupe for light mode
                }
            })
            #else
            return Color(red: 0.45, green: 0.42, blue: 0.38)
            #endif
        }()
        
        /// Tertiary text - soft warm gray
        static let textTertiary: Color = {
            #if os(macOS)
            return Color(NSColor(name: "TextTertiaryWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.64, green: 0.61, blue: 0.56, alpha: 1.0) // Muted warm gray for dark mode
                } else {
                    return NSColor(red: 0.62, green: 0.58, blue: 0.54, alpha: 1.0) // Soft warm gray for light mode
                }
            })
            #else
            return Color(red: 0.62, green: 0.58, blue: 0.54)
            #endif
        }()
        
        /// Placeholder text - gentle warm gray
        static let textPlaceholder: Color = {
            #if os(macOS)
            return Color(NSColor(name: "TextPlaceholderWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.52, green: 0.49, blue: 0.44, alpha: 1.0) // Muted warm brown for dark mode
                } else {
                    return NSColor(red: 0.72, green: 0.68, blue: 0.64, alpha: 1.0) // Gentle warm gray for light mode
                }
            })
            #else
            return Color(red: 0.72, green: 0.68, blue: 0.64)
            #endif
        }()
        
        // MARK: Background Colors - Warm Paper & Cozy Evening
        
        /// Primary background - warm off-white (#FAFAF8)
        static let backgroundPrimary: Color = {
            #if os(macOS)
            return Color(NSColor(name: "BackgroundPrimaryWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.11, green: 0.10, blue: 0.09, alpha: 1.0) // Deeper cozy evening charcoal for dark mode
                } else {
                    return NSColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1.0) // Warm off-white for light mode
                }
            })
            #else
            return Color(red: 0.98, green: 0.98, blue: 0.97)
            #endif
        }()
        
        /// Secondary background - warm cards and panels
        static let backgroundSecondary: Color = {
            #if os(macOS)
            return Color(NSColor(name: "BackgroundSecondaryWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.15, green: 0.13, blue: 0.11, alpha: 1.0) // Darker elevated surface for dark mode
                } else {
                    return NSColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1.0) // Slightly elevated warm white for light mode
                }
            })
            #else
            return Color(red: 0.99, green: 0.98, blue: 0.96)
            #endif
        }()
        
        /// Tertiary background - subtle warm elevation
        static let backgroundTertiary: Color = {
            #if os(macOS)
            return Color(NSColor(name: "BackgroundTertiaryWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.17, green: 0.15, blue: 0.13, alpha: 1.0) // Darker highest elevation surface for dark mode
                } else {
                    return NSColor(red: 0.96, green: 0.94, blue: 0.91, alpha: 1.0) // Subtle warm beige for light mode
                }
            })
            #else
            return Color(red: 0.96, green: 0.94, blue: 0.91)
            #endif
        }()
        
        /// Window background - same as primary for consistency
        static let backgroundWindow = backgroundPrimary
        
        // MARK: Floating Panel Colors - Coffee Shop Warmth
        
        /// Main panel background with subtle warmth
        static let panelBackground = backgroundSecondary
        
        /// Floating panel background with elevated appearance
        static let floatingPanelBackground = backgroundSecondary
        
        /// Canvas background behind floating panels - warm and inviting
        static let canvasBackground: Color = {
            #if os(macOS)
            return Color(NSColor(name: "CanvasBackgroundWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1.0) // Deep cozy coffee for dark mode
                } else {
                    return NSColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0) // Warm latte for light mode
                }
            })
            #else
            return Color(red: 0.96, green: 0.94, blue: 0.90)
            #endif
        }()
        
        /// Sidebar background with warm depth
        static let sidebarBackground: Color = {
            #if os(macOS)
            return Color(NSColor(name: "SidebarBackgroundWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.12, green: 0.11, blue: 0.10, alpha: 1.0) // Darker warm cocoa for dark mode
                } else {
                    return NSColor(red: 0.94, green: 0.92, blue: 0.88, alpha: 1.0) // Warm oat milk for light mode
                }
            })
            #else
            return Color(red: 0.94, green: 0.92, blue: 0.88)
            #endif
        }()
        
        // MARK: Interface Colors - Warm and Inviting
        
        /// Dividers and borders - warm subtle lines
        static let divider: Color = {
            #if os(macOS)
            return Color(NSColor(name: "DividerWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.25, green: 0.23, blue: 0.20, alpha: 1.0) // Darker warm brown divider for dark mode
                } else {
                    return NSColor(red: 0.85, green: 0.82, blue: 0.78, alpha: 1.0) // Warm beige divider for light mode
                }
            })
            #else
            return Color(red: 0.85, green: 0.82, blue: 0.78)
            #endif
        }()
        
        /// Interactive elements - warm blue accent
        static let interactive = primary
        
        /// Hover states - gentle warm glow
        static let hover: Color = {
            #if os(macOS)
            return Color(NSColor(name: "HoverWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.68, green: 0.81, blue: 0.94, alpha: 0.15) // Warm blue glow for dark mode
                } else {
                    return NSColor(red: 0.49, green: 0.73, blue: 0.89, alpha: 0.12) // Gentle warm blue for light mode
                }
            })
            #else
            return Color(red: 0.49, green: 0.73, blue: 0.89).opacity(0.12)
            #endif
        }()
        
        /// Selection states - warm highlight
        static let selection: Color = {
            #if os(macOS)
            return Color(NSColor(name: "SelectionWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.58, green: 0.71, blue: 0.84, alpha: 0.25) // Warm blue selection for dark mode
                } else {
                    return NSColor(red: 0.49, green: 0.73, blue: 0.89, alpha: 0.18) // Warm blue selection for light mode
                }
            })
            #else
            return Color(red: 0.49, green: 0.73, blue: 0.89).opacity(0.18)
            #endif
        }()
        
        // MARK: Sculptural Shadow Colors - Overly-Done Beautiful Depth
        
        /// Whisper shadow - subtle warm foundation
        static let shadowWhisper: Color = {
            #if os(macOS)
            return Color(NSColor(name: "ShadowWhisperWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.12, green: 0.08, blue: 0.05, alpha: 0.25) // Warm charcoal whisper for dark mode
                } else {
                    return NSColor(red: 0.52, green: 0.43, blue: 0.35, alpha: 0.06) // Warm coffee whisper for light mode
                }
            })
            #else
            return Color(red: 0.52, green: 0.43, blue: 0.35).opacity(0.06)
            #endif
        }()
        
        /// Light shadow - defined warm presence
        static let shadowLight: Color = {
            #if os(macOS)
            return Color(NSColor(name: "ShadowLightWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.08, green: 0.05, blue: 0.03, alpha: 0.45) // Warm espresso for dark mode
                } else {
                    return NSColor(red: 0.45, green: 0.37, blue: 0.28, alpha: 0.12) // Warm mocha for light mode
                }
            })
            #else
            return Color(red: 0.45, green: 0.37, blue: 0.28).opacity(0.12)
            #endif
        }()
        
        /// Medium shadow - structured warm depth
        static let shadowMedium: Color = {
            #if os(macOS)
            return Color(NSColor(name: "ShadowMediumWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.05, green: 0.03, blue: 0.02, alpha: 0.65) // Deep warm cocoa for dark mode
                } else {
                    return NSColor(red: 0.38, green: 0.29, blue: 0.22, alpha: 0.18) // Rich warm chocolate for light mode
                }
            })
            #else
            return Color(red: 0.38, green: 0.29, blue: 0.22).opacity(0.18)
            #endif
        }()
        
        /// Heavy shadow - dramatic warm foundation
        static let shadowHeavy: Color = {
            #if os(macOS)
            return Color(NSColor(name: "ShadowHeavyWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.03, green: 0.02, blue: 0.01, alpha: 0.80) // Dramatic warm shadow for dark mode
                } else {
                    return NSColor(red: 0.32, green: 0.24, blue: 0.18, alpha: 0.28) // Bold warm umber for light mode
                }
            })
            #else
            return Color(red: 0.32, green: 0.24, blue: 0.18).opacity(0.28)
            #endif
        }()
        
        /// Epic shadow - maximum dramatic depth
        static let shadowEpic: Color = {
            #if os(macOS)
            return Color(NSColor(name: "ShadowEpicWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.02, green: 0.01, blue: 0.00, alpha: 0.90) // Epic warm darkness for dark mode
                } else {
                    return NSColor(red: 0.28, green: 0.20, blue: 0.14, alpha: 0.35) // Epic warm sepia for light mode
                }
            })
            #else
            return Color(red: 0.28, green: 0.20, blue: 0.14).opacity(0.35)
            #endif
        }()
        
        // MARK: Interactive Shadow Colors - Beautiful State Changes
        
        /// Hover shadow - warm glow enhancement
        static let shadowHover: Color = {
            #if os(macOS)
            return Color(NSColor(name: "ShadowHoverWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.68, green: 0.81, blue: 0.94, alpha: 0.25) // Warm blue glow for dark mode
                } else {
                    return NSColor(red: 0.49, green: 0.73, blue: 0.89, alpha: 0.15) // Gentle warm blue glow for light mode
                }
            })
            #else
            return Color(red: 0.49, green: 0.73, blue: 0.89).opacity(0.15)
            #endif
        }()
        
        /// Focus shadow - attention-drawing warmth
        static let shadowFocus: Color = {
            #if os(macOS)
            return Color(NSColor(name: "ShadowFocusWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.68, green: 0.81, blue: 0.94, alpha: 0.40) // Strong warm blue for dark mode
                } else {
                    return NSColor(red: 0.49, green: 0.73, blue: 0.89, alpha: 0.25) // Defined warm blue for light mode
                }
            })
            #else
            return Color(red: 0.49, green: 0.73, blue: 0.89).opacity(0.25)
            #endif
        }()
        
        /// Selected shadow - chosen element warmth
        static let shadowSelected: Color = {
            #if os(macOS)
            return Color(NSColor(name: "ShadowSelectedWarm") { appearance in
                if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                    return NSColor(red: 0.58, green: 0.71, blue: 0.84, alpha: 0.35) // Rich warm selection for dark mode
                } else {
                    return NSColor(red: 0.49, green: 0.73, blue: 0.89, alpha: 0.22) // Warm selection glow for light mode
                }
            })
            #else
            return Color(red: 0.49, green: 0.73, blue: 0.89).opacity(0.22)
            #endif
        }()
        
        // MARK: Semantic Colors (fallback to system)
        
        static let systemBackground = Color(NSColor.windowBackgroundColor)
        static let systemSecondaryBackground = Color(NSColor.controlBackgroundColor)
        static let systemTertiaryBackground = Color(NSColor.tertiarySystemFill)
        static let systemAccent = Color.accentColor
        
        // MARK: Compatibility Aliases
        
        /// Alias for divider to maintain compatibility
        static let separator = divider
    }
    
    // MARK: - Generous Coffee Shop Spacing System
    
    enum Spacing {
        /// Micro spacing (4pt) - subtle element separation
        static let micro: CGFloat = 4
        
        /// Tiny spacing (8pt) - close related elements
        static let tiny: CGFloat = 8
        
        /// Small spacing (16pt) - comfortable element spacing
        static let small: CGFloat = 16
        
        /// Medium spacing (24pt) - related sections
        static let medium: CGFloat = 24
        
        /// Base spacing (32pt) - standard generous margin
        static let base: CGFloat = 32
        
        /// Large spacing (48pt) - major section breathing room
        static let large: CGFloat = 48
        
        /// Extra large spacing (64pt) - panel separation
        static let extraLarge: CGFloat = 64
        
        /// Huge spacing (80pt) - major layout spacing
        static let huge: CGFloat = 80
        
        /// Expansive spacing (120pt) - maximum breathing room
        static let expansive: CGFloat = 120
        
        // MARK: Coffee Shop Layout Constants
        
        /// Sidebar width (240pt) - translucent with vibrancy
        static let sidebarWidth: CGFloat = 240
        
        /// Timeline width (380pt) - generous reading space
        static let timelineWidth: CGFloat = 380
        
        /// Minimum timeline width (320pt) - never cramped
        static let timelineMinWidth: CGFloat = 320
        
        /// Maximum timeline width (480pt) - luxurious reading
        static let timelineMaxWidth: CGFloat = 480
        
        /// Panel padding (40pt) - generous floating panel padding
        static let panelPadding: CGFloat = 40
        
        /// Window edge margin (40pt) - floating distance from edges
        static let windowEdgeMargin: CGFloat = 40
        
        /// Content padding (28pt) - comfortable text spacing
        static let contentPadding: CGFloat = 28
        
        /// Touch target minimum (48pt) - substantial interaction areas
        static let touchTargetMin: CGFloat = 48
        
        // MARK: Semantic Spacing - Claude-style Generosity
        
        /// Standard margin spacing (32pt) - generous breathing room
        static let margin: CGFloat = base
        
        /// Internal padding for components (24pt) - comfortable interior
        static let internalPadding: CGFloat = medium
        
        /// Card spacing (20pt) - distinct but connected
        static let cardSpacing: CGFloat = 20
        
        /// Section spacing (56pt) - clear visual separation
        static let sectionSpacing: CGFloat = 56
        
        /// Panel gap (36pt) - independent floating panels
        static let panelGap: CGFloat = 36
    }
    
    // MARK: - Component Specifications
    
    enum Components {
        // MARK: Corner Radius
        
        /// Small radius for buttons and small elements
        static let radiusSmall: CGFloat = 6
        
        /// Medium radius for cards and panels
        static let radiusMedium: CGFloat = 12
        
        /// Large radius for major containers
        static let radiusLarge: CGFloat = 16
        
        /// Extra large radius for floating panels
        static let radiusFloating: CGFloat = 20
        
        /// Base corner radius alias
        static let radiusBase: CGFloat = radiusMedium
        
        /// Corner radius alias
        static let cornerRadius: CGFloat = radiusMedium
        
        // MARK: Sculptural Shadow Definitions - Overly-Done Beautiful Depth
        
        /// Journal entry shadow - like beautiful handwritten pages
        static var shadowJournalEntry: [(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)] {
            return [
                // Foundation shadow - warm paper depth
                (color: Colors.shadowWhisper, radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1)),
                // Structure shadow - defined page lift
                (color: Colors.shadowLight, radius: CGFloat(8), x: CGFloat(0), y: CGFloat(3)),
                // Drama shadow - substantial presence
                (color: Colors.shadowMedium, radius: CGFloat(16), x: CGFloat(0), y: CGFloat(6)),
                // Epic foundation - inspiring depth
                (color: Colors.shadowHeavy, radius: CGFloat(24), x: CGFloat(0), y: CGFloat(8))
            ]
        }
        
        /// Floating panel shadow - dramatic sculptural presence
        static var shadowFloatingPanel: [(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)] {
            return [
                // Close contact shadow
                (color: Colors.shadowWhisper, radius: CGFloat(1), x: CGFloat(0), y: CGFloat(0)),
                // Defined lift shadow
                (color: Colors.shadowLight, radius: CGFloat(12), x: CGFloat(0), y: CGFloat(4)),
                // Structural depth shadow
                (color: Colors.shadowMedium, radius: CGFloat(28), x: CGFloat(0), y: CGFloat(8)),
                // Dramatic foundation shadow
                (color: Colors.shadowHeavy, radius: CGFloat(48), x: CGFloat(0), y: CGFloat(16)),
                // Epic ambient shadow
                (color: Colors.shadowEpic, radius: CGFloat(72), x: CGFloat(0), y: CGFloat(24))
            ]
        }
        
        /// Epic main panel shadow - maximum inspiring depth
        static var shadowMainPanel: [(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)] {
            return [
                // Surface contact
                (color: Colors.shadowWhisper, radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1)),
                // Close definition
                (color: Colors.shadowLight, radius: CGFloat(16), x: CGFloat(0), y: CGFloat(6)),
                // Mid-range structure
                (color: Colors.shadowMedium, radius: CGFloat(36), x: CGFloat(0), y: CGFloat(12)),
                // Deep foundation
                (color: Colors.shadowHeavy, radius: CGFloat(64), x: CGFloat(0), y: CGFloat(20)),
                // Epic atmospheric depth
                (color: Colors.shadowEpic, radius: CGFloat(96), x: CGFloat(0), y: CGFloat(32))
            ]
        }
        
        /// Interactive shadows for different states
        static var shadowButton: [(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)] {
            return [
                (color: Colors.shadowWhisper, radius: CGFloat(1), x: CGFloat(0), y: CGFloat(1)),
                (color: Colors.shadowLight, radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2)),
                (color: Colors.shadowMedium, radius: CGFloat(8), x: CGFloat(0), y: CGFloat(3))
            ]
        }
        
        static var shadowButtonHover: [(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)] {
            return [
                (color: Colors.shadowWhisper, radius: CGFloat(2), x: CGFloat(0), y: CGFloat(2)),
                (color: Colors.shadowLight, radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4)),
                (color: Colors.shadowMedium, radius: CGFloat(16), x: CGFloat(0), y: CGFloat(6)),
                (color: Colors.shadowHover, radius: CGFloat(12), x: CGFloat(0), y: CGFloat(0))
            ]
        }
        
        static var shadowButtonPressed: [(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)] {
            return [
                (color: Colors.shadowLight, radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1)),
                (color: Colors.shadowMedium, radius: CGFloat(4), x: CGFloat(0), y: CGFloat(1))
            ]
        }
        
        /// Selection state shadows
        static var shadowSelected: [(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)] {
            return [
                (color: Colors.shadowWhisper, radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1)),
                (color: Colors.shadowLight, radius: CGFloat(12), x: CGFloat(0), y: CGFloat(4)),
                (color: Colors.shadowMedium, radius: CGFloat(24), x: CGFloat(0), y: CGFloat(8)),
                (color: Colors.shadowSelected, radius: CGFloat(16), x: CGFloat(0), y: CGFloat(0))
            ]
        }
        
        static var shadowFocused: [(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)] {
            return [
                (color: Colors.shadowWhisper, radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1)),
                (color: Colors.shadowLight, radius: CGFloat(12), x: CGFloat(0), y: CGFloat(4)),
                (color: Colors.shadowMedium, radius: CGFloat(24), x: CGFloat(0), y: CGFloat(8)),
                (color: Colors.shadowFocus, radius: CGFloat(20), x: CGFloat(0), y: CGFloat(0))
            ]
        }
        
        /// Legacy single shadow definitions for compatibility
        static let shadowCard = (color: Colors.shadowLight, radius: CGFloat(12), x: CGFloat(0), y: CGFloat(4))
        static let shadowElevated = (color: Colors.shadowMedium, radius: CGFloat(24), x: CGFloat(0), y: CGFloat(8))
        static let shadowDeep = (color: Colors.shadowHeavy, radius: CGFloat(48), x: CGFloat(0), y: CGFloat(16))
        
        /// Floating panel shadow - warm and inviting for writing inspiration
        static var shadowFloating: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            return (color: Colors.shadowMedium, radius: CGFloat(32), x: CGFloat(0), y: CGFloat(12))
        }
        
        /// Heavy floating shadow for main content panels - defined warm depth
        static var shadowFloatingHeavy: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            return (color: Colors.shadowHeavy, radius: CGFloat(64), x: CGFloat(0), y: CGFloat(20))
        }
        
        /// Inner shadow for depth effect - subtle warm inset
        static var shadowInner: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            return (color: Colors.shadowWhisper, radius: CGFloat(6), x: CGFloat(0), y: CGFloat(-2))
        }
        
        // MARK: Substantial Sizing - Coffee Shop Comfort
        
        /// Standard button height - more substantial
        static let buttonHeight: CGFloat = 48
        
        /// Large button height - generous and inviting
        static let buttonHeightLarge: CGFloat = 56
        
        /// Toolbar height - spacious and comfortable
        static let toolbarHeight: CGFloat = 72
        
        /// Minimum touch target - generous interaction area
        static let touchTarget: CGFloat = 48
        
        /// Icon sizes - more prominent and friendly
        static let iconSmall: CGFloat = 20
        static let iconMedium: CGFloat = 24
        static let iconLarge: CGFloat = 32
        static let iconHuge: CGFloat = 48
        
        /// Panel header height - substantial presence
        static let panelHeaderHeight: CGFloat = 88
        
        /// Sidebar item height - comfortable selection
        static let sidebarItemHeight: CGFloat = 52
    }
    
    // MARK: - Encouraging Coffee Shop Animation Specifications
    
    enum Animation {
        /// Instant response for immediate feedback - encouraging responsiveness
        static let instant = SwiftUI.Animation.easeOut(duration: 0.1)
        
        /// Quick interactions with gentle ease - warm acknowledgment
        static let quick = SwiftUI.Animation.easeOut(duration: 0.18)
        
        /// Standard animations with welcoming curves - supportive transitions
        static let standard = SwiftUI.Animation.timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.3)
        
        /// Smooth transitions with encouraging flow - maintaining cozy mood
        static let smooth = SwiftUI.Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.45)
        
        /// Playful bounce for delightful interactions - encouraging writing
        static let playfulBounce = SwiftUI.Animation.interpolatingSpring(
            mass: 0.8,
            stiffness: 180,
            damping: 12,
            initialVelocity: 0
        )
        
        /// Gentle encouraging spring - like a supportive friend
        static let encouragingSpring = SwiftUI.Animation.interpolatingSpring(
            mass: 1.0,
            stiffness: 120,
            damping: 15,
            initialVelocity: 0
        )
        
        /// Warm welcome spring - for onboarding and first interactions
        static let warmWelcome = SwiftUI.Animation.interpolatingSpring(
            mass: 1.2,
            stiffness: 100,
            damping: 18,
            initialVelocity: 2
        )
        
        /// Cozy settle animation - for panels and major transitions
        static let cozySettle = SwiftUI.Animation.interpolatingSpring(
            mass: 1.5,
            stiffness: 140,
            damping: 22,
            initialVelocity: 0
        )
        
        /// Gentle float for hover effects - inviting interaction
        static let gentleFloat = SwiftUI.Animation.timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.25)
        
        /// Supportive emphasis - for important moments
        static let supportiveEmphasis = SwiftUI.Animation.interpolatingSpring(
            mass: 0.6,
            stiffness: 200,
            damping: 10,
            initialVelocity: 1
        )
        
        /// Writing flow animation - optimized for text input
        static let writingFlow = SwiftUI.Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.2)
        
        /// Heartbeat pulse for subtle life
        static let heartbeat = SwiftUI.Animation.easeInOut(duration: 1.2)
        
        /// Gentle breathing for ambient elements
        static let breathing = SwiftUI.Animation.easeInOut(duration: 2.5)
        
        // MARK: - Legacy Aliases for Compatibility
        static let spring = encouragingSpring
        static let gentleSpring = cozySettle
    }
}

// MARK: - Button Styles

/// Primary button style with encouraging, warm interactions
struct GemiPrimaryButtonStyle: ButtonStyle {
    let isLoading: Bool
    @State private var isHovered = false
    @State private var pulsePhase = 0.0
    
    init(isLoading: Bool = false) {
        self.isLoading = isLoading
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .handwrittenStyle()
            .foregroundStyle(.white)
            .frame(height: DesignSystem.Components.buttonHeight)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    // Main button background with encouraging glow
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary,
                                    DesignSystem.Colors.primary.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .brightness(configuration.isPressed ? -0.1 : 0)
                    
                    // Warm encouraging glow on hover
                    if isHovered {
                        RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: 80
                                )
                            )
                            .scaleEffect(1.2)
                    }
                    
                    // Subtle heartbeat pulse for important actions
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                        .stroke(
                            Color.white.opacity(0.4 + 0.2 * sin(pulsePhase)),
                            lineWidth: 1.5
                        )
                        .onAppear {
                            withAnimation(DesignSystem.Animation.breathing) {
                                pulsePhase = 2 * .pi
                            }
                        }
                }
            )
            .scaleEffect(
                configuration.isPressed ? 0.94 : 
                isHovered ? 1.05 : 1.0
            )
            .opacity(isLoading ? 0.6 : 1.0)
            .interactiveButtonShadow(isPressed: configuration.isPressed, isHovered: isHovered)
            .onHover { hovering in
                withAnimation(DesignSystem.Animation.gentleFloat) {
                    isHovered = hovering
                }
            }
            .animation(DesignSystem.Animation.playfulBounce, value: configuration.isPressed)
            .animation(DesignSystem.Animation.encouragingSpring, value: isHovered)
            .disabled(isLoading)
    }
}

/// Secondary button style with inviting, warm interactions
struct GemiSecondaryButtonStyle: ButtonStyle {
    @State private var isHovered = false
    @State private var glowIntensity = 0.0
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .handwrittenStyle()
            .foregroundStyle(DesignSystem.Colors.primary)
            .frame(height: DesignSystem.Components.buttonHeight)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    // Base background with encouraging warmth
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                        .fill(DesignSystem.Colors.backgroundSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                                .fill(
                                    DesignSystem.Colors.primary.opacity(
                                        configuration.isPressed ? 0.15 : 
                                        isHovered ? 0.08 : 0.02
                                    )
                                )
                        )
                    
                    // Inviting border with gentle glow
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary.opacity(0.8 + glowIntensity * 0.4),
                                    DesignSystem.Colors.primary.opacity(0.6 + glowIntensity * 0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isHovered ? 2.5 : 2
                        )
                    
                    // Encouraging shimmer on hover
                    if isHovered {
                        RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        Color.clear,
                                        DesignSystem.Colors.primary.opacity(0.6),
                                        Color.clear
                                    ],
                                    center: .center,
                                    angle: .degrees(glowIntensity * 360)
                                ),
                                lineWidth: 1
                            )
                    }
                }
            )
            .scaleEffect(
                configuration.isPressed ? 0.95 : 
                isHovered ? 1.02 : 1.0
            )
            .interactiveButtonShadow(isPressed: configuration.isPressed, isHovered: isHovered)
            .onHover { hovering in
                withAnimation(DesignSystem.Animation.gentleFloat) {
                    isHovered = hovering
                }
                if hovering {
                    withAnimation(DesignSystem.Animation.breathing) {
                        glowIntensity = 1.0
                    }
                } else {
                    withAnimation(DesignSystem.Animation.standard) {
                        glowIntensity = 0.0
                    }
                }
            }
            .animation(DesignSystem.Animation.playfulBounce, value: configuration.isPressed)
            .animation(DesignSystem.Animation.encouragingSpring, value: isHovered)
    }
}

/// Subtle button style with gentle, encouraging presence
struct GemiSubtleButtonStyle: ButtonStyle {
    @State private var isHovered = false
    @State private var subtleGlow = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.callout)
            .diaryTypography()
            .foregroundStyle(
                isHovered ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary
            )
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
            .background(
                ZStack {
                    // Base background with subtle warmth
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                        .fill(DesignSystem.Colors.backgroundSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                                .fill(
                                    DesignSystem.Colors.hover.opacity(
                                        configuration.isPressed ? 0.8 : 
                                        isHovered ? 0.4 : 0.0
                                    )
                                )
                        )
                    
                    // Encouraging glow on interaction
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                        .stroke(
                            DesignSystem.Colors.primary.opacity(
                                subtleGlow ? 0.3 : 0.0
                            ),
                            lineWidth: 1
                        )
                    
                    // Subtle definition border
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusSmall)
                        .stroke(
                            DesignSystem.Colors.divider.opacity(
                                isHovered ? 0.6 : 0.3
                            ), 
                            lineWidth: 0.5
                        )
                }
            )
            .scaleEffect(
                configuration.isPressed ? 0.96 : 
                isHovered ? 1.01 : 1.0
            )
            .interactiveButtonShadow(isPressed: configuration.isPressed, isHovered: isHovered)
            .onHover { hovering in
                withAnimation(DesignSystem.Animation.gentleFloat) {
                    isHovered = hovering
                    subtleGlow = hovering
                }
            }
            .animation(DesignSystem.Animation.supportiveEmphasis, value: configuration.isPressed)
            .animation(DesignSystem.Animation.writingFlow, value: isHovered)
    }
}

// MARK: - Card Styles

/// Beautiful card with journal-like depth
struct GemiCardStyle: ViewModifier {
    let showShadow: Bool
    let isJournalEntry: Bool
    
    init(showShadow: Bool = true, isJournalEntry: Bool = false) {
        self.showShadow = showShadow
        self.isJournalEntry = isJournalEntry
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Card background with warm paper feel
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                        .fill(DesignSystem.Colors.backgroundSecondary)
                    
                    // Subtle warm border
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                        .stroke(DesignSystem.Colors.divider.opacity(0.2), lineWidth: 0.5)
                    
                    // Inner warm glow for depth
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusMedium)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary.opacity(0.03),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .modifier(
                showShadow ? (isJournalEntry ? 
                    MultiLayerShadowStyle(shadows: DesignSystem.Components.shadowJournalEntry) :
                    MultiLayerShadowStyle(shadows: DesignSystem.Components.shadowButton)
                ) : MultiLayerShadowStyle(shadows: [])
            )
    }
}

/// Epic elevated card for modals and important overlays
struct GemiElevatedCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Elevated background with dramatic presence
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusLarge)
                        .fill(DesignSystem.Colors.backgroundPrimary)
                    
                    // Defined warm border
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusLarge)
                        .stroke(DesignSystem.Colors.divider.opacity(0.3), lineWidth: 1)
                    
                    // Dramatic inner glow
                    RoundedRectangle(cornerRadius: DesignSystem.Components.radiusLarge)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                }
            )
            .modifier(
                MultiLayerShadowStyle(shadows: DesignSystem.Components.shadowMainPanel)
            )
    }
}

// MARK: - Floating Panel Styles

/// Main floating panel style with sculptural overly-done depth
struct GemiFloatingPanelStyle: ViewModifier {
    let cornerRadius: CGFloat
    let shadowIntensity: CGFloat
    let isMainPanel: Bool
    
    init(cornerRadius: CGFloat = 20, shadowIntensity: CGFloat = 1.0, isMainPanel: Bool = false) {
        self.cornerRadius = cornerRadius
        self.shadowIntensity = shadowIntensity
        self.isMainPanel = isMainPanel
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Main panel background with warm depth
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(DesignSystem.Colors.floatingPanelBackground)
                    
                    // Subtle inner shadow for depth
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(DesignSystem.Colors.divider.opacity(0.15), lineWidth: 1)
                    
                    // Inner glow for warmth
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                }
            )
            .modifier(
                MultiLayerShadowStyle(
                    shadows: isMainPanel ? 
                        DesignSystem.Components.shadowMainPanel :
                        DesignSystem.Components.shadowFloatingPanel
                )
            )
    }
}

/// Sidebar panel style with subtle depth
struct GemiSidebarPanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.sidebarBackground)
                    .shadow(
                        color: DesignSystem.Components.shadowCard.color,
                        radius: DesignSystem.Components.shadowCard.radius,
                        x: DesignSystem.Components.shadowCard.x,
                        y: DesignSystem.Components.shadowCard.y
                    )
            )
    }
}

/// Canvas background for the main workspace
struct GemiCanvasStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.canvasBackground,
                        DesignSystem.Colors.canvasBackground.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

// MARK: - Typography Modifiers for Personal Feel

/// Adds diary-style letter spacing and personal touches
struct DiaryTypographyStyle: ViewModifier {
    let letterSpacing: CGFloat
    let lineSpacing: CGFloat
    
    init(letterSpacing: CGFloat = 0.3, lineSpacing: CGFloat = 2) {
        self.letterSpacing = letterSpacing
        self.lineSpacing = lineSpacing
    }
    
    func body(content: Content) -> some View {
        content
            .tracking(letterSpacing)
            .lineSpacing(lineSpacing)
    }
}

/// Adds handwritten feel with gentle letter spacing
struct HandwrittenStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tracking(0.5)
            .lineSpacing(3)
    }
}

/// Adds elegant serif styling for special moments
struct ElegantSerifStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tracking(0.8)
            .lineSpacing(4)
    }
}

/// Adds relaxed reading style for diary entries
struct RelaxedReadingStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tracking(0.2)
            .lineSpacing(6)
    }
}

// MARK: - Sculptural Shadow Modifiers - Overly-Done Beautiful Depth

/// Applies multi-layered shadows to create sculptural depth
struct MultiLayerShadowStyle: ViewModifier {
    let shadows: [(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)]
    
    func body(content: Content) -> some View {
        shadows.reversed().reduce(AnyView(content)) { view, shadow in
            AnyView(
                view.shadow(
                    color: shadow.color,
                    radius: shadow.radius,
                    x: shadow.x,
                    y: shadow.y
                )
            )
        }
    }
}

/// Epic main panel shadow - maximum inspiring depth for primary content
struct EpicMainPanelShadowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .modifier(MultiLayerShadowStyle(shadows: DesignSystem.Components.shadowMainPanel))
    }
}

/// Floating panel shadow - dramatic sculptural presence
struct FloatingPanelShadowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .modifier(MultiLayerShadowStyle(shadows: DesignSystem.Components.shadowFloatingPanel))
    }
}

/// Journal entry shadow - beautiful handwritten pages
struct JournalEntryShadowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .modifier(MultiLayerShadowStyle(shadows: DesignSystem.Components.shadowJournalEntry))
    }
}

/// Interactive button shadows with state management
struct InteractiveButtonShadowStyle: ViewModifier {
    let isPressed: Bool
    let isHovered: Bool
    
    func body(content: Content) -> some View {
        content
            .modifier(
                MultiLayerShadowStyle(
                    shadows: isPressed ? DesignSystem.Components.shadowButtonPressed :
                            isHovered ? DesignSystem.Components.shadowButtonHover :
                            DesignSystem.Components.shadowButton
                )
            )
    }
}

/// Selection state shadows
struct SelectionShadowStyle: ViewModifier {
    let isSelected: Bool
    let isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .modifier(
                MultiLayerShadowStyle(
                    shadows: isSelected ? DesignSystem.Components.shadowSelected :
                            isFocused ? DesignSystem.Components.shadowFocused :
                            DesignSystem.Components.shadowJournalEntry
                )
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Applies Gemi's primary button style
    func gemiPrimaryButton(isLoading: Bool = false) -> some View {
        self.buttonStyle(GemiPrimaryButtonStyle(isLoading: isLoading))
    }
    
    /// Applies Gemi's secondary button style
    func gemiSecondaryButton() -> some View {
        self.buttonStyle(GemiSecondaryButtonStyle())
    }
    
    /// Applies Gemi's subtle button style
    func gemiSubtleButton() -> some View {
        self.buttonStyle(GemiSubtleButtonStyle())
    }
    
    /// Applies Gemi's card style with beautiful depth
    func gemiCard(showShadow: Bool = true, isJournalEntry: Bool = false) -> some View {
        self.modifier(GemiCardStyle(showShadow: showShadow, isJournalEntry: isJournalEntry))
    }
    
    /// Applies Gemi's epic elevated card style
    func gemiElevatedCard() -> some View {
        self.modifier(GemiElevatedCardStyle())
    }
    
    /// Applies consistent padding for card content
    func gemiCardPadding() -> some View {
        self.padding(DesignSystem.Spacing.base)
    }
    
    /// Applies standard section spacing
    func gemiSectionSpacing() -> some View {
        self.padding(.bottom, DesignSystem.Spacing.large)
    }
    
    /// Applies floating panel style with sculptural shadows
    func gemiFloatingPanel(cornerRadius: CGFloat = 20, shadowIntensity: CGFloat = 1.0, isMainPanel: Bool = false) -> some View {
        self.modifier(GemiFloatingPanelStyle(cornerRadius: cornerRadius, shadowIntensity: shadowIntensity, isMainPanel: isMainPanel))
    }
    
    /// Applies sidebar panel style
    func gemiSidebarPanel() -> some View {
        self.modifier(GemiSidebarPanelStyle())
    }
    
    /// Applies canvas background style
    func gemiCanvas() -> some View {
        self.modifier(GemiCanvasStyle())
    }
    
    // MARK: - Personal Typography Extensions
    
    /// Applies diary-style typography with personal feel
    func diaryTypography(letterSpacing: CGFloat = 0.3, lineSpacing: CGFloat = 2) -> some View {
        self.modifier(DiaryTypographyStyle(letterSpacing: letterSpacing, lineSpacing: lineSpacing))
    }
    
    /// Applies handwritten feel with gentle letter spacing
    func handwrittenStyle() -> some View {
        self.modifier(HandwrittenStyle())
    }
    
    /// Applies elegant serif styling for special moments
    func elegantSerifStyle() -> some View {
        self.modifier(ElegantSerifStyle())
    }
    
    /// Applies relaxed reading style for diary entries
    func relaxedReadingStyle() -> some View {
        self.modifier(RelaxedReadingStyle())
    }
    
    // MARK: - Sculptural Shadow Extensions - Beautiful Depth
    
    /// Applies epic main panel shadow for maximum inspiring depth
    func epicMainPanelShadow() -> some View {
        self.modifier(EpicMainPanelShadowStyle())
    }
    
    /// Applies floating panel shadow for dramatic sculptural presence
    func floatingPanelShadow() -> some View {
        self.modifier(FloatingPanelShadowStyle())
    }
    
    /// Applies journal entry shadow like beautiful handwritten pages
    func journalEntryShadow() -> some View {
        self.modifier(JournalEntryShadowStyle())
    }
    
    /// Applies interactive button shadows with state management
    func interactiveButtonShadow(isPressed: Bool = false, isHovered: Bool = false) -> some View {
        self.modifier(InteractiveButtonShadowStyle(isPressed: isPressed, isHovered: isHovered))
    }
    
    /// Applies selection state shadows
    func selectionShadow(isSelected: Bool = false, isFocused: Bool = false) -> some View {
        self.modifier(SelectionShadowStyle(isSelected: isSelected, isFocused: isFocused))
    }
    
    /// Applies custom multi-layer shadows
    func multiLayerShadow(_ shadows: [(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)]) -> some View {
        self.modifier(MultiLayerShadowStyle(shadows: shadows))
    }
}
