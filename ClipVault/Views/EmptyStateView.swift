import SwiftUI

/// Placeholder view displayed when clipboard history is empty.
/// Shows a friendly message and hint about how to start using the app.
struct EmptyStateView: View {

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Icon
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            // Title
            Text("No Clipboard History")
                .font(.headline)
                .foregroundStyle(.primary)

            // Description
            Text("Copy something to get started.\nYour clipboard history will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()

            // Hint about hotkey
            HStack(spacing: 4) {
                Text("Tip: Use")
                    .foregroundStyle(.secondary)
                KeyboardShortcutView(shortcut: "⌘⇧V")
                Text("to show EdaBoard anytime")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Small view for displaying a keyboard shortcut with styling
struct KeyboardShortcutView: View {
    let shortcut: String

    var body: some View {
        Text(shortcut)
            .font(.caption.monospaced())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
    }
}

#Preview {
    EmptyStateView()
        .frame(width: 320, height: 400)
}
