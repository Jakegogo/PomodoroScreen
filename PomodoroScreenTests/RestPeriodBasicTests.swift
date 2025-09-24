import XCTest
@testable import PomodoroScreen

/// 基础休息期间状态测试
/// 
/// 作者: AI Assistant
/// 创建时间: 2024-09-21
/// 
/// 测试休息期间状态标记的基本功能
class RestPeriodBasicTests: XCTestCase {
    
    var pomodoroTimer: PomodoroTimer!
    
    override func setUp() {
        super.setUp()
        pomodoroTimer = PomodoroTimer()
        
        // 设置测试环境：短时间便于测试
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
            longBreakTimeMinutes: 3,
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
        pomodoroTimer?.stop()
        pomodoroTimer = nil
        super.tearDown()
    }
    
    /// 测试初始状态不在休息期间
    func testInitialStateNotInRestPeriod() {
        XCTAssertFalse(pomodoroTimer.isInRestPeriod, "初始状态不应该在休息期间")
    }
    
    /// 测试番茄钟完成后进入休息期间
    func testEnterRestPeriodAfterPomodoroFinish() {
        // Given: 启动番茄钟
        pomodoroTimer.start()
        XCTAssertFalse(pomodoroTimer.isInRestPeriod, "启动后不应该在休息期间")
        
        // When: 手动触发完成（模拟番茄钟时间到）
        pomodoroTimer.triggerFinish()
        
        // Then: 应该进入休息期间
        XCTAssertTrue(pomodoroTimer.isInRestPeriod, "番茄钟完成后应该进入休息期间")
    }
    
    /// 测试取消休息后退出休息期间
    func testExitRestPeriodAfterCancel() {
        // Given: 进入休息期间
        pomodoroTimer.start()
        pomodoroTimer.triggerFinish()
        XCTAssertTrue(pomodoroTimer.isInRestPeriod, "应该在休息期间")
        
        // When: 取消休息
        pomodoroTimer.cancelBreak()
        
        // Then: 应该退出休息期间
        XCTAssertFalse(pomodoroTimer.isInRestPeriod, "取消休息后不应该在休息期间")
    }
    
    /// 测试开始休息计时
    func testStartBreakTimer() {
        // Given: 进入休息期间
        pomodoroTimer.start()
        pomodoroTimer.triggerFinish()
        XCTAssertTrue(pomodoroTimer.isInRestPeriod, "应该在休息期间")
        
        // When: 开始休息计时
        pomodoroTimer.startBreak()
        
        // Then: 应该仍在休息期间且计时器运行
        XCTAssertTrue(pomodoroTimer.isInRestPeriod, "开始休息计时后仍应该在休息期间")
        XCTAssertTrue(pomodoroTimer.isRunning, "休息计时器应该在运行")
    }
    
    /// 测试休息结束后退出休息期间
    func testExitRestPeriodAfterRestFinish() {
        // Given: 进入休息期间并开始休息计时
        pomodoroTimer.start()
        pomodoroTimer.triggerFinish()
        pomodoroTimer.startBreak()
        XCTAssertTrue(pomodoroTimer.isInRestPeriod, "应该在休息期间")
        
        // When: 休息时间结束
        pomodoroTimer.triggerFinish()
        
        // Then: 应该退出休息期间
        XCTAssertFalse(pomodoroTimer.isInRestPeriod, "休息结束后不应该在休息期间")
    }
}
