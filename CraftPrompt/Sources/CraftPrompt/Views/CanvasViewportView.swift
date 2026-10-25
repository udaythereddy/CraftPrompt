import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct CanvasViewportView: View {
    @ObservedObject var state: DocumentState

    public init(state: DocumentState) {
        self.state = state
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Background dark neutral grid / pasteboard
                Color(nsColor: .underPageBackgroundColor)
                    .ignoresSafeArea()

                if let currentImage = state.canvasImage {
                    ZStack {
                        if state.isSplitComparisonActive, let original = state.originalImage {
                            // Split Before/After View
                            SplitComparisonView(
                                original: original,
                                edited: currentImage,
                                splitProgress: $state.splitProgress
                            )
                        } else {
                            // Standard High-Resolution Image Canvas
                            Image(nsImage: currentImage)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                    .frame(
                        width: max(currentImage.size.width * state.zoomScale, 10),
                        height: max(currentImage.size.height * state.zoomScale, 10)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
                    .offset(x: state.panOffset.width, y: state.panOffset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                state.panOffset = CGSize(
                                    width: state.dragStartOffset.width + value.translation.width,
                                    height: state.dragStartOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                state.dragStartOffset = state.panOffset
                            }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale in
                                state.zoomScale = min(max(state.zoomScale * scale, 0.1), 16.0)
                            }
                    )
                } else {
                    // Empty State: Drag & Drop Zone
                    EmptyDropZoneView(state: state)
                }

                // Canvas HUD (Zoom level, Dimensions, Coordinates)
                VStack {
                    HStack {
                        if let img = state.canvasImage {
                            CanvasInfoHUD(
                                width: Int(img.size.width),
                                height: Int(img.size.height),
                                zoom: state.zoomScale,
                                onFit: { state.zoomToFit(viewportSize: proxy.size) },
                                onActual: { state.zoomToActual() },
                                onZoomIn: { state.zoomIn() },
                                onZoomOut: { state.zoomOut() }
                            )
                        }
                        Spacer()
                        
                        if state.canvasImage != nil {
                            // Before / After Comparison Toggle
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    state.isSplitComparisonActive.toggle()
                                }
                            } label: {
                                Label(
                                    state.isSplitComparisonActive ? "Split: ON" : "Compare Before/After",
                                    systemImage: state.isSplitComparisonActive ? "rectangle.split.2x1.fill" : "rectangle.split.2x1"
                                )
                                .font(.caption.weight(.medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(state.isSplitComparisonActive ? .accentColor : .secondary)
                            .padding(.trailing, 16)
                            .padding(.top, 14)
                        }
                    }
                    Spacer()
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in
                await state.openFile(url: url)
            }
        }
        return true
    }
}

// MARK: - Split Comparison View

struct SplitComparisonView: View {
    let original: NSImage
    let edited: NSImage
    @Binding var splitProgress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Edited image (full background)
                Image(nsImage: edited)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)

                // Original image (clipped by split progress)
                Image(nsImage: original)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle()
                                .frame(width: max(geo.size.width * splitProgress, 0))
                            Spacer(minLength: 0)
                        }
                    )

                // Divider line with draggable thumb
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 0)
                    .offset(x: max(geo.size.width * splitProgress - 1, 0))
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                            .overlay(
                                Image(systemName: "arrow.left.and.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.black)
                            )
                            .offset(x: max(geo.size.width * splitProgress - 14, 0))
                            .gesture(
                                DragGesture()
                                    .onChanged { val in
                                        let progress = val.location.x / geo.size.width
                                        splitProgress = min(max(progress, 0.0), 1.0)
                                    }
                            )
                    )
            }
        }
    }
}

// MARK: - Empty State Drop Zone

struct EmptyDropZoneView: View {
    @ObservedObject var state: DocumentState

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 96, height: 96)
                
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 6) {
                Text("Drop Any Image to Begin")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)

                Text("Supports PNG, JPG, TIFF, PSD, WebP, EXR & PCRAFT")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    openFileDialog()
                } label: {
                    Label("Choose Image...", systemImage: "folder")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    Task {
                        await state.createNewDocument()
                    }
                } label: {
                    Label("New Blank Canvas", systemImage: "plus.rectangle")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(48)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    Color.accentColor.opacity(state.isDropTargetHovering ? 0.6 : 0.2),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 8])
                )
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.6))
                )
        )
        .padding(32)
        .onDrop(of: [.fileURL], isTargeted: $state.isDropTargetHovering) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    await state.openFile(url: url)
                }
            }
            return true
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
            Task { @MainActor in
                await state.openFile(url: url)
            }
        }
    }
}

// MARK: - Canvas Info HUD

struct CanvasInfoHUD: View {
    let width: Int
    let height: Int
    let zoom: Double
    let onFit: () -> Void
    let onActual: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(width) × \(height) px")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 12)

            Text("\(Int((zoom * 100).rounded()))%")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)

            HStack(spacing: 4) {
                Button(action: onZoomOut) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)

                Button(action: onZoomIn) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
            }

            Divider()
                .frame(height: 12)

            Button("Fit", action: onFit)
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))

            Button("100%", action: onActual)
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.leading, 16)
        .padding(.top, 14)
    }
}
