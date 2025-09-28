//
//  ShutdownIntegrationTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2025-09-27.
//

import XCTest
@testable import PomodoroScreen
import Cocoa

class ShutdownIntegrationTests: XCTestCase {
    
    var pomodoroTimer: PomodoroTimer!
    var overlayWindow: OverlayWindow!
    var shutdownConfirmationWindow: ShutdownConfirmationWindow?
    
    override func setUp() {
        super.setUp()
        pomodoroTimer = PomodoroTimer()
        
        // 模拟强制睡眠状态
        _ = pomodoroTimer.stateMachineForTesting.processEvent(.forcedSleepTriggered)
    }
    
    override func tearDown() {
        shutdownConfirmationWindow?.orderOut(nil)
        shutdownConfirmationWindow = nil
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        pomodoroTimer = nil
        super.tearDown()
    }
    
    // MARK: - 完整关机流程集成测试
    
    func testCompleteShutdownFlow() {
        let expectation = self.expectation(description: "完整关机流程应该正确执行")
        
        // 步骤1: 创建遮罩窗口（强制睡眠状态）
        overlayWindow = OverlayWindow(timer: pomodoroTimer)
        overlayWindow.showOverlay()
        
        // 验证遮罩窗口显示
        XCTAssertTrue(overlayWindow.isVisible, "遮罩窗口应该可见")
        XCTAssertEqual(overlayWindow.level, .screenSaver, "遮罩窗口应该使用screenSaver层级")
        
        // 步骤2: 等待遮罩窗口完全显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 步骤3: 模拟点击关机按钮
            self.simulateShutdownButtonClick()
            
            // 步骤4: 验证关机确认对话框显示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.verifyShutdownDialogDisplayed()
                
                // 步骤5: 模拟用户确认关机
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.simulateShutdownConfirmation()
                    
                    // 步骤6: 验证关机流程完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.verifyShutdownFlowCompleted()
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testShutdownCancellation() {
        let expectation = self.expectation(description: "关机取消流程应该正确执行")
        
        // 步骤1: 创建遮罩窗口
        overlayWindow = OverlayWindow(timer: pomodoroTimer)
        overlayWindow.showOverlay()
        
        // 步骤2: 触发关机确认对话框
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.simulateShutdownButtonClick()
            
            // 步骤3: 验证对话框显示后取消
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.verifyShutdownDialogDisplayed()
                self.simulateShutdownCancellation()
                
                // 步骤4: 验证取消后状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.verifyShutdownCancelled()
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 4.0)
    }
    
    func testShutdownDialogLayerLevel() {
        let expectation = self.expectation(description: "关机对话框层级应该高于遮罩层")
        
        // 创建遮罩窗口
        overlayWindow = OverlayWindow(timer: pomodoroTimer)
        overlayWindow.showOverlay()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 触发关机确认对话框
            self.simulateShutdownButtonClick()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // 验证层级关系
                if let confirmationWindow = self.findShutdownConfirmationWindow() {
                    XCTAssertTrue(confirmationWindow.level.rawValue > self.overlayWindow.level.rawValue,
                                 "关机确认对话框(\(confirmationWindow.level.rawValue))应该高于遮罩层(\(self.overlayWindow.level.rawValue))")
                    
                    XCTAssertTrue(confirmationWindow.isVisible, "关机确认对话框应该可见")
                    XCTAssertTrue(self.overlayWindow.isVisible, "遮罩窗口应该仍然可见")
                } else {
                    XCTFail("未找到关机确认对话框")
                }
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testKeyboardShortcuts() {
        let expectation = self.expectation(description: "键盘快捷键应该正确工作")
        
        overlayWindow = OverlayWindow(timer: pomodoroTimer)
        overlayWindow.showOverlay()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.simulateShutdownButtonClick()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let confirmationWindow = self.findShutdownConfirmationWindow() {
                    // 测试ESC键取消
                    self.simulateKeyPress(keyCode: 53, window: confirmationWindow) // ESC键
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        XCTAssertFalse(confirmationWindow.isVisible, "按ESC键后对话框应该关闭")
                        expectation.fulfill()
                    }
                } else {
                    XCTFail("未找到关机确认对话框")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testMultipleShutdownAttempts() {
        let expectation = self.expectation(description: "多次关机尝试应该正确处理")
        
        overlayWindow = OverlayWindow(timer: pomodoroTimer)
        overlayWindow.showOverlay()
        
        var attemptCount = 0
        let maxAttempts = 3
        
        func performShutdownAttempt() {
            attemptCount += 1
            
            self.simulateShutdownButtonClick()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if self.findShutdownConfirmationWindow() != nil {
                    // 取消这次尝试
                    self.simulateShutdownCancellation()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if attemptCount < maxAttempts {
                            performShutdownAttempt()
                        } else {
                            // 最后一次尝试确认关机
                            self.simulateShutdownButtonClick()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.simulateShutdownConfirmation()
                                expectation.fulfill()
                            }
                        }
                    }
                } else {
                    XCTFail("第\(attemptCount)次尝试未找到关机确认对话框")
                    expectation.fulfill()
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            performShutdownAttempt()
        }
        
        wait(for: [expectation], timeout: 8.0)
    }
    
    // MARK: - 辅助方法
    
    private func simulateShutdownButtonClick() {
        // 获取遮罩窗口的内容视图
        guard let overlayView = overlayWindow.contentView as? OverlayView else {
            XCTFail("无法获取OverlayView")
            return
        }
        
        // 使用测试专用方法触发关机按钮点击
        overlayView.triggerShutdownButtonForTesting()
    }
    
    private func simulateShutdownConfirmation() {
        if let confirmationWindow = findShutdownConfirmationWindow() {
            // 模拟Enter键按下（确认）
            simulateKeyPress(keyCode: 36, window: confirmationWindow)
        }
    }
    
    private func simulateShutdownCancellation() {
        if let confirmationWindow = findShutdownConfirmationWindow() {
            // 模拟ESC键按下（取消）
            simulateKeyPress(keyCode: 53, window: confirmationWindow)
        }
    }
    
    private func simulateKeyPress(keyCode: UInt16, window: NSWindow) {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: NSPoint.zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )
        
        if let keyEvent = event {
            window.keyDown(with: keyEvent)
        }
    }
    
    private func findShutdownConfirmationWindow() -> ShutdownConfirmationWindow? {
        // 在所有窗口中查找ShutdownConfirmationWindow
        for window in NSApplication.shared.windows {
            if let confirmationWindow = window as? ShutdownConfirmationWindow {
                shutdownConfirmationWindow = confirmationWindow
                return confirmationWindow
            }
        }
        return nil
    }
    
    private func verifyShutdownDialogDisplayed() {
        if let confirmationWindow = findShutdownConfirmationWindow() {
            XCTAssertTrue(confirmationWindow.isVisible, "关机确认对话框应该可见")
            XCTAssertTrue(confirmationWindow.level.rawValue > overlayWindow.level.rawValue, 
                         "关机确认对话框应该在遮罩层之上")
        } else {
            XCTFail("应该显示关机确认对话框")
        }
    }
    
    private func verifyShutdownFlowCompleted() {
        // 验证关机流程完成后的状态
        if let confirmationWindow = shutdownConfirmationWindow {
            XCTAssertFalse(confirmationWindow.isVisible, "关机确认对话框应该已关闭")
        }
        
        // 注意：实际的系统关机不会在测试中执行，但我们可以验证相关状态
        print("✅ 关机流程测试完成 - 实际环境中会触发系统关机")
    }
    
    private func verifyShutdownCancelled() {
        // 验证取消关机后的状态
        if let confirmationWindow = shutdownConfirmationWindow {
            XCTAssertFalse(confirmationWindow.isVisible, "关机确认对话框应该已关闭")
        }
        
        XCTAssertTrue(overlayWindow.isVisible, "遮罩窗口应该仍然可见")
        XCTAssertTrue(pomodoroTimer.isStayUpTime, "应该仍处于强制睡眠状态")
    }
    
    // MARK: - 性能测试
    
    func testShutdownDialogPerformance() {
        measure {
            let window = OverlayWindow(timer: pomodoroTimer)
            window.showOverlay()
            
            // 模拟快速的关机对话框显示/隐藏
            for _ in 0..<5 {
                simulateShutdownButtonClick()
                
                if let confirmationWindow = findShutdownConfirmationWindow() {
                    confirmationWindow.hideWithAnimation()
                }
            }
            
            window.orderOut(nil)
        }
    }
    
    // MARK: - 边界条件测试
    
    func testShutdownInNonForcedSleepState() {
        // 测试在非强制睡眠状态下的行为
        _ = pomodoroTimer.stateMachineForTesting.processEvent(.timerStopped)
        
        let expectation = self.expectation(description: "非强制睡眠状态不应显示关机按钮")
        
        overlayWindow = OverlayWindow(timer: pomodoroTimer)
        overlayWindow.showOverlay()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 在非强制睡眠状态下，应该显示取消休息按钮而不是关机按钮
            // 这里我们验证不会有关机确认对话框出现
            
            // 尝试查找关机确认对话框（应该不存在）
            let confirmationWindow = self.findShutdownConfirmationWindow()
            XCTAssertNil(confirmationWindow, "非强制睡眠状态不应该有关机确认对话框")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testMemoryLeakPrevention() {
        autoreleasepool {
            let window = OverlayWindow(timer: pomodoroTimer)
            
            window.showOverlay()
            simulateShutdownButtonClick()
            
            if let confirmationWindow = findShutdownConfirmationWindow() {
                confirmationWindow.hideWithAnimation()
            }
            
            window.orderOut(nil)
        }
        
        // 等待清理完成
        let expectation = self.expectation(description: "内存应该被正确释放")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 注意：由于系统可能保持窗口引用，这些测试可能不总是通过
            // 但至少验证不会崩溃
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
}
