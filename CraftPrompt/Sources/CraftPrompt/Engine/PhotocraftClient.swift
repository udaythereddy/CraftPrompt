import AppKit
import Foundation

public actor PhotocraftClient {
    private var process: PhotocraftProcess?
    private var requestIdCounter = 0
    private var activeDocumentPath: URL?
    private var customBinaryPath: String?

    public init(customBinaryPath: String? = nil) {
        self.customBinaryPath = customBinaryPath
    }

    private func nextRequestId() -> String {
        requestIdCounter += 1
        return "\(requestIdCounter)"
    }

    public func ensureStarted(workingDirectory: URL? = nil) async throws {
        if process == nil {
            let root = workingDirectory ?? FileManager.default.temporaryDirectory
            let proc = PhotocraftProcess(
                mode: .serve,
                customBinaryPath: customBinaryPath,
                readRoot: root,
                writeRoot: root
            )
            try await proc.start()
            self.process = proc
        }
    }

    public func restart(workingDirectory: URL? = nil) async throws {
        await process?.stop()
        process = nil
        try await ensureStarted(workingDirectory: workingDirectory)
    }

    public func shutdown() async {
        await process?.stop()
        process = nil
    }

    // MARK: - Core RPC Methods

    public func call(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        try await ensureStarted()
        guard let proc = process else {
            throw NSError(domain: "PhotocraftClient", code: 10, userInfo: [NSLocalizedDescriptionKey: "Photocraft process not available."])
        }

        let reqId = nextRequestId()
        let requestDict: [String: Any] = [
            "id": reqId,
            "method": method,
            "params": params
        ]

        let data = try JSONSerialization.data(withJSONObject: requestDict, options: [])
        guard let line = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "PhotocraftClient", code: 11, userInfo: [NSLocalizedDescriptionKey: "Could not format JSON line."])
        }

        let responseData = try await proc.send(line: line, expectedRequestId: reqId)
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw NSError(domain: "PhotocraftClient", code: 12, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response from Photocraft."])
        }

        if let ok = json["ok"] as? Bool, !ok {
            let errorMsg = json["error"] as? String ?? "Unknown Photocraft error"
            throw NSError(domain: "PhotocraftClient", code: 13, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        if let result = json["result"] as? [String: Any] {
            return result
        }

        if let boolResult = json["result"] as? Bool {
            return ["success": boolResult]
        }

        return json
    }

    // MARK: - Document Operations

    public func openDocument(at fileURL: URL) async throws -> DocumentMetadata {
        // Ensure process has readRoot and writeRoot enclosing this file's folder
        let parentDir = fileURL.deletingLastPathComponent()
        try await restart(workingDirectory: parentDir)

        activeDocumentPath = fileURL
        let relativePath = fileURL.lastPathComponent
        _ = try await call(method: "doc.open", params: ["path": relativePath])

        let inspected = try await inspect()
        return inspected.metadata
    }

    public func newDocument(width: Int = 1920, height: Int = 1080, background: String = "white") async throws {
        _ = try await call(method: "doc.new", params: [
            "width": width,
            "height": height,
            "background": background
        ])
    }

    public func renderCanvas(maxSide: Int = 1920) async throws -> NSImage {
        let result = try await call(method: "doc.render", params: ["maxSide": maxSide])
        guard let base64String = result["base64"] as? String,
              let imageData = Data(base64Encoded: base64String),
              let image = NSImage(data: imageData) else {
            throw NSError(domain: "PhotocraftClient", code: 14, userInfo: [NSLocalizedDescriptionKey: "Failed to decode rendered PNG image."])
        }
        return image
    }

    public func inspect() async throws -> (metadata: DocumentMetadata, layers: [LayerItem], history: [String], canUndo: Bool, canRedo: Bool) {
        let result = try await call(method: "doc.inspect", params: [:])

        let width = result["width"] as? Int ?? 0
        let height = result["height"] as? Int ?? 0
        let name = result["name"] as? String ?? "Untitled"
        let mode = result["mode"] as? String ?? "RGB"
        let depth = result["depth"] as? Int ?? 8
        let canUndo = result["canUndo"] as? Bool ?? false
        let canRedo = result["canRedo"] as? Bool ?? false
        let history = result["history"] as? [String] ?? []

        var layers: [LayerItem] = []
        if let rawLayers = result["layers"] as? [[String: Any]] {
            for raw in rawLayers {
                if let item = LayerItem.from(json: raw) {
                    layers.append(item)
                }
            }
        }

        let meta = DocumentMetadata(
            name: name,
            width: width,
            height: height,
            mode: mode,
            depth: depth,
            layersCount: layers.count
        )

        return (metadata: meta, layers: layers, history: history, canUndo: canUndo, canRedo: canRedo)
    }

    // MARK: - Command Execution

    public func execute(command: String, params: [String: Any]) async throws -> [String: Any] {
        let validated = try ParameterValidator.validate(command: command, params: params)
        return try await call(method: "engine.execute", params: [
            "command": command,
            "params": validated
        ])
    }

    public func batch(steps: [(command: String, params: [String: Any])]) async throws -> BatchExecutionReport {
        var rawSteps: [[String: Any]] = []
        for step in steps {
            let validated = try ParameterValidator.validate(command: step.command, params: step.params)
            rawSteps.append([
                "command": step.command,
                "params": validated
            ])
        }

        let result = try await call(method: "batch", params: [
            "steps": rawSteps,
            "stopOnError": true
        ])

        let completed = result["completed"] as? Int ?? 0
        let failed = result["failed"] as? Int ?? 0
        let rawResults = result["results"] as? [Any] ?? []
        let parsedResults = rawResults.map { AnyCodable($0) }

        return BatchExecutionReport(completed: completed, failed: failed, results: parsedResults)
    }

    // MARK: - History (Undo/Redo)

    public func undo() async throws {
        _ = try await call(method: "engine.execute", params: ["command": "edit.undo", "params": [:]])
    }

    public func redo() async throws {
        _ = try await call(method: "engine.execute", params: ["command": "edit.redo", "params": [:]])
    }

    // MARK: - Layer Manipulation

    public func setLayerProps(layerId: Int, visible: Bool? = nil, opacity: Double? = nil, blend: String? = nil) async throws {
        var params: [String: Any] = ["layer": layerId]
        if let v = visible { params["visible"] = v }
        if let o = opacity { params["opacity"] = o }
        if let b = blend { params["blend"] = b }
        _ = try await execute(command: "layer.setProps", params: params)
    }

    public func deleteLayer(layerId: Int) async throws {
        _ = try await execute(command: "layer.delete", params: ["layer": layerId])
    }

    public func selectLayer(layerId: Int) async throws {
        _ = try await execute(command: "layer.select", params: ["layer": layerId, "mode": "replace"])
    }

    // MARK: - Save / Export

    public func save(to destinationURL: URL, format: String? = nil, quality: Int? = 90) async throws {
        let relativePath = destinationURL.lastPathComponent
        var params: [String: Any] = ["path": relativePath]
        if let fmt = format {
            params["format"] = fmt
        }
        if let q = quality {
            params["quality"] = q
        }
        _ = try await call(method: "doc.save", params: params)
    }
}
