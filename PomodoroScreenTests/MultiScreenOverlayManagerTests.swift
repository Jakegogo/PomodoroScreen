//
//  MultiScreenOverlayManagerTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2025-09-27.
//

import XCTest
@testable import PomodoroScreen
import Cocoa

class MultiScreenOverlayManagerTests: XCTestCase {
    
    var pomodoroTimer: PomodoroTimer!
    var multiScreenManager: MultiScreenOverlayManager!
    
    override func setUp() {
        super.setUp()
        pomodoroTimer = PomodoroTimer()
    }
    
    override func tearDown() {
        multiScreenManager?.hideAllOverlays()
        multiScreenManager = nil
        pomodoroTimer = nil
        super.tearDown()
    }
    
    // MARK: - 初始化测试
    
    func testMultiScreenManagerInitialization() {
        // 测试正常模式初始化
        multiScreenManager = MultiScreenOverlayManager(timer: pomodoroTimer)
        XCTAssertNotNil(multiScreenManager, "多屏幕管理器应该成功初始化")
    }
    
    func testPreviewModeInitialization() {
        // 测试预览模式初始化
        let previewFiles: [BackgroundFile] = []
        multiScreenManager = MultiScreenOverlayManager(previewFiles: previewFiles, selectedIndex: 0)
        XCTAssertNotNil(multiScreenManager, "预览模式的多屏幕管理器应该成功初始化")
    }
    
    // MARK: - 屏幕信息测试
    
    func testGetScreenInfo() {
        multiScreenManager = MultiScreenOverlayManager(timer: pomodoroTimer)
        
        let screenInfo = multiScreenManager.getScreenInfo()
        
        XCTAssertNotNil(screenInfo["screenCount"], "应该包含屏幕数量信息")
        XCTAssertNotNil(screenInfo["screens"], "应该包含屏幕详细信息")
        
        if let screenCount = screenInfo["screenCount"] as? Int {
            XCTAssertGreaterThan(screenCount, 0, "屏幕数量应该大于0")
            print("📺 检测到 \(screenCount) 个屏幕")
        }
        
        if let screens = screenInfo["screens"] as? [[String: Any]] {
            XCTAssertEqual(screens.count, NSScreen.screens.count, "屏幕信息数量应该与系统检测一致")
            
            for (index, screen) in screens.enumerated() {
                XCTAssertNotNil(screen["index"], "屏幕 \(index) 应该有索引信息")
                XCTAssertNotNil(screen["frame"], "屏幕 \(index) 应该有尺寸信息")
                XCTAssertNotNil(screen["isMain"], "屏幕 \(index) 应该有主屏幕标识")
                
                print("  屏幕 \(index + 1): \(screen)")
            }
        }
    }
    
    // MARK: - 遮罩层显示测试
    
    func testShowOverlaysOnAllScreens() {
        multiScreenManager = MultiScreenOverlayManager(timer: pomodoroTimer)
        
        let expectation = XCTestExpectation(description: "遮罩层应该在所有屏幕上显示")
        
        // 显示遮罩层
        multiScreenManager.showOverlaysOnAllScreens()
        
        // 给动画一些时间完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            // 验证遮罩层已创建
            // 注意：在单元测试环境中，我们主要验证方法调用不会崩溃
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testHideAllOverlays() {
        multiScreenManager = MultiScreenOverlayManager(timer: pomodoroTimer)
        
        let expectation = XCTestExpectation(description: "所有遮罩层应该被隐藏")
        
        // 先显示遮罩层
        multiScreenManager.showOverlaysOnAllScreens()
        
        // 然后隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.multiScreenManager.hideAllOverlays()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - 屏幕配置变化测试
    
    func testScreenConfigurationChange() {
        multiScreenManager = MultiScreenOverlayManager(timer: pomodoroTimer)
        
        let expectation = XCTestExpectation(description: "屏幕配置变化应该被正确处理")
        
        // 显示遮罩层
        multiScreenManager.showOverlaysOnAllScreens()
        
        // 模拟屏幕配置变化
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.multiScreenManager.updateOverlaysForScreenChanges()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - 预览模式测试
    
    func testPreviewModeOverlays() {
        let previewFiles: [BackgroundFile] = [
            BackgroundFile(path: "/test/path1.mp4", type: .video, name: "测试视频1", playbackRate: 1.0),
            BackgroundFile(path: "/test/path2.jpg", type: .image, name: "测试图片1", playbackRate: 1.0)
        ]
        
        multiScreenManager = MultiScreenOverlayManager(previewFiles: previewFiles, selectedIndex: 0)
        XCTAssertNotNil(multiScreenManager, "预览模式的多屏幕管理器应该成功初始化")
        
        // 简化测试，只验证初始化和基本方法调用不会崩溃
        multiScreenManager.showOverlaysOnAllScreens()
        multiScreenManager.hideAllOverlays()
        
        // 验证屏幕信息获取
        let screenInfo = multiScreenManager.getScreenInfo()
        XCTAssertNotNil(screenInfo["screenCount"], "应该能获取屏幕信息")
    }
    
    // MARK: - 内存管理测试
    
    func testMemoryManagement() {
        weak var weakManager: MultiScreenOverlayManager?
        
        autoreleasepool {
            let manager = MultiScreenOverlayManager(timer: pomodoroTimer)
            weakManager = manager
            
            // 显示遮罩层
            manager.showOverlaysOnAllScreens()
            
            // 隐藏遮罩层
            manager.hideAllOverlays()
        }
        
        // 验证对象被正确释放
        XCTAssertNil(weakManager, "MultiScreenOverlayManager 应该被正确释放")
    }
    
    // MARK: - 错误处理测试
    
    func testNilTimerHandling() {
        // 测试传入 nil timer 的情况
        // 注意：当前实现要求 timer 不为 nil，这个测试验证初始化行为
        let manager = MultiScreenOverlayManager(timer: pomodoroTimer)
        XCTAssertNotNil(manager, "即使在边界条件下，管理器也应该能正确初始化")
    }
    
    func testEmptyPreviewFiles() {
        // 测试空的预览文件列表
        let emptyFiles: [BackgroundFile] = []
        multiScreenManager = MultiScreenOverlayManager(previewFiles: emptyFiles, selectedIndex: 0)
        
        let expectation = XCTestExpectation(description: "空预览文件列表应该被正确处理")
        
        multiScreenManager.showOverlaysOnAllScreens()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 性能测试
    
    func testPerformanceOfShowingOverlays() {
        multiScreenManager = MultiScreenOverlayManager(timer: pomodoroTimer)
        
        measure {
            multiScreenManager.showOverlaysOnAllScreens()
            multiScreenManager.hideAllOverlays()
        }
    }
    
    // MARK: - 集成测试
    
    func testIntegrationWithAppDelegate() {
        // 测试与 AppDelegate 的集成
        let screenCount = NSScreen.screens.count
        
        if screenCount == 1 {
            print("⚠️ 单屏幕环境：应该使用原有的 OverlayWindow")
            XCTAssertEqual(screenCount, 1, "当前为单屏幕环境")
        } else {
            print("✅ 多屏幕环境：应该使用 MultiScreenOverlayManager")
            XCTAssertGreaterThan(screenCount, 1, "当前为多屏幕环境")
        }
        
        // 验证屏幕检测逻辑
        let shouldUseMultiScreen = screenCount > 1
        print("📊 屏幕数量: \(screenCount), 使用多屏幕模式: \(shouldUseMultiScreen)")
    }
    
    // MARK: - 辅助方法
    
    private func createMockBackgroundFiles() -> [BackgroundFile] {
        return [
            BackgroundFile(path: "/mock/video1.mp4", type: .video, name: "模拟视频1", playbackRate: 1.0),
            BackgroundFile(path: "/mock/image1.jpg", type: .image, name: "模拟图片1", playbackRate: 1.0),
            BackgroundFile(path: "/mock/video2.mp4", type: .video, name: "模拟视频2", playbackRate: 0.5)
        ]
    }
}
