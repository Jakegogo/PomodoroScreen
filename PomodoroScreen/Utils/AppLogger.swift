import Foundation

/// 统一应用日志（SQL + 状态机）按天滚动输出
final class AppLogger {
    static let shared = AppLogger()

    private let fileManager = FileManager.default
    private let logDirectory: URL
    private let queue = DispatchQueue(label: "com.pomodoroscreen.applogger", qos: .utility)

    private init() {
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupportDir.appendingPathComponent("PomodoroScreen")
        logDirectory = appDir.appendingPathComponent("Logs")
        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    private func logFileURL(for date: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        #if DEBUG
        let prefix = "app-debug-"
        #else
        let prefix = "app-"
        #endif
        let name = "\(prefix)\(formatter.string(from: date)).log"
        return logDirectory.appendingPathComponent(name)
    }

    // MARK: - SQL
    func logSQL(_ sql: String, params: [Any?] = [], tag: String? = nil) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let prefix = tag != nil ? "[\(tag!)]" : ""
        let paramsString = params.enumerated().map { (idx, v) in
            if let v = v {
                return "\(idx+1): \(String(describing: v))"
            } else {
                return "\(idx+1): NULL"
            }
        }.joined(separator: ", ")
        let line = "\(timestamp) \(prefix) SQL: \(sql)\nPARAMS: [\(paramsString)]\n\n"
        write(line)
    }

    // MARK: - State Machine
    func logStateMachine(_ message: String, tag: String? = nil) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let prefix = tag != nil ? "[\(tag!)]" : ""
        let line = "\(timestamp) \(prefix) SM: \(message)\n"
        write(line)
    }

    // MARK: - File Write
    private func write(_ line: String) {
        queue.async {
            let url = self.logFileURL()
            guard let data = line.data(using: .utf8) else { return }
            if self.fileManager.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    defer { try? handle.close() }
                    try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                }
            } else {
                try? data.write(to: url)
            }
        }
    }
}


