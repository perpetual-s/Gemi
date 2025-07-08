import SwiftUI

/// Settings panel for Focus Mode
struct FocusSettingsPanel: View {
    @ObservedObject var settings: FocusModeSettings
    @Binding var isPresented: Bool
    
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Focus Settings")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(settings.effectiveTextColor)
                
                Spacer()
                
                Button {
                    withAnimation {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
                .foregroundColor(settings.effectiveTextColor.opacity(0.1))
            
            // Tab selector
            HStack(spacing: 0) {
                ForEach(["Visual", "Writing", "Sound"], id: \.self) { tab in
                    TabButton(
                        title: tab,
                        isSelected: selectedTab == ["Visual", "Writing", "Sound"].firstIndex(of: tab),
                        textColor: settings.effectiveTextColor
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = ["Visual", "Writing", "Sound"].firstIndex(of: tab) ?? 0
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            
            Divider()
                .foregroundColor(settings.effectiveTextColor.opacity(0.1))
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    switch selectedTab {
                    case 0:
                        visualSettings
                    case 1:
                        writingSettings
                    case 2:
                        soundSettings
                    default:
                        visualSettings
                    }
                }
                .padding(24)
            }
            .frame(maxHeight: 400)
            
            Divider()
                .foregroundColor(settings.effectiveTextColor.opacity(0.1))
            
            // Footer
            HStack {
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                .buttonStyle(.plain)
                .foregroundColor(settings.effectiveTextColor.opacity(0.6))
                
                Spacer()
                
                Button("Done") {
                    settings.saveSettings()
                    withAnimation {
                        isPresented = false
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.blue)
                )
                .foregroundColor(.white)
            }
            .padding(20)
        }
        .frame(width: 450, height: 600)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(settings.effectiveBackgroundColor)
                .shadow(color: .black.opacity(0.3), radius: 30)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(settings.effectiveTextColor.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Visual Settings
    
    private var visualSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Focus Level
            VStack(alignment: .leading, spacing: 12) {
                Label("Focus Level", systemImage: "viewfinder")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(settings.effectiveTextColor)
                
                HStack(spacing: 12) {
                    ForEach(FocusModeSettings.FocusLevel.allCases, id: \.self) { level in
                        FocusLevelButton(
                            level: level,
                            isSelected: settings.focusLevel == level,
                            textColor: settings.effectiveTextColor
                        ) {
                            settings.focusLevel = level
                        }
                    }
                }
                
                Text("Highlight intensity")
                    .font(.system(size: 12))
                    .foregroundColor(settings.effectiveTextColor.opacity(0.6))
                
                HStack {
                    Text("Subtle")
                        .font(.system(size: 11))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.5))
                    
                    Slider(value: $settings.highlightIntensity, in: 0.2...0.8)
                        .tint(Color.blue)
                    
                    Text("Strong")
                        .font(.system(size: 11))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.5))
                }
            }
            
            Divider()
                .foregroundColor(settings.effectiveTextColor.opacity(0.1))
            
            // Color Scheme
            VStack(alignment: .leading, spacing: 12) {
                Label("Color Scheme", systemImage: "paintpalette")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(settings.effectiveTextColor)
                
                HStack(spacing: 12) {
                    ForEach(FocusModeSettings.FocusColorScheme.allCases, id: \.self) { scheme in
                        ColorSchemeButton(
                            scheme: scheme,
                            isSelected: settings.colorScheme == scheme,
                            textColor: settings.effectiveTextColor
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.colorScheme = scheme
                            }
                        }
                    }
                }
            }
            
            Divider()
                .foregroundColor(settings.effectiveTextColor.opacity(0.1))
            
            // Font Size
            VStack(alignment: .leading, spacing: 12) {
                Label("Text Size", systemImage: "textformat.size")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(settings.effectiveTextColor)
                
                HStack {
                    Text("A")
                        .font(.system(size: 14))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.5))
                    
                    Slider(value: $settings.fontSize, in: 16...32, step: 1)
                        .tint(Color.blue)
                    
                    Text("A")
                        .font(.system(size: 24))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.5))
                    
                    Text("\(Int(settings.fontSize))pt")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.6))
                        .frame(width: 40)
                }
            }
            
            Divider()
                .foregroundColor(settings.effectiveTextColor.opacity(0.1))
            
            // UI Visibility
            VStack(alignment: .leading, spacing: 12) {
                Label("Interface", systemImage: "rectangle.3.group")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(settings.effectiveTextColor)
                
                Toggle("Auto-hide UI elements", isOn: $settings.autoHideUI)
                    .toggleStyle(.switch)
                    .tint(Color.blue)
                
                Toggle("Show word count", isOn: $settings.showWordCount)
                    .toggleStyle(.switch)
                    .tint(Color.blue)
                
                Toggle("Show progress bar", isOn: $settings.showProgress)
                    .toggleStyle(.switch)
                    .tint(Color.blue)
            }
        }
    }
    
    // MARK: - Writing Settings
    
    private var writingSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Typewriter Mode
            VStack(alignment: .leading, spacing: 12) {
                Label("Typewriter Mode", systemImage: "text.cursor")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(settings.effectiveTextColor)
                
                Toggle("Keep cursor centered while typing", isOn: $settings.typewriterMode)
                    .toggleStyle(.switch)
                    .tint(Color.blue)
                
                Text("Maintains your typing position in the center of the screen")
                    .font(.system(size: 12))
                    .foregroundColor(settings.effectiveTextColor.opacity(0.6))
            }
            
            Divider()
                .foregroundColor(settings.effectiveTextColor.opacity(0.1))
            
            // Writing Goals
            VStack(alignment: .leading, spacing: 12) {
                Label("Writing Goals", systemImage: "target")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(settings.effectiveTextColor)
                
                HStack {
                    Text("Word goal:")
                        .font(.system(size: 13))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.8))
                    
                    TextField("750", value: $settings.wordGoal, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    
                    Text("words")
                        .font(.system(size: 13))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.6))
                    
                    Spacer()
                }
                
                HStack {
                    Text("Time goal:")
                        .font(.system(size: 13))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.8))
                    
                    TextField("30", value: $settings.timeGoal, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    
                    Text("minutes")
                        .font(.system(size: 13))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.6))
                    
                    Spacer()
                }
            }
            
            Divider()
                .foregroundColor(settings.effectiveTextColor.opacity(0.1))
            
            // Line Width
            VStack(alignment: .leading, spacing: 12) {
                Label("Line Width", systemImage: "arrow.left.and.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(settings.effectiveTextColor)
                
                HStack {
                    Text("Narrow")
                        .font(.system(size: 11))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.5))
                    
                    Slider(value: $settings.maxLineWidth, in: 500...1200, step: 50)
                        .tint(Color.blue)
                    
                    Text("Wide")
                        .font(.system(size: 11))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.5))
                    
                    Text("\(Int(settings.maxLineWidth))px")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.6))
                        .frame(width: 60)
                }
            }
        }
    }
    
    // MARK: - Sound Settings
    
    private var soundSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Ambient Sounds
            VStack(alignment: .leading, spacing: 12) {
                Label("Ambient Sound", systemImage: "speaker.wave.2")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(settings.effectiveTextColor)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                    ForEach(["none", "rain", "coffeeshop", "ocean", "forest", "fireplace"], id: \.self) { sound in
                        AmbientSoundButton(
                            sound: sound,
                            isSelected: settings.ambientSound == sound,
                            textColor: settings.effectiveTextColor
                        ) {
                            settings.ambientSound = sound
                            if sound == "none" {
                                AmbientSoundPlayer.shared.stop()
                            } else if let ambientSound = AmbientSound(rawValue: sound.capitalized) {
                                AmbientSoundPlayer.shared.play(sound: ambientSound)
                            }
                        }
                    }
                }
                
                Text("Volume")
                    .font(.system(size: 12))
                    .foregroundColor(settings.effectiveTextColor.opacity(0.6))
                
                HStack {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 12))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.5))
                    
                    Slider(value: $settings.ambientVolume, in: 0...1)
                        .tint(Color.blue)
                        .disabled(settings.ambientSound == "none")
                    
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 12))
                        .foregroundColor(settings.effectiveTextColor.opacity(0.5))
                }
                
                Toggle("Show ambient visual effects", isOn: $settings.showAmbientVisuals)
                    .toggleStyle(.switch)
                    .tint(Color.blue)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetToDefaults() {
        settings.focusLevel = .sentence
        settings.typewriterMode = true
        settings.fontSize = 22
        settings.highlightIntensity = 0.4
        settings.colorScheme = .dark
        settings.wordGoal = 750
        settings.ambientSound = "none"
    }
}

// MARK: - Supporting Views

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let textColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? textColor : textColor.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    VStack(spacing: 0) {
                        Spacer()
                        if isSelected {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(height: 2)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

struct FocusLevelButton: View {
    let level: FocusModeSettings.FocusLevel
    let isSelected: Bool
    let textColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: level.icon)
                    .font(.system(size: 18))
                
                Text(level.rawValue)
                    .font(.system(size: 11))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(isSelected ? .white : textColor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : textColor.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

struct ColorSchemeButton: View {
    let scheme: FocusModeSettings.FocusColorScheme
    let isSelected: Bool
    let textColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(scheme.backgroundColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? Color.blue : textColor.opacity(0.2), lineWidth: isSelected ? 3 : 1)
                    )
                
                Text(scheme.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(textColor.opacity(0.8))
            }
        }
        .buttonStyle(.plain)
    }
}

struct AmbientSoundButton: View {
    let sound: String
    let isSelected: Bool
    let textColor: Color
    let action: () -> Void
    
    var icon: String {
        switch sound {
        case "none": return "speaker.slash"
        case "rain": return "cloud.rain"
        case "coffeeshop": return "cup.and.saucer"
        case "ocean": return "water.waves"
        case "forest": return "leaf"
        case "fireplace": return "flame"
        default: return "speaker"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : textColor.opacity(0.8))
                
                Text(sound.capitalized)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white : textColor.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : textColor.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}