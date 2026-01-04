//
//  ScreenDetectionIntegrationTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2025-09-23.
//  自动检测投屏功能的集成测试
//

import XCTest
@testable import PomodoroScreen

class ScreenDetectionIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    var mockScreenDetection: MockScreenDetectionManager!
    var testExpectation: XCTestExpectation!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockScreenDetection = MockScreenDetectionManager()
        
        // 清理UserDefaults，确保测试环境干净
        UserDefaults.standard.removeObject(forKey: "MeetingModeEnabled")
        UserDefaults.standard.removeObject(forKey: "MeetingModeAutoEnabled")
        UserDefaults.standard.removeObject(forKey: "AutoDetectScreencastEnabled")
        
        print("🧪 测试环境初始化完成")
    }
    
    override func tearDown() {
        mockScreenDetection = nil
        testExpectation = nil
        
        // 清理测试数据
        UserDefaults.standard.removeObject(forKey: "MeetingModeEnabled")
        UserDefaults.standard.removeObject(forKey: "MeetingModeAutoEnabled")
        UserDefaults.standard.removeObject(forKey: "AutoDetectScreencastEnabled")
        
        print("🧪 测试环境清理完成")
        super.tearDown()
    }
    
    // MARK: - 基础屏幕检测测试
    
    func testScreenDetection_SingleScreen() {
        // Given: 单屏状态
        mockScreenDetection.simulateResetToSingleScreen()
        
        // When: 检测屏幕
        let hasExternal = mockScreenDetection.checkForExternalScreens()
        
        // Then: 应该没有外部屏幕
        XCTAssertFalse(hasExternal, "单屏状态下不应该检测到外部屏幕")
        XCTAssertFalse(mockScreenDetection.hasExternalScreen, "hasExternalScreen属性应该为false")
        
        print("✅ testScreenDetection_SingleScreen 通过")
    }
    
    func testScreenDetection_ExternalMonitor() {
        // Given: 连接外部显示器
        mockScreenDetection.simulateExternalScreenConnected(width: 2560, height: 1440)
        
        // When: 检测屏幕
        let hasExternal = mockScreenDetection.checkForExternalScreens()
        
        // Then: 应该检测到外部屏幕
        XCTAssertTrue(hasExternal, "连接外部显示器后应该检测到外部屏幕")
        XCTAssertTrue(mockScreenDetection.hasExternalScreen, "hasExternalScreen属性应该为true")
        
        print("✅ testScreenDetection_ExternalMonitor 通过")
    }
    
    func testScreenDetection_Screencasting() {
        // Given: 投屏状态
        mockScreenDetection.simulateScreencasting(mirrorResolution: true)
        
        // When: 检测投屏
        let isScreencasting = mockScreenDetection.isScreencasting()
        
        // Then: 应该检测到投屏
        XCTAssertTrue(isScreencasting, "镜像投屏状态下应该检测到投屏")
        XCTAssertTrue(mockScreenDetection.hasExternalScreen, "投屏状态下应该有外部屏幕")
        
        print("✅ testScreenDetection_Screencasting 通过")
    }
    
    // MARK: - 专注模式自动切换测试
    
    func testAutoMeetingMode_EnabledOnScreencast() {
        // Given: 启用自动检测，初始状态为单屏
        mockScreenDetection.isAutoDetectionEnabled = true
        UserDefaults.standard.set(false, forKey: "MeetingModeEnabled")
        
        testExpectation = expectation(description: "屏幕配置变化回调")
        
        var callbackReceived = false
        mockScreenDetection.onScreenConfigurationChanged = { [weak self] hasExternalScreen in
            print("📺 收到屏幕配置变化回调: \(hasExternalScreen)")
            callbackReceived = true
            self?.testExpectation.fulfill()
        }
        
        // When: 模拟投屏连接
        mockScreenDetection.simulateScreencasting(mirrorResolution: false)
        
        // Then: 等待回调并验证
        wait(for: [testExpectation], timeout: 2.0)
        
        XCTAssertTrue(callbackReceived, "应该收到屏幕配置变化回调")
        XCTAssertTrue(mockScreenDetection.shouldAutoEnableMeetingMode(), "应该自动启用专注模式")
        
        print("✅ testAutoMeetingMode_EnabledOnScreencast 通过")
    }
    
    func testAutoMeetingMode_DisabledWhenAutoDetectionOff() {
        // Given: 禁用自动检测
        mockScreenDetection.isAutoDetectionEnabled = false
        
        // When: 模拟投屏连接
        mockScreenDetection.simulateScreencasting()
        
        // Then: 不应该自动启用专注模式
        XCTAssertFalse(mockScreenDetection.shouldAutoEnableMeetingMode(), "禁用自动检测时不应该自动启用专注模式")
        
        print("✅ testAutoMeetingMode_DisabledWhenAutoDetectionOff 通过")
    }
    
    // MARK: - 端到端集成测试
    
    func testFullIntegration_ConnectAndDisconnectScreencast() {
        // Given: 启用自动检测，初始单屏状态
        mockScreenDetection.isAutoDetectionEnabled = true
        mockScreenDetection.simulateResetToSingleScreen()
        UserDefaults.standard.set(false, forKey: "MeetingModeEnabled")
        
        var screenChangeCount = 0
        var lastScreenStatus = false
        
        mockScreenDetection.onScreenConfigurationChanged = { hasExternalScreen in
            screenChangeCount += 1
            lastScreenStatus = hasExternalScreen
            print("📺 屏幕状态变化 #\(screenChangeCount): \(hasExternalScreen)")
        }
        
        // When: 连接投屏
        print("🎬 步骤1: 连接投屏")
        mockScreenDetection.simulateScreencasting()
        
        // Then: 验证投屏连接
        XCTAssertEqual(screenChangeCount, 1, "应该收到1次屏幕变化通知")
        XCTAssertTrue(lastScreenStatus, "最后状态应该为有外部屏幕")
        XCTAssertTrue(mockScreenDetection.shouldAutoEnableMeetingMode(), "应该自动启用专注模式")
        
        // When: 断开投屏
        print("🎬 步骤2: 断开投屏")
        mockScreenDetection.simulateExternalScreenDisconnected()
        
        // Then: 验证投屏断开
        XCTAssertEqual(screenChangeCount, 2, "应该收到2次屏幕变化通知")
        XCTAssertFalse(lastScreenStatus, "最后状态应该为无外部屏幕")
        XCTAssertFalse(mockScreenDetection.shouldAutoEnableMeetingMode(), "应该不再自动启用专注模式")
        
        print("✅ testFullIntegration_ConnectAndDisconnectScreencast 通过")
    }
    
    func testFullIntegration_MultipleScreenChanges() {
        // Given: 启用自动检测
        mockScreenDetection.isAutoDetectionEnabled = true
        var screenEvents: [(Bool, String)] = []
        
        mockScreenDetection.onScreenConfigurationChanged = { hasExternalScreen in
            let eventType = hasExternalScreen ? "连接" : "断开"
            screenEvents.append((hasExternalScreen, eventType))
            print("📺 屏幕事件: \(eventType) - 外部屏幕: \(hasExternalScreen)")
        }
        
        // When: 执行多次屏幕变化
        print("🎬 多屏幕变化测试开始")
        
        // 连接外部显示器
        mockScreenDetection.simulateExternalScreenConnected(width: 1920, height: 1080)
        
        // 断开外部显示器
        mockScreenDetection.simulateExternalScreenDisconnected()
        
        // 连接投屏
        mockScreenDetection.simulateScreencasting(mirrorResolution: true)
        
        // 断开投屏
        mockScreenDetection.simulateResetToSingleScreen()
        
        // Then: 验证事件序列
        XCTAssertEqual(screenEvents.count, 4, "应该收到4次屏幕变化事件")
        
        let expectedSequence = [true, false, true, false]
        for (index, expected) in expectedSequence.enumerated() {
            XCTAssertEqual(screenEvents[index].0, expected, "第\(index+1)次事件状态不正确")
        }
        
        print("✅ testFullIntegration_MultipleScreenChanges 通过")
    }
    
    // MARK: - 边界条件测试
    
    func testEdgeCase_CommonProjectionResolutions() {
        let commonResolutions: [(CGFloat, CGFloat, String)] = [
            (1920, 1080, "Full HD"),
            (1280, 720, "HD"),
            (1024, 768, "XGA"),
            (1280, 800, "WXGA"),
            (1366, 768, "常见笔记本"),
            (1600, 900, "HD+"),
            (1440, 900, "WXGA+"),
            (1680, 1050, "WSXGA+")
        ]
        
        for (width, height, name) in commonResolutions {
            // Given: 重置为单屏
            mockScreenDetection.simulateResetToSingleScreen()
            
            // When: 连接特定分辨率的投屏
            mockScreenDetection.simulateExternalScreenConnected(width: width, height: height)
            
            // Then: 应该检测到投屏
            XCTAssertTrue(mockScreenDetection.isScreencasting(), "应该检测到\(name)分辨率的投屏")
            
            print("✅ 测试分辨率 \(name) (\(Int(width))x\(Int(height))) 通过")
        }
    }
    
    func testEdgeCase_RapidScreenChanges() {
        // Given: 快速屏幕变化测试
        mockScreenDetection.isAutoDetectionEnabled = true
        var eventCount = 0
        
        mockScreenDetection.onScreenConfigurationChanged = { _ in
            eventCount += 1
        }
        
        // When: 快速连接和断开
        for i in 0..<5 {
            mockScreenDetection.simulateExternalScreenConnected()
            mockScreenDetection.simulateExternalScreenDisconnected()
            print("🔄 快速变化循环 \(i+1)/5")
        }
        
        // Then: 应该正确处理所有事件
        XCTAssertEqual(eventCount, 10, "应该收到10次屏幕变化事件")
        XCTAssertFalse(mockScreenDetection.hasExternalScreen, "最终应该回到单屏状态")
        
        print("✅ testEdgeCase_RapidScreenChanges 通过")
    }
    
    // MARK: - 性能测试
    
    func testPerformance_ScreenDetection() {
        measure {
            for _ in 0..<100 {
                mockScreenDetection.checkForExternalScreens()
                mockScreenDetection.isScreencasting()
                mockScreenDetection.shouldAutoEnableMeetingMode()
            }
        }
        print("✅ testPerformance_ScreenDetection 性能测试通过")
    }
}
