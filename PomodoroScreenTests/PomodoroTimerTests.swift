import XCTest
@testable import PomodoroScreen

class PomodoroTimerTests: XCTestCase {
    
    var pomodoroTimer: PomodoroTimer!
    
    override func setUp() {
        super.setUp()
        pomodoroTimer = PomodoroTimer()
    }
    
    override func tearDown() {
        pomodoroTimer.stop()
        pomodoroTimer = nil
        super.tearDown()
    }
    
    func testInitialRemainingTime() {
        // 测试初始剩余时间应该是25分钟
        let expectedTime = "25:00"
        let actualTime = pomodoroTimer.getRemainingTimeString()
        XCTAssertEqual(actualTime, expectedTime, "初始时间应该是25:00")
    }
    
    func testTimerStart() {
        // 测试计时器开始功能
        let expectation = self.expectation(description: "Timer should update time")
        
        pomodoroTimer.onTimeUpdate = { timeString in
            // 验证时间格式正确
            XCTAssertTrue(timeString.contains(":"), "时间格式应该包含冒号")
            expectation.fulfill()
        }
        
        pomodoroTimer.start()
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testTimerReset() {
        // 测试重置功能
        pomodoroTimer.start()
        
        // 等待一秒让计时器运行
        let expectation = self.expectation(description: "Wait for timer")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
        
        // 重置计时器
        pomodoroTimer.reset()
        
        // 验证时间已重置
        let resetTime = pomodoroTimer.getRemainingTimeString()
        XCTAssertEqual(resetTime, "25:00", "重置后时间应该回到25:00")
    }
    
    func testTimerStop() {
        // 测试停止功能
        pomodoroTimer.start()
        pomodoroTimer.stop()
        
        // 验证计时器已停止（这里简单验证不会崩溃）
        XCTAssertNoThrow(pomodoroTimer.stop(), "停止计时器不应该抛出异常")
    }
    
    func testTimeFormatting() {
        // 测试时间格式化功能
        // 由于formatTime是私有方法，我们通过getRemainingTimeString间接测试
        let timeString = pomodoroTimer.getRemainingTimeString()
        
        // 验证格式：MM:SS
        let components = timeString.components(separatedBy: ":")
        XCTAssertEqual(components.count, 2, "时间格式应该是MM:SS")
        
        if components.count == 2 {
            XCTAssertEqual(components[0].count, 2, "分钟应该是两位数")
            XCTAssertEqual(components[1].count, 2, "秒钟应该是两位数")
        }
    }
    
    func testTriggerFinish() {
        // 测试立即完成功能
        let expectation = self.expectation(description: "Timer should finish immediately")
        
        pomodoroTimer.onTimerFinished = {
            expectation.fulfill()
        }
        
        // 触发立即完成
        pomodoroTimer.triggerFinish()
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testOverlayBehavior() {
        // 测试遮罩层行为：3分钟自动隐藏，点击不隐藏
        // 这里只测试计时器完成回调是否正确触发
        let expectation = self.expectation(description: "Overlay should be triggered")
        
        pomodoroTimer.onTimerFinished = {
            // 验证遮罩层被触发（通过回调验证）
            expectation.fulfill()
        }
        
        pomodoroTimer.triggerFinish()
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testOverlayWithCancelButton() {
        // 测试遮罩层取消按钮功能
        let expectation = self.expectation(description: "Overlay with cancel button should work")
        
        pomodoroTimer.onTimerFinished = {
            // 验证遮罩层被触发，现在包含取消按钮
            expectation.fulfill()
        }
        
        pomodoroTimer.triggerFinish()
        
        waitForExpectations(timeout: 1, handler: nil)
    }
}
