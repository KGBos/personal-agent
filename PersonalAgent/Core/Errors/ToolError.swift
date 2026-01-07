import Foundation

enum ToolError: Error, LocalizedError {
    case invalidArguments(String)
    case notAllowed(String)
    case executionFailed(String)
    case permissionDenied(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let msg): return "Invalid arguments: \(msg)"
        case .notAllowed(let msg): return "Not allowed: \(msg)"
        case .executionFailed(let msg): return "Execution failed: \(msg)"
        case .permissionDenied(let msg): return "Permission denied: \(msg)"
        case .notFound(let msg): return "Not found: \(msg)"
        }
    }
}
