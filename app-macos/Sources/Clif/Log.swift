import Foundation
import os.log

enum LogSubsystem: String {
    case app = "app"
    case hotkey = "hotkey"
    case capture = "capture"
    case encoding = "encoding"
    case storage = "storage"
}

enum Log {
    private static let bundleIdentifier = "com.clif.app"

    private static func logger(for subsystem: LogSubsystem) -> Logger {
        Logger(subsystem: bundleIdentifier, category: subsystem.rawValue)
    }

    static func debug(_ message: String, subsystem: LogSubsystem) {
        logger(for: subsystem).debug("\(message, privacy: .public)")
    }

    static func info(_ message: String, subsystem: LogSubsystem) {
        logger(for: subsystem).info("\(message, privacy: .public)")
    }

    static func warning(_ message: String, subsystem: LogSubsystem) {
        logger(for: subsystem).warning("\(message, privacy: .public)")
    }

    static func error(_ message: String, subsystem: LogSubsystem) {
        logger(for: subsystem).error("\(message, privacy: .public)")
    }
}
