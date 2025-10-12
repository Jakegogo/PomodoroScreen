import Foundation
@testable import PomodoroScreen

struct TestStatisticsDatabasePathProvider: StatisticsDatabasePathProviding {
    static func isRunningUnitTests() -> Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    
    private static func resolveIntegrationDir() -> URL? {
        let fm = FileManager.default
        // A) 通过源文件路径推导（当前文件位于 Tests/Integration 下）
        let sourcePath = (#file as NSString)
        var url = URL(fileURLWithPath: sourcePath as String)
        url.deleteLastPathComponent() // .../PomodoroScreenTests/Integration
        let candidate = url // Integration 目录
        if fm.fileExists(atPath: candidate.path, isDirectory: nil) { return candidate }
        // B) PWD
        if let pwd = ProcessInfo.processInfo.environment["PWD"] {
            let base = URL(fileURLWithPath: pwd).appendingPathComponent("PomodoroScreenTests/Integration")
            if fm.fileExists(atPath: base.path, isDirectory: nil) { return base }
        }
        // C) CWD
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("PomodoroScreenTests/Integration")
        if fm.fileExists(atPath: cwd.path, isDirectory: nil) { return cwd }
        return nil
    }
    
    func resolveDatabasePath(appSupportDefault: URL) -> URL {
        guard let integration = Self.resolveIntegrationDir() else {
            return appSupportDefault
        }
        if Self.isRunningUnitTests() {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let unique = "statistics-\(formatter.string(from: Date())).db"
            return integration.appendingPathComponent(unique)
        } else {
            return integration.appendingPathComponent("statistics.db")
        }
    }
}
