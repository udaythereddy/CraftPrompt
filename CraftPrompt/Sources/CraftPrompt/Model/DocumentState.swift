import AppKit
import Combine
import Foundation
import SwiftUI

public enum StatusState: Equatable, Sendable {
    case idle
    case translating
    case executing
    case rendering
    case error(String)

    public var title: String {
        switch self {
        case .idle: return "Ready"
        case .translating: return "Interpreting prompt..."
        case .executing: return "Applying PhotoCraft operations..."
        case .rendering: return "Rendering high-res viewport..."
        case .error(let msg): return "Error: \(msg)"
        }
    }

    public var badgeColor: Color {
        switch self {
        case .idle: return .green
        case .translating: return .purple
        case .executing: return .blue
        case .rendering: return .orange
        case .error: return .red
        }
    }
}

public enum InspectorTab: String, CaseIterable, Identifiable, Sendable {
    case layers = "Layers"
    case history = "History"
    case info = "Info"

    public var id: String { rawValue }
    public var sfSymbol: String {
        switch self {
        case .layers: return "square.3.layers.3d"
        case .history: return "clock.arrow.circlepath"
        case .info: return "info.circle"
        }
    }
}

@MainActor
public final class DocumentState: ObservableObject {
    @Published public var canvasImage: NSImage?
    @Published public var originalImage: NSImage?
    @Published public var isSplitComparisonActive: Bool = false
    @Published public var splitProgress: Double = 0.5 // 0.0 .. 1.0
    
    @Published public var documentURL: URL?
    @Published public var metadata: DocumentMetadata = DocumentMetadata()
    @Published public var layers: [LayerItem] = []
    @Published public var historySteps: [HistoryStep] = []
    
    @Published public var zoomScale: Double = 1.0
    @Published public var panOffset: CGSize = .zero
    @Published public var dragStartOffset: CGSize = .zero
    @Published public var isDropTargetHovering: Bool = false
    @Published public var selectedInspectorTab: InspectorTab = .layers

    @Published public var promptText: String = ""
    @Published public var isProcessing: Bool = false
    @Published public var status: StatusState = .idle
    @Published public var isInspectorVisible: Bool = true
    @Published public var isShowingExportSheet: Bool = false
    @Published public var isShowingSecuritySheet: Bool = false
    
    @Published public var canUndo: Bool = false
    @Published public var canRedo: Bool = false
    @Published public var selectedLayerId: Int? = nil
    @Published public var lastAppliedSummary: String? = nil

    public let client: PhotocraftClient
    public let translator: PromptTranslator
    private var stepCounter = 0

    public init(client: PhotocraftClient = PhotocraftClient(), translator: PromptTranslator = PromptTranslator()) {
        self.client = client
        self.translator = translator
    }

    // MARK: - Open Document

    public func openFile(url: URL) async {
        do {
            status = .rendering
            isProcessing = true
            
            let sanitizedURL = try PathSanitizer.sanitize(path: url.path)
            let meta = try await client.openDocument(at: sanitizedURL)
            let image = try await client.renderCanvas(maxSide: 2048)

            self.documentURL = sanitizedURL
            self.metadata = meta
            self.canvasImage = image
            self.originalImage = image // Store untouched base
            self.zoomScale = 1.0
            self.panOffset = .zero

            await refreshInspection()

            self.status = .idle
            self.isProcessing = false
        } catch {
            self.status = .error(error.localizedDescription)
            self.isProcessing = false
        }
    }

    public func createNewDocument(width: Int = 1920, height: Int = 1080) async {
        do {
            status = .rendering
            isProcessing = true
            try await client.newDocument(width: width, height: height, background: "white")
            let image = try await client.renderCanvas(maxSide: 2048)

            self.documentURL = nil
            self.metadata = DocumentMetadata(name: "Untitled", width: width, height: height, mode: "RGB", depth: 8, layersCount: 1)
            self.canvasImage = image
            self.originalImage = image
            self.zoomScale = 1.0
            self.panOffset = .zero

            await refreshInspection()
            self.status = .idle
            self.isProcessing = false
        } catch {
            self.status = .error(error.localizedDescription)
            self.isProcessing = false
        }
    }

    // MARK: - Prompt Submission

    public func submitPrompt(_ promptToRun: String? = nil) async {
        let text = (promptToRun ?? promptText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isProcessing else { return }

        isProcessing = true
        status = .translating
        let startTime = Date()

        let translation = await translator.translate(prompt: text)

        if translation.isUndo {
            await undo()
            promptText = ""
            isProcessing = false
            return
        }

        if translation.isRedo {
            await redo()
            promptText = ""
            isProcessing = false
            return
        }

        do {
            status = .executing
            
            if translation.commands.count == 1, let single = translation.commands.first {
                _ = try await client.execute(command: single.command, params: single.params)
            } else {
                _ = try await client.batch(steps: translation.commands)
            }

            status = .rendering
            let updatedImage = try await client.renderCanvas(maxSide: 2048)
            self.canvasImage = updatedImage
            self.lastAppliedSummary = translation.summary

            stepCounter += 1
            let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
            let newStep = HistoryStep(
                stepNumber: stepCounter,
                userPrompt: text,
                commandsDescription: translation.summary,
                commandNames: translation.commands.map { $0.command },
                durationMs: durationMs
            )
            historySteps.insert(newStep, at: 0)

            await refreshInspection()

            promptText = ""
            status = .idle
            isProcessing = false
        } catch {
            status = .error(error.localizedDescription)
            isProcessing = false
        }
    }

    // MARK: - Inspection & State Sync

    public func refreshInspection() async {
        do {
            let info = try await client.inspect()
            self.metadata = info.metadata
            self.layers = info.layers
            self.canUndo = info.canUndo
            self.canRedo = info.canRedo
            if let activeLayer = info.layers.first(where: { $0.active }) {
                self.selectedLayerId = activeLayer.id
            }
        } catch {
            print("Inspection failed: \(error)")
        }
    }

    // MARK: - History (Undo / Redo)

    public func undo() async {
        guard !isProcessing else { return }
        isProcessing = true
        status = .executing
        do {
            try await client.undo()
            status = .rendering
            let updatedImage = try await client.renderCanvas(maxSide: 2048)
            self.canvasImage = updatedImage
            await refreshInspection()
            status = .idle
            isProcessing = false
        } catch {
            status = .error("Undo failed: \(error.localizedDescription)")
            isProcessing = false
        }
    }

    public func redo() async {
        guard !isProcessing else { return }
        isProcessing = true
        status = .executing
        do {
            try await client.redo()
            status = .rendering
            let updatedImage = try await client.renderCanvas(maxSide: 2048)
            self.canvasImage = updatedImage
            await refreshInspection()
            status = .idle
            isProcessing = false
        } catch {
            status = .error("Redo failed: \(error.localizedDescription)")
            isProcessing = false
        }
    }

    // MARK: - Layer Actions

    public func toggleLayerVisibility(layer: LayerItem) async {
        do {
            try await client.setLayerProps(layerId: layer.id, visible: !layer.visible)
            let updatedImage = try await client.renderCanvas(maxSide: 2048)
            self.canvasImage = updatedImage
            await refreshInspection()
        } catch {
            status = .error("Visibility toggle failed: \(error.localizedDescription)")
        }
    }

    public func setLayerOpacity(layer: LayerItem, opacity: Double) async {
        do {
            try await client.setLayerProps(layerId: layer.id, opacity: opacity)
            let updatedImage = try await client.renderCanvas(maxSide: 2048)
            self.canvasImage = updatedImage
            await refreshInspection()
        } catch {
            status = .error("Opacity change failed: \(error.localizedDescription)")
        }
    }

    public func deleteLayer(layer: LayerItem) async {
        do {
            try await client.deleteLayer(layerId: layer.id)
            let updatedImage = try await client.renderCanvas(maxSide: 2048)
            self.canvasImage = updatedImage
            await refreshInspection()
        } catch {
            status = .error("Delete layer failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Export

    public func export(to destinationURL: URL, format: String = "png", quality: Int = 90) async throws {
        let sanitizedURL = try PathSanitizer.sanitize(path: destinationURL.path)
        try await client.save(to: sanitizedURL, format: format, quality: quality)
    }

    // MARK: - Viewport Navigation

    public func zoomIn() {
        zoomScale = min(zoomScale * 1.25, 16.0)
    }

    public func zoomOut() {
        zoomScale = max(zoomScale / 1.25, 0.1)
    }

    public func zoomToActual() {
        zoomScale = 1.0
        panOffset = .zero
    }

    public func zoomToFit(viewportSize: CGSize) {
        guard let img = canvasImage, img.size.width > 0, img.size.height > 0 else {
            zoomScale = 1.0
            panOffset = .zero
            return
        }

        let horizontalScale = (viewportSize.width - 40) / img.size.width
        let verticalScale = (viewportSize.height - 40) / img.size.height
        zoomScale = min(horizontalScale, verticalScale, 1.0)
        panOffset = .zero
    }
}
