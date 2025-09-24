import XCTest
@testable import PomodoroScreen

/// 状态机休息期间功能测试
/// 
/// 作者: AI Assistant
/// 创建时间: 2024-09-21
/// 
/// 测试重构后的状态机休息期间管理功能
class StateMachineRestPeriodTests: XCTestCase {
    
    var pomodoroTimer: PomodoroTimer!
    var timerFinishedCallCount: Int = 0
    
    override func setUp() {
        super.setUp()
        pomodoroTimer = PomodoroTimer()
        timerFinishedCallCount = 0
        
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
        
        // 设置回调监听
        pomodoroTimer.onTimerFinished = { [weak self] in
            self?.timerFinishedCallCount += 1
            print("🧪 Timer finished callback called, count: \(self?.timerFinishedCallCount ?? 0)")
        }
    }
    
    override func tearDown() {
        pomodoroTimer?.stop()
        pomodoroTimer = nil
        super.tearDown()
    }
    
    // MARK: - 状态机基础测试
    
    /// 测试状态机初始状态
    func testStateMachineInitialState() {
        let state = pomodoroTimer.stateMachineForTesting.getCurrentState()
        let timerType = pomodoroTimer.stateMachineForTesting.getCurrentTimerType()
        let isInRestPeriod = pomodoroTimer.stateMachineForTesting.isInRestPeriod()
        
        XCTAssertEqual(state, .idle, "初始状态应该是idle")
        XCTAssertEqual(timerType, .pomodoro, "初始计时器类型应该是pomodoro")
        XCTAssertFalse(isInRestPeriod, "初始不应该在休息期间")
    }
    
    /// 测试番茄钟完成后的状态转换
    func testPomodoroFinishedStateTransition() {
        // Given: 启动番茄钟
        pomodoroTimer.start()
        
        let initialState = pomodoroTimer.stateMachineForTesting.getCurrentState()
        XCTAssertEqual(initialState, .timerRunning, "启动后应该是timerRunning状态")
        
        // When: 番茄钟完成
        pomodoroTimer.triggerFinish()
        
        // Then: 应该进入休息期间状态
        let finalState = pomodoroTimer.stateMachineForTesting.getCurrentState()
        let isInRestPeriod = pomodoroTimer.stateMachineForTesting.isInRestPeriod()
        
        XCTAssertEqual(finalState, .restPeriod, "番茄钟完成后应该进入restPeriod状态")
        XCTAssertTrue(isInRestPeriod, "应该标记为休息期间")
        XCTAssertEqual(timerFinishedCallCount, 1, "应该触发一次完成回调")
    }
    
    /// 测试开始休息计时的状态转换
    func testRestStartedStateTransition() {
        // Given: 番茄钟完成，进入休息期间
        pomodoroTimer.start()
        pomodoroTimer.triggerFinish()
        
        let restPeriodState = pomodoroTimer.stateMachineForTesting.getCurrentState()
        XCTAssertEqual(restPeriodState, .restPeriod, "应该在休息期间状态")
        
        // When: 开始短休息
        pomodoroTimer.startBreak()
        
        // Then: 应该进入休息计时状态
        let runningState = pomodoroTimer.stateMachineForTesting.getCurrentState()
        let timerType = pomodoroTimer.stateMachineForTesting.getCurrentTimerType()
        let isInRestPeriod = pomodoroTimer.stateMachineForTesting.isInRestPeriod()
        
        XCTAssertEqual(runningState, .restTimerRunning, "应该进入restTimerRunning状态")
        XCTAssertEqual(timerType, .shortBreak, "计时器类型应该是shortBreak")
        XCTAssertTrue(isInRestPeriod, "应该仍在休息期间")
        XCTAssertTrue(pomodoroTimer.isRunning, "休息计时器应该在运行")
    }
    
    /// 测试休息完成的状态转换
    func testRestFinishedStateTransition() {
        // Given: 进入休息计时状态
        pomodoroTimer.start()
        pomodoroTimer.triggerFinish()
        pomodoroTimer.startBreak()
        
        let restRunningState = pomodoroTimer.stateMachineForTesting.getCurrentState()
        XCTAssertEqual(restRunningState, .restTimerRunning, "应该在休息计时状态")
        
        // When: 休息时间结束
        pomodoroTimer.triggerFinish()
        
        // Then: 应该回到空闲状态
        let finalState = pomodoroTimer.stateMachineForTesting.getCurrentState()
        let timerType = pomodoroTimer.stateMachineForTesting.getCurrentTimerType()
        let isInRestPeriod = pomodoroTimer.stateMachineForTesting.isInRestPeriod()
        
        XCTAssertEqual(finalState, .idle, "休息完成后应该回到idle状态")
        XCTAssertEqual(timerType, .pomodoro, "计时器类型应该重置为pomodoro")
        XCTAssertFalse(isInRestPeriod, "不应该在休息期间")
        XCTAssertEqual(timerFinishedCallCount, 2, "应该触发两次完成回调（番茄钟+休息）")
    }
    
    /// 测试取消休息的状态转换
    func testRestCancelledStateTransition() {
        // Given: 进入休息计时状态
        pomodoroTimer.start()
        pomodoroTimer.triggerFinish()
        pomodoroTimer.startBreak()
        
        let restRunningState = pomodoroTimer.stateMachineForTesting.getCurrentState()
        XCTAssertEqual(restRunningState, .restTimerRunning, "应该在休息计时状态")
        
        // When: 取消休息
        pomodoroTimer.cancelBreak()
        
        // Then: 应该回到番茄钟运行状态
        let finalState = pomodoroTimer.stateMachineForTesting.getCurrentState()
        let timerType = pomodoroTimer.stateMachineForTesting.getCurrentTimerType()
        let isInRestPeriod = pomodoroTimer.stateMachineForTesting.isInRestPeriod()
        
        XCTAssertEqual(finalState, .timerRunning, "取消休息后应该开始新的番茄钟")
        XCTAssertEqual(timerType, .pomodoro, "计时器类型应该重置为pomodoro")
        XCTAssertFalse(isInRestPeriod, "不应该在休息期间")
        XCTAssertTrue(pomodoroTimer.isRunning, "新的番茄钟应该在运行")
    }
    
    // MARK: - 屏保事件测试
    
    /// 测试休息期间屏保事件不会干扰状态
    func testScreensaverEventsDoNotDisruptRestPeriod() {
        // Given: 启用屏保功能并进入休息计时状态
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 1,
            breakMinutes: 1,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: false,
            screenLockRestart: false,
            screenLockActionIsRestart: false,
            screensaverRestart: true, // 启用屏保功能
            screensaverActionIsRestart: false, // 屏保停止时恢复而不是重启
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
        
        pomodoroTimer.start()
        pomodoroTimer.triggerFinish()
        pomodoroTimer.startBreak()
        
        let initialState = pomodoroTimer.stateMachineForTesting.getCurrentState()
        let initialCallCount = timerFinishedCallCount
        XCTAssertEqual(initialState, .restTimerRunning, "应该在休息计时状态")
        
        // When: 屏保启动
        pomodoroTimer.stateMachineForTesting.processEvent(.screensaverStarted)
        
        // Then: 应该暂停休息计时
        let pausedState = pomodoroTimer.stateMachineForTesting.getCurrentState()
        XCTAssertEqual(pausedState, .restTimerPausedBySystem, "屏保启动后应该暂停休息计时")
        XCTAssertTrue(pomodoroTimer.stateMachineForTesting.isInRestPeriod(), "应该仍在休息期间")
        
        // When: 屏保停止
        pomodoroTimer.stateMachineForTesting.processEvent(.screensaverStopped)
        
        // Then: 应该恢复休息计时
        let resumedState = pomodoroTimer.stateMachineForTesting.getCurrentState()
        XCTAssertEqual(resumedState, .restTimerRunning, "屏保停止后应该恢复休息计时")
        XCTAssertTrue(pomodoroTimer.stateMachineForTesting.isInRestPeriod(), "应该仍在休息期间")
        XCTAssertEqual(timerFinishedCallCount, initialCallCount, "不应该触发额外的完成回调")
    }
    
    /// 测试重复的番茄钟完成事件被正确处理
    func testDuplicatePomodoroFinishedEvents() {
        // Given: 启动番茄钟
        pomodoroTimer.start()
        
        // When: 第一次完成
        pomodoroTimer.triggerFinish()
        
        let firstState = pomodoroTimer.stateMachineForTesting.getCurrentState()
        let firstCallCount = timerFinishedCallCount
        XCTAssertEqual(firstState, .restPeriod, "第一次完成后应该进入休息期间")
        XCTAssertEqual(firstCallCount, 1, "应该触发一次完成回调")
        
        // When: 尝试再次触发完成（模拟重复事件）
        pomodoroTimer.stateMachineForTesting.processEvent(.pomodoroFinished)
        
        // Then: 状态应该保持不变，不应该重复处理
        let finalState = pomodoroTimer.stateMachineForTesting.getCurrentState()
        let finalCallCount = timerFinishedCallCount
        XCTAssertEqual(finalState, .restPeriod, "状态应该保持在休息期间")
        XCTAssertEqual(finalCallCount, firstCallCount, "不应该触发额外的完成回调")
    }
    
    // MARK: - 长休息测试
    
    /// 测试长休息的状态管理
    func testLongBreakStateManagement() {
        // Given: 设置长休息周期为1（每次都是长休息）
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
            longBreakCycle: 1, // 每次都是长休息
            longBreakTimeMinutes: 3,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [],
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 0,
            meetingMode: false
        )
        
        // When: 完成番茄钟并开始长休息
        pomodoroTimer.start()
        pomodoroTimer.triggerFinish()
        pomodoroTimer.startBreak()
        
        // Then: 应该是长休息状态
        let state = pomodoroTimer.stateMachineForTesting.getCurrentState()
        let timerType = pomodoroTimer.stateMachineForTesting.getCurrentTimerType()
        let isInRestPeriod = pomodoroTimer.stateMachineForTesting.isInRestPeriod()
        
        XCTAssertEqual(state, .restTimerRunning, "应该在休息计时状态")
        XCTAssertEqual(timerType, .longBreak, "应该是长休息类型")
        XCTAssertTrue(isInRestPeriod, "应该在休息期间")
        XCTAssertTrue(pomodoroTimer.isLongBreak, "应该标记为长休息")
    }
    
    // MARK: - 边界条件测试
    
    /// 测试在不同状态下的事件处理
    func testEventHandlingInDifferentStates() {
        // Test 1: 在idle状态下处理pomodoroFinished事件
        let idleState = pomodoroTimer.stateMachineForTesting.getCurrentState()
        XCTAssertEqual(idleState, .idle, "初始应该是idle状态")
        
        pomodoroTimer.stateMachineForTesting.processEvent(.pomodoroFinished)
        let afterPomodoroFinished = pomodoroTimer.stateMachineForTesting.getCurrentState()
        XCTAssertEqual(afterPomodoroFinished, .restPeriod, "idle状态下pomodoroFinished应该进入休息期间")
        
        // Test 2: 在restPeriod状态下处理restCancelled事件
        pomodoroTimer.stateMachineForTesting.processEvent(.restCancelled)
        let afterRestCancelled = pomodoroTimer.stateMachineForTesting.getCurrentState()
        XCTAssertEqual(afterRestCancelled, .idle, "取消休息后应该回到idle状态")
        
        // Test 3: 在idle状态下处理restStarted事件
        pomodoroTimer.stateMachineForTesting.setTimerType(.shortBreak)
        pomodoroTimer.stateMachineForTesting.processEvent(.restStarted)
        let afterRestStarted = pomodoroTimer.stateMachineForTesting.getCurrentState()
        XCTAssertEqual(afterRestStarted, .restTimerRunning, "开始休息后应该进入休息计时状态")
    }
}
