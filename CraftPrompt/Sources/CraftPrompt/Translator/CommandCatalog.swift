import Foundation

public struct CommandDefinition: Sendable, Identifiable {
    public let id: String
    public let label: String
    public let category: Category
    public let description: String
    public let parameterSummary: String

    public enum Category: String, Sendable, CaseIterable {
        case adjustment = "Adjustments"
        case filter = "Filters"
        case layer = "Layers"
        case edit = "Edit & History"
        case document = "Document"
    }
}

public struct CommandCatalog: Sendable {
    public static let allCommands: [CommandDefinition] = [
        // Adjustments
        CommandDefinition(
            id: "layer.newAdjustmentLayer.brightnessContrast",
            label: "Brightness / Contrast",
            category: .adjustment,
            description: "Adjusts the tonal range and brightness of the image non-destructively.",
            parameterSummary: "brightness (-150..150), contrast (-50..100)"
        ),
        CommandDefinition(
            id: "layer.newAdjustmentLayer.vibrance",
            label: "Vibrance & Saturation",
            category: .adjustment,
            description: "Boosts less-saturated colors intelligently without clipping skin tones.",
            parameterSummary: "vibrance (-100..100), saturation (-100..100)"
        ),
        CommandDefinition(
            id: "layer.newAdjustmentLayer.exposure",
            label: "Exposure",
            category: .adjustment,
            description: "Adjusts exposure, offset, and gamma correction for high dynamic range changes.",
            parameterSummary: "exposure (-20..20), offset (-0.5..0.5), gamma (0.01..9.99)"
        ),
        CommandDefinition(
            id: "layer.newAdjustmentLayer.hueSaturation",
            label: "Hue / Saturation",
            category: .adjustment,
            description: "Shifts overall color hue, saturation intensity, and lightness.",
            parameterSummary: "hue (-180..180), saturation (-100..100), lightness (-100..100), colorize (bool)"
        ),
        CommandDefinition(
            id: "layer.newAdjustmentLayer.levels",
            label: "Levels",
            category: .adjustment,
            description: "Adjusts tonal values by setting input black/white points and gamma midtones.",
            parameterSummary: "inBlack (0..253), inWhite (2..255), outBlack (0..255), outWhite (0..255), gamma (0.01..9.99)"
        ),
        CommandDefinition(
            id: "layer.newAdjustmentLayer.curves",
            label: "Curves",
            category: .adjustment,
            description: "Controls tonal mapping across shadows, midtones, and highlights with control points.",
            parameterSummary: "points ([[x, y], ...], 0..255)"
        ),
        CommandDefinition(
            id: "layer.newAdjustmentLayer.photoFilter",
            label: "Photo Filter",
            category: .adjustment,
            description: "Simulates optical photographic warming, cooling, or color filtration.",
            parameterSummary: "filter (warming85, cooling80, sepia, deepEmerald, etc.), density (0..100), preserveLuminosity (bool)"
        ),
        CommandDefinition(
            id: "layer.newAdjustmentLayer.colorBalance",
            label: "Color Balance",
            category: .adjustment,
            description: "Changes the overall mixture of colors for shadows, midtones, and highlights.",
            parameterSummary: "shadows ([c-r, m-g, y-b]), midtones ([c-r, m-g, y-b]), highlights ([c-r, m-g, y-b])"
        ),
        CommandDefinition(
            id: "layer.newAdjustmentLayer.blackWhite",
            label: "Black & White",
            category: .adjustment,
            description: "Converts color images to monochrome with granular per-channel tonal controls.",
            parameterSummary: "reds (-200..300), yellows, greens, cyans, blues, magentas, tint (bool), tintColor (hex)"
        ),
        CommandDefinition(
            id: "layer.newAdjustmentLayer.invert",
            label: "Invert",
            category: .adjustment,
            description: "Inverts all composite color values to their photographic negative.",
            parameterSummary: "{}"
        ),
        CommandDefinition(
            id: "layer.newAdjustmentLayer.posterize",
            label: "Posterize",
            category: .adjustment,
            description: "Reduces the number of tonal levels in each color channel.",
            parameterSummary: "levels (2..255)"
        ),
        CommandDefinition(
            id: "layer.newAdjustmentLayer.threshold",
            label: "Threshold",
            category: .adjustment,
            description: "Converts grayscale or color images into high-contrast black-and-white.",
            parameterSummary: "level (1..255)"
        ),

        // Filters
        CommandDefinition(
            id: "filter.blur.gaussianBlur",
            label: "Gaussian Blur",
            category: .filter,
            description: "Quickly softens a selection or layer with a bell-shaped bell curve radius.",
            parameterSummary: "radius (0.1..1000.0)"
        ),
        CommandDefinition(
            id: "filter.blur.surfaceBlur",
            label: "Surface Blur",
            category: .filter,
            description: "Blurs an image while retaining edge sharpness, great for skin smoothing.",
            parameterSummary: "radius (1.0..100.0), threshold (2.0..255.0)"
        ),
        CommandDefinition(
            id: "filter.blur.motionBlur",
            label: "Motion Blur",
            category: .filter,
            description: "Blurs in a specified directional angle to simulate camera or object movement.",
            parameterSummary: "angle (-360..360), distance (1.0..2000.0)"
        ),
        CommandDefinition(
            id: "filter.sharpen.smartSharpen",
            label: "Smart Sharpen",
            category: .filter,
            description: "Advanced sharpening with noise suppression and edge halo control.",
            parameterSummary: "amount (1.0..500.0), radius (0.1..64.0), reduceNoise (0.0..100.0)"
        ),
        CommandDefinition(
            id: "filter.sharpen.unsharpMask",
            label: "Unsharp Mask",
            category: .filter,
            description: "Classic high-contrast edge enhancement sharpening.",
            parameterSummary: "amount (1.0..500.0), radius (0.1..1000.0), threshold (0.0..255.0)"
        ),
        CommandDefinition(
            id: "filter.noise.addNoise",
            label: "Add Noise",
            category: .filter,
            description: "Applies random noise or film grain to blend layers or add analog texture.",
            parameterSummary: "amount (0.1..400.0), distribution (uniform/gaussian), monochromatic (bool)"
        ),
        CommandDefinition(
            id: "filter.pixelate.mosaic",
            label: "Mosaic",
            category: .filter,
            description: "Groups pixels into square pixel blocks for censorship or 8-bit styling.",
            parameterSummary: "cellSize (2.0..200.0)"
        ),
        CommandDefinition(
            id: "filter.distort.twirl",
            label: "Twirl",
            category: .filter,
            description: "Rotates an image more sharply in the center than at the edges.",
            parameterSummary: "angle (-999.0..999.0)"
        ),
        CommandDefinition(
            id: "filter.distort.pinch",
            label: "Pinch",
            category: .filter,
            description: "Squeezes or expands a selection inwards or outwards.",
            parameterSummary: "amount (-100.0..100.0)"
        ),

        // Edit & History
        CommandDefinition(
            id: "edit.undo",
            label: "Undo",
            category: .edit,
            description: "Reverts the previous document editing operation in PhotoCraft's history stack.",
            parameterSummary: "{}"
        ),
        CommandDefinition(
            id: "edit.redo",
            label: "Redo",
            category: .edit,
            description: "Re-applies the next document editing operation in PhotoCraft's history stack.",
            parameterSummary: "{}"
        )
    ]
}
