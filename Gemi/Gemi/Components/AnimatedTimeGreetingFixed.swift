//
//  AnimatedTimeGreetingFixed.swift
//  Gemi
//
//  Fixed animated time-aware greeting with proper time reactivity
//

import SwiftUI

struct AnimatedTimeGreetingFixed: View {
    let currentHour: Int
    
    @State private var currentGreeting: String = ""
    @State private var currentSubtitle: String = ""
    @State private var currentIcon: String = ""
    @State private var iconColor: Color = .orange
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.9
    @State private var glowIntensity: Double = 0.15
    
    var body: some View {
        VStack(spacing: 12) {
            // Animated icon with reduced glow effects
            ZStack {
                // Multi-layer glow effect with reduced intensity
                ForEach(0..<3) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    iconColor.opacity((glowIntensity - Double(index) * 0.05) * 0.5),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 30 + CGFloat(index * 10),
                                endRadius: 60 + CGFloat(index * 15)
                            )
                        )
                        .frame(width: 120 + CGFloat(index * 25), height: 120 + CGFloat(index * 25))
                        .blur(radius: 20 + CGFloat(index * 5))
                        .scaleEffect(1 + sin(Date().timeIntervalSince1970 * 0.5 + Double(index)) * 0.03)
                }
                
                // Background circle with subtle gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                iconColor.opacity(0.08),
                                iconColor.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                // Icon with reduced shadow
                Image(systemName: currentIcon)
                    .font(.system(size: 56, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                iconColor,
                                iconColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: iconColor.opacity(0.2), radius: 6, x: 0, y: 2)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .scaleEffect(scale)
            }
            
            // Greeting text with fade animation
            VStack(spacing: 8) {
                Text(currentGreeting)
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.primary,
                                Color.primary.opacity(0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                
                Text(currentSubtitle)
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.secondary,
                                Color.secondary.opacity(0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .opacity(opacity)
        .onAppear {
            updateGreeting(animated: false)
            animateIn()
        }
        .onChange(of: currentHour) { _, _ in
            updateGreeting(animated: true)
        }
    }
    
    // MARK: - Methods
    
    private func animateIn() {
        withAnimation(.easeOut(duration: 0.8)) {
            opacity = 1
            scale = 1
        }
    }
    
    private func updateGreeting(animated: Bool) {
        let newGreeting = getGreeting(for: currentHour)
        let newSubtitle = getSubtitle(for: currentHour)
        let newIcon = getIcon(for: currentHour)
        let newIconColor = getIconColor(for: currentHour)
        
        if animated {
            // Fade out
            withAnimation(.easeIn(duration: 0.4)) {
                opacity = 0
                scale = 0.9
            }
            
            // Update content after fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                currentGreeting = newGreeting
                currentSubtitle = newSubtitle
                currentIcon = newIcon
                
                // Animate color change
                withAnimation(.easeInOut(duration: 1.0)) {
                    iconColor = newIconColor
                    glowIntensity = getGlowIntensity(for: currentHour)
                }
                
                // Fade in with new content
                withAnimation(.easeOut(duration: 0.6)) {
                    opacity = 1
                    scale = 1
                }
            }
        } else {
            // Immediate update without animation
            currentGreeting = newGreeting
            currentSubtitle = newSubtitle
            currentIcon = newIcon
            iconColor = newIconColor
            glowIntensity = getGlowIntensity(for: currentHour)
        }
    }
    
    private func getGreeting(for hour: Int) -> String {
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default: return "Good Night"
        }
    }
    
    private func getSubtitle(for hour: Int) -> String {
        switch hour {
        case 5..<7: return "Rise and shine!"
        case 7..<9: return "Start your day with intention"
        case 9..<12: return "Perfect time to reflect"
        case 12..<14: return "Take a mindful break"
        case 14..<17: return "How's your day going?"
        case 17..<19: return "Time to unwind"
        case 19..<21: return "Reflect on today's moments"
        case 21..<23: return "Wind down with your thoughts"
        default: return "Sweet dreams await"
        }
    }
    
    private func getIcon(for hour: Int) -> String {
        switch hour {
        case 5..<12: return "sun.and.horizon.fill"    // Rising sun for morning
        case 12..<17: return "sun.max.fill"           // Full sun at peak for afternoon
        case 17..<21: return "sunset.fill"            // Setting sun for evening
        default: return "moon.stars.fill"             // Moon and stars for night
        }
    }
    
    private func getIconColor(for hour: Int) -> Color {
        switch hour {
        case 5..<12: return Color(red: 1.0, green: 0.8, blue: 0.2)   // Warm golden yellow for morning sun
        case 12..<17: return Color(red: 1.0, green: 0.9, blue: 0.0)  // Bright yellow for afternoon
        case 17..<21: return .orange                                  // Orange for sunset/evening
        default: return .indigo                                       // Deep indigo for night
        }
    }
    
    private func getGlowIntensity(for hour: Int) -> Double {
        switch hour {
        case 5..<9: return 0.2    // Soft morning glow
        case 9..<17: return 0.15  // Subtle day glow
        case 17..<21: return 0.18 // Warm evening glow
        default: return 0.12      // Minimal night glow
        }
    }
}

// MARK: - Preview

struct AnimatedTimeGreetingFixed_Previews: PreviewProvider {
    static var previews: some View {
        AnimatedTimeGreetingFixed(currentHour: 8)
            .padding(40)
            .background(Color.black)
    }
}