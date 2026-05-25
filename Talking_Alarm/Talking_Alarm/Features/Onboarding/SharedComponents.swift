import SwiftUI

// MARK: - OnboardingHeader

/// A consistent header component for onboarding screens.
/// Uses Brand tokens for consistent styling.
struct OnboardingHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(Brand.Typography.largeTitle)
                .foregroundStyle(Brand.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            Text(subtitle)
                .font(Brand.Typography.body)
                .foregroundStyle(Brand.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - DarkTextField

/// A custom TextField styled for dark theme consistency.
/// Uses Brand tokens for consistent styling.
struct DarkTextField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(Brand.Colors.textPrimary)
            .padding(.horizontal, Brand.Spacing.vertical)
            .padding(.vertical, 14)
            .background(Color.white.opacity(Brand.Card.rowBackgroundOpacity))
            .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Card.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(Brand.Button.strokeOpacity), lineWidth: 1)
            )
    }
}

// MARK: - GlassButton

/// A reusable glass-morphic button component matching the main app's design language.
/// Uses Brand tokens for consistent styling.
struct GlassButton: View {
    let title: String
    let icon: String?
    let isEnabled: Bool
    let isPrimary: Bool
    let action: () -> Void
    
    init(
        title: String,
        icon: String? = nil,
        isEnabled: Bool = true,
        isPrimary: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.isPrimary = isPrimary
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(Brand.Button.font)
            .foregroundStyle(Brand.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: Brand.Button.height)
            .background(Color.white.opacity(Brand.Button.backgroundOpacity))
            .clipShape(.rect(cornerRadius: Brand.Button.cornerRadiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Button.cornerRadiusLarge, style: .continuous)
                    .stroke(Color.white.opacity(Brand.Button.strokeOpacity), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : Brand.Button.disabledOpacity)
    }
}

// MARK: - Previews

#Preview("GlassButton - Primary Enabled") {
    ZStack {
        LinearGradient(
            colors: [Color.black, Color.gray.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        VStack(spacing: 20) {
            GlassButton(
                title: "Continue",
                isEnabled: true,
                isPrimary: true
            ) {
                DebugLogger.log("Primary button tapped")
            }
            .padding(.horizontal, 24)
            
            GlassButton(
                title: "Get Started",
                icon: "arrow.right",
                isEnabled: true,
                isPrimary: true
            ) {
                DebugLogger.log("Primary with icon tapped")
            }
            .padding(.horizontal, 24)
        }
    }
}

#Preview("GlassButton - Secondary") {
    ZStack {
        LinearGradient(
            colors: [Color.black, Color.gray.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        VStack(spacing: 20) {
            GlassButton(
                title: "Back",
                isEnabled: true,
                isPrimary: false
            ) {
                DebugLogger.log("Secondary button tapped")
            }
            .frame(width: 100)
            
            GlassButton(
                title: "Cancel",
                icon: "xmark",
                isEnabled: true,
                isPrimary: false
            ) {
                DebugLogger.log("Secondary with icon tapped")
            }
            .frame(width: 140)
        }
    }
}

#Preview("GlassButton - Disabled States") {
    ZStack {
        LinearGradient(
            colors: [Color.black, Color.gray.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        VStack(spacing: 20) {
            GlassButton(
                title: "Continue",
                isEnabled: false,
                isPrimary: true
            ) {
                DebugLogger.log("Should not print - disabled")
            }
            .padding(.horizontal, 24)
            
            GlassButton(
                title: "Back",
                isEnabled: false,
                isPrimary: false
            ) {
                DebugLogger.log("Should not print - disabled")
            }
            .frame(width: 100)
        }
    }
}

#Preview("DarkTextField - Empty") {
    ZStack {
        LinearGradient(
            colors: [Color.black, Color.gray.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        VStack(spacing: 20) {
            DarkTextField(
                placeholder: "Enter your name",
                text: .constant("")
            )
            .padding(.horizontal, 24)
            
            DarkTextField(
                placeholder: "What's your goal?",
                text: .constant("")
            )
            .padding(.horizontal, 24)
        }
    }
}

#Preview("DarkTextField - With Text") {
    ZStack {
        LinearGradient(
            colors: [Color.black, Color.gray.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        VStack(spacing: 20) {
            DarkTextField(
                placeholder: "Enter your name",
                text: .constant("John")
            )
            .padding(.horizontal, 24)
            
            DarkTextField(
                placeholder: "What's your goal?",
                text: .constant("Wake up feeling energized and ready to tackle the day!")
            )
            .padding(.horizontal, 24)
        }
    }
}


#Preview("OnboardingHeader - Welcome") {
    ZStack {
        LinearGradient(
            colors: [Color.black, Color.gray.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        OnboardingHeader(
            title: "Welcome to Rouse",
            subtitle: "Your AI-powered wake-up companion that helps you start each day with energy and purpose."
        )
        .padding(.horizontal, 24)
    }
}

#Preview("OnboardingHeader - Permissions") {
    ZStack {
        LinearGradient(
            colors: [Color.black, Color.gray.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        OnboardingHeader(
            title: "Permissions",
            subtitle: "We need a few permissions to wake you up and have a conversation."
        )
        .padding(.horizontal, 24)
    }
}

#Preview("OnboardingHeader - Short Text") {
    ZStack {
        LinearGradient(
            colors: [Color.black, Color.gray.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        OnboardingHeader(
            title: "What's Your Name?",
            subtitle: "So we can personalize your experience."
        )
        .padding(.horizontal, 24)
    }
}
