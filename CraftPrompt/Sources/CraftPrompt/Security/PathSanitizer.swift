import Foundation

public enum SecurityError: LocalizedError, Equatable {
    case pathTraversalDetected(String)
    case outsideAllowedRoots(String)
    case dangerousCharactersDetected(String)
    case nullByteDetected
    case fileNotFound(String)
    case unsupportedFileType(String)
    case parameterOutOfBounds(command: String, parameter: String, value: String, allowedRange: String)
    case invalidParameterType(command: String, parameter: String, expected: String)
    case injectionAttemptDetected(String)

    public var errorDescription: String? {
        switch self {
        case .pathTraversalDetected(let path):
            return "Security Violation: Directory traversal attempt detected in '\(path)'."
        case .outsideAllowedRoots(let path):
            return "Security Violation: File path '\(path)' is outside authorized sandbox boundary."
        case .dangerousCharactersDetected(let chars):
            return "Security Violation: Path contains illegal or shell metacharacters: \(chars)"
        case .nullByteDetected:
            return "Security Violation: Null byte poison detected in input string."
        case .fileNotFound(let path):
            return "File does not exist: '\(path)'."
        case .unsupportedFileType(let ext):
            return "File type '.\(ext)' is not supported. Supported formats: PNG, JPG/JPEG, TIFF, PSD, EXR, WEBP, PCRAFT."
        case .parameterOutOfBounds(let cmd, let param, let val, let range):
            return "Parameter validation failed for '\(cmd)': '\(param)' = \(val) is out of bounds (expected: \(range))."
        case .invalidParameterType(let cmd, let param, let expected):
            return "Parameter validation failed for '\(cmd)': '\(param)' must be \(expected)."
        case .injectionAttemptDetected(let token):
            return "Security Violation: Potential command injection token detected: '\(token)'."
        }
    }
}

public struct PathSanitizer: Sendable {
    public static let allowedExtensions: Set<String> = [
        "png", "jpg", "jpeg", "tif", "tiff", "psd", "psb", "webp", "exr", "pcraft"
    ]

    /// Sanitizes an input file path and validates it against allowed root directories.
    public static func sanitize(path inputPath: String, allowedRoots: [URL] = []) throws -> URL {
        // 1. Check for null byte poisoning
        if inputPath.contains("\0") {
            throw SecurityError.nullByteDetected
        }

        // 2. Reject shell control / dangerous metacharacters
        let dangerousSubstrings = [";", "&&", "||", "`", "$", "\n", "\r", "|", ">", "<"]
        for dangerous in dangerousSubstrings {
            if inputPath.contains(dangerous) {
                throw SecurityError.dangerousCharactersDetected(dangerous)
            }
        }

        // 3. Reject relative traversal patterns
        let components = inputPath.components(separatedBy: "/")
        for component in components {
            if component == ".." {
                throw SecurityError.pathTraversalDetected(inputPath)
            }
        }

        // 4. Resolve standardized URL
        let expandedPath = NSString(string: inputPath).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath).standardizedFileURL

        // 5. Verify file extension
        let fileExtension = url.pathExtension.lowercased()
        if !fileExtension.isEmpty && !allowedExtensions.contains(fileExtension) {
            throw SecurityError.unsupportedFileType(fileExtension)
        }

        // 6. If allowedRoots are provided, ensure url is contained within one of them
        if !allowedRoots.isEmpty {
            let standardPath = url.path
            let isContained = allowedRoots.contains { root in
                let standardRoot = root.standardizedFileURL.path
                return standardPath.hasPrefix(standardRoot)
            }
            if !isContained {
                throw SecurityError.outsideAllowedRoots(standardPath)
            }
        }

        return url
    }
}
