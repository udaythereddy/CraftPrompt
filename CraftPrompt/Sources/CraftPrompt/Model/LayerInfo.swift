import Foundation

public struct LayerItem: Identifiable, Sendable, Equatable {
    public let id: Int
    public var name: String
    public var kind: LayerKind
    public var visible: Bool
    public var opacity: Double // 0.0 .. 1.0
    public var blendMode: String
    public var bounds: [Int]? // [x, y, w, h]
    public var selected: Bool
    public var active: Bool

    public enum LayerKind: String, Sendable, Codable {
        case pixel
        case adjustment
        case group
        case smart
        case type
        case shape
        case unknown

        public var sfSymbol: String {
            switch self {
            case .pixel: return "photo.fill"
            case .adjustment: return "slider.horizontal.2.square"
            case .group: return "folder.fill"
            case .smart: return "cube.transparent.fill"
            case .type: return "character"
            case .shape: return "square.on.circle"
            case .unknown: return "square.fill"
            }
        }
    }

    public init(
        id: Int,
        name: String,
        kind: LayerKind = .pixel,
        visible: Bool = true,
        opacity: Double = 1.0,
        blendMode: String = "Normal",
        bounds: [Int]? = nil,
        selected: Bool = false,
        active: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.visible = visible
        self.opacity = opacity
        self.blendMode = blendMode
        self.bounds = bounds
        self.selected = selected
        self.active = active
    }

    public static func from(json: [String: Any]) -> LayerItem? {
        guard let id = json["id"] as? Int ?? (json["id"] as? NSNumber)?.intValue else { return nil }
        let name = json["name"] as? String ?? "Layer \(id)"
        let kindStr = (json["kind"] as? String)?.lowercased() ?? "pixel"
        let kind = LayerKind(rawValue: kindStr) ?? .unknown
        let visible = json["visible"] as? Bool ?? true
        let opacity = json["opacity"] as? Double ?? 1.0
        let blend = json["blend"] as? String ?? "Normal"
        let bounds = json["bounds"] as? [Int]
        let selected = json["selected"] as? Bool ?? false
        let active = json["active"] as? Bool ?? false

        return LayerItem(
            id: id,
            name: name,
            kind: kind,
            visible: visible,
            opacity: opacity,
            blendMode: blend,
            bounds: bounds,
            selected: selected,
            active: active
        )
    }
}
