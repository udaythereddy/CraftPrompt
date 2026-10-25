import AppKit
import Foundation

@main
struct RunTests {
    static func main() async {
        print("=====================================================")
        print("  CraftPrompt Native macOS Test & Verification Suite ")
        print("=====================================================\n")

        var totalPassed = 0
        var totalFailed = 0

        func record(name: String, passed: Bool, details: String = "") {
            if passed {
                totalPassed += 1
                print("  [PASS] \(name)")
            } else {
                totalFailed += 1
                print("  [FAIL] \(name): \(details)")
            }
        }

        // --- 1. Path Sanitization Tests ---
        print("[1] Security & Path Sanitization Tests:")
        do {
            _ = try PathSanitizer.sanitize(path: "../../etc/passwd")
            record(name: "Directory traversal (../../) rejection", passed: false, details: "Expected error")
        } catch {
            record(name: "Directory traversal (../../) rejection", passed: true)
        }

        do {
            _ = try PathSanitizer.sanitize(path: "photo.png; rm -rf /")
            record(name: "Shell metacharacter ';' rejection", passed: false, details: "Expected error")
        } catch {
            record(name: "Shell metacharacter ';' rejection", passed: true)
        }

        do {
            _ = try PathSanitizer.sanitize(path: "photo.png\0.evil")
            record(name: "Null byte poison rejection", passed: false, details: "Expected error")
        } catch {
            record(name: "Null byte poison rejection", passed: true)
        }

        do {
            _ = try PathSanitizer.sanitize(path: "/tmp/sample.png")
            record(name: "Valid file extension (.png) acceptance", passed: true)
        } catch {
            record(name: "Valid file extension (.png) acceptance", passed: false, details: "\(error)")
        }

        do {
            _ = try PathSanitizer.sanitize(path: "/tmp/exploit.exe")
            record(name: "Disallowed extension (.exe) rejection", passed: false, details: "Expected error")
        } catch {
            record(name: "Disallowed extension (.exe) rejection", passed: true)
        }

        // --- 2. Parameter Validation Tests ---
        print("\n[2] Parameter Validation & Schema Enforcement Tests:")
        do {
            let clampedBrightness = try ParameterValidator.validate(
                command: "layer.newAdjustmentLayer.brightnessContrast",
                params: ["brightness": 800.0, "contrast": -300.0]
            )
            let b = clampedBrightness["brightness"] as? Double
            let c = clampedBrightness["contrast"] as? Double
            record(name: "Brightness/Contrast clamping [-150..150, -50..100]", passed: (b == 150.0 && c == -50.0))
        } catch {
            record(name: "Brightness/Contrast clamping", passed: false, details: "\(error)")
        }

        do {
            let clampedBlur = try ParameterValidator.validate(
                command: "filter.blur.gaussianBlur",
                params: ["radius": 50000.0]
            )
            let r = clampedBlur["radius"] as? Double
            record(name: "Gaussian Blur radius clamping [0.1..1000.0]", passed: (r == 1000.0))
        } catch {
            record(name: "Gaussian Blur radius clamping", passed: false, details: "\(error)")
        }

        do {
            let clampedVibrance = try ParameterValidator.validate(
                command: "layer.newAdjustmentLayer.vibrance",
                params: ["vibrance": -200.0, "saturation": 200.0]
            )
            let v = clampedVibrance["vibrance"] as? Double
            let s = clampedVibrance["saturation"] as? Double
            record(name: "Vibrance clamping [-100..100]", passed: (v == -100.0 && s == 100.0))
        } catch {
            record(name: "Vibrance clamping", passed: false, details: "\(error)")
        }

        // --- 3. Prompt Translation Layer Tests ---
        print("\n[3] Natural Language Translation Layer Tests:")
        let translator = PromptTranslator()

        let compoundResult = await translator.translate(prompt: "warm up the sunset, boost vibrance, and blur out the distracting background")
        let compoundCommands = compoundResult.commands.map { $0.command }
        let hasWarming = compoundCommands.contains("layer.newAdjustmentLayer.photoFilter")
        let hasVibrance = compoundCommands.contains("layer.newAdjustmentLayer.vibrance")
        let hasBlur = compoundCommands.contains("filter.blur.gaussianBlur")
        record(
            name: "Compound prompt decomposition ('warm up the sunset, boost vibrance, and blur background')",
            passed: (hasWarming && hasVibrance && hasBlur),
            details: "Commands: \(compoundCommands)"
        )

        let bwResult = await translator.translate(prompt: "make it dramatic black and white")
        let bwCommands = bwResult.commands.map { $0.command }
        record(
            name: "Black and White conversion intent",
            passed: bwCommands.contains("layer.newAdjustmentLayer.blackWhite"),
            details: "Commands: \(bwCommands)"
        )

        let undoResult = await translator.translate(prompt: "undo that")
        record(name: "Undo intent mapping ('undo that' -> edit.undo)", passed: (undoResult.isUndo && undoResult.commands.first?.command == "edit.undo"))

        let redoResult = await translator.translate(prompt: "redo that")
        record(name: "Redo intent mapping ('redo that' -> edit.redo)", passed: (redoResult.isRedo && redoResult.commands.first?.command == "edit.redo"))

        // Conversational refinement
        _ = await translator.translate(prompt: "boost vibrance 20")
        let refined = await translator.translate(prompt: "make it stronger")
        let refVibrance = refined.commands.first?.params["vibrance"] as? Double ?? 0.0
        record(name: "Conversational refinement ('make it stronger' amplifies by 40%)", passed: (refVibrance > 20.0))

        // --- 4. Security Auditor Suite ---
        print("\n[4] Comprehensive Security Audit Checks:")
        let auditChecks = SecurityAuditor.runAudit()
        for check in auditChecks {
            record(name: "\(check.category): \(check.title)", passed: check.passed, details: check.details)
        }

        // --- 5. Live PhotoCraft Engine Integration ---
        print("\n[5] Live PhotoCraft Engine Integration Tests:")
        if let binaryPath = PhotocraftProcess.locateBinary() {
            record(name: "Photocraft binary located at '\(binaryPath)'", passed: true)
            let client = PhotocraftClient(customBinaryPath: binaryPath)

            do {
                // Test doc.new
                try await client.newDocument(width: 80, height: 80, background: "white")
                record(name: "PhotoCraft process spawn & doc.new (80x80)", passed: true)

                // Test execute adjustment layer
                let adjResult = try await client.execute(
                    command: "layer.newAdjustmentLayer.vibrance",
                    params: ["vibrance": 40.0, "saturation": 15.0]
                )
                let layerId = adjResult["layer"]
                record(name: "engine.execute (layer.newAdjustmentLayer.vibrance) -> Layer \(layerId ?? -1)", passed: (layerId != nil))

                // Test doc.inspect
                let inspectInfo = try await client.inspect()
                let metaOk = (inspectInfo.metadata.width == 80 && inspectInfo.metadata.height == 80)
                record(name: "doc.inspect (verified dimensions and history stack)", passed: metaOk && inspectInfo.canUndo)

                // Test doc.render to NSImage
                let canvasImage = try await client.renderCanvas(maxSide: 80)
                let imageValid = (canvasImage.size.width > 0 && canvasImage.size.height > 0)
                record(name: "doc.render -> NSImage decoded (\(Int(canvasImage.size.width))x\(Int(canvasImage.size.height)))", passed: imageValid)

                // Test undo
                try await client.undo()
                let afterUndo = try await client.inspect()
                record(name: "engine.execute (edit.undo) -> canRedo is true", passed: afterUndo.canRedo)

                // Test redo
                try await client.redo()
                let afterRedo = try await client.inspect()
                record(name: "engine.execute (edit.redo) -> canUndo is true", passed: afterRedo.canUndo)

                await client.shutdown()
                record(name: "PhotoCraft client shutdown gracefully", passed: true)
            } catch {
                record(name: "Live PhotoCraft session", passed: false, details: "\(error)")
                await client.shutdown()
            }
        } else {
            record(name: "Photocraft binary locator", passed: false, details: "Binary not found")
        }

        print("\n=====================================================")
        print("  Test Results: \(totalPassed) Passed, \(totalFailed) Failed")
        print("=====================================================")

        if totalFailed > 0 {
            exit(1)
        }
    }
}
