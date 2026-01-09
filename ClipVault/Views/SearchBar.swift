import SwiftUI

/// Search bar component for filtering clipboard history.
/// Provides instant search with clear button and keyboard focus support.
struct SearchBar: View {

    // MARK: - Bindings

    @Binding var text: String

    // MARK: - State

    @FocusState private var isFocused: Bool

    // MARK: - Properties

    let placeholder: String
    var onSubmit: (() -> Void)?

    // MARK: - Initialization

    init(
        text: Binding<String>,
        placeholder: String = "Search...",
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))

            // Text field
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }

            // Clear button (visible when there's text)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
        .onAppear {
            // Auto-focus search bar when view appears
            isFocused = true
        }
    }
}

// MARK: - Convenience Modifiers

extension SearchBar {
    /// Set focus state programmatically
    func focused(_ focused: Bool) -> some View {
        self.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isFocused = focused
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SearchBar(text: .constant(""))
        SearchBar(text: .constant("Hello"))
        SearchBar(text: .constant(""), placeholder: "Filter items...")
    }
    .padding()
    .frame(width: 300)
}
