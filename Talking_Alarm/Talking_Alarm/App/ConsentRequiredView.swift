import SwiftUI

/// Consent required view shown when AI consent has been revoked.
/// Uses glass-morphic styling and dark mode only.
/// **Requirements: 1.2, 2.4, 8.1, 8.2, 8.3**
struct ConsentRequiredView: View {
    let onEnableAI: () -> Void
    let onDeleteAccount: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.white)

                Text("AI Consent Required")
                    .font(.title)
                    .bold()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("This app cannot function without AI calls, which you did not consent to.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                GlassButton(
                    title: "Enable AI Calls",
                    icon: "checkmark.circle.fill",
                    isEnabled: true,
                    isPrimary: true
                ) {
                    onEnableAI()
                }
                .padding(.horizontal, 24)

                // Delete button with red tint
                Button {
                    onDeleteAccount()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "trash.fill")
                        Text("Delete Account")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.15))
                    .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Brand.Card.cornerRadius, style: .continuous)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            Brand.Colors.background
                .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
    }
}
