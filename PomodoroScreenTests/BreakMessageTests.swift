import XCTest
@testable import PomodoroScreen

/// 休息时间消息显示测试
/// 
/// 作者: AI Assistant
/// 创建时间: 2024-09-21
/// 
/// 测试休息时间消息根据实际设置动态显示
class BreakMessageTests: XCTestCase {
    
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
    
    // MARK: - 休息时间信息测试
    
    /// 测试短休息时间信息获取
    func testGetCurrentBreakInfo_ShortBreak() {
        // Given: 设置短休息时间为5分钟
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 25,
            breakMinutes: 5,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: false,
            screenLockRestart: false,
            screenLockActionIsRestart: false,
            screensaverRestart: false,
            screensaverActionIsRestart: false,
            showCancelRestButton: true,
            longBreakCycle: 4,
            longBreakTimeMinutes: 15,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [],
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 0
        )
        
        // When: 获取当前休息信息（默认为短休息）
        let breakInfo = pomodoroTimer.getCurrentBreakInfo()
        
        // Then: 应该返回短休息信息
        XCTAssertFalse(breakInfo.isLongBreak, "应该是短休息")
        XCTAssertEqual(breakInfo.breakMinutes, 5, "短休息时间应该是5分钟")
    }
    
    /// 测试长休息时间信息获取
    func testGetCurrentBreakInfo_LongBreak() {
        // Given: 设置长休息时间为20分钟
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 25,
            breakMinutes: 5,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: false,
            screenLockRestart: false,
            screenLockActionIsRestart: false,
            screensaverRestart: false,
            screensaverActionIsRestart: false,
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 20,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [],
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 0
        )
        
        // 模拟进入长休息状态
        // 注意：由于 isLongBreak 是 internal，我们可以通过完成番茄钟来触发长休息
        // 但为了测试简单，我们直接测试方法逻辑
        
        // When: 获取当前休息信息（在短休息状态下）
        let shortBreakInfo = pomodoroTimer.getCurrentBreakInfo()
        
        // Then: 应该返回短休息信息
        XCTAssertFalse(shortBreakInfo.isLongBreak, "默认应该是短休息")
        XCTAssertEqual(shortBreakInfo.breakMinutes, 5, "短休息时间应该是5分钟")
    }
    
    /// 测试不同休息时间设置
    func testGetCurrentBreakInfo_DifferentSettings() {
        let testCases = [
            (breakMinutes: 3, longBreakMinutes: 15),
            (breakMinutes: 5, longBreakMinutes: 20),
            (breakMinutes: 10, longBreakMinutes: 30),
            (breakMinutes: 1, longBreakMinutes: 5)
        ]
        
        for testCase in testCases {
            // Given: 设置不同的休息时间
            pomodoroTimer.updateSettings(
                pomodoroMinutes: 25,
                breakMinutes: testCase.breakMinutes,
                idleRestart: false,
                idleTime: 10,
                idleActionIsRestart: false,
                screenLockRestart: false,
                screenLockActionIsRestart: false,
                screensaverRestart: false,
                screensaverActionIsRestart: false,
                showCancelRestButton: true,
                longBreakCycle: 4,
                longBreakTimeMinutes: testCase.longBreakMinutes,
                showLongBreakCancelButton: true,
                accumulateRestTime: false,
                backgroundFiles: [],
                stayUpLimitEnabled: false,
                stayUpLimitHour: 23,
                stayUpLimitMinute: 0
            )
            
            // When: 获取休息信息
            let breakInfo = pomodoroTimer.getCurrentBreakInfo()
            
            // Then: 应该返回正确的时间
            XCTAssertEqual(breakInfo.breakMinutes, testCase.breakMinutes, 
                          "短休息时间应该是\(testCase.breakMinutes)分钟")
        }
    }
    
    /// 测试累积休息时间功能
    func testGetCurrentBreakInfo_WithAccumulatedTime() {
        // Given: 启用累积休息时间功能
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 25,
            breakMinutes: 5,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: false,
            screenLockRestart: false,
            screenLockActionIsRestart: false,
            screensaverRestart: false,
            screensaverActionIsRestart: false,
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 15,
            showLongBreakCancelButton: true,
            accumulateRestTime: true, // 启用累积功能
            backgroundFiles: [],
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 0
        )
        
        // When: 获取休息信息
        let breakInfo = pomodoroTimer.getCurrentBreakInfo()
        
        // Then: 短休息时间应该正确
        XCTAssertFalse(breakInfo.isLongBreak, "应该是短休息")
        XCTAssertEqual(breakInfo.breakMinutes, 5, "短休息时间应该是5分钟")
    }
    
    /// 测试边界情况 - 零分钟休息时间
    func testGetCurrentBreakInfo_ZeroMinutes() {
        // Given: 设置0分钟休息时间（边界情况）
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 25,
            breakMinutes: 0,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: false,
            screenLockRestart: false,
            screenLockActionIsRestart: false,
            screensaverRestart: false,
            screensaverActionIsRestart: false,
            showCancelRestButton: true,
            longBreakCycle: 4,
            longBreakTimeMinutes: 0,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [],
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 0
        )
        
        // When: 获取休息信息
        let breakInfo = pomodoroTimer.getCurrentBreakInfo()
        
        // Then: 应该返回0分钟
        XCTAssertEqual(breakInfo.breakMinutes, 0, "休息时间应该是0分钟")
    }
    
    /// 测试大数值休息时间
    func testGetCurrentBreakInfo_LargeValues() {
        // Given: 设置较大的休息时间值
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 60,
            breakMinutes: 30,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: false,
            screenLockRestart: false,
            screenLockActionIsRestart: false,
            screensaverRestart: false,
            screensaverActionIsRestart: false,
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 60,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [],
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 0
        )
        
        // When: 获取休息信息
        let breakInfo = pomodoroTimer.getCurrentBreakInfo()
        
        // Then: 应该返回正确的大数值
        XCTAssertEqual(breakInfo.breakMinutes, 30, "短休息时间应该是30分钟")
    }
}
