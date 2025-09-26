//
//  CountdownWarningTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2025-09-26.
//

import XCTest
@testable import PomodoroScreen

class CountdownWarningTests: XCTestCase {
    var pomodoroTimer: PomodoroTimer!
    var mockStateMachine: AutoRestartStateMachine!
    
    override func setUp() {
        super.setUp()
        pomodoroTimer = PomodoroTimer()
        mockStateMachine = pomodoroTimer.stateMachineForTesting
    }
    
    override func tearDown() {
        pomodoroTimer = nil
        mockStateMachine = nil
        super.tearDown()
    }
    
    func testCountdownWarningCallback() {
        // 测试倒计时警告回调是否正确设置
        XCTAssertNotNil(mockStateMachine.onCountdownWarning, "倒计时警告回调应该被设置")
    }
    
    func testCountdownWarningLogic() {
        // 创建一个期望来捕获回调
        let expectation = XCTestExpectation(description: "倒计时警告回调应该被触发")
        var receivedMinutes: Int?
        
        // 设置测试回调
        mockStateMachine.onCountdownWarning = { minutes in
            receivedMinutes = minutes
            expectation.fulfill()
        }
        
        // 模拟触发5分钟警告
        mockStateMachine.onCountdownWarning?(5)
        
        // 等待回调
        wait(for: [expectation], timeout: 1.0)
        
        // 验证结果
        XCTAssertEqual(receivedMinutes, 5, "应该收到5分钟警告")
    }
    
    func testCountdownNotificationWindowCreation() {
        // 测试CountdownNotificationWindow的创建
        let window = CountdownNotificationWindow()
        
        XCTAssertNotNil(window.messageLabel, "消息标签应该被创建")
        XCTAssertNotNil(window.backgroundView, "背景视图应该被创建")
        XCTAssertEqual(window.alphaValue, 0.0, "初始状态应该是隐藏的")
    }
    
    func testCountdownWarningTrigger() {
        // 测试强制睡眠前的警告触发
        let expectation = XCTestExpectation(description: "强制睡眠警告应该被触发")
        
        // 监听倒计时警告
        var warningTriggered = false
        mockStateMachine.onCountdownWarning = { minutes in
            if minutes == 5 || minutes == 1 {
                warningTriggered = true
                expectation.fulfill()
            }
        }
        
        // 模拟触发警告
        mockStateMachine.onCountdownWarning?(5)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(warningTriggered, "警告应该被触发")
    }
}
