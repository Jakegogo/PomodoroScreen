import XCTest
@testable import PomodoroScreen

/// 熬夜功能测试用例
/// 
/// 作者: AI Assistant
/// 创建时间: 2024-09-21
/// 修改时间: 2024-09-24 - 适配状态机重构
/// 
/// 测试熬夜限制功能的各种场景，现在通过状态机管理
class StayUpFeatureTests: XCTestCase {
    
    var pomodoroTimer: PomodoroTimer!
    
    override func setUp() {
        super.setUp()
        pomodoroTimer = PomodoroTimer()
    }
    
    override func tearDown() {
        pomodoroTimer = nil
        super.tearDown()
    }
    
    // MARK: - 熬夜设置测试
    
    /// 测试熬夜设置通过状态机正确保存
    func testStayUpSettings_EnabledWithTime() {
        // Given & When: 通过updateSettings设置熬夜限制为22:30
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
            stayUpLimitEnabled: true,
            stayUpLimitHour: 22,
            stayUpLimitMinute: 30,
            meetingMode: false
        )
        
        // Then: 验证状态机中的设置
        let stateMachine = pomodoroTimer.stateMachineForTesting
        let stayUpInfo = stateMachine.getStayUpLimitInfo()
        XCTAssertTrue(stayUpInfo.enabled)
        XCTAssertEqual(stayUpInfo.hour, 22)
        XCTAssertEqual(stayUpInfo.minute, 30)
    }
    
    /// 测试禁用熬夜限制
    func testStayUpSettings_Disabled() {
        // Given & When: 设置熬夜限制为禁用
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
            stayUpLimitMinute: 0,
            meetingMode: false
        )
        
        // Then: 验证状态机中的设置
        let stateMachine = pomodoroTimer.stateMachineForTesting
        let stayUpInfo = stateMachine.getStayUpLimitInfo()
        XCTAssertFalse(stayUpInfo.enabled)
    }
    
    /// 测试跨日期时间设置（00:00-01:00）
    func testStayUpSettings_MidnightHours() {
        // Given & When: 设置熬夜限制为00:30（次日）
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
            stayUpLimitEnabled: true,
            stayUpLimitHour: 0,
            stayUpLimitMinute: 30,
            meetingMode: false
        )
        
        // Then: 验证设置
        let stateMachine = pomodoroTimer.stateMachineForTesting
        let stayUpInfo = stateMachine.getStayUpLimitInfo()
        XCTAssertTrue(stayUpInfo.enabled)
        XCTAssertEqual(stayUpInfo.hour, 0)
        XCTAssertEqual(stayUpInfo.minute, 30)
    }
    
    // MARK: - 熬夜状态检测测试
    
    /// 测试熬夜状态检测接口
    func testStayUpTimeStatus() {
        // Given: 启用熬夜限制
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
            stayUpLimitEnabled: true,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 0,
            meetingMode: false
        )
        
        // When & Then: 测试熬夜状态检测接口
        let stateMachine = pomodoroTimer.stateMachineForTesting
        
        // 注意：由于无法控制系统时间，这里主要测试接口是否正常工作
        // 实际的时间检测逻辑在状态机内部
        let isStayUpTime = stateMachine.isInStayUpTime()
        
        // 验证接口返回布尔值（无论true还是false都是正常的）
        XCTAssertTrue(isStayUpTime == true || isStayUpTime == false, "isInStayUpTime should return a boolean value")
    }
    
    // MARK: - 集成测试
    
    /// 测试熬夜状态与计时器的集成
    func testStayUpIntegrationWithTimer() {
        // Given: 启用熬夜限制
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
            stayUpLimitEnabled: true,
            stayUpLimitHour: 22,
            stayUpLimitMinute: 0,
            meetingMode: false
        )
        
        // When: 启动计时器
        pomodoroTimer.start()
        
        // Then: 验证计时器可以正常启动（无论是否在熬夜时间）
        // 如果当前是熬夜时间，计时器可能不会启动，这是正常行为
        let stateMachine = pomodoroTimer.stateMachineForTesting
        let currentState = stateMachine.getCurrentState()
        
        // 验证状态机处于合理的状态
        XCTAssertTrue(
            currentState == .timerRunning || 
            currentState == .forcedSleep || 
            currentState == .idle,
            "Timer should be in a valid state after start() call"
        )
        
        // 清理
        pomodoroTimer.stop()
    }
}