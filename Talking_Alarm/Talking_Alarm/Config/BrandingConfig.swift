import SwiftUI

// MARK: - Branding Configuration
/// Centralized design tokens for consistent styling across the app.
/// All views should reference these values instead of hardcoding.

enum Brand {
    
    // MARK: - Colors
    
    enum Colors {
        /// Deep space blue background - RGB(0.05, 0.05, 0.1)
        static let background = Color(red: 0.05, green: 0.05, blue: 0.1)
        
        /// Primary text color
        static let textPrimary = Color.white
        
        /// Secondary text color (labels, hints)
        static let textSecondary = Color.white.opacity(0.7)
        
        /// Tertiary text color (very subtle hints)
        static let textTertiary = Color.white.opacity(0.5)
        
        /// Muted text color (disabled, footer hints)
        static let textMuted = Color.white.opacity(0.3)
        
        /// Success color
        static let success = Color.green
        
        /// Error/destructive color
        static let error = Color.red
        
        /// Accent color for selections
        static let accent = Color.blue
    }
    
    // MARK: - Button Styles
    
    enum Button {
        /// Standard button background opacity
        static let backgroundOpacity: Double = 0.1
        
        /// Standard button stroke opacity
        static let strokeOpacity: Double = 0.12
        
        /// Standard button corner radius
        static let cornerRadius: CGFloat = 16
        
        /// Large button corner radius (primary CTAs)
        static let cornerRadiusLarge: CGFloat = 20
        
        /// Standard button height
        static let height: CGFloat = 56
        
        /// Compact button height (settings rows)
        static let heightCompact: CGFloat = 52
        
        /// Disabled state opacity
        static let disabledOpacity: Double = 0.45
        
        /// Button font
        static let font = Font.system(size: 17, weight: .semibold)
    }
    
    // MARK: - Card/Container Styles
    
    enum Card {
        /// Card background opacity
        static let backgroundOpacity: Double = 0.05
        
        /// Card stroke opacity
        static let strokeOpacity: Double = 0.08
        
        /// Card corner radius
        static let cornerRadius: CGFloat = 16
        
        /// Row background opacity (slightly more visible)
        static let rowBackgroundOpacity: Double = 0.08
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        /// Standard horizontal padding
        static let horizontal: CGFloat = 24
        
        /// Large horizontal padding (drawers)
        static let horizontalLarge: CGFloat = 30
        
        /// Standard vertical padding
        static let vertical: CGFloat = 16
        
        /// Safe area top padding
        static let safeAreaTop: CGFloat = 60
        
        /// Bottom padding for navigation controls
        static let bottomNavigation: CGFloat = 40
        
        /// Standard gap between elements
        static let gap: CGFloat = 16
        
        /// Large gap between sections
        static let gapLarge: CGFloat = 24
    }
    
    // MARK: - Typography
    
    enum Typography {
        /// Header tracking (letter spacing)
        static let headerTracking: CGFloat = 2
        
        /// Caption tracking
        static let captionTracking: CGFloat = 1.5
        
        /// Large title font
        static let largeTitle = Font.largeTitle.bold()
        
        /// Section header font
        static let sectionHeader = Font.headline
        
        /// Body font
        static let body = Font.body
        
        /// Caption font
        static let caption = Font.caption
        
        /// Small caption font
        static let caption2 = Font.caption2
    }
    
    // MARK: - Icon Sizes
    
    enum Icon {
        /// Standard icon frame width
        static let frameWidth: CGFloat = 30
        
        /// Navigation icon font
        static let navigationFont = Font.title2
    }
}

// MARK: - Convenience Extensions

extension Color {
    /// App background color
    static var appBackground: Color { Brand.Colors.background }
}

extension View {
    /// Apply standard card styling
    func cardStyle() -> some View {
        self
            .background(Color.white.opacity(Brand.Card.backgroundOpacity))
            .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Card.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(Brand.Card.strokeOpacity), lineWidth: 1)
            )
    }
    
    /// Apply standard row styling (slightly more visible than card)
    func rowStyle() -> some View {
        self
            .background(Color.white.opacity(Brand.Card.rowBackgroundOpacity))
            .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Card.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(Brand.Card.strokeOpacity), lineWidth: 1)
            )
    }
}
