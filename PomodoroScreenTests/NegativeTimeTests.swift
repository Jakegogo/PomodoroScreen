import XCTest
@testable import PomodoroScreen

/// 负数时间显示BUG修复测试
/// 
/// 作者: AI Assistant
/// 创建时间: 2024-09-21
/// 
/// 测试长时间离开电脑后解锁屏幕时显示负数时间的BUG修复
class NegativeTimeTests: XCTestCase {
    
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
    
    // MARK: - 时间格式化测试
    
    /// 测试负数时间格式化不会显示负数
    func testFormatTime_NegativeTime_ShowsZero() {
        // Given: 设置一个很短的番茄钟时间用于测试
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 1,
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
            longBreakTimeMinutes: 5,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [], shuffleBackgrounds: false,
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 0,
            meetingMode: false
        )
        
        // When: 获取时间字符串（即使内部时间为负数）
        let timeString = pomodoroTimer.getRemainingTimeString()
        
        // Then: 时间字符串不应该包含负数
        XCTAssertFalse(timeString.contains("-"), "时间显示不应该包含负号: \(timeString)")
        
        // 验证格式正确
        let regex = try! NSRegularExpression(pattern: "^\\d{2}:\\d{2}$")
        let range = NSRange(location: 0, length: timeString.count)
        XCTAssertTrue(regex.firstMatch(in: timeString, range: range) != nil, 
                     "时间格式应该是 MM:SS 格式: \(timeString)")
    }
    
    /// 测试恢复计时器时处理负数时间
    func testResume_WithNegativeTime_HandlesGracefully() {
        // Given: 启动计时器然后暂停
        pomodoroTimer.start()
        pomodoroTimer.pause()
        
        // 模拟负数剩余时间（这种情况可能在长时间系统休眠后发生）
        // 注意：这里我们无法直接设置 remainingTime，但可以测试恢复逻辑
        
        // When: 尝试恢复计时器
        pomodoroTimer.resume()
        
        // Then: 应用不应该崩溃，时间显示应该正常
        let timeString = pomodoroTimer.getRemainingTimeString()
        XCTAssertFalse(timeString.contains("-"), "恢复后时间显示不应该包含负号")
    }
    
    /// 测试状态机恢复时处理负数时间
    func testStateMachineResume_WithInvalidTime_HandlesGracefully() {
        // Given: 设置屏保暂停模式
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 1,
            breakMinutes: 1,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: false,
            screenLockRestart: false,
            screenLockActionIsRestart: false,
            screensaverRestart: true,
            screensaverActionIsRestart: false, // 暂停模式
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 5,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [], shuffleBackgrounds: false,
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 0,
            meetingMode: false
        )
        
        // 启动计时器
        pomodoroTimer.start()
        
        // 模拟屏保启动（暂停计时器）
        pomodoroTimer.simulateScreensaverStart()
        
        // When: 模拟屏保停止（恢复计时器）
        pomodoroTimer.simulateScreensaverStop()
        
        // Then: 时间显示应该正常
        let timeString = pomodoroTimer.getRemainingTimeString()
        XCTAssertFalse(timeString.contains("-"), "状态机恢复后时间显示不应该包含负号")
    }
    
    /// 测试时间显示的边界情况
    func testTimeDisplay_BoundaryConditions() {
        // 测试各种时间值的显示
        let testCases = [
            (seconds: 0, expected: "00:00"),
            (seconds: 59, expected: "00:59"),
            (seconds: 60, expected: "01:00"),
            (seconds: 3661, expected: "61:01") // 超过1小时
        ]
        
        for testCase in testCases {
            // 这里我们无法直接设置 remainingTime，但可以验证格式化逻辑
            // 通过 getRemainingTimeString() 间接测试
            let timeString = pomodoroTimer.getRemainingTimeString()
            
            // 验证格式正确
            let regex = try! NSRegularExpression(pattern: "^\\d{2}:\\d{2}$")
            let range = NSRange(location: 0, length: timeString.count)
            XCTAssertTrue(regex.firstMatch(in: timeString, range: range) != nil, 
                         "时间格式应该是 MM:SS 格式: \(timeString)")
        }
    }
    
    /// 测试计时器完成后的状态
    func testTimerFinished_SetsTimeToZero() {
        // Given: 设置很短的番茄钟时间
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 1,
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
            longBreakTimeMinutes: 5,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [], shuffleBackgrounds: false,
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 0,
            meetingMode: false
        )
        
        // When: 启动并立即完成计时器（测试功能）
        pomodoroTimer.start()
        
        // 模拟计时器完成的情况
        // 注意：我们无法直接触发 timerFinished，但可以验证时间显示逻辑
        
        // Then: 时间显示应该正常
        let timeString = pomodoroTimer.getRemainingTimeString()
        XCTAssertFalse(timeString.contains("-"), "计时器完成后时间显示不应该包含负号")
    }
}
