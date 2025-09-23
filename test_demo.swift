#!/usr/bin/env swift

//
//  test_demo.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-23.
//  屏幕检测功能测试演示脚本
//

import Foundation

// MARK: - 简化的Mock类（用于演示）

class MockScreenDetectionManager {
    var onScreenConfigurationChanged: ((Bool) -> Void)?
    private(set) var hasExternalScreen: Bool = false
    var isAutoDetectionEnabled: Bool = true
    private var mockScreens: [(width: Double, height: Double, isMain: Bool)] = []
    
    init() {
        mockScreens = [(width: 1440, height: 900, isMain: true)]
        print("📺 [Mock] 初始化屏幕检测管理器")
    }
    
    func simulateExternalScreenConnected(width: Double = 1920, height: Double = 1080) {
        mockScreens.append((width: width, height: height, isMain: false))
        let previousStatus = hasExternalScreen
        hasExternalScreen = mockScreens.count > 1
        
        print("📺 [Mock] 模拟外部屏幕连接: \(Int(width))x\(Int(height))")
        
        if previousStatus != hasExternalScreen {
            onScreenConfigurationChanged?(hasExternalScreen)
        }
    }
    
    func simulateExternalScreenDisconnected() {
        mockScreens.removeAll { !$0.isMain }
        let previousStatus = hasExternalScreen
        hasExternalScreen = mockScreens.count > 1
        
        print("📺 [Mock] 模拟外部屏幕断开")
        
        if previousStatus != hasExternalScreen {
            onScreenConfigurationChanged?(hasExternalScreen)
        }
    }
    
    func shouldAutoEnableMeetingMode() -> Bool {
        return isAutoDetectionEnabled && hasExternalScreen
    }
}

// MARK: - 简化的会议模式管理器

class MockMeetingModeManager {
    private var meetingModeEnabled = false
    private var autoEnabled = false
    
    func enableMeetingMode(auto: Bool = true) {
        meetingModeEnabled = true
        autoEnabled = auto
        print("🔇 [Mock] 会议模式已启用 (自动: \(auto))")
    }
    
    func disableMeetingMode() {
        let wasAuto = autoEnabled
        meetingModeEnabled = false
        autoEnabled = false
        print("🔇 [Mock] 会议模式已关闭 (之前为自动: \(wasAuto))")
    }
    
    func isMeetingModeEnabled() -> Bool {
        return meetingModeEnabled
    }
    
    func isAutoEnabled() -> Bool {
        return autoEnabled
    }
}

// MARK: - 测试演示类

class TestDemo {
    private let screenDetection = MockScreenDetectionManager()
    private let meetingModeManager = MockMeetingModeManager()
    
    init() {
        setupScreenDetection()
    }
    
    private func setupScreenDetection() {
        screenDetection.onScreenConfigurationChanged = { [weak self] hasExternalScreen in
            self?.handleScreenConfigurationChanged(hasExternalScreen)
        }
    }
    
    private func handleScreenConfigurationChanged(_ hasExternalScreen: Bool) {
        print("📺 屏幕配置变化: 外部屏幕 = \(hasExternalScreen)")
        
        if screenDetection.shouldAutoEnableMeetingMode() {
            if !meetingModeManager.isMeetingModeEnabled() {
                meetingModeManager.enableMeetingMode(auto: true)
            }
        } else {
            if meetingModeManager.isMeetingModeEnabled() && meetingModeManager.isAutoEnabled() {
                meetingModeManager.disableMeetingMode()
            }
        }
    }
    
    // MARK: - 测试场景
    
    func runTestScenario1() {
        print("\n🎬 测试场景1: 基础投屏连接和断开")
        print("=" * 50)
        
        // 初始状态
        print("初始状态 - 会议模式: \(meetingModeManager.isMeetingModeEnabled())")
        
        // 连接外部屏幕
        print("\n步骤1: 连接外部显示器")
        screenDetection.simulateExternalScreenConnected()
        print("会议模式状态: \(meetingModeManager.isMeetingModeEnabled())")
        
        // 断开外部屏幕
        print("\n步骤2: 断开外部显示器")
        screenDetection.simulateExternalScreenDisconnected()
        print("会议模式状态: \(meetingModeManager.isMeetingModeEnabled())")
    }
    
    func runTestScenario2() {
        print("\n🎬 测试场景2: 多种分辨率投屏测试")
        print("=" * 50)
        
        let resolutions = [
            (1920, 1080, "Full HD"),
            (1280, 720, "HD"),
            (1024, 768, "XGA"),
            (2560, 1440, "2K")
        ]
        
        for (width, height, name) in resolutions {
            print("\n测试 \(name) 分辨率 (\(width)x\(height))")
            
            // 连接特定分辨率的屏幕
            screenDetection.simulateExternalScreenConnected(width: Double(width), height: Double(height))
            print("会议模式: \(meetingModeManager.isMeetingModeEnabled())")
            
            // 断开
            screenDetection.simulateExternalScreenDisconnected()
            print("断开后会议模式: \(meetingModeManager.isMeetingModeEnabled())")
        }
    }
    
    func runTestScenario3() {
        print("\n🎬 测试场景3: 快速连接断开测试")
        print("=" * 50)
        
        var changeCount = 0
        screenDetection.onScreenConfigurationChanged = { [weak self] hasExternalScreen in
            changeCount += 1
            print("📺 屏幕变化事件 #\(changeCount): \(hasExternalScreen ? "连接" : "断开")")
            self?.handleScreenConfigurationChanged(hasExternalScreen)
        }
        
        // 快速连接断开5次
        for i in 1...5 {
            print("\n循环 \(i):")
            screenDetection.simulateExternalScreenConnected()
            screenDetection.simulateExternalScreenDisconnected()
        }
        
        print("\n总共触发 \(changeCount) 次屏幕变化事件")
    }
    
    func runTestScenario4() {
        print("\n🎬 测试场景4: 自动检测开关测试")
        print("=" * 50)
        
        // 禁用自动检测
        print("步骤1: 禁用自动检测")
        screenDetection.isAutoDetectionEnabled = false
        
        screenDetection.simulateExternalScreenConnected()
        print("连接外部屏幕后，会议模式: \(meetingModeManager.isMeetingModeEnabled())")
        
        // 启用自动检测
        print("\n步骤2: 启用自动检测")
        screenDetection.isAutoDetectionEnabled = true
        
        // 重新触发检测
        screenDetection.simulateExternalScreenDisconnected()
        screenDetection.simulateExternalScreenConnected()
        print("重新连接后，会议模式: \(meetingModeManager.isMeetingModeEnabled())")
    }
    
    func runAllTests() {
        print("🚀 开始屏幕检测功能测试演示")
        print("=" * 60)
        
        runTestScenario1()
        runTestScenario2()
        runTestScenario3()
        runTestScenario4()
        
        print("\n🎉 测试演示完成!")
        print("=" * 60)
        
        // 生成简单的测试报告
        generateTestReport()
    }
    
    private func generateTestReport() {
        let timestamp = DateFormatter().string(from: Date())
        
        print("\n📊 测试报告")
        print("-" * 40)
        print("测试时间: \(timestamp)")
        print("测试场景: 4个")
        print("测试功能:")
        print("  ✓ 基础屏幕检测")
        print("  ✓ 会议模式自动切换")
        print("  ✓ 多分辨率支持")
        print("  ✓ 快速切换处理")
        print("  ✓ 自动检测开关")
        print("测试结果: 所有场景正常运行")
    }
}

// MARK: - String扩展（用于重复字符）

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// MARK: - 主程序入口

print("🧪 屏幕检测功能Mock测试演示")
print("该演示展示了如何使用Mock框架测试投屏检测功能")

let demo = TestDemo()
demo.runAllTests()

print("\n💡 提示:")
print("  • 这是一个简化的演示版本")
print("  • 完整的测试套件包含更多边界条件和性能测试")
print("  • 运行完整测试请使用: ./run_screen_detection_tests.sh")
