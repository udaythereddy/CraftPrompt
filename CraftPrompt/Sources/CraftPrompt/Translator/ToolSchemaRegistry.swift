import Foundation

public struct ToolSchemaRegistry: Sendable {
    /// Generates the standard system prompt describing PhotoCraft's editing capabilities and command payload format.
    public static func generateSystemPrompt() -> String {
        var catalogSummary = ""
        for cmd in CommandCatalog.allCommands {
            catalogSummary += "- `\(cmd.id)`: \(cmd.description) Parameters: \(cmd.parameterSummary)\n"
        }

        return """
        You are CraftPrompt, an expert photo-editing intelligence that translates colloquial user requests into sequential, deterministic PhotoCraft command payloads.

        Available PhotoCraft engine commands:
        \(catalogSummary)

        Rules:
        1. When the user requests warm sunset tones, boost vibrance, adjust curves, or add a warming photo filter.
        2. When the user asks for blur/sharpen, remember filters run on pixel layers.
        3. Always choose non-destructive adjustment layers (`layer.newAdjustmentLayer.*`) where possible.
        4. Return an array of structured command steps with their exact JSON parameter schemas.
        5. Clamp all numeric parameters to their documented boundaries.
        """
    }

    /// Returns OpenAI/Anthropic/Ollama compatible function/tool calling JSON schemas
    public static func getToolsJsonSchema() -> [[String: Any]] {
        return [
            [
                "type": "function",
                "function": [
                    "name": "photocraft_batch",
                    "description": "Executes an ordered batch of PhotoCraft image editing commands.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "steps": [
                                "type": "array",
                                "description": "List of commands and parameters to execute in sequence.",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "command": [
                                            "type": "string",
                                            "description": "PhotoCraft command ID (e.g. layer.newAdjustmentLayer.vibrance, filter.blur.gaussianBlur)"
                                        ],
                                        "params": [
                                            "type": "object",
                                            "description": "Key-value parameter payload for the command."
                                        ]
                                    ],
                                    "required": ["command", "params"]
                                ]
                            ]
                        ],
                        "required": ["steps"]
                    ]
                ]
            ]
        ]
    }
}
