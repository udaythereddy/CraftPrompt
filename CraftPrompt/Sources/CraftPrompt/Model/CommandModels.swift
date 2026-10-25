import Foundation

// MARK: - Dynamic JSON Value

public enum AnyCodable: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])

    public init(_ value: Any?) {
        guard let value = value else {
            self = .null
            return
        }
        if let b = value as? Bool {
            self = .bool(b)
        } else if let i = value as? Int {
            self = .int(i)
        } else if let d = value as? Double {
            self = .double(d)
        } else if let f = value as? Float {
            self = .double(Double(f))
        } else if let s = value as? String {
            self = .string(s)
        } else if let arr = value as? [Any] {
            self = .array(arr.map { AnyCodable($0) })
        } else if let dict = value as? [String: Any] {
            self = .dictionary(dict.mapValues { AnyCodable($0) })
        } else if let anyCodable = value as? AnyCodable {
            self = anyCodable
        } else {
            self = .string("\(value)")
        }
    }

    public var rawValue: Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let b):
            return b
        case .int(let i):
            return i
        case .double(let d):
            return d
        case .string(let s):
            return s
        case .array(let a):
            return a.map { $0.rawValue }
        case .dictionary(let d):
            return d.mapValues { $0.rawValue }
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([AnyCodable].self) {
            self = .array(a)
        } else if let d = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(d)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown AnyCodable payload")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let b):
            try container.encode(b)
        case .int(let i):
            try container.encode(i)
        case .double(let d):
            try container.encode(d)
        case .string(let s):
            try container.encode(s)
        case .array(let a):
            try container.encode(a)
        case .dictionary(let d):
            try container.encode(d)
        }
    }
}

// MARK: - RPC Message Envelopes

public struct RpcRequest: Codable, Sendable {
    public let id: String
    public let method: String
    public let params: AnyCodable?

    public init(id: String = UUID().uuidString, method: String, params: AnyCodable? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct RpcResponse: Codable, Sendable {
    public let id: String?
    public let ok: Bool?
    public let result: AnyCodable?
    public let error: String?

    public var isSuccess: Bool {
        return (ok == true) || (error == nil && result != nil)
    }
}

// MARK: - Batch Models

public struct BatchStepItem: Codable, Sendable {
    public let command: String
    public let params: [String: AnyCodable]?
    public let wait: Bool?

    public init(command: String, params: [String: AnyCodable]? = nil, wait: Bool? = true) {
        self.command = command
        self.params = params
        self.wait = wait
    }
}

public struct BatchExecutionReport: Sendable {
    public let completed: Int
    public let failed: Int
    public let results: [AnyCodable]
}

// MARK: - Document Metadata

public struct DocumentMetadata: Sendable, Equatable {
    public var name: String
    public var width: Int
    public var height: Int
    public var mode: String
    public var depth: Int
    public var layersCount: Int

    public init(name: String = "Untitled", width: Int = 0, height: Int = 0, mode: String = "RGB", depth: Int = 8, layersCount: Int = 1) {
        self.name = name
        self.width = width
        self.height = height
        self.mode = mode
        self.depth = depth
        self.layersCount = layersCount
    }
}
