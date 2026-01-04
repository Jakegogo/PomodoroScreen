//
//  ScreenDetectionManager.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-23.
//  屏幕检测管理器，用于检测投屏和外接显示器
//

import Cocoa

class ScreenDetectionManager {
    
    // MARK: - Properties
    
    /// 单例实例
    static let shared = ScreenDetectionManager()
    
    /// 屏幕变化回调
    var onScreenConfigurationChanged: ((Bool) -> Void)?
    
    /// 当前是否检测到外部屏幕
    private(set) var hasExternalScreen: Bool = false
    
    /// 是否启用自动检测投屏进入专注模式
    var isAutoDetectionEnabled: Bool {
        get { SettingsStore.autoDetectScreencastEnabled }
        set { SettingsStore.autoDetectScreencastEnabled = newValue }
    }
    
    // MARK: - Initialization
    
    private init() {
        setupScreenChangeNotification()
        updateScreenStatus()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// 检查当前是否有外部屏幕连接
    func checkForExternalScreens() -> Bool {
        let screens = NSScreen.screens
        let hasExternal = screens.count > 1
        
        print("📺 屏幕检测: 总屏幕数 \(screens.count), 外部屏幕: \(hasExternal)")
        
        // 详细日志输出
        for (index, screen) in screens.enumerated() {
            let frame = screen.frame
            let isMain = screen == NSScreen.main
            print("📺 屏幕 \(index): \(Int(frame.width))x\(Int(frame.height)) \(isMain ? "(主屏幕)" : "(外部屏幕)")")
        }
        
        return hasExternal
    }
    
    /// 检查是否正在投屏（更精确的检测）
    func isScreencasting() -> Bool {
        let screens = NSScreen.screens
        
        // 基本检测：多于一个屏幕
        guard screens.count > 1 else {
            return false
        }
        
        // 高级检测：检查是否有相同分辨率的屏幕（可能是镜像投屏）
        let mainScreen = NSScreen.main
        guard let mainScreen = mainScreen else { return false }
        
        let mainSize = mainScreen.frame.size
        
        for screen in screens {
            if screen != mainScreen {
                let screenSize = screen.frame.size
                
                // 检查是否是镜像屏幕（相同或相似分辨率）
                let widthDiff = abs(screenSize.width - mainSize.width)
                let heightDiff = abs(screenSize.height - mainSize.height)
                
                // 如果分辨率完全相同，很可能是投屏
                if widthDiff < 10 && heightDiff < 10 {
                    print("📺 检测到可能的投屏: \(Int(screenSize.width))x\(Int(screenSize.height))")
                    return true
                }
                
                // 如果是常见的投屏分辨率
                if isCommonProjectionResolution(screenSize) {
                    print("📺 检测到常见投屏分辨率: \(Int(screenSize.width))x\(Int(screenSize.height))")
                    return true
                }
            }
        }
        
        // 如果有外部屏幕但不是明显的投屏，仍然认为可能需要专注模式
        return true
    }
    
    /// 手动刷新屏幕状态
    func refreshScreenStatus() {
        updateScreenStatus()
    }
    
    // MARK: - Private Methods
    
    private func setupScreenChangeNotification() {
        // 监听屏幕配置变化通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        print("📺 屏幕检测管理器已启动，开始监听屏幕变化")
    }
    
    @objc private func screenConfigurationChanged() {
        print("📺 屏幕配置发生变化")
        
        // 延迟一点执行，确保屏幕配置已经稳定
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateScreenStatus()
        }
    }
    
    private func updateScreenStatus() {
        let newHasExternalScreen = checkForExternalScreens()
        let previousStatus = hasExternalScreen
        
        hasExternalScreen = newHasExternalScreen
        
        // 如果状态发生变化，通知回调
        if previousStatus != newHasExternalScreen {
            print("📺 屏幕状态变化: \(previousStatus) -> \(newHasExternalScreen)")
            onScreenConfigurationChanged?(newHasExternalScreen)
        }
    }
    
    /// 检查是否是常见的投屏分辨率
    private func isCommonProjectionResolution(_ size: CGSize) -> Bool {
        let width = Int(size.width)
        let height = Int(size.height)
        
        // 常见的投影仪和会议室显示器分辨率
        let commonResolutions: [(Int, Int)] = [
            (1920, 1080), // Full HD
            (1280, 720),  // HD
            (1024, 768),  // XGA
            (1280, 800),  // WXGA
            (1366, 768),  // 常见笔记本分辨率
            (1600, 900),  // HD+
            (1440, 900),  // WXGA+
            (1680, 1050), // WSXGA+
        ]
        
        for (w, h) in commonResolutions {
            if (width == w && height == h) || (width == h && height == w) {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Convenience Methods

extension ScreenDetectionManager {
    
    /// 获取屏幕信息描述
    func getScreenInfoDescription() -> String {
        let screens = NSScreen.screens
        var info = "屏幕数量: \(screens.count)\n"
        
        for (index, screen) in screens.enumerated() {
            let frame = screen.frame
            let isMain = screen == NSScreen.main
            info += "屏幕 \(index + 1): \(Int(frame.width))x\(Int(frame.height))"
            if isMain {
                info += " (主屏幕)"
            }
            info += "\n"
        }
        
        return info
    }
    
    /// 检查是否应该自动启用专注模式
    func shouldAutoEnableMeetingMode() -> Bool {
        return isAutoDetectionEnabled && (hasExternalScreen || isScreencasting())
    }
}
