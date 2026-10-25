import Foundation

public struct ParameterValidator: Sendable {
    /// Validates and returns a clamped/sanitized dictionary of parameters for a given PhotoCraft command.
    public static func validate(command: String, params: [String: Any]) throws -> [String: Any] {
        var cleanParams: [String: Any] = [:]

        switch command {
        case "layer.newAdjustmentLayer.brightnessContrast", "image.adjustments.brightnessContrast":
            let brightness = clampDouble(params["brightness"], min: -150.0, max: 150.0, defaultVal: 0.0)
            let contrast = clampDouble(params["contrast"], min: -50.0, max: 100.0, defaultVal: 0.0)
            let legacy = params["legacy"] as? Bool ?? false
            cleanParams["brightness"] = brightness
            cleanParams["contrast"] = contrast
            cleanParams["legacy"] = legacy

        case "layer.newAdjustmentLayer.vibrance", "image.adjustments.vibrance":
            let vibrance = clampDouble(params["vibrance"], min: -100.0, max: 100.0, defaultVal: 0.0)
            let saturation = clampDouble(params["saturation"], min: -100.0, max: 100.0, defaultVal: 0.0)
            cleanParams["vibrance"] = vibrance
            cleanParams["saturation"] = saturation

        case "layer.newAdjustmentLayer.exposure", "image.adjustments.exposure":
            let exposure = clampDouble(params["exposure"], min: -20.0, max: 20.0, defaultVal: 0.0)
            let offset = clampDouble(params["offset"], min: -0.5, max: 0.5, defaultVal: 0.0)
            let gamma = clampDouble(params["gamma"], min: 0.01, max: 9.99, defaultVal: 1.0)
            cleanParams["exposure"] = exposure
            cleanParams["offset"] = offset
            cleanParams["gamma"] = gamma

        case "layer.newAdjustmentLayer.hueSaturation", "image.adjustments.hueSaturation":
            let hue = clampDouble(params["hue"], min: -180.0, max: 180.0, defaultVal: 0.0)
            let saturation = clampDouble(params["saturation"], min: -100.0, max: 100.0, defaultVal: 0.0)
            let lightness = clampDouble(params["lightness"], min: -100.0, max: 100.0, defaultVal: 0.0)
            let colorize = params["colorize"] as? Bool ?? false
            cleanParams["hue"] = hue
            cleanParams["saturation"] = saturation
            cleanParams["lightness"] = lightness
            cleanParams["colorize"] = colorize

        case "layer.newAdjustmentLayer.levels", "image.adjustments.levels":
            let inBlack = clampInt(params["inBlack"], min: 0, max: 253, defaultVal: 0)
            let inWhite = clampInt(params["inWhite"], min: max(inBlack + 2, 2), max: 255, defaultVal: 255)
            let outBlack = clampInt(params["outBlack"], min: 0, max: 255, defaultVal: 0)
            let outWhite = clampInt(params["outWhite"], min: 0, max: 255, defaultVal: 255)
            let gamma = clampDouble(params["gamma"], min: 0.01, max: 9.99, defaultVal: 1.0)
            cleanParams["inBlack"] = inBlack
            cleanParams["inWhite"] = inWhite
            cleanParams["outBlack"] = outBlack
            cleanParams["outWhite"] = outWhite
            cleanParams["gamma"] = gamma

        case "layer.newAdjustmentLayer.curves", "image.adjustments.curves":
            if let points = params["points"] as? [[Double]] {
                var validatedPoints: [[Double]] = []
                for pt in points {
                    guard pt.len >= 2 else { continue }
                    let x = min(max(pt[0], 0.0), 255.0)
                    let y = min(max(pt[1], 0.0), 255.0)
                    validatedPoints.append([x, y])
                }
                if validatedPoints.count >= 2 {
                    cleanParams["points"] = validatedPoints
                } else {
                    cleanParams["points"] = [[0.0, 0.0], [255.0, 255.0]]
                }
            } else {
                cleanParams["points"] = [[0.0, 0.0], [255.0, 255.0]]
            }

        case "layer.newAdjustmentLayer.photoFilter", "image.adjustments.photoFilter":
            let allowedFilters: Set<String> = [
                "warming85", "warmingLBA", "warming81", "cooling80", "coolingLBB", "cooling82",
                "red", "orange", "yellow", "green", "cyan", "blue", "violet", "magenta", "sepia",
                "deepRed", "deepBlue", "deepEmerald", "deepYellow", "underwater"
            ]
            let filterName = (params["filter"] as? String) ?? "warming85"
            cleanParams["filter"] = allowedFilters.contains(filterName) ? filterName : "warming85"
            cleanParams["density"] = clampDouble(params["density"], min: 0.0, max: 100.0, defaultVal: 25.0)
            cleanParams["preserveLuminosity"] = params["preserveLuminosity"] as? Bool ?? true

        case "layer.newAdjustmentLayer.colorBalance", "image.adjustments.colorBalance":
            cleanParams["preserveLuminosity"] = params["preserveLuminosity"] as? Bool ?? true
            if let shadows = params["shadows"] as? [Double], shadows.count == 3 {
                cleanParams["shadows"] = shadows.map { min(max($0, -100.0), 100.0) }
            }
            if let midtones = params["midtones"] as? [Double], midtones.count == 3 {
                cleanParams["midtones"] = midtones.map { min(max($0, -100.0), 100.0) }
            }
            if let highlights = params["highlights"] as? [Double], highlights.count == 3 {
                cleanParams["highlights"] = highlights.map { min(max($0, -100.0), 100.0) }
            }

        case "layer.newAdjustmentLayer.blackWhite", "image.adjustments.blackWhite":
            cleanParams["reds"] = clampDouble(params["reds"], min: -200.0, max: 300.0, defaultVal: 40.0)
            cleanParams["yellows"] = clampDouble(params["yellows"], min: -200.0, max: 300.0, defaultVal: 60.0)
            cleanParams["greens"] = clampDouble(params["greens"], min: -200.0, max: 300.0, defaultVal: 40.0)
            cleanParams["cyans"] = clampDouble(params["cyans"], min: -200.0, max: 300.0, defaultVal: 60.0)
            cleanParams["blues"] = clampDouble(params["blues"], min: -200.0, max: 300.0, defaultVal: 20.0)
            cleanParams["magentas"] = clampDouble(params["magentas"], min: -200.0, max: 300.0, defaultVal: 80.0)
            cleanParams["tint"] = params["tint"] as? Bool ?? false
            if let tintColor = params["tintColor"] as? String {
                cleanParams["tintColor"] = tintColor
            }

        case "filter.blur.gaussianBlur":
            cleanParams["radius"] = clampDouble(params["radius"], min: 0.1, max: 1000.0, defaultVal: 1.0)

        case "filter.blur.boxBlur":
            cleanParams["radius"] = clampDouble(params["radius"], min: 1.0, max: 2000.0, defaultVal: 1.0)

        case "filter.blur.motionBlur":
            cleanParams["angle"] = clampDouble(params["angle"], min: -360.0, max: 360.0, defaultVal: 0.0)
            cleanParams["distance"] = clampDouble(params["distance"], min: 1.0, max: 2000.0, defaultVal: 10.0)

        case "filter.blur.radialBlur":
            cleanParams["amount"] = clampDouble(params["amount"], min: 1.0, max: 100.0, defaultVal: 10.0)
            let method = (params["method"] as? String) == "zoom" ? "zoom" : "spin"
            cleanParams["method"] = method

        case "filter.blur.surfaceBlur":
            cleanParams["radius"] = clampDouble(params["radius"], min: 1.0, max: 100.0, defaultVal: 5.0)
            cleanParams["threshold"] = clampDouble(params["threshold"], min: 2.0, max: 255.0, defaultVal: 15.0)

        case "filter.sharpen.unsharpMask":
            cleanParams["amount"] = clampDouble(params["amount"], min: 1.0, max: 500.0, defaultVal: 50.0)
            cleanParams["radius"] = clampDouble(params["radius"], min: 0.1, max: 1000.0, defaultVal: 1.0)
            cleanParams["threshold"] = clampDouble(params["threshold"], min: 0.0, max: 255.0, defaultVal: 0.0)

        case "filter.sharpen.smartSharpen":
            cleanParams["amount"] = clampDouble(params["amount"], min: 1.0, max: 500.0, defaultVal: 100.0)
            cleanParams["radius"] = clampDouble(params["radius"], min: 0.1, max: 64.0, defaultVal: 1.0)
            cleanParams["reduceNoise"] = clampDouble(params["reduceNoise"], min: 0.0, max: 100.0, defaultVal: 10.0)

        case "filter.other.highPass":
            cleanParams["radius"] = clampDouble(params["radius"], min: 0.1, max: 1000.0, defaultVal: 10.0)

        case "filter.noise.addNoise":
            cleanParams["amount"] = clampDouble(params["amount"], min: 0.1, max: 400.0, defaultVal: 12.5)
            let dist = (params["distribution"] as? String) == "gaussian" ? "gaussian" : "uniform"
            cleanParams["distribution"] = dist
            cleanParams["monochromatic"] = params["monochromatic"] as? Bool ?? false

        case "filter.noise.median":
            cleanParams["radius"] = clampDouble(params["radius"], min: 1.0, max: 500.0, defaultVal: 1.0)

        case "filter.pixelate.mosaic":
            cleanParams["cellSize"] = clampDouble(params["cellSize"], min: 2.0, max: 200.0, defaultVal: 10.0)

        case "filter.stylize.emboss":
            cleanParams["angle"] = clampDouble(params["angle"], min: -360.0, max: 360.0, defaultVal: 135.0)
            cleanParams["height"] = clampDouble(params["height"], min: 1.0, max: 100.0, defaultVal: 3.0)
            cleanParams["amount"] = clampDouble(params["amount"], min: 1.0, max: 500.0, defaultVal: 100.0)

        case "layer.setProps":
            if let opacity = params["opacity"] {
                cleanParams["opacity"] = clampDouble(opacity, min: 0.0, max: 1.0, defaultVal: 1.0)
            }
            if let visible = params["visible"] as? Bool {
                cleanParams["visible"] = visible
            }
            if let blend = params["blend"] as? String {
                cleanParams["blend"] = blend
            }
            if let name = params["name"] as? String {
                cleanParams["name"] = name
            }

        default:
            // For any other command, preserve valid primitive values
            cleanParams = params
        }

        return cleanParams
    }

    private static func clampDouble(_ val: Any?, min: Double, max: Double, defaultVal: Double) -> Double {
        guard let val = val else { return defaultVal }
        if let d = val as? Double {
            return Swift.min(Swift.max(d, min), max)
        }
        if let i = val as? Int {
            return Swift.min(Swift.max(Double(i), min), max)
        }
        if let f = val as? Float {
            return Swift.min(Swift.max(Double(f), min), max)
        }
        if let s = val as? String, let parsed = Double(s) {
            return Swift.min(Swift.max(parsed, min), max)
        }
        return defaultVal
    }

    private static func clampInt(_ val: Any?, min: Int, max: Int, defaultVal: Int) -> Int {
        guard let val = val else { return defaultVal }
        if let i = val as? Int {
            return Swift.min(Swift.max(i, min), max)
        }
        if let d = val as? Double {
            return Swift.min(Swift.max(Int(d.rounded()), min), max)
        }
        if let s = val as? String, let parsed = Int(s) {
            return Swift.min(Swift.max(parsed, min), max)
        }
        return defaultVal
    }
}

private extension Array {
    var len: Int { count }
}
