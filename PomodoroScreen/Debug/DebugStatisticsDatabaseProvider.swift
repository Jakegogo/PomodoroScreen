import Foundation

#if DEBUG
struct DebugStatisticsDatabasePathProvider: StatisticsDatabasePathProviding {
    private func resolveRepoRoot() -> URL? {
        let fm = FileManager.default
        // A) 从当前源文件位置回溯到仓库根目录
        let sourcePath = (#file as NSString)
        var url = URL(fileURLWithPath: sourcePath as String)
        // 当前文件位于 PomodoroScreen/PomodoroScreen/DebugStatisticsDatabaseProvider.swift
        url.deleteLastPathComponent() // .../PomodoroScreen/PomodoroScreen
        url.deleteLastPathComponent() // .../PomodoroScreen
        if fm.fileExists(atPath: url.path, isDirectory: nil) { return url }
        // B) PWD
        if let pwd = ProcessInfo.processInfo.environment["PWD"] {
            let base = URL(fileURLWithPath: pwd)
            if fm.fileExists(atPath: base.path, isDirectory: nil) { return base }
        }
        // C) CWD
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        if fm.fileExists(atPath: cwd.path, isDirectory: nil) { return cwd }
        return nil
    }
    
    func resolveDatabasePath(appSupportDefault: URL) -> URL {
        guard let root = resolveRepoRoot() else { return appSupportDefault }
        return root.appendingPathComponent("Debug/statistics-debug.db")
    }
}
#endif
