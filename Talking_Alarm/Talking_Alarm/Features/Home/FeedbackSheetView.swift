import SwiftUI

struct FeedbackSheetView: View {
    @Binding var text: String
    let helperText: String
    let maxLength: Int
    let isSending: Bool
    let isValid: Bool
    let onSend: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool
    @State private var didScheduleFocus = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Brand.Spacing.gap) {
                TextField("Share your feedback", text: $text, axis: .vertical)
                    .focused($isFocused)
                    .lineLimit(4...12)
                    .font(Brand.Typography.body)
                    .foregroundStyle(Brand.Colors.textPrimary)
                    .padding(Brand.Spacing.gap)
                    .frame(minHeight: Brand.Button.height * 2.5, alignment: .topLeading)
                    .background(Color.white.opacity(Brand.Card.rowBackgroundOpacity))
                    .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Brand.Card.cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(Brand.Card.strokeOpacity), lineWidth: 1)
                    )

                HStack(alignment: .top, spacing: Brand.Spacing.gap) {
                    Text(helperText)
                        .font(Brand.Typography.caption)
                        .foregroundStyle(Brand.Colors.textSecondary)

                    Spacer(minLength: Brand.Spacing.gap)

                    Text("\(text.count)/\(maxLength)")
                        .font(Brand.Typography.caption2)
                        .foregroundStyle(Brand.Colors.textMuted)
                }
            }
            .padding(.horizontal, Brand.Spacing.horizontal)
            .padding(.top, Brand.Spacing.vertical)
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send", action: onSend)
                        .disabled(!isValid || isSending)
                }
            }
        }
        .task {
            guard didScheduleFocus == false else { return }
            didScheduleFocus = true
            try? await Task.sleep(for: .milliseconds(220))
            isFocused = true
        }
        .onDisappear {
            isFocused = false
            didScheduleFocus = false
        }
    }
}
