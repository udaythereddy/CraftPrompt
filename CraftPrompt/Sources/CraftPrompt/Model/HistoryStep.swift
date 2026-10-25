import Foundation

public struct HistoryStep: Identifiable, Sendable, Equatable {
    public let id: String
    public let stepNumber: Int
    public let userPrompt: String
    public let commandsDescription: String
    public let commandNames: [String]
    public let timestamp: Date
    public let durationMs: Int
    public var isActiveState: Bool

    public init(
        id: String = UUID().uuidString,
        stepNumber: Int,
        userPrompt: String,
        commandsDescription: String,
        commandNames: [String] = [],
        timestamp: Date = Date(),
        durationMs: Int = 0,
        isActiveState: Bool = true
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.userPrompt = userPrompt
        self.commandsDescription = commandsDescription
        self.commandNames = commandNames
        self.timestamp = timestamp
        self.durationMs = durationMs
        self.isActiveState = isActiveState
    }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}
