import SwiftUI

public struct InspectorDrawer: View {
    @ObservedObject var state: DocumentState

    public init(state: DocumentState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Segmented Control
            Picker("Inspector View", selection: $state.selectedInspectorTab) {
                ForEach(InspectorTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.sfSymbol).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)

            Divider()

            // Tab Content
            switch state.selectedInspectorTab {
            case .layers:
                LayersTabContent(state: state)
            case .history:
                HistoryTabContent(state: state)
            case .info:
                DocumentInfoTabContent(state: state)
            }
        }
        .frame(minWidth: 260, idealWidth: 280, maxWidth: 360)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Layers Tab Content

struct LayersTabContent: View {
    @ObservedObject var state: DocumentState

    var body: some View {
        VStack(spacing: 0) {
            if state.layers.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No Layers Loaded")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(selection: $state.selectedLayerId) {
                    ForEach(state.layers) { layer in
                        LayerRowView(layer: layer, state: state)
                            .tag(layer.id)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

// MARK: - Layer Row View

struct LayerRowView: View {
    let layer: LayerItem
    @ObservedObject var state: DocumentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Visibility Eye Toggle
                Button {
                    Task {
                        await state.toggleLayerVisibility(layer: layer)
                    }
                } label: {
                    Image(systemName: layer.visible ? "eye" : "eye.slash")
                        .font(.system(size: 12))
                        .foregroundColor(layer.visible ? .primary : .secondary.opacity(0.5))
                        .frame(width: 18)
                }
                .buttonStyle(.plain)

                // Layer Kind Icon
                Image(systemName: layer.kind.sfSymbol)
                    .font(.system(size: 13))
                    .foregroundColor(layer.kind == .adjustment ? .accentColor : .secondary)

                // Layer Name
                Text(layer.name)
                    .font(.system(size: 12, weight: layer.active ? .semibold : .regular))
                    .lineLimit(1)

                Spacer()

                // Blend mode badge
                Text(layer.blendMode)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))

                // Delete Layer Button
                Button {
                    Task {
                        await state.deleteLayer(layer: layer)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Opacity Slider (shown for selected layer)
            if state.selectedLayerId == layer.id {
                HStack(spacing: 8) {
                    Text("Opacity")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Slider(
                        value: Binding(
                            get: { layer.opacity },
                            set: { newOpacity in
                                Task {
                                    await state.setLayerOpacity(layer: layer, opacity: newOpacity)
                                }
                            }
                        ),
                        in: 0.0...1.0
                    )
                    .controlSize(.mini)

                    Text("\(Int((layer.opacity * 100).rounded()))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.leading, 26)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - History Tab Content

struct HistoryTabContent: View {
    @ObservedObject var state: DocumentState

    var body: some View {
        VStack(spacing: 0) {
            if state.historySteps.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No Edits Yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Prompts and tool operations will appear here.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                }
            } else {
                List {
                    ForEach(state.historySteps) { step in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("#\(step.stepNumber)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.accentColor)

                                Text(step.formattedTime)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(step.durationMs)ms")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            Text("\"\(step.userPrompt)\"")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)

                            Text(step.commandsDescription)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            // Commands pills
                            HStack(spacing: 4) {
                                ForEach(step.commandNames, id: \.self) { cmd in
                                    Text(cmd.replacingOccurrences(of: "layer.newAdjustmentLayer.", with: "adj:")
                                            .replacingOccurrences(of: "filter.", with: "fx:"))
                                        .font(.system(size: 9, design: .monospaced))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

// MARK: - Document Info Tab Content

struct DocumentInfoTabContent: View {
    @ObservedObject var state: DocumentState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                InfoSection(title: "Canvas") {
                    InfoRow(label: "Dimensions", value: "\(state.metadata.width) × \(state.metadata.height) px")
                    InfoRow(label: "Color Mode", value: state.metadata.mode)
                    InfoRow(label: "Bit Depth", value: "\(state.metadata.depth)-bit")
                    InfoRow(label: "Layers Count", value: "\(state.layers.count)")
                }

                InfoSection(title: "File") {
                    InfoRow(label: "File Name", value: state.documentURL?.lastPathComponent ?? "Untitled")
                    InfoRow(label: "Path", value: state.documentURL?.path ?? "Memory Canvas")
                }

                InfoSection(title: "Backend Engine") {
                    InfoRow(label: "Core Engine", value: "storytold/photocraft (Rust)")
                    InfoRow(label: "Transport", value: "photocraft-cli stdio serve")
                    InfoRow(label: "Local Execution", value: "Active (Localhost)")
                }
            }
            .padding(16)
        }
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 6) {
                content
            }
            .padding(10)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
