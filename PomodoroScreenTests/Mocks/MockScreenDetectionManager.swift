//
//  MockScreenDetectionManager.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2025-09-23.
//  Mock类用于测试屏幕检测功能
//

import Foundation
@testable import PomodoroScreen

class MockScreenDetectionManager {
    
    // MARK: - Properties
    
    /// 模拟的屏幕配置变化回调
    var onScreenConfigurationChanged: ((Bool) -> Void)?
    
    /// 模拟的外部屏幕状态
    private(set) var hasExternalScreen: Bool = false
    
    /// 模拟的自动检测开关状态
    var isAutoDetectionEnabled: Bool = true
    
    /// 模拟的屏幕列表
    private var mockScreens: [MockScreen] = []
    
    // MARK: - Mock Screen Structure
    
    struct MockScreen {
        let width: CGFloat
        let height: CGFloat
        let isMain: Bool
        
        var frame: CGRect {
            return CGRect(x: 0, y: 0, width: width, height: height)
        }
    }
    
    // MARK: - Mock Methods
    
    /// 模拟添加外部屏幕
    func simulateExternalScreenConnected(width: CGFloat = 1920, height: CGFloat = 1080) {
        let externalScreen = MockScreen(width: width, height: height, isMain: false)
        mockScreens.append(externalScreen)
        
        let previousStatus = hasExternalScreen
        hasExternalScreen = checkForExternalScreens()
        
        print("📺 [Mock] 模拟外部屏幕连接: \(Int(width))x\(Int(height))")
        
        if previousStatus != hasExternalScreen {
            onScreenConfigurationChanged?(hasExternalScreen)
        }
    }
    
    /// 模拟断开外部屏幕
    func simulateExternalScreenDisconnected() {
        // 移除所有非主屏幕
        mockScreens.removeAll { !$0.isMain }
        
        let previousStatus = hasExternalScreen
        hasExternalScreen = checkForExternalScreens()
        
        print("📺 [Mock] 模拟外部屏幕断开")
        
        if previousStatus != hasExternalScreen {
            onScreenConfigurationChanged?(hasExternalScreen)
        }
    }
    
    /// 模拟投屏场景（镜像显示）
    func simulateScreencasting(mirrorResolution: Bool = true) {
        let mainScreen = mockScreens.first { $0.isMain } ?? MockScreen(width: 1440, height: 900, isMain: true)
        
        let projectorScreen: MockScreen
        if mirrorResolution {
            // 镜像投屏 - 相同分辨率
            projectorScreen = MockScreen(width: mainScreen.width, height: mainScreen.height, isMain: false)
        } else {
            // 投屏到投影仪 - 常见投屏分辨率
            projectorScreen = MockScreen(width: 1024, height: 768, isMain: false)
        }
        
        mockScreens.append(projectorScreen)
        
        let previousStatus = hasExternalScreen
        hasExternalScreen = checkForExternalScreens()
        
        print("📺 [Mock] 模拟投屏: \(Int(projectorScreen.width))x\(Int(projectorScreen.height)) (镜像: \(mirrorResolution))")
        
        if previousStatus != hasExternalScreen {
            onScreenConfigurationChanged?(hasExternalScreen)
        }
    }
    
    /// 模拟重置到单屏状态
    func simulateResetToSingleScreen() {
        mockScreens = [MockScreen(width: 1440, height: 900, isMain: true)]
        
        let previousStatus = hasExternalScreen
        hasExternalScreen = false
        
        print("📺 [Mock] 重置为单屏状态")
        
        if previousStatus != hasExternalScreen {
            onScreenConfigurationChanged?(hasExternalScreen)
        }
    }
    
    // MARK: - Screen Detection Logic (模拟原始逻辑)
    
    func checkForExternalScreens() -> Bool {
        let hasExternal = mockScreens.count > 1
        
        print("📺 [Mock] 屏幕检测: 总屏幕数 \(mockScreens.count), 外部屏幕: \(hasExternal)")
        
        for (index, screen) in mockScreens.enumerated() {
            let isMain = screen.isMain
            print("📺 [Mock] 屏幕 \(index): \(Int(screen.width))x\(Int(screen.height)) \(isMain ? "(主屏幕)" : "(外部屏幕)")")
        }
        
        return hasExternal
    }
    
    func isScreencasting() -> Bool {
        guard mockScreens.count > 1 else {
            return false
        }
        
        let mainScreen = mockScreens.first { $0.isMain }
        guard let mainScreen = mainScreen else { return false }
        
        for screen in mockScreens {
            if !screen.isMain {
                // 检查是否是镜像屏幕（相同或相似分辨率）
                let widthDiff = abs(screen.width - mainScreen.width)
                let heightDiff = abs(screen.height - mainScreen.height)
                
                if widthDiff < 10 && heightDiff < 10 {
                    print("📺 [Mock] 检测到可能的投屏: \(Int(screen.width))x\(Int(screen.height))")
                    return true
                }
                
                if isCommonProjectionResolution(screen) {
                    print("📺 [Mock] 检测到常见投屏分辨率: \(Int(screen.width))x\(Int(screen.height))")
                    return true
                }
            }
        }
        
        return true // 有外部屏幕就认为可能需要会议模式
    }
    
    func shouldAutoEnableMeetingMode() -> Bool {
        return isAutoDetectionEnabled && (hasExternalScreen || isScreencasting())
    }
    
    // MARK: - Helper Methods
    
    private func isCommonProjectionResolution(_ screen: MockScreen) -> Bool {
        let width = Int(screen.width)
        let height = Int(screen.height)
        
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
    
    // MARK: - Initialization
    
    init() {
        // 默认单屏状态
        mockScreens = [MockScreen(width: 1440, height: 900, isMain: true)]
        print("📺 [Mock] MockScreenDetectionManager 初始化完成")
    }
}
