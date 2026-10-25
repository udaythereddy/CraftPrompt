import SwiftUI

public struct FloatingPromptBar: View {
    @ObservedObject var state: DocumentState
    @FocusState private var isPromptFocused: Bool

    private let suggestions = [
        "Warm Sunset",
        "Moody B&W",
        "Pop Colors",
        "Soft Dreamy Glow",
        "Cyberpunk Neon",
        "Crisp Sharpen",
        "Vintage Film"
    ]

    public init(state: DocumentState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Suggestion Chips (horizontal scroll)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            state.promptText = suggestion
                            Task {
                                await state.submitPrompt(suggestion)
                            }
                        } label: {
                            Text(suggestion)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                        )
                        .disabled(state.isProcessing)
                    }
                }
                .padding(.horizontal, 4)
            }

            // Main Input Capsule
            HStack(spacing: 12) {
                // Status Indicator Pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(state.status.badgeColor)
                        .frame(width: 8, height: 8)
                        .opacity(state.isProcessing ? 0.8 : 1.0)
                        .scaleEffect(state.isProcessing ? 1.2 : 1.0)
                        .animation(
                            state.isProcessing ? Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default,
                            value: state.isProcessing
                        )

                    Text(state.status.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05), in: Capsule())

                // Prompt Text Field
                TextField("Describe edits (e.g. 'warm up the sunset, boost vibrance, and blur background')...", text: $state.promptText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isPromptFocused)
                    .onSubmit {
                        Task {
                            await state.submitPrompt()
                        }
                    }
                    .disabled(state.isProcessing)

                // Quick Undo / Redo
                HStack(spacing: 4) {
                    Button {
                        Task { await state.undo() }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(!state.canUndo || state.isProcessing)
                    .help("Undo (Cmd+Z)")

                    Button {
                        Task { await state.redo() }
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(!state.canRedo || state.isProcessing)
                    .help("Redo (Shift+Cmd+Z)")
                }

                // Submit Button
                Button {
                    Task {
                        await state.submitPrompt()
                    }
                } label: {
                    ZStack {
                        if state.isProcessing {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                        }
                    }
                }
                .buttonStyle(.plain)
                .background(state.promptText.isEmpty ? Color.secondary.opacity(0.3) : Color.accentColor, in: Circle())
                .disabled(state.promptText.isEmpty || state.isProcessing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 14, x: 0, y: 6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}
