//
//  SequentialScreenOverlayTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2025-09-27.
//

import XCTest
@testable import PomodoroScreen
import Cocoa

class SequentialScreenOverlayTests: XCTestCase {
    
    var pomodoroTimer: PomodoroTimer!
    var testExpectation: XCTestExpectation!
    
    override func setUp() {
        super.setUp()
        pomodoroTimer = PomodoroTimer()
    }
    
    override func tearDown() {
        pomodoroTimer = nil
        super.tearDown()
    }
    
    // MARK: - 顺序屏幕遮罩测试
    
    func testSequentialScreenOverlayDisplay() throws {
        print("🧪 开始顺序屏幕遮罩测试")
        
        let screens = NSScreen.screens
        guard screens.count >= 2 else {
            throw XCTSkip("需要至少2个屏幕才能进行此测试")
        }
        
        print("📺 检测到 \(screens.count) 个屏幕")
        for (index, screen) in screens.enumerated() {
            print("屏幕 \(index + 1): \(screen.frame) (主屏幕: \(screen == NSScreen.main))")
        }
        
        testExpectation = expectation(description: "顺序屏幕遮罩测试完成")
        
        // 开始测试序列
        startSequentialTest(screens: screens)
        
        // 等待测试完成 (总共需要约12秒: 5秒屏幕1 + 1秒间隔 + 5秒屏幕2 + 1秒清理)
        wait(for: [testExpectation], timeout: 15.0)
    }
    
    private func startSequentialTest(screens: [NSScreen]) {
        print("\n🎬 第一阶段：在屏幕1显示遮罩层5秒")
        
        // 第一阶段：在第一个屏幕显示遮罩层
        showOverlayOnScreen(screen: screens[0], screenIndex: 0, duration: 5.0) { [weak self] in
            print("✅ 屏幕1遮罩层显示完成")
            
            // 短暂间隔
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("\n🎬 第二阶段：在屏幕2显示遮罩层5秒")
                
                // 第二阶段：在第二个屏幕显示遮罩层
                self?.showOverlayOnScreen(screen: screens[1], screenIndex: 1, duration: 5.0) { [weak self] in
                    print("✅ 屏幕2遮罩层显示完成")
                    print("🎉 顺序屏幕遮罩测试全部完成")
                    
                    // 完成测试
                    self?.testExpectation.fulfill()
                }
            }
        }
    }
    
    private func showOverlayOnScreen(screen: NSScreen, screenIndex: Int, duration: TimeInterval, completion: @escaping () -> Void) {
        print("   🖼️ 在屏幕 \(screenIndex + 1) 创建遮罩窗口")
        print("      - 屏幕尺寸: \(screen.frame)")
        print("      - 显示时长: \(duration)秒")
        
        // 创建遮罩窗口
        let overlayWindow = OverlayWindow(timer: pomodoroTimer)
        
        // 设置窗口位置和大小为指定屏幕
        overlayWindow.setFrame(screen.frame, display: true)
        
        // 设置窗口属性
        overlayWindow.level = .modalPanel
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        overlayWindow.ignoresMouseEvents = false
        
        // 为非主屏幕设置特殊处理
        if screen != NSScreen.main {
            overlayWindow.setFrameOrigin(screen.frame.origin)
            print("      - 设置非主屏幕原点: \(screen.frame.origin)")
        }
        
        // 显示遮罩
        print("   🎬 显示遮罩层...")
        overlayWindow.showOverlay()
        
        // 强制显示
        overlayWindow.makeKeyAndOrderFront(nil)
        overlayWindow.orderFrontRegardless()
        
        // 验证显示状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("      - 窗口可见性: \(overlayWindow.isVisible)")
            print("      - 窗口层级: \(overlayWindow.level.rawValue)")
            print("      - 窗口位置: \(overlayWindow.frame)")
            
            if !overlayWindow.isVisible {
                print("      ⚠️ 窗口不可见，尝试强制显示")
                overlayWindow.orderFront(nil)
                overlayWindow.makeKeyAndOrderFront(nil)
            }
        }
        
        // 设置定时器，指定时间后隐藏遮罩
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            print("   🔄 隐藏屏幕 \(screenIndex + 1) 的遮罩层")
            overlayWindow.orderOut(nil)
            
            // 短暂延迟后执行完成回调
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion()
            }
        }
    }
    
    // MARK: - 多屏幕管理器测试
    
    func testMultiScreenManagerSequentialDisplay() throws {
        print("🧪 开始多屏幕管理器顺序测试")
        
        let screens = NSScreen.screens
        guard screens.count >= 2 else {
            throw XCTSkip("需要至少2个屏幕才能进行此测试")
        }
        
        testExpectation = expectation(description: "多屏幕管理器顺序测试完成")
        
        // 第一阶段：显示所有屏幕的遮罩层
        print("\n🎬 第一阶段：同时在所有屏幕显示遮罩层5秒")
        let multiScreenManager = MultiScreenOverlayManager(timer: pomodoroTimer)
        multiScreenManager.showOverlaysOnAllScreens()
        
        // 5秒后隐藏所有遮罩
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            print("🔄 隐藏所有屏幕的遮罩层")
            multiScreenManager.hideAllOverlays()
            
            // 第二阶段：单独在第二个屏幕显示遮罩层
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("\n🎬 第二阶段：仅在屏幕2显示遮罩层5秒")
                
                self.showOverlayOnScreen(screen: screens[1], screenIndex: 1, duration: 5.0) { [weak self] in
                    print("🎉 多屏幕管理器顺序测试完成")
                    self?.testExpectation.fulfill()
                }
            }
        }
        
        wait(for: [testExpectation], timeout: 15.0)
    }
    
    // MARK: - 性能测试
    
    func testOverlayPerformanceOnMultipleScreens() throws {
        print("🧪 开始多屏幕遮罩性能测试")
        
        let screens = NSScreen.screens
        guard screens.count >= 2 else {
            throw XCTSkip("需要至少2个屏幕才能进行此测试")
        }
        
        // 测量创建和显示遮罩的时间
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let multiScreenManager = MultiScreenOverlayManager(timer: pomodoroTimer)
        multiScreenManager.showOverlaysOnAllScreens()
        
        let creationTime = CFAbsoluteTimeGetCurrent() - startTime
        print("📊 多屏幕遮罩创建时间: \(String(format: "%.3f", creationTime))秒")
        
        // 验证性能要求（应该在1秒内完成）
        XCTAssertLessThan(creationTime, 1.0, "多屏幕遮罩创建时间应该小于1秒")
        
        // 清理
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            multiScreenManager.hideAllOverlays()
        }
    }
    
    // MARK: - 屏幕切换测试
    
    func testScreenSwitchingBehavior() throws {
        print("🧪 开始屏幕切换行为测试")
        
        let screens = NSScreen.screens
        guard screens.count >= 2 else {
            throw XCTSkip("需要至少2个屏幕才能进行此测试")
        }
        
        testExpectation = expectation(description: "屏幕切换测试完成")
        
        var currentScreenIndex = 0
        let switchInterval: TimeInterval = 2.0
        let totalSwitches = 4
        var switchCount = 0
        
        func switchToNextScreen() {
            guard switchCount < totalSwitches else {
                print("🎉 屏幕切换测试完成")
                testExpectation.fulfill()
                return
            }
            
            let screen = screens[currentScreenIndex]
            print("🔄 切换到屏幕 \(currentScreenIndex + 1): \(screen.frame)")
            
            showOverlayOnScreen(screen: screen, screenIndex: currentScreenIndex, duration: switchInterval) {
                switchCount += 1
                currentScreenIndex = (currentScreenIndex + 1) % screens.count
                
                // 短暂间隔后切换到下一个屏幕
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    switchToNextScreen()
                }
            }
        }
        
        switchToNextScreen()
        wait(for: [testExpectation], timeout: 20.0)
    }
}

// MARK: - 测试辅助扩展

extension SequentialScreenOverlayTests {
    
    /// 验证窗口是否在指定屏幕上正确显示
    private func verifyWindowOnScreen(_ window: NSWindow, expectedScreen: NSScreen) -> Bool {
        let windowFrame = window.frame
        let screenFrame = expectedScreen.frame
        
        // 检查窗口是否完全在目标屏幕范围内
        let isWithinScreen = screenFrame.contains(windowFrame)
        
        print("      📍 窗口验证:")
        print("         - 窗口位置: \(windowFrame)")
        print("         - 目标屏幕: \(screenFrame)")
        print("         - 是否在屏幕内: \(isWithinScreen)")
        
        return isWithinScreen
    }
    
    /// 获取屏幕信息摘要
    private func getScreenSummary() -> String {
        let screens = NSScreen.screens
        var summary = "屏幕配置: \(screens.count)个屏幕\n"
        
        for (index, screen) in screens.enumerated() {
            let isMain = screen == NSScreen.main ? " (主屏幕)" : ""
            summary += "  屏幕\(index + 1): \(Int(screen.frame.width))x\(Int(screen.frame.height)) at (\(Int(screen.frame.origin.x)), \(Int(screen.frame.origin.y)))\(isMain)\n"
        }
        
        return summary
    }
}
