//
//  MeetingModeAutoSwitchTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2025-09-23.
//  会议模式自动切换功能的专项测试
//

import XCTest
@testable import PomodoroScreen

class MeetingModeAutoSwitchTests: XCTestCase {
    
    // MARK: - Properties
    
    var mockScreenDetection: MockScreenDetectionManager!
    var mockAppDelegate: MockAppDelegate!
    
    // MARK: - Mock App Delegate
    
    class MockAppDelegate {
        var screenDetectionManager: MockScreenDetectionManager
        var meetingModeChangeCount = 0
        var lastMeetingModeState = false
        var enableMeetingModeCallCount = 0
        var disableMeetingModeCallCount = 0
        
        init(screenDetectionManager: MockScreenDetectionManager) {
            self.screenDetectionManager = screenDetectionManager
            setupScreenDetection()
        }
        
        private func setupScreenDetection() {
            screenDetectionManager.onScreenConfigurationChanged = { [weak self] hasExternalScreen in
                self?.handleScreenConfigurationChanged(hasExternalScreen)
            }
        }
        
        private func handleScreenConfigurationChanged(_ hasExternalScreen: Bool) {
            print("📺 [Mock] 屏幕配置变化: 外部屏幕 = \(hasExternalScreen)")
            
            if screenDetectionManager.shouldAutoEnableMeetingMode() {
                enableMeetingModeAutomatically()
            } else {
                disableMeetingModeAutomatically()
            }
        }
        
        private func enableMeetingModeAutomatically() {
            guard screenDetectionManager.isAutoDetectionEnabled else {
                print("📺 [Mock] 自动检测已禁用，跳过自动启用会议模式")
                return
            }
            
            let currentMeetingMode = UserDefaults.standard.bool(forKey: "MeetingModeEnabled")
            if !currentMeetingMode {
                print("📺 [Mock] 检测到投屏/外接显示器，自动启用会议模式")
                UserDefaults.standard.set(true, forKey: "MeetingModeEnabled")
                UserDefaults.standard.set(true, forKey: "MeetingModeAutoEnabled")
                
                meetingModeChangeCount += 1
                lastMeetingModeState = true
                enableMeetingModeCallCount += 1
            }
        }
        
        private func disableMeetingModeAutomatically() {
            let wasAutoEnabled = UserDefaults.standard.bool(forKey: "MeetingModeAutoEnabled")
            let currentMeetingMode = UserDefaults.standard.bool(forKey: "MeetingModeEnabled")
            
            if currentMeetingMode && wasAutoEnabled {
                print("📺 [Mock] 投屏/外接显示器已断开，自动关闭会议模式")
                UserDefaults.standard.set(false, forKey: "MeetingModeEnabled")
                UserDefaults.standard.set(false, forKey: "MeetingModeAutoEnabled")
                
                meetingModeChangeCount += 1
                lastMeetingModeState = false
                disableMeetingModeCallCount += 1
            }
        }
    }
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockScreenDetection = MockScreenDetectionManager()
        mockAppDelegate = MockAppDelegate(screenDetectionManager: mockScreenDetection)
        
        // 清理UserDefaults
        UserDefaults.standard.removeObject(forKey: "MeetingModeEnabled")
        UserDefaults.standard.removeObject(forKey: "MeetingModeAutoEnabled")
        UserDefaults.standard.removeObject(forKey: "AutoDetectScreencastEnabled")
        
        print("🧪 会议模式测试环境初始化完成")
    }
    
    override func tearDown() {
        mockScreenDetection = nil
        mockAppDelegate = nil
        
        // 清理测试数据
        UserDefaults.standard.removeObject(forKey: "MeetingModeEnabled")
        UserDefaults.standard.removeObject(forKey: "MeetingModeAutoEnabled")
        UserDefaults.standard.removeObject(forKey: "AutoDetectScreencastEnabled")
        
        print("🧪 会议模式测试环境清理完成")
        super.tearDown()
    }
    
    // MARK: - 自动启用会议模式测试
    
    func testAutoEnable_OnExternalMonitorConnect() {
        // Given: 初始状态 - 单屏，会议模式关闭
        mockScreenDetection.simulateResetToSingleScreen()
        UserDefaults.standard.set(false, forKey: "MeetingModeEnabled")
        mockScreenDetection.isAutoDetectionEnabled = true
        
        // When: 连接外部显示器
        mockScreenDetection.simulateExternalScreenConnected(width: 2560, height: 1440)
        
        // Then: 应该自动启用会议模式
        XCTAssertEqual(mockAppDelegate.enableMeetingModeCallCount, 1, "应该调用一次启用会议模式")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "MeetingModeEnabled"), "会议模式应该被启用")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "MeetingModeAutoEnabled"), "应该标记为自动启用")
        XCTAssertTrue(mockAppDelegate.lastMeetingModeState, "最后状态应该为启用")
        
        print("✅ testAutoEnable_OnExternalMonitorConnect 通过")
    }
    
    func testAutoEnable_OnScreencastConnect() {
        // Given: 初始状态 - 单屏，会议模式关闭
        mockScreenDetection.simulateResetToSingleScreen()
        UserDefaults.standard.set(false, forKey: "MeetingModeEnabled")
        mockScreenDetection.isAutoDetectionEnabled = true
        
        // When: 开始投屏
        mockScreenDetection.simulateScreencasting(mirrorResolution: true)
        
        // Then: 应该自动启用会议模式
        XCTAssertEqual(mockAppDelegate.enableMeetingModeCallCount, 1, "应该调用一次启用会议模式")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "MeetingModeEnabled"), "会议模式应该被启用")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "MeetingModeAutoEnabled"), "应该标记为自动启用")
        
        print("✅ testAutoEnable_OnScreencastConnect 通过")
    }
    
    func testAutoEnable_SkipWhenAlreadyEnabled() {
        // Given: 会议模式已经手动启用
        UserDefaults.standard.set(true, forKey: "MeetingModeEnabled")
        UserDefaults.standard.set(false, forKey: "MeetingModeAutoEnabled") // 手动启用
        mockScreenDetection.isAutoDetectionEnabled = true
        
        // When: 连接外部屏幕
        mockScreenDetection.simulateExternalScreenConnected()
        
        // Then: 不应该重复启用
        XCTAssertEqual(mockAppDelegate.enableMeetingModeCallCount, 0, "不应该重复启用会议模式")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "MeetingModeEnabled"), "会议模式应该保持启用")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "MeetingModeAutoEnabled"), "应该保持手动启用标记")
        
        print("✅ testAutoEnable_SkipWhenAlreadyEnabled 通过")
    }
    
    func testAutoEnable_SkipWhenAutoDetectionDisabled() {
        // Given: 禁用自动检测
        mockScreenDetection.isAutoDetectionEnabled = false
        UserDefaults.standard.set(false, forKey: "MeetingModeEnabled")
        
        // When: 连接外部屏幕
        mockScreenDetection.simulateExternalScreenConnected()
        
        // Then: 不应该自动启用
        XCTAssertEqual(mockAppDelegate.enableMeetingModeCallCount, 0, "禁用自动检测时不应该启用会议模式")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "MeetingModeEnabled"), "会议模式应该保持关闭")
        
        print("✅ testAutoEnable_SkipWhenAutoDetectionDisabled 通过")
    }
    
    // MARK: - 自动关闭会议模式测试
    
    func testAutoDisable_OnExternalScreenDisconnect() {
        // Given: 外部屏幕已连接，会议模式自动启用
        mockScreenDetection.simulateExternalScreenConnected()
        UserDefaults.standard.set(true, forKey: "MeetingModeEnabled")
        UserDefaults.standard.set(true, forKey: "MeetingModeAutoEnabled")
        
        // When: 断开外部屏幕
        mockScreenDetection.simulateExternalScreenDisconnected()
        
        // Then: 应该自动关闭会议模式
        XCTAssertEqual(mockAppDelegate.disableMeetingModeCallCount, 1, "应该调用一次关闭会议模式")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "MeetingModeEnabled"), "会议模式应该被关闭")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "MeetingModeAutoEnabled"), "自动启用标记应该被清除")
        XCTAssertFalse(mockAppDelegate.lastMeetingModeState, "最后状态应该为关闭")
        
        print("✅ testAutoDisable_OnExternalScreenDisconnect 通过")
    }
    
    func testAutoDisable_SkipWhenManuallyEnabled() {
        // Given: 外部屏幕已连接，会议模式手动启用
        mockScreenDetection.simulateExternalScreenConnected()
        UserDefaults.standard.set(true, forKey: "MeetingModeEnabled")
        UserDefaults.standard.set(false, forKey: "MeetingModeAutoEnabled") // 手动启用
        
        // When: 断开外部屏幕
        mockScreenDetection.simulateExternalScreenDisconnected()
        
        // Then: 不应该自动关闭
        XCTAssertEqual(mockAppDelegate.disableMeetingModeCallCount, 0, "手动启用的会议模式不应该自动关闭")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "MeetingModeEnabled"), "会议模式应该保持启用")
        
        print("✅ testAutoDisable_SkipWhenManuallyEnabled 通过")
    }
    
    // MARK: - 复杂场景测试
    
    func testComplexScenario_MultipleConnectDisconnect() {
        // Given: 初始单屏状态
        mockScreenDetection.simulateResetToSingleScreen()
        UserDefaults.standard.set(false, forKey: "MeetingModeEnabled")
        mockScreenDetection.isAutoDetectionEnabled = true
        
        // Scenario: 连接 -> 断开 -> 连接 -> 断开
        
        // Step 1: 连接外部显示器
        print("🎬 步骤1: 连接外部显示器")
        mockScreenDetection.simulateExternalScreenConnected()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "MeetingModeEnabled"), "步骤1: 会议模式应该启用")
        XCTAssertEqual(mockAppDelegate.enableMeetingModeCallCount, 1, "步骤1: 启用次数应该为1")
        
        // Step 2: 断开外部显示器
        print("🎬 步骤2: 断开外部显示器")
        mockScreenDetection.simulateExternalScreenDisconnected()
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "MeetingModeEnabled"), "步骤2: 会议模式应该关闭")
        XCTAssertEqual(mockAppDelegate.disableMeetingModeCallCount, 1, "步骤2: 关闭次数应该为1")
        
        // Step 3: 连接投屏
        print("🎬 步骤3: 连接投屏")
        mockScreenDetection.simulateScreencasting()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "MeetingModeEnabled"), "步骤3: 会议模式应该再次启用")
        XCTAssertEqual(mockAppDelegate.enableMeetingModeCallCount, 2, "步骤3: 启用次数应该为2")
        
        // Step 4: 断开投屏
        print("🎬 步骤4: 断开投屏")
        mockScreenDetection.simulateResetToSingleScreen()
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "MeetingModeEnabled"), "步骤4: 会议模式应该最终关闭")
        XCTAssertEqual(mockAppDelegate.disableMeetingModeCallCount, 2, "步骤4: 关闭次数应该为2")
        
        print("✅ testComplexScenario_MultipleConnectDisconnect 通过")
    }
    
    func testComplexScenario_ManualOverrideAutomatic() {
        // Given: 自动启用会议模式
        mockScreenDetection.simulateExternalScreenConnected()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "MeetingModeEnabled"), "前置条件: 会议模式应该自动启用")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "MeetingModeAutoEnabled"), "前置条件: 应该标记为自动启用")
        
        // When: 用户手动关闭会议模式（模拟用户在UI中关闭）
        print("🎬 用户手动关闭会议模式")
        UserDefaults.standard.set(false, forKey: "MeetingModeEnabled")
        UserDefaults.standard.set(false, forKey: "MeetingModeAutoEnabled") // 清除自动启用标记
        
        // Then: 断开外部屏幕时不应该有任何变化
        print("🎬 断开外部屏幕")
        let initialDisableCount = mockAppDelegate.disableMeetingModeCallCount
        mockScreenDetection.simulateExternalScreenDisconnected()
        
        XCTAssertEqual(mockAppDelegate.disableMeetingModeCallCount, initialDisableCount, "手动关闭后不应该再次调用自动关闭")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "MeetingModeEnabled"), "会议模式应该保持关闭")
        
        print("✅ testComplexScenario_ManualOverrideAutomatic 通过")
    }
    
    // MARK: - 状态一致性测试
    
    func testStateConsistency_UserDefaultsAndManager() {
        // Given: 多次状态变化
        let scenarios = [
            ("连接显示器", { self.mockScreenDetection.simulateExternalScreenConnected() }),
            ("断开显示器", { self.mockScreenDetection.simulateExternalScreenDisconnected() }),
            ("连接投屏", { self.mockScreenDetection.simulateScreencasting() }),
            ("断开投屏", { self.mockScreenDetection.simulateResetToSingleScreen() })
        ]
        
        for (description, action) in scenarios {
            print("🎬 执行: \(description)")
            action()
            
            // 验证状态一致性
            let meetingModeEnabled = UserDefaults.standard.bool(forKey: "MeetingModeEnabled")
            let shouldAutoEnable = mockScreenDetection.shouldAutoEnableMeetingMode()
            let hasExternalScreen = mockScreenDetection.hasExternalScreen
            
            if mockScreenDetection.isAutoDetectionEnabled && hasExternalScreen {
                XCTAssertTrue(meetingModeEnabled, "\(description): 有外部屏幕时会议模式应该启用")
            } else {
                // 注意：如果是手动启用的，断开屏幕时不会自动关闭
                let wasAutoEnabled = UserDefaults.standard.bool(forKey: "MeetingModeAutoEnabled")
                if !hasExternalScreen && wasAutoEnabled {
                    XCTAssertFalse(meetingModeEnabled, "\(description): 无外部屏幕且为自动启用时会议模式应该关闭")
                }
            }
        }
        
        print("✅ testStateConsistency_UserDefaultsAndManager 通过")
    }
    
    // MARK: - 性能测试
    
    func testPerformance_AutoSwitchLogic() {
        measure {
            for _ in 0..<50 {
                mockScreenDetection.simulateExternalScreenConnected()
                mockScreenDetection.simulateExternalScreenDisconnected()
            }
        }
        print("✅ testPerformance_AutoSwitchLogic 性能测试通过")
    }
}
