//
//  AppIconDesign.swift
//  Gemi
//
//  Created by Chaeho Shin on 6/30/25.
//

import SwiftUI

/// Generates a beautiful app icon for Gemi with depth and premium feel
struct AppIconDesign: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background gradient with warm coffee shop tones
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.98, green: 0.96, blue: 0.92),  // Warm cream
                    Color(red: 0.94, green: 0.91, blue: 0.86)   // Soft latte
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle paper texture overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.3),
                    Color.clear,
                    Color.black.opacity(0.1)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.overlay)
            
            // Main journal icon with depth
            ZStack {
                // Shadow layers for depth
                ForEach(0..<3) { index in
                    journalShape
                        .fill(Color.black.opacity(0.1 - Double(index) * 0.03))
                        .offset(y: CGFloat(index + 1) * 2)
                        .blur(radius: CGFloat(index + 1) * 1.5)
                }
                
                // Main journal
                journalShape
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.36, green: 0.61, blue: 0.84),  // Pastel blue top
                                Color(red: 0.29, green: 0.54, blue: 0.79)   // Slightly deeper blue
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Journal spine highlight
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.08)
                    .offset(x: -size * 0.25)
                
                // Gem sparkle overlay
                gemSparkle
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.9),
                                Color(red: 0.36, green: 0.61, blue: 0.84).opacity(0.3)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.15
                        )
                    )
                    .frame(width: size * 0.2, height: size * 0.2)
                    .offset(x: size * 0.1, y: -size * 0.1)
                
                // Subtle inner glow
                journalShape
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .frame(width: size * 0.6, height: size * 0.7)
            
            // Top shine effect
            Ellipse()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.3),
                            Color.clear
                        ]),
                        center: .top,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size * 0.8, height: size * 0.4)
                .offset(y: -size * 0.35)
                .blur(radius: 10)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237))
    }
    
    var journalShape: some Shape {
        RoundedRectangle(cornerRadius: size * 0.05)
    }
    
    var gemSparkle: some Shape {
        Star(points: 4, smoothness: 0.3)
    }
}

// MARK: - Star Shape

struct Star: Shape {
    let points: Int
    let smoothness: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * smoothness
        
        var path = Path()
        
        for i in 0..<points * 2 {
            let angle = (CGFloat(i) * .pi) / CGFloat(points)
            let isOuter = i.isMultiple(of: 2)
            let r = isOuter ? radius : innerRadius
            
            let x = center.x + r * cos(angle - .pi / 2)
            let y = center.y + r * sin(angle - .pi / 2)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - App Icon Generator

struct AppIconGenerator {
    static func generateIcons() {
        let sizes = [16, 32, 64, 128, 256, 512, 1024]
        
        for size in sizes {
            let icon = AppIconDesign(size: CGFloat(size))
            // In a real implementation, this would export to PNG files
            // For now, this is a placeholder for the icon generation logic
            print("Generated icon at size: \(size)x\(size)")
        }
    }
}

// MARK: - Preview

#Preview("App Icon - 1024pt") {
    AppIconDesign(size: 1024)
        .padding(50)
        .background(Color.gray.opacity(0.2))
}

#Preview("App Icon - 128pt") {
    AppIconDesign(size: 128)
        .padding(20)
        .background(Color.gray.opacity(0.2))
}