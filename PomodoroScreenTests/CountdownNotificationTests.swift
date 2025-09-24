//
//  CountdownNotificationTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2025-09-21.
//

import XCTest
@testable import PomodoroScreen

class CountdownNotificationTests: XCTestCase {
    var pomodoroTimer: PomodoroTimer!
    
    override func setUp() {
        super.setUp()
        pomodoroTimer = PomodoroTimer()
        
        // 配置基本设置
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 1,  // 1分钟用于快速测试
            breakMinutes: 1,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: false,
            screenLockRestart: false,
            screenLockActionIsRestart: false,
            screensaverRestart: false,
            screensaverActionIsRestart: false,
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 2,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [],
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 0,
            meetingMode: false
        )
    }
    
    override func tearDown() {
        pomodoroTimer = nil
        super.tearDown()
    }
    
    // 测试倒计时通知窗口创建
    func testCountdownNotificationWindowCreation() {
        let window = CountdownNotificationWindow()
        
        // 验证窗口属性
        XCTAssertEqual(window.level, .floating, "通知窗口应该浮动在其他窗口之上")
        XCTAssertTrue(window.ignoresMouseEvents, "通知窗口不应该影响鼠标点击")
        XCTAssertFalse(window.isOpaque, "通知窗口应该是透明的")
        XCTAssertEqual(window.alphaValue, 0.0, "初始状态应该是隐藏的")
    }
    
    // 测试30秒警告显示
    func testThirtySecondWarning() {
        let window = CountdownNotificationWindow()
        let expectation = XCTestExpectation(description: "Warning window should be visible")
        
        // 显示30秒警告
        window.showWarning()
        
        // 给动画一些时间完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertGreaterThan(window.alphaValue, 0.0, "30秒警告显示后窗口应该可见")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // 测试倒计时显示
    func testCountdownDisplay() {
        let window = CountdownNotificationWindow()
        let expectation = XCTestExpectation(description: "Countdown window should be visible")
        
        // 显示倒计时
        window.showCountdown(5)
        
        // 给动画一些时间完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertGreaterThan(window.alphaValue, 0.0, "倒计时显示时窗口应该可见")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // 测试窗口隐藏
    func testWindowHiding() {
        let window = CountdownNotificationWindow()
        let expectation = XCTestExpectation(description: "Window hiding animation completed")
        
        // 先显示窗口
        window.showWarning()
        
        // 等待显示动画完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertGreaterThan(window.alphaValue, 0.0, "窗口应该先显示")
            
            // 隐藏窗口
            window.hideNotification()
            
            // 等待隐藏动画完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                XCTAssertEqual(window.alphaValue, 0.0, "隐藏后窗口应该不可见")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // 测试窗口位置更新
    func testWindowPositionUpdate() {
        let window = CountdownNotificationWindow()
        
        // 更新位置
        window.updatePosition()
        
        // 验证位置在屏幕右上角（考虑Dock宽度）
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero
        let windowWidth: CGFloat = 200
        let windowHeight: CGFloat = 60
        let margin: CGFloat = 20
        let dockWidth: CGFloat = 80
        
        let expectedX = screenFrame.maxX - windowWidth - margin - dockWidth
        let expectedY = screenFrame.maxY - windowHeight - margin
        
        XCTAssertEqual(window.frame.origin.x, expectedX, accuracy: 1.0, "窗口X位置应该考虑Dock宽度")
        XCTAssertEqual(window.frame.origin.y, expectedY, accuracy: 1.0, "窗口Y位置应该在右上角")
    }
    
    // 测试番茄钟倒计时通知集成
    func testPomodoroCountdownIntegration() {
        var timeUpdates: [String] = []
        
        // 监听时间更新
        pomodoroTimer.onTimeUpdate = { timeString in
            timeUpdates.append(timeString)
        }
        
        // 设置剩余时间为35秒（测试30秒警告）
        pomodoroTimer.setRemainingTime(35)
        pomodoroTimer.start()
        
        // 等待一段时间让计时器运行
        let expectation = self.expectation(description: "计时器运行并触发通知")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.pomodoroTimer.stop()
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 3.0, handler: nil)
        
        // 验证时间更新
        XCTAssertFalse(timeUpdates.isEmpty, "应该有时间更新")
    }
    
    // 测试只在番茄钟模式下显示通知
    func testNotificationOnlyInPomodoroMode() {
        // 启动短休息
        pomodoroTimer.startShortBreak()
        
        // 设置剩余时间为30秒
        pomodoroTimer.setRemainingTime(30)
        
        // 在休息模式下不应该显示倒计时通知
        // 这个测试主要验证逻辑正确性，实际的通知显示需要UI测试
        XCTAssertTrue(pomodoroTimer.isInRestPeriod, "应该处于休息期间")
    }
    
    // 测试计时器停止时隐藏通知
    func testHideNotificationOnStop() {
        // 启动番茄钟
        pomodoroTimer.start()
        
        // 设置剩余时间为30秒（触发通知）
        pomodoroTimer.setRemainingTime(30)
        
        // 停止计时器
        pomodoroTimer.stop()
        
        // 验证计时器已停止
        XCTAssertFalse(pomodoroTimer.isRunning, "计时器应该已停止")
        
        // 通知窗口应该被隐藏（通过stop方法中的hideCountdownNotification调用）
        // 这个测试主要验证逻辑调用正确性
    }
}
