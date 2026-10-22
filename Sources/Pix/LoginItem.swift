import Foundation

/// Keeps first launch and app relocation rules together; the app supplies macOS's current login status.
@MainActor
struct LoginItem {
    var path: String
    var savedPath: () -> String?
    var savePath: (String) -> Void
    var enabled: () -> Bool
    var register: () throws -> Void
    var unregister: () throws -> Void

    func sync() throws {
        let previous = savedPath()
        defer {
            if previous == nil || enabled() { savePath(path) }
        }
        if previous == nil {
            try register()
        } else if enabled() && previous != path {
            try unregister()
            try register()
        }
    }

    func setEnabled(_ on: Bool) throws {
        defer { savePath(path) }
        if on { try register() }
        else if enabled() { try unregister() }
    }
}
