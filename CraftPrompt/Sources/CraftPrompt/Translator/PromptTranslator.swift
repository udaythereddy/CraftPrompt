import Foundation

public struct TranslationResult: @unchecked Sendable {
    public let commands: [(command: String, params: [String: Any])]
    public let summary: String
    public let isUndo: Bool
    public let isRedo: Bool

    public init(commands: [(command: String, params: [String: Any])], summary: String, isUndo: Bool = false, isRedo: Bool = false) {
        self.commands = commands
        self.summary = summary
        self.isUndo = isUndo
        self.isRedo = isRedo
    }
}

public actor PromptTranslator {
    private var lastExecutedSteps: [(command: String, params: [String: Any])] = []
    private var conversationHistory: [String] = []

    public init() {}

    /// Main translation entry point: translates natural language to PhotoCraft commands
    public func translate(prompt rawPrompt: String) async -> TranslationResult {
        let prompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        conversationHistory.append(rawPrompt)

        // 1. Direct Undo/Redo intent
        if isUndoIntent(prompt) {
            return TranslationResult(commands: [("edit.undo", [:])], summary: "Reverted previous edit", isUndo: true)
        }
        if isRedoIntent(prompt) {
            return TranslationResult(commands: [("edit.redo", [:])], summary: "Restored next edit", isRedo: true)
        }

        // 2. Conversational Refinement ("make it stronger", "tone it down")
        if isIntensityIncrease(prompt), !lastExecutedSteps.isEmpty {
            let adjusted = amplifyLastSteps(multiplier: 1.4)
            lastExecutedSteps = adjusted
            return TranslationResult(commands: adjusted, summary: "Amplified previous adjustments by +40%")
        }
        if isIntensityDecrease(prompt), !lastExecutedSteps.isEmpty {
            let adjusted = amplifyLastSteps(multiplier: 0.6)
            lastExecutedSteps = adjusted
            return TranslationResult(commands: adjusted, summary: "Subdued previous adjustments by -40%")
        }

        // 3. Multi-clause semantic parser
        var steps: [(command: String, params: [String: Any])] = []
        var summaries: [String] = []

        // Split into clauses by comma, "and", "then", semicolons
        let clauses = splitIntoClauses(prompt)

        for clause in clauses {
            let (clauseSteps, clauseSummary) = parseClause(clause)
            if !clauseSteps.isEmpty {
                steps.append(contentsOf: clauseSteps)
                if let sum = clauseSummary {
                    summaries.append(sum)
                }
            }
        }

        // If no clauses matched, perform whole-string fuzzy intent matching
        if steps.isEmpty {
            let (fallbackSteps, fallbackSummary) = parseClause(prompt)
            steps = fallbackSteps
            if let sum = fallbackSummary {
                summaries.append(sum)
            }
        }

        // If still empty, apply a smart aesthetic auto-enhancement
        if steps.isEmpty {
            steps.append(("layer.newAdjustmentLayer.vibrance", ["vibrance": 25.0, "saturation": 10.0]))
            steps.append(("layer.newAdjustmentLayer.brightnessContrast", ["brightness": 10.0, "contrast": 15.0]))
            summaries.append("Applied subtle smart balance (Vibrance +25, Contrast +15)")
        }

        lastExecutedSteps = steps
        let overallSummary = summaries.isEmpty ? "Applied adjustments" : summaries.joined(separator: ", ")
        return TranslationResult(commands: steps, summary: overallSummary)
    }

    // MARK: - Semantic Clause Parsing

    private func parseClause(_ clause: String) -> ([(command: String, params: [String: Any])], String?) {
        var steps: [(command: String, params: [String: Any])] = []
        var summary: String? = nil

        // Warm up / Golden hour / Sunset
        if clause.contains("warm") || clause.contains("sunset") || clause.contains("golden hour") || clause.contains("sunlight") {
            steps.append(("layer.newAdjustmentLayer.photoFilter", [
                "filter": "warming85",
                "density": 35.0,
                "preserveLuminosity": true
            ]))
            steps.append(("layer.newAdjustmentLayer.curves", [
                "points": [[0.0, 0.0], [128.0, 138.0], [255.0, 255.0]]
            ]))
            summary = "Warmed up tones (Warming 85 filter & highlight warmth)"
        }
        // Cool down / Cold / Winter / Blue
        else if clause.contains("cool") || clause.contains("cold") || clause.contains("chill") || clause.contains("winter") {
            steps.append(("layer.newAdjustmentLayer.photoFilter", [
                "filter": "cooling80",
                "density": 30.0,
                "preserveLuminosity": true
            ]))
            summary = "Cooled down color temperature (Cooling 80 filter)"
        }
        // Vibrance / Pop / Colorful
        else if clause.contains("vibran") || clause.contains("pop") || clause.contains("rich color") {
            let amount = extractNumber(from: clause) ?? 35.0
            steps.append(("layer.newAdjustmentLayer.vibrance", [
                "vibrance": amount,
                "saturation": amount * 0.4
            ]))
            summary = "Boosted vibrance (+\(Int(amount)))"
        }
        // Contrast
        else if clause.contains("contrast") {
            let amount = extractNumber(from: clause) ?? 25.0
            let isDecrease = clause.contains("less") || clause.contains("lower") || clause.contains("reduce")
            let finalVal = isDecrease ? -amount : amount
            steps.append(("layer.newAdjustmentLayer.brightnessContrast", [
                "brightness": 0.0,
                "contrast": finalVal
            ]))
            summary = "\(isDecrease ? "Decreased" : "Boosted") contrast (\(Int(finalVal)))"
        }
        // Brighten / Exposure / Lighter
        else if clause.contains("bright") || clause.contains("lighten") || clause.contains("expose") {
            let amount = extractNumber(from: clause) ?? 20.0
            steps.append(("layer.newAdjustmentLayer.brightnessContrast", [
                "brightness": amount,
                "contrast": 5.0
            ]))
            summary = "Brightened image (+\(Int(amount)))"
        }
        // Darken / Moody / Dim
        else if clause.contains("darken") || clause.contains("dim") || clause.contains("shadow") {
            let amount = extractNumber(from: clause) ?? 20.0
            steps.append(("layer.newAdjustmentLayer.brightnessContrast", [
                "brightness": -amount,
                "contrast": 10.0
            ]))
            summary = "Darkened image (-\(Int(amount)))"
        }
        // Blur / Depth of field / Bokeh / Soften background
        else if clause.contains("blur") || clause.contains("bokeh") || clause.contains("defocus") || clause.contains("soften") {
            let radius = extractNumber(from: clause) ?? 6.0
            steps.append(("filter.blur.gaussianBlur", [
                "radius": radius
            ]))
            summary = "Softened with Gaussian blur (radius \(radius)px)"
        }
        // Sharpen / Crisp / Clarity / Details
        else if clause.contains("sharp") || clause.contains("crisp") || clause.contains("clarity") || clause.contains("detail") {
            let amount = extractNumber(from: clause) ?? 120.0
            steps.append(("filter.sharpen.smartSharpen", [
                "amount": amount,
                "radius": 1.2,
                "reduceNoise": 15.0
            ]))
            summary = "Sharpened fine details (Smart Sharpen \(Int(amount))%)"
        }
        // Black and White / Monochrome
        else if clause.contains("black and white") || clause.contains("b&w") || clause.contains("monochrome") || clause.contains("grayscale") {
            steps.append(("layer.newAdjustmentLayer.blackWhite", [
                "reds": 40.0,
                "yellows": 60.0,
                "greens": 40.0,
                "cyans": 60.0,
                "blues": 20.0,
                "magentas": 80.0
            ]))
            // If dramatic / contrasty b&w
            if clause.contains("dramatic") || clause.contains("moody") || clause.contains("high contrast") {
                steps.append(("layer.newAdjustmentLayer.curves", [
                    "points": [[0.0, 0.0], [64.0, 48.0], [192.0, 210.0], [255.0, 255.0]]
                ]))
            }
            summary = "Converted to Black & White with custom channel balance"
        }
        // Vintage / Retro / Film / Analog
        else if clause.contains("vintage") || clause.contains("retro") || clause.contains("film") || clause.contains("analog") {
            steps.append(("layer.newAdjustmentLayer.photoFilter", [
                "filter": "sepia",
                "density": 18.0,
                "preserveLuminosity": true
            ]))
            steps.append(("layer.newAdjustmentLayer.curves", [
                // Lift shadows for faded film matte look
                "points": [[0.0, 24.0], [128.0, 128.0], [255.0, 245.0]]
            ]))
            steps.append(("filter.noise.addNoise", [
                "amount": 4.5,
                "distribution": "gaussian",
                "monochromatic": true
            ]))
            summary = "Applied vintage analog film look (Sepia tint, lifted matte shadows, film grain)"
        }
        // Cyberpunk / Neon
        else if clause.contains("cyberpunk") || clause.contains("neon") || clause.contains("futuristic") {
            steps.append(("layer.newAdjustmentLayer.colorBalance", [
                "shadows": [-25.0, 10.0, 35.0], // Cyan-blue shadows
                "highlights": [30.0, -10.0, -15.0], // Red-magenta highlights
                "preserveLuminosity": true
            ]))
            steps.append(("layer.newAdjustmentLayer.vibrance", [
                "vibrance": 45.0,
                "saturation": 20.0
            ]))
            summary = "Applied Cyberpunk neon palette (Teal shadows, pink/orange highlights, vibrant saturation)"
        }
        // Invert colors
        else if clause.contains("invert") || clause.contains("negative") {
            steps.append(("layer.newAdjustmentLayer.invert", [:]))
            summary = "Inverted color values"
        }
        // Noise / Grain
        else if clause.contains("noise") || clause.contains("grain") {
            let amount = extractNumber(from: clause) ?? 8.0
            steps.append(("filter.noise.addNoise", [
                "amount": amount,
                "distribution": "gaussian",
                "monochromatic": true
            ]))
            summary = "Added analog grain texture (\(amount)%)"
        }
        // Smooth skin / Despeckle / Denoise
        else if clause.contains("smooth") || clause.contains("denoise") || clause.contains("skin") {
            steps.append(("filter.blur.surfaceBlur", [
                "radius": 4.0,
                "threshold": 16.0
            ]))
            summary = "Surface smoothed preserving edge boundaries"
        }
        // Pixelate / Mosaic / 8-bit
        else if clause.contains("pixel") || clause.contains("mosaic") || clause.contains("8-bit") {
            let size = extractNumber(from: clause) ?? 14.0
            steps.append(("filter.pixelate.mosaic", [
                "cellSize": size
            ]))
            summary = "Pixelated with mosaic grid (cellSize \(Int(size))px)"
        }

        return (steps, summary)
    }

    // MARK: - Conversational Helpers

    private func isUndoIntent(_ p: String) -> Bool {
        return p == "undo" || p.hasPrefix("undo ") || p == "revert" || p == "take that back" || p == "cancel that" || p == "reset"
    }

    private func isRedoIntent(_ p: String) -> Bool {
        return p == "redo" || p.hasPrefix("redo ") || p == "re-apply" || p == "bring back"
    }

    private func isIntensityIncrease(_ p: String) -> Bool {
        return p.contains("more") || p.contains("stronger") || p.contains("increase") || p.contains("boost more") || p.contains("intenser")
    }

    private func isIntensityDecrease(_ p: String) -> Bool {
        return p.contains("less") || p.contains("subtler") || p.contains("tone down") || p.contains("weaker") || p.contains("decrease")
    }

    private func amplifyLastSteps(multiplier: Double) -> [(command: String, params: [String: Any])] {
        var adjusted: [(command: String, params: [String: Any])] = []
        for step in lastExecutedSteps {
            var newParams: [String: Any] = [:]
            for (key, val) in step.params {
                if let d = val as? Double {
                    newParams[key] = d * multiplier
                } else if let i = val as? Int {
                    newParams[key] = Int((Double(i) * multiplier).rounded())
                } else {
                    newParams[key] = val
                }
            }
            adjusted.append((step.command, newParams))
        }
        return adjusted
    }

    private func splitIntoClauses(_ text: String) -> [String] {
        let delimiters = CharacterSet(charactersIn: ",;.\n")
        let rawParts = text.components(separatedBy: delimiters)
        var clauses: [String] = []

        for part in rawParts {
            let subparts = part.components(separatedBy: " and ")
            for sub in subparts {
                let trimmed = sub.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    clauses.append(trimmed)
                }
            }
        }
        return clauses
    }

    private func extractNumber(from text: String) -> Double? {
        let pattern = "([0-9]+(?:\\.[0-9]+)?)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        if let match = results.first {
            let matchedString = nsString.substring(with: match.range)
            return Double(matchedString)
        }
        return nil
    }
}
