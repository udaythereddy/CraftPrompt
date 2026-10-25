import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct ContentView: View {
    @StateObject private var state = DocumentState()

    public init() {}

    public var body: some View {
        HSplitView {
            // Main Center Viewport with Floating Prompt Bar
            ZStack(alignment: .bottom) {
                CanvasViewportView(state: state)

                // Floating Prompt Bar (visible when document or canvas is present)
                FloatingPromptBar(state: state)
            }
            .frame(minWidth: 480, idealWidth: 800)

            // Right Inspector Drawer (collapsible)
            if state.isInspectorVisible {
                InspectorDrawer(state: state)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                // Open File
                Button {
                    openFileDialog()
                } label: {
                    Label("Open Image", systemImage: "photo")
                }
                .help("Open Image (Cmd+O)")

                // New Blank Canvas
                Button {
                    Task {
                        await state.createNewDocument()
                    }
                } label: {
                    Label("New Canvas", systemImage: "plus.rectangle")
                }
                .help("New Blank Canvas (Cmd+N)")
            }

            ToolbarItemGroup(placement: .principal) {
                if let doc = state.documentURL {
                    Text(doc.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                } else if state.canvasImage != nil {
                    Text("Untitled Project")
                        .font(.headline)
                }
            }

            ToolbarItemGroup(placement: .automatic) {
                // Undo / Redo
                Button {
                    Task { await state.undo() }
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!state.canUndo || state.isProcessing)
                .keyboardShortcut("z", modifiers: .command)

                Button {
                    Task { await state.redo() }
                } label: {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .disabled(!state.canRedo || state.isProcessing)
                .keyboardShortcut("z", modifiers: [.command, .shift])

                Divider()

                // Security Audit
                Button {
                    state.isShowingSecuritySheet = true
                } label: {
                    Label("Security Audit", systemImage: "shield.lefthalf.filled")
                }
                .help("Open Security & Safety Audit Dashboard")

                // Export As...
                Button {
                    state.isShowingExportSheet = true
                } label: {
                    Label("Export As...", systemImage: "square.and.arrow.up")
                }
                .disabled(state.canvasImage == nil || state.isProcessing)
                .keyboardShortcut("e", modifiers: [.command, .shift])

                // Toggle Inspector
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        state.isInspectorVisible.toggle()
                    }
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.right")
                }
                .help("Toggle Layer & History Inspector")
            }
        }
        .sheet(isPresented: $state.isShowingExportSheet) {
            ExportSheet(state: state)
        }
        .sheet(isPresented: $state.isShowingSecuritySheet) {
            SecurityAuditView()
        }
        .onOpenURL { url in
            Task {
                await state.openFile(url: url)
            }
        }
    }

    private func openFileDialog() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowedContentTypes = [
            .png, .jpeg, .tiff,
            UTType(filenameExtension: "psd") ?? .data,
            UTType(filenameExtension: "webp") ?? .data,
            UTType(filenameExtension: "pcraft") ?? .data
        ]

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await state.openFile(url: url)
            }
        }
    }
}
