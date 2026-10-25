import XCTest
@testable import CraftPrompt

final class CraftPromptTests: XCTestCase {

    // MARK: - 1. Path Sanitization & Injection Defense

    func testDirectoryTraversalDefense() {
        XCTAssertThrowsError(try PathSanitizer.sanitize(path: "../../etc/shadow")) { error in
            guard case SecurityError.pathTraversalDetected = error else {
                XCTFail("Expected pathTraversalDetected, got \(error)")
                return
            }
        }
    }

    func testShellMetacharacterDefense() {
        let maliciousPaths = [
            "image.png; rm -rf /",
            "test.jpg | echo attack",
            "`whoami`.png",
            "pic$(date).png",
            "file>out.txt"
        ]

        for path in maliciousPaths {
            XCTAssertThrowsError(try PathSanitizer.sanitize(path: path)) { error in
                guard case SecurityError.dangerousCharactersDetected = error else {
                    XCTFail("Expected dangerousCharactersDetected for '\(path)', got \(error)")
                    return
                }
            }
        }
    }

    func testNullBytePoisonDefense() {
        let nullBytePath = "image.png\0.evil"
        XCTAssertThrowsError(try PathSanitizer.sanitize(path: nullBytePath)) { error in
            guard case SecurityError.nullByteDetected = error else {
                XCTFail("Expected nullByteDetected, got \(error)")
                return
            }
        }
    }

    func testAllowedExtensions() {
        XCTAssertNoThrow(try PathSanitizer.sanitize(path: "/tmp/sample.png"))
        XCTAssertNoThrow(try PathSanitizer.sanitize(path: "/tmp/photo.jpg"))
        XCTAssertNoThrow(try PathSanitizer.sanitize(path: "/tmp/artwork.psd"))
        XCTAssertNoThrow(try PathSanitizer.sanitize(path: "/tmp/layers.tif"))

        XCTAssertThrowsError(try PathSanitizer.sanitize(path: "/tmp/script.sh")) { error in
            guard case SecurityError.unsupportedFileType = error else {
                XCTFail("Expected unsupportedFileType for .sh, got \(error)")
                return
            }
        }
    }

    // MARK: - 2. Parameter Validation

    func testParameterClampingBrightnessContrast() throws {
        let params: [String: Any] = [
            "brightness": 500.0,
            "contrast": -300.0
        ]
        let validated = try ParameterValidator.validate(command: "layer.newAdjustmentLayer.brightnessContrast", params: params)
        XCTAssertEqual(validated["brightness"] as? Double, 150.0)
        XCTAssertEqual(validated["contrast"] as? Double, -50.0)
    }

    func testParameterClampingGaussianBlur() throws {
        let params: [String: Any] = ["radius": 999999.0]
        let validated = try ParameterValidator.validate(command: "filter.blur.gaussianBlur", params: params)
        XCTAssertEqual(validated["radius"] as? Double, 1000.0)
    }

    func testParameterClampingVibrance() throws {
        let params: [String: Any] = [
            "vibrance": -250.0,
            "saturation": 300.0
        ]
        let validated = try ParameterValidator.validate(command: "layer.newAdjustmentLayer.vibrance", params: params)
        XCTAssertEqual(validated["vibrance"] as? Double, -100.0)
        XCTAssertEqual(validated["saturation"] as? Double, 100.0)
    }

    // MARK: - 3. Natural Language Translation Layer

    func testCompoundPromptTranslation() async {
        let translator = PromptTranslator()
        let result = await translator.translate(prompt: "warm up the sunset, boost vibrance, and blur out the distracting background")

        XCTAssertFalse(result.commands.isEmpty)
        let commandNames = result.commands.map { $0.command }

        // Must contain warming filter, vibrance adjustment, and gaussian blur
        XCTAssertTrue(commandNames.contains("layer.newAdjustmentLayer.photoFilter"), "Must contain photoFilter")
        XCTAssertTrue(commandNames.contains("layer.newAdjustmentLayer.vibrance"), "Must contain vibrance")
        XCTAssertTrue(commandNames.contains("filter.blur.gaussianBlur"), "Must contain gaussianBlur")
    }

    func testUndoRedoIntent() async {
        let translator = PromptTranslator()

        let undoResult = await translator.translate(prompt: "undo")
        XCTAssertTrue(undoResult.isUndo)
        XCTAssertEqual(undoResult.commands.first?.command, "edit.undo")

        let redoResult = await translator.translate(prompt: "redo")
        XCTAssertTrue(redoResult.isRedo)
        XCTAssertEqual(redoResult.commands.first?.command, "edit.redo")
    }

    func testConversationalRefinement() async {
        let translator = PromptTranslator()

        // 1. Initial prompt
        let initial = await translator.translate(prompt: "boost vibrance 30")
        XCTAssertEqual(initial.commands.first?.command, "layer.newAdjustmentLayer.vibrance")
        let initVibrance = initial.commands.first?.params["vibrance"] as? Double ?? 0.0
        XCTAssertEqual(initVibrance, 30.0)

        // 2. Refinement: "make it stronger"
        let amplified = await translator.translate(prompt: "make it stronger")
        let amplifiedVibrance = amplified.commands.first?.params["vibrance"] as? Double ?? 0.0
        XCTAssertGreaterThan(amplifiedVibrance, initVibrance)
    }

    // MARK: - 4. Security Audit Suite

    func testSecurityAuditorChecks() {
        let checks = SecurityAuditor.runAudit()
        XCTAssertFalse(checks.isEmpty)
        for check in checks {
            XCTAssertTrue(check.passed, "Audit check failed: \(check.title) - \(check.details)")
        }
    }

    // MARK: - 5. Live PhotoCraft Engine Integration

    func testLivePhotocraftEngineSession() async throws {
        guard let binaryPath = PhotocraftProcess.locateBinary() else {
            XCTFail("Photocraft binary not located")
            return
        }
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: binaryPath))

        let client = PhotocraftClient(customBinaryPath: binaryPath)

        // Create new document
        try await client.newDocument(width: 80, height: 80, background: "white")

        // Apply an adjustment layer
        let adjResult = try await client.execute(
            command: "layer.newAdjustmentLayer.vibrance",
            params: ["vibrance": 40.0, "saturation": 15.0]
        )
        XCTAssertNotNil(adjResult["layer"])

        // Inspect document
        let inspectInfo = try await client.inspect()
        XCTAssertEqual(inspectInfo.metadata.width, 80)
        XCTAssertEqual(inspectInfo.metadata.height, 80)
        XCTAssertTrue(inspectInfo.canUndo)

        // Render viewport canvas
        let canvas = try await client.renderCanvas(maxSide: 80)
        XCTAssertNotNil(canvas)
        XCTAssertGreaterThan(canvas.size.width, 0)

        // Undo
        try await client.undo()
        let afterUndo = try await client.inspect()
        XCTAssertTrue(afterUndo.canRedo)

        await client.shutdown()
    }
}
