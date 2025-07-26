import SwiftUI

// MARK: - Responsive Onboarding Button

/// A responsive button that adapts to content and screen size
struct OnboardingButton: View {
    enum Style {
        case primary
        case secondary
        case text
    }
    
    let title: String
    let icon: String?
    let style: Style
    let isLoading: Bool
    let action: () -> Void
    
    init(
        _ title: String,
        icon: String? = nil,
        style: Style = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }
    
    @Environment(\.isEnabled) private var isEnabled
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(
                            tint: style == .primary ? .black : .white
                        ))
                        .scaleEffect(0.8)
                } else {
                    HStack(spacing: 12) {
                        if let icon = icon {
                            Image(systemName: icon)
                                .font(.system(size: fontSize - 2, weight: fontWeight))
                        }
                        
                        Text(title)
                            .font(.system(size: fontSize, weight: fontWeight))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .foregroundColor(foregroundColor)
            .frame(minWidth: minWidth, idealWidth: idealWidth, minHeight: minHeight)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(background)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
            .animation(.spring(response: 0.2), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
    
    // MARK: - Style Properties
    
    private var fontSize: CGFloat {
        switch style {
        case .primary: return 18
        case .secondary: return 16
        case .text: return 14
        }
    }
    
    private var fontWeight: Font.Weight {
        switch style {
        case .primary: return .semibold
        case .secondary, .text: return .medium
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary: return .black
        case .secondary: return .white
        case .text: return .white.opacity(0.6)
        }
    }
    
    private var minWidth: CGFloat {
        switch style {
        case .primary: return 180
        case .secondary: return 120
        case .text: return 80
        }
    }
    
    private var idealWidth: CGFloat {
        switch style {
        case .primary: return 280
        case .secondary: return 200
        case .text: return 120
        }
    }
    
    private var minHeight: CGFloat {
        switch style {
        case .primary: return 56
        case .secondary: return 48
        case .text: return 36
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch style {
        case .primary: return 32
        case .secondary: return 24
        case .text: return 16
        }
    }
    
    private var verticalPadding: CGFloat {
        switch style {
        case .primary: return 0
        case .secondary: return 0
        case .text: return 0
        }
    }
    
    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            Capsule()
                .fill(Color.white)
                .shadow(color: .white.opacity(0.3), radius: 20, y: 10)
        case .secondary:
            Capsule()
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
        case .text:
            Color.clear
        }
    }
}

// MARK: - Password Field Component

/// A beautiful, consistent password field with built-in validation
struct OnboardingPasswordField: View {
    let placeholder: String
    @Binding var text: String
    let showPasswordToggle: Bool
    @State private var showPassword = false
    let validationIcon: String?
    let validationColor: Color?
    
    var body: some View {
        HStack {
            Image(systemName: "lock.fill")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.5))
            
            Group {
                if showPassword {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .textContentType(.password)
                        .autocorrectionDisabled(true)
                } else {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled(true)
                }
            }
            .font(.system(size: 18))
            
            Spacer()
            
            HStack(spacing: 12) {
                if let icon = validationIcon, let color = validationColor {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.3), value: icon)
                }
                
                if showPasswordToggle {
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Step Progress Indicator

/// A visual step progress indicator for multi-step flows
struct StepProgressIndicator: View {
    let totalSteps: Int
    let currentStep: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(currentStep == index ? Color.white : Color.white.opacity(0.3))
                    .frame(width: currentStep == index ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentStep)
            }
        }
    }
}

// MARK: - Feature Card

/// A reusable card component for displaying features or requirements
struct OnboardingFeatureCard: View {
    let items: [(icon: String, text: String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(items.indices, id: \.self) { index in
                Label(items[index].text, systemImage: items[index].icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Error State View

/// A consistent error state view for onboarding flows
struct OnboardingErrorView: View {
    let title: String
    let message: String
    let primaryAction: (title: String, action: () -> Void)?
    let secondaryAction: (title: String, action: () -> Void)?
    let diagnosticsAction: (() -> Void)?
    
    init(
        title: String,
        message: String,
        primaryAction: (title: String, action: () -> Void)? = nil,
        secondaryAction: (title: String, action: () -> Void)? = nil,
        diagnosticsAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.diagnosticsAction = diagnosticsAction
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Error icon with animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.orange.opacity(0.5), radius: 20)
            }
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if primaryAction != nil || secondaryAction != nil {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        if let secondary = secondaryAction {
                            OnboardingButton(
                                secondary.title,
                                style: .secondary,
                                action: secondary.action
                            )
                        }
                        
                        if let primary = primaryAction {
                            OnboardingButton(
                                primary.title,
                                style: .primary,
                                action: primary.action
                            )
                        }
                    }
                    
                    if let diagnostics = diagnosticsAction {
                        Button {
                            diagnostics()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "stethoscope")
                                    .font(.caption)
                                Text("Run Diagnostics")
                                    .font(.caption)
                            }
                            .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Loading State View

/// A beautiful loading state for onboarding processes
struct OnboardingLoadingView: View {
    let title: String
    let subtitle: String?
    
    @State private var rotationAngle = 0.0
    
    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .stroke(lineWidth: 4)
                    .foregroundColor(.white.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(
                        .linear(duration: 1)
                        .repeatForever(autoreverses: false),
                        value: rotationAngle
                    )
            }
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .onAppear {
            rotationAngle = 360
        }
    }
}