import Foundation

public actor PhotocraftProcess {
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var outputHandle: FileHandle?
    private var inputHandle: FileHandle?
    private var buffer = Data()
    private var pendingRequests: [String: CheckedContinuation<Data, Error>] = [:]
    private var isRunning = false
    private var customBinaryPath: String?

    public enum Mode {
        case serve
        case mcp
    }

    public let mode: Mode
    public let readRoot: URL
    public let writeRoot: URL

    public init(mode: Mode = .serve, customBinaryPath: String? = nil, readRoot: URL? = nil, writeRoot: URL? = nil) {
        self.mode = mode
        self.customBinaryPath = customBinaryPath
        let defaultRoot = FileManager.default.temporaryDirectory
        self.readRoot = readRoot ?? defaultRoot
        self.writeRoot = writeRoot ?? defaultRoot
    }

    /// Locates the `photocraft-cli` binary
    public static func locateBinary(customPath: String? = nil) -> String? {
        if let custom = customPath, FileManager.default.fileExists(atPath: custom) {
            return custom
        }

        // 1. Direct path in local repo target/release
        let currentDir = FileManager.default.currentDirectoryPath
        let possiblePaths = [
            "\(currentDir)/photocraft/target/release/photocraft-cli",
            "\(currentDir)/../photocraft/target/release/photocraft-cli",
            "/Users/udaykumarkamireddy/Desktop/AI Apps/My Photocraft/photocraft/target/release/photocraft-cli",
            Bundle.main.path(forResource: "photocraft-cli", ofType: nil) ?? ""
        ]

        for path in possiblePaths {
            if !path.isEmpty && FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // 2. Check PATH
        let paths = ProcessInfo.processInfo.environment["PATH"]?.components(separatedBy: ":") ?? []
        for dir in paths {
            let candidate = (dir as NSString).appendingPathComponent("photocraft-cli")
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }

    public func start() throws {
        guard !isRunning else { return }

        guard let binaryPath = Self.locateBinary(customPath: customBinaryPath) else {
            throw NSError(
                domain: "PhotocraftProcess",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "photocraft-cli executable could not be found. Please build photocraft with cargo first."]
            )
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)

        var args: [String] = []
        switch mode {
        case .serve:
            args.append("serve")
        case .mcp:
            args.append("mcp")
        }

        // Sandbox isolation arguments
        args.append(contentsOf: [
            "--automation-read-root", readRoot.path,
            "--automation-write-root", writeRoot.path
        ])

        proc.arguments = args

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        self.inputHandle = stdin.fileHandleForWriting
        self.outputHandle = stdout.fileHandleForReading
        self.stdinPipe = stdin
        self.stdoutPipe = stdout
        self.stderrPipe = stderr
        self.process = proc

        // Handle process termination
        proc.terminationHandler = { [weak self] _ in
            Task { [weak self] in
                await self?.handleTermination()
            }
        }

        // Asynchronous non-blocking readability handler
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let available = handle.availableData
            guard !available.isEmpty else { return }
            Task { [weak self] in
                await self?.appendAndProcess(chunk: available)
            }
        }

        try proc.run()
        self.isRunning = true
    }

    private func handleTermination() {
        isRunning = false
        // Cancel all pending continuations
        let error = NSError(domain: "PhotocraftProcess", code: 2, userInfo: [NSLocalizedDescriptionKey: "Photocraft process terminated unexpectedly."])
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: error)
        }
        pendingRequests.removeAll()
    }

    public func stop() {
        guard isRunning, let proc = process else { return }
        isRunning = false
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        try? inputHandle?.close()
        try? outputHandle?.close()
        proc.terminate()
        process = nil
    }

    public func send(line: String, expectedRequestId: String) async throws -> Data {
        guard isRunning, let input = inputHandle else {
            throw NSError(domain: "PhotocraftProcess", code: 3, userInfo: [NSLocalizedDescriptionKey: "Photocraft process is not running."])
        }

        guard let data = "\(line)\n".data(using: .utf8) else {
            throw NSError(domain: "PhotocraftProcess", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request string."])
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.pendingRequests[expectedRequestId] = continuation
            do {
                try input.write(contentsOf: data)
            } catch {
                self.pendingRequests.removeValue(forKey: expectedRequestId)
                continuation.resume(throwing: error)
            }
        }
    }

    private func appendAndProcess(chunk: Data) {
        buffer.append(chunk)

        // Find newlines (0x0A)
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer.subdata(in: 0..<newlineIndex)
            buffer.removeSubrange(0...newlineIndex)

            guard !lineData.isEmpty else { continue }
            processOutputLine(lineData)
        }
    }

    private func processOutputLine(_ data: Data) {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Try extracting "id"
        let idVal: String?
        if let strId = jsonObject["id"] as? String {
            idVal = strId
        } else if let intId = jsonObject["id"] as? Int {
            idVal = String(intId)
        } else {
            idVal = nil
        }

        if let id = idVal, let continuation = pendingRequests.removeValue(forKey: id) {
            continuation.resume(returning: data)
        } else if let firstContinuation = pendingRequests.first {
            // Fallback if no matching ID
            pendingRequests.removeValue(forKey: firstContinuation.key)
            firstContinuation.value.resume(returning: data)
        }
    }

    deinit {
        try? inputHandle?.close()
        try? outputHandle?.close()
        process?.terminate()
    }
}
