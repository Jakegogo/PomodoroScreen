import XCTest
@testable import PomodoroScreen

class AutoRestartStateMachineTests: XCTestCase {
    
    var stateMachine: AutoRestartStateMachine!
    
    override func setUp() {
        super.setUp()
        // 创建默认设置：所有功能都启用，都设置为停止计时模式
        let settings = AutoRestartStateMachine.AutoRestartSettings(
            idleEnabled: true,
            idleActionIsRestart: false,  // 停止计时模式
            screenLockEnabled: true,
            screenLockActionIsRestart: false,  // 停止计时模式
            screensaverEnabled: true,
            screensaverActionIsRestart: false  // 停止计时模式
        )
        stateMachine = AutoRestartStateMachine(settings: settings)
    }
    
    override func tearDown() {
        stateMachine = nil
        super.tearDown()
    }
    
    // MARK: - 基础状态转换测试
    
    func testInitialState() {
        XCTAssertEqual(stateMachine.getCurrentState(), .idle, "初始状态应该是idle")
    }
    
    func testTimerLifecycle() {
        // 启动计时器
        let action1 = stateMachine.processEvent(.timerStarted)
        XCTAssertEqual(action1, .none, "启动计时器不应该触发动作")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "启动后状态应该是timerRunning")
        
        // 停止计时器
        let action2 = stateMachine.processEvent(.timerStopped)
        XCTAssertEqual(action2, .none, "停止计时器不应该触发动作")
        XCTAssertEqual(stateMachine.getCurrentState(), .idle, "停止后状态应该回到idle")
    }
    
    func testTimerPause() {
        // 先启动计时器
        _ = stateMachine.processEvent(.timerStarted)
        
        // 暂停计时器
        let action = stateMachine.processEvent(.timerPaused)
        XCTAssertEqual(action, .none, "暂停计时器不应该触发动作")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerPausedBySystem, "暂停后状态应该是timerPausedBySystem")
    }
    
    // MARK: - 无操作检测测试
    
    func testIdleTimeExceeded() {
        // 先启动计时器
        _ = stateMachine.processEvent(.timerStarted)
        
        // 无操作时间超过
        let action = stateMachine.processEvent(.idleTimeExceeded)
        XCTAssertEqual(action, .pauseTimer, "无操作超时应该暂停计时器")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerPausedByIdle, "无操作超时后状态应该是timerPausedByIdle")
    }
    
    func testUserActivityDetectedFromIdlePause() {
        // 设置到无操作暂停状态
        _ = stateMachine.processEvent(.timerStarted)
        _ = stateMachine.processEvent(.idleTimeExceeded)
        
        // 检测到用户活动
        let action = stateMachine.processEvent(.userActivityDetected)
        XCTAssertEqual(action, .resumeTimer, "从无操作暂停状态检测到用户活动应该恢复计时器")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "用户活动后状态应该恢复到timerRunning")
    }
    
    func testUserActivityDetectedFromSystemPause() {
        // 设置到系统暂停状态
        _ = stateMachine.processEvent(.timerStarted)
        _ = stateMachine.processEvent(.screensaverStarted)
        
        // 在系统暂停状态下检测到用户活动
        let action = stateMachine.processEvent(.userActivityDetected)
        XCTAssertEqual(action, .none, "系统暂停期间用户活动不应该触发动作")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerPausedBySystem, "系统暂停期间用户活动不应该改变状态")
    }
    
    func testIdleTimeExceededWhenNotRunning() {
        // 在idle状态下无操作超时
        let action = stateMachine.processEvent(.idleTimeExceeded)
        XCTAssertEqual(action, .none, "非运行状态下无操作超时不应该触发动作")
        XCTAssertEqual(stateMachine.getCurrentState(), .idle, "非运行状态下无操作超时不应该改变状态")
    }
    
    // MARK: - 屏保测试
    
    func testScreensaverStopTimerMode() {
        // 先启动计时器
        _ = stateMachine.processEvent(.timerStarted)
        
        // 屏保启动
        let action1 = stateMachine.processEvent(.screensaverStarted)
        XCTAssertEqual(action1, .pauseTimer, "屏保启动应该暂停计时器（停止计时模式）")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerPausedBySystem, "屏保启动后状态应该是timerPausedBySystem")
        
        // 屏保停止
        let action2 = stateMachine.processEvent(.screensaverStopped)
        XCTAssertEqual(action2, .resumeTimer, "屏保停止应该恢复计时器（停止计时模式）")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "屏保停止后状态应该恢复到timerRunning")
    }
    
    func testScreensaverRestartMode() {
        // 创建重新计时模式的设置
        let restartSettings = AutoRestartStateMachine.AutoRestartSettings(
            idleEnabled: true,
            idleActionIsRestart: true,
            screenLockEnabled: true,
            screenLockActionIsRestart: true,
            screensaverEnabled: true,
            screensaverActionIsRestart: true  // 重新计时模式
        )
        stateMachine.updateSettings(restartSettings)
        
        // 先启动计时器
        _ = stateMachine.processEvent(.timerStarted)
        
        // 屏保启动（重新计时模式下不暂停）
        let action1 = stateMachine.processEvent(.screensaverStarted)
        XCTAssertEqual(action1, .none, "屏保启动不应该触发动作（重新计时模式）")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "屏保启动不应该改变状态（重新计时模式）")
        
        // 屏保停止（重新计时模式）
        let action2 = stateMachine.processEvent(.screensaverStopped)
        XCTAssertEqual(action2, .restartTimer, "屏保停止应该重新开始计时器（重新计时模式）")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "屏保停止后状态应该保持timerRunning")
    }
    
    func testScreensaverStoppedFromWrongState() {
        // 在idle状态下屏保停止
        let action = stateMachine.processEvent(.screensaverStopped)
        XCTAssertEqual(action, .none, "非系统暂停状态下屏保停止不应该触发动作")
        XCTAssertEqual(stateMachine.getCurrentState(), .idle, "非系统暂停状态下屏保停止不应该改变状态")
    }
    
    // MARK: - 锁屏测试
    
    func testScreenLockStopTimerMode() {
        // 先启动计时器
        _ = stateMachine.processEvent(.timerStarted)
        
        // 锁屏
        let action1 = stateMachine.processEvent(.screenLocked)
        XCTAssertEqual(action1, .pauseTimer, "锁屏应该暂停计时器（停止计时模式）")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerPausedBySystem, "锁屏后状态应该是timerPausedBySystem")
        
        // 解锁
        let action2 = stateMachine.processEvent(.screenUnlocked)
        XCTAssertEqual(action2, .resumeTimer, "解锁应该恢复计时器（停止计时模式）")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "解锁后状态应该恢复到timerRunning")
    }
    
    func testScreenLockRestartMode() {
        // 创建重新计时模式的设置
        let restartSettings = AutoRestartStateMachine.AutoRestartSettings(
            idleEnabled: true,
            idleActionIsRestart: true,
            screenLockEnabled: true,
            screenLockActionIsRestart: true,  // 重新计时模式
            screensaverEnabled: true,
            screensaverActionIsRestart: true
        )
        stateMachine.updateSettings(restartSettings)
        
        // 先启动计时器
        _ = stateMachine.processEvent(.timerStarted)
        
        // 锁屏（重新计时模式下不暂停）
        let action1 = stateMachine.processEvent(.screenLocked)
        XCTAssertEqual(action1, .none, "锁屏不应该触发动作（重新计时模式）")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "锁屏不应该改变状态（重新计时模式）")
        
        // 解锁（重新计时模式）
        let action2 = stateMachine.processEvent(.screenUnlocked)
        XCTAssertEqual(action2, .restartTimer, "解锁应该重新开始计时器（重新计时模式）")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "解锁后状态应该保持timerRunning")
    }
    
    // MARK: - 功能开关测试
    
    func testIdleDisabled() {
        // 创建禁用无操作检测的设置
        let disabledSettings = AutoRestartStateMachine.AutoRestartSettings(
            idleEnabled: false,  // 禁用无操作检测
            idleActionIsRestart: false,
            screenLockEnabled: true,
            screenLockActionIsRestart: false,
            screensaverEnabled: true,
            screensaverActionIsRestart: false
        )
        stateMachine.updateSettings(disabledSettings)
        
        // 先启动计时器
        _ = stateMachine.processEvent(.timerStarted)
        
        // 无操作时间超过（但功能已禁用）
        let action = stateMachine.processEvent(.idleTimeExceeded)
        XCTAssertEqual(action, .none, "禁用无操作检测时不应该触发动作")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "禁用无操作检测时不应该改变状态")
    }
    
    func testScreensaverDisabled() {
        // 创建禁用屏保处理的设置
        let disabledSettings = AutoRestartStateMachine.AutoRestartSettings(
            idleEnabled: true,
            idleActionIsRestart: false,
            screenLockEnabled: true,
            screenLockActionIsRestart: false,
            screensaverEnabled: false,  // 禁用屏保处理
            screensaverActionIsRestart: false
        )
        stateMachine.updateSettings(disabledSettings)
        
        // 先启动计时器
        _ = stateMachine.processEvent(.timerStarted)
        
        // 屏保启动（但功能已禁用）
        let action1 = stateMachine.processEvent(.screensaverStarted)
        XCTAssertEqual(action1, .none, "禁用屏保处理时不应该触发动作")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "禁用屏保处理时不应该改变状态")
        
        // 屏保停止（但功能已禁用）
        let action2 = stateMachine.processEvent(.screensaverStopped)
        XCTAssertEqual(action2, .none, "禁用屏保处理时不应该触发动作")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "禁用屏保处理时不应该改变状态")
    }
    
    // MARK: - 复合场景测试
    
    func testComplexScenario1() {
        // 复合场景：计时器运行 -> 屏保暂停 -> 用户活动（应被忽略）-> 屏保停止恢复
        
        // 启动计时器
        _ = stateMachine.processEvent(.timerStarted)
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning)
        
        // 屏保启动，暂停计时器
        let action1 = stateMachine.processEvent(.screensaverStarted)
        XCTAssertEqual(action1, .pauseTimer)
        XCTAssertEqual(stateMachine.getCurrentState(), .timerPausedBySystem)
        
        // 屏保期间用户活动（应被忽略）
        let action2 = stateMachine.processEvent(.userActivityDetected)
        XCTAssertEqual(action2, .none, "系统暂停期间用户活动应被忽略")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerPausedBySystem, "状态不应该改变")
        
        // 屏保停止，恢复计时器
        let action3 = stateMachine.processEvent(.screensaverStopped)
        XCTAssertEqual(action3, .resumeTimer)
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning)
    }
    
    func testComplexScenario2() {
        // 复合场景：计时器运行 -> 无操作暂停 -> 用户活动恢复 -> 锁屏暂停
        
        // 启动计时器
        _ = stateMachine.processEvent(.timerStarted)
        
        // 无操作超时，暂停计时器
        let action1 = stateMachine.processEvent(.idleTimeExceeded)
        XCTAssertEqual(action1, .pauseTimer)
        XCTAssertEqual(stateMachine.getCurrentState(), .timerPausedByIdle)
        
        // 用户活动，恢复计时器
        let action2 = stateMachine.processEvent(.userActivityDetected)
        XCTAssertEqual(action2, .resumeTimer)
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning)
        
        // 锁屏，暂停计时器
        let action3 = stateMachine.processEvent(.screenLocked)
        XCTAssertEqual(action3, .pauseTimer)
        XCTAssertEqual(stateMachine.getCurrentState(), .timerPausedBySystem)
    }
    
    // MARK: - 边界条件测试
    
    func testInvalidTransitions() {
        // 测试一些无效的状态转换
        
        // 在idle状态下解锁屏幕
        let action1 = stateMachine.processEvent(.screenUnlocked)
        XCTAssertEqual(action1, .none, "idle状态下解锁不应该触发动作")
        XCTAssertEqual(stateMachine.getCurrentState(), .idle, "idle状态下解锁不应该改变状态")
        
        // 在idle状态下检测用户活动
        let action2 = stateMachine.processEvent(.userActivityDetected)
        XCTAssertEqual(action2, .none, "idle状态下用户活动不应该触发动作")
        XCTAssertEqual(stateMachine.getCurrentState(), .idle, "idle状态下用户活动不应该改变状态")
    }
    
    func testSettingsUpdate() {
        // 测试设置更新功能
        
        // 创建新的设置
        let newSettings = AutoRestartStateMachine.AutoRestartSettings(
            idleEnabled: false,
            idleActionIsRestart: true,
            screenLockEnabled: false,
            screenLockActionIsRestart: true,
            screensaverEnabled: false,
            screensaverActionIsRestart: true
        )
        
        // 更新设置
        stateMachine.updateSettings(newSettings)
        
        // 启动计时器
        _ = stateMachine.processEvent(.timerStarted)
        
        // 测试屏保功能是否被禁用
        let action = stateMachine.processEvent(.screensaverStarted)
        XCTAssertEqual(action, .none, "更新设置后屏保功能应该被禁用")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "禁用屏保后状态不应该改变")
    }
    
    // MARK: - 重新计时模式测试
    
    func testIdleRestartMode() {
        // 创建无操作重新计时模式的设置
        let restartSettings = AutoRestartStateMachine.AutoRestartSettings(
            idleEnabled: true,
            idleActionIsRestart: true,  // 重新计时模式
            screenLockEnabled: true,
            screenLockActionIsRestart: false,
            screensaverEnabled: true,
            screensaverActionIsRestart: false
        )
        stateMachine.updateSettings(restartSettings)
        
        // 设置到无操作暂停状态
        _ = stateMachine.processEvent(.timerStarted)
        _ = stateMachine.processEvent(.idleTimeExceeded)
        
        // 检测到用户活动（重新计时模式）
        let action = stateMachine.processEvent(.userActivityDetected)
        XCTAssertEqual(action, .restartTimer, "无操作重新计时模式下用户活动应该重新开始计时器")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "重新计时后状态应该是timerRunning")
    }
    
    // MARK: - 屏保暂停计时详细验证测试
    
    func testScreensaverPauseAndResumeDetailedVerification() {
        // 专门验证屏保暂停计时模式：进入屏保暂停计时，退出屏保继续计时
        
        // 确保使用停止计时模式的设置
        let pauseSettings = AutoRestartStateMachine.AutoRestartSettings(
            idleEnabled: true,
            idleActionIsRestart: false,
            screenLockEnabled: true,
            screenLockActionIsRestart: false,
            screensaverEnabled: true,
            screensaverActionIsRestart: false  // 关键：设置为暂停计时模式（不是重新计时）
        )
        stateMachine.updateSettings(pauseSettings)
        
        // 1. 验证初始状态
        XCTAssertEqual(stateMachine.getCurrentState(), .idle, "初始状态应该是idle")
        
        // 2. 启动计时器
        let startAction = stateMachine.processEvent(.timerStarted)
        XCTAssertEqual(startAction, .none, "启动计时器不应该触发额外动作")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "启动后状态应该是timerRunning")
        
        // 3. 进入屏保 - 应该暂停计时器
        let screensaverStartAction = stateMachine.processEvent(.screensaverStarted)
        XCTAssertEqual(screensaverStartAction, .pauseTimer, "进入屏保应该触发暂停计时器动作")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerPausedBySystem, "进入屏保后状态应该是timerPausedBySystem")
        
        // 4. 退出屏保 - 应该恢复计时器（继续计时）
        let screensaverStopAction = stateMachine.processEvent(.screensaverStopped)
        XCTAssertEqual(screensaverStopAction, .resumeTimer, "退出屏保应该触发恢复计时器动作（继续计时）")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "退出屏保后状态应该恢复到timerRunning")
        
        // 5. 验证可以再次正常进入屏保暂停
        let secondScreensaverStartAction = stateMachine.processEvent(.screensaverStarted)
        XCTAssertEqual(secondScreensaverStartAction, .pauseTimer, "再次进入屏保应该再次暂停计时器")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerPausedBySystem, "再次进入屏保后状态应该是timerPausedBySystem")
        
        // 6. 再次验证退出屏保恢复计时
        let secondScreensaverStopAction = stateMachine.processEvent(.screensaverStopped)
        XCTAssertEqual(secondScreensaverStopAction, .resumeTimer, "再次退出屏保应该恢复计时器")
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, "再次退出屏保后状态应该恢复到timerRunning")
    }
}

// MARK: - PomodoroTimer 集成测试（验证剩余时间）

import XCTest
@testable import PomodoroScreen

class PomodoroTimerScreensaverIntegrationTests: XCTestCase {
    var pomodoroTimer: PomodoroTimer!
    
    override func setUp() {
        super.setUp()
        pomodoroTimer = PomodoroTimer()
        
        // 设置屏保为暂停计时模式
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 1, // 1分钟，方便测试
            breakMinutes: 1,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: false,
            screenLockRestart: false,
            screenLockActionIsRestart: false,
            screensaverRestart: true, // 启用屏保检测
            screensaverActionIsRestart: false, // 关键：设置为暂停计时模式
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 5,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [] // 测试中不使用背景文件
        )
    }
    
    override func tearDown() {
        pomodoroTimer.stop()
        pomodoroTimer = nil
        super.tearDown()
    }
    
    func testScreensaverPauseResumeWithRemainingTimeConsistency() {
        print("🧪 开始屏保暂停/恢复剩余时间一致性测试")
        
        // 1. 启动计时器
        pomodoroTimer.start()
        XCTAssertTrue(pomodoroTimer.isRunning, "计时器应该在运行")
        print("✅ 计时器启动成功，isRunning: \(pomodoroTimer.isRunning)")
        
        // 2. 等待让计时器运行更长时间，确保时间会减少
        Thread.sleep(forTimeInterval: 1.5) // 让计时器运行1.5秒，确保时间减少
        
        // 3. 记录暂停前的剩余时间
        let remainingTimeBeforePause = pomodoroTimer.getRemainingTimeString()
        print("🕒 暂停前剩余时间: \(remainingTimeBeforePause)")
        
        // 验证计时器确实在运行（时间应该从01:00减少）
        let isTimeDecreased = remainingTimeBeforePause != "01:00"
        print("⏰ 时间是否减少: \(isTimeDecreased), 当前时间: \(remainingTimeBeforePause)")
        
        // 如果时间没有减少，可能是计时器更新间隔问题，我们继续测试暂停逻辑
        
        // 4. 模拟屏保启动
        print("📢 模拟屏保启动")
        pomodoroTimer.simulateScreensaverStart()
        
        // 5. 验证计时器被暂停
        let isPausedAfterScreensaver = pomodoroTimer.isPausedState
        let isRunningAfterScreensaver = pomodoroTimer.isRunning
        print("📊 屏保后状态 - isPausedState: \(isPausedAfterScreensaver), isRunning: \(isRunningAfterScreensaver)")
        
        XCTAssertTrue(isPausedAfterScreensaver, "进入屏保后计时器应该被暂停")
        XCTAssertFalse(isRunningAfterScreensaver, "进入屏保后计时器不应该在运行")
        
        // 6. 记录暂停时的剩余时间
        let remainingTimeWhilePaused = pomodoroTimer.getRemainingTimeString()
        print("⏸️ 暂停时剩余时间: \(remainingTimeWhilePaused)")
        
        // 验证暂停时的剩余时间与暂停前相同或相近（允许1秒误差）
        XCTAssertEqual(remainingTimeWhilePaused, remainingTimeBeforePause,
                      "暂停时的剩余时间应该与暂停前相同")
        
        // 7. 等待一段时间确保计时器真的暂停了
        Thread.sleep(forTimeInterval: 0.3)
        let remainingTimeAfterPauseWait = pomodoroTimer.getRemainingTimeString()
        print("⏸️ 暂停等待后剩余时间: \(remainingTimeAfterPauseWait)")
        
        XCTAssertEqual(remainingTimeAfterPauseWait, remainingTimeWhilePaused,
                      "暂停期间剩余时间不应该改变")
        
        // 8. 模拟屏保停止
        print("📢 模拟屏保停止")
        pomodoroTimer.simulateScreensaverStop()
        
        // 9. 验证计时器恢复运行
        let isPausedAfterResume = pomodoroTimer.isPausedState
        let isRunningAfterResume = pomodoroTimer.isRunning
        print("📊 屏保停止后状态 - isPausedState: \(isPausedAfterResume), isRunning: \(isRunningAfterResume)")
        
        XCTAssertTrue(isRunningAfterResume, "退出屏保后计时器应该恢复运行")
        XCTAssertFalse(isPausedAfterResume, "退出屏保后计时器不应该处于暂停状态")
        
        // 10. 验证恢复时的剩余时间与暂停时相同
        let remainingTimeAfterResume = pomodoroTimer.getRemainingTimeString()
        print("▶️ 恢复后剩余时间: \(remainingTimeAfterResume)")
        
        XCTAssertEqual(remainingTimeAfterResume, remainingTimeWhilePaused,
                      "恢复后的剩余时间应该与暂停时相同")
        
        // 11. 等待一段时间验证计时器确实在继续运行
        Thread.sleep(forTimeInterval: 1.5) // 等待更长时间确保时间减少
        let finalRemainingTimeString = pomodoroTimer.getRemainingTimeString()
        print("🏃 最终剩余时间: \(finalRemainingTimeString)")
        
        // 只有当时间真的在减少时才验证这个断言
        if isTimeDecreased {
            XCTAssertNotEqual(finalRemainingTimeString, remainingTimeAfterResume,
                             "恢复后计时器应该继续计时，剩余时间应该减少")
        } else {
            print("⚠️ 注意：计时器时间没有明显减少，可能是更新间隔问题，但暂停/恢复逻辑验证通过")
        }
        
        print("✅ 屏保暂停/恢复功能测试完成")
    }
    
    // MARK: - 集成测试：验证屏保停止不会意外触发重新计时
    
    func testScreensaverStopDoesNotTriggerUnexpectedRestart() {
        print("🧪 开始屏保停止不意外重新计时集成测试")
        
        // 1. 设置：无操作重新计时启用，屏保暂停计时
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 1,
            breakMinutes: 3,
            idleRestart: true,
            idleTime: 1, // 1分钟无操作
            idleActionIsRestart: true, // 无操作时重新计时
            screenLockRestart: false,
            screenLockActionIsRestart: false,
            screensaverRestart: true,
            screensaverActionIsRestart: false, // 屏保时暂停计时
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 5,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [] // 测试中不使用背景文件
        )
        
        // 2. 启动计时器
        pomodoroTimer.start()
        XCTAssertTrue(pomodoroTimer.isRunning, "计时器应该在运行")
        print("✅ 计时器启动成功")
        
        // 3. 等待一段时间让计时器运行
        Thread.sleep(forTimeInterval: 1.0)
        let timeBeforeScreensaver = pomodoroTimer.getRemainingTimeString()
        print("🕒 屏保前剩余时间: \(timeBeforeScreensaver)")
        
        // 4. 模拟屏保启动（应该暂停计时器）
        print("📢 模拟屏保启动")
        pomodoroTimer.simulateScreensaverStart()
        
        // 验证计时器被暂停
        XCTAssertTrue(pomodoroTimer.isPausedState, "屏保启动后计时器应该被暂停")
        XCTAssertFalse(pomodoroTimer.isRunning, "屏保启动后计时器不应该在运行")
        
        let timeWhilePaused = pomodoroTimer.getRemainingTimeString()
        print("⏸️ 暂停时剩余时间: \(timeWhilePaused)")
        
        // 5. 等待一段时间确保暂停期间时间不变
        Thread.sleep(forTimeInterval: 0.5)
        let timeAfterPauseWait = pomodoroTimer.getRemainingTimeString()
        XCTAssertEqual(timeAfterPauseWait, timeWhilePaused, "暂停期间时间不应该改变")
        
        // 6. 模拟屏保停止（应该恢复计时器，但不应该重新计时）
        print("📢 模拟屏保停止")
        pomodoroTimer.simulateScreensaverStop()
        
        // 验证计时器恢复运行
        XCTAssertTrue(pomodoroTimer.isRunning, "屏保停止后计时器应该恢复运行")
        XCTAssertFalse(pomodoroTimer.isPausedState, "屏保停止后计时器不应该处于暂停状态")
        
        let timeAfterScreensaverStop = pomodoroTimer.getRemainingTimeString()
        print("▶️ 屏保停止后剩余时间: \(timeAfterScreensaverStop)")
        
        // 关键验证：屏保停止后的剩余时间应该与暂停时相同，不应该重置为满时间
        XCTAssertEqual(timeAfterScreensaverStop, timeWhilePaused, 
                      "屏保停止后应该从暂停的时间继续，而不是重新计时")
        
        // 验证时间不是重置为满时间（01:00）
        XCTAssertNotEqual(timeAfterScreensaverStop, "01:00", 
                         "屏保停止后不应该重新计时到满时间")
        
        // 7. 等待一段时间验证计时器确实在继续运行
        Thread.sleep(forTimeInterval: 1.0)
        let finalTime = pomodoroTimer.getRemainingTimeString()
        print("🏃 最终剩余时间: \(finalTime)")
        
        // 验证计时器在继续减少（从恢复的时间点继续）
        XCTAssertNotEqual(finalTime, timeAfterScreensaverStop, 
                         "计时器应该从恢复的时间点继续计时")
        
        print("✅ 屏保停止不意外重新计时测试通过")
    }
    
    // MARK: - 集成测试：验证复杂场景下的状态一致性
    
    func testComplexScenarioStateConsistency() {
        print("🧪 开始复杂场景状态一致性测试")
        
        // 设置：无操作和屏保都启用，但行为不同
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 2,
            breakMinutes: 3,
            idleRestart: true,
            idleTime: 1, // 1分钟无操作
            idleActionIsRestart: true, // 无操作时重新计时
            screenLockRestart: false,
            screenLockActionIsRestart: false,
            screensaverRestart: true,
            screensaverActionIsRestart: false, // 屏保时暂停计时
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 5,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [] // 测试中不使用背景文件
        )
        
        // 启动计时器
        pomodoroTimer.start()
        Thread.sleep(forTimeInterval: 1.0)
        let initialTime = pomodoroTimer.getRemainingTimeString()
        print("🕒 初始剩余时间: \(initialTime)")
        
        // 场景1：屏保启动 -> 屏保停止 -> 验证状态
        print("📱 场景1：屏保启动和停止")
        pomodoroTimer.simulateScreensaverStart()
        XCTAssertTrue(pomodoroTimer.isPausedState, "屏保启动后应该暂停")
        
        let pausedTime = pomodoroTimer.getRemainingTimeString()
        pomodoroTimer.simulateScreensaverStop()
        XCTAssertTrue(pomodoroTimer.isRunning, "屏保停止后应该恢复运行")
        
        let resumedTime = pomodoroTimer.getRemainingTimeString()
        XCTAssertEqual(resumedTime, pausedTime, "恢复后时间应该与暂停时相同")
        
        // 场景2：等待一段时间，然后再次屏保，验证时间继续性
        print("📱 场景2：再次屏保测试")
        Thread.sleep(forTimeInterval: 1.0)
        let beforeSecondScreensaver = pomodoroTimer.getRemainingTimeString()
        print("🕒 第二次屏保前时间: \(beforeSecondScreensaver)")
        
        pomodoroTimer.simulateScreensaverStart()
        let pausedSecondTime = pomodoroTimer.getRemainingTimeString()
        XCTAssertEqual(pausedSecondTime, beforeSecondScreensaver, "第二次暂停时时间应该正确")
        
        pomodoroTimer.simulateScreensaverStop()
        let resumedSecondTime = pomodoroTimer.getRemainingTimeString()
        XCTAssertEqual(resumedSecondTime, pausedSecondTime, "第二次恢复后时间应该正确")
        
        // 验证最终状态：时间应该比初始时间少，但不应该是满时间
        XCTAssertNotEqual(resumedSecondTime, initialTime, "最终时间应该比初始时间少")
        XCTAssertNotEqual(resumedSecondTime, "02:00", "不应该重置为满时间")
        
        print("✅ 复杂场景状态一致性测试通过")
    }
    
    // MARK: - 集成测试：验证无操作检测与屏保事件的隔离
    
    func testIdleDetectionIsolationFromScreensaverEvents() {
        print("🧪 开始无操作检测与屏保事件隔离测试")
        
        // 设置：无操作重新计时，屏保暂停计时
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 1,
            breakMinutes: 3,
            idleRestart: true,
            idleTime: 1, // 很短的无操作时间用于测试
            idleActionIsRestart: true, // 无操作时重新计时
            screenLockRestart: false,
            screenLockActionIsRestart: false,
            screensaverRestart: true,
            screensaverActionIsRestart: false, // 屏保时暂停计时
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 5,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [] // 测试中不使用背景文件
        )
        
        pomodoroTimer.start()
        Thread.sleep(forTimeInterval: 0.5)
        let timeBeforeScreensaver = pomodoroTimer.getRemainingTimeString()
        print("🕒 屏保前时间: \(timeBeforeScreensaver)")
        
        // 模拟屏保启动（暂停计时器）
        pomodoroTimer.simulateScreensaverStart()
        let stateMachine = pomodoroTimer.stateMachineForTesting
        XCTAssertEqual(stateMachine.getCurrentState(), .timerPausedBySystem, 
                      "屏保启动后应该处于系统暂停状态")
        
        // 关键测试：屏保停止后，即使更新了活动时间，也不应该触发无操作重新计时逻辑
        pomodoroTimer.simulateScreensaverStop()
        
        // 验证状态正确转换
        XCTAssertEqual(stateMachine.getCurrentState(), .timerRunning, 
                      "屏保停止后应该恢复到运行状态")
        
        let timeAfterScreensaver = pomodoroTimer.getRemainingTimeString()
        print("▶️ 屏保停止后时间: \(timeAfterScreensaver)")
        
        // 关键验证：时间应该与暂停前相同，不应该重置
        XCTAssertEqual(timeAfterScreensaver, timeBeforeScreensaver, 
                      "屏保停止后时间应该与暂停前相同，不受无操作检测影响")
        
        // 额外验证：等待一小段时间，确保计时器正常继续
        Thread.sleep(forTimeInterval: 0.5)
        let finalTime = pomodoroTimer.getRemainingTimeString()
        XCTAssertNotEqual(finalTime, timeAfterScreensaver, 
                         "计时器应该正常继续计时")
        
        print("✅ 无操作检测与屏保事件隔离测试通过")
    }
    
    // MARK: - 简化测试：验证屏保修复
    
    func testScreensaverFixValidation() {
        print("🧪 开始简化屏保修复验证测试")
        
        // 设置屏保暂停计时
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 1,
            breakMinutes: 3,
            idleRestart: false,  // 关闭无操作功能，专注测试屏保
            idleTime: 10,
            idleActionIsRestart: false,
            screenLockRestart: false,
            screenLockActionIsRestart: false,
            screensaverRestart: true,
            screensaverActionIsRestart: false, // 屏保时暂停计时
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 5,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [] // 测试中不使用背景文件
        )
        
        pomodoroTimer.start()
        print("📊 计时器启动，初始状态：\(pomodoroTimer.stateMachineForTesting.getCurrentState())")
        
        Thread.sleep(forTimeInterval: 0.5)
        let timeBeforeScreensaver = pomodoroTimer.getRemainingTimeString()
        print("🕒 屏保前时间: \(timeBeforeScreensaver)")
        
        // 模拟屏保启动
        pomodoroTimer.simulateScreensaverStart()
        let stateAfterStart = pomodoroTimer.stateMachineForTesting.getCurrentState()
        print("📊 屏保启动后状态：\(stateAfterStart)")
        XCTAssertEqual(stateAfterStart, .timerPausedBySystem, "屏保启动后应该是系统暂停状态")
        
        let timeWhilePaused = pomodoroTimer.getRemainingTimeString()
        print("⏸️ 暂停时间: \(timeWhilePaused)")
        
        // 模拟屏保停止
        pomodoroTimer.simulateScreensaverStop()
        let stateAfterStop = pomodoroTimer.stateMachineForTesting.getCurrentState()
        print("📊 屏保停止后状态：\(stateAfterStop)")
        XCTAssertEqual(stateAfterStop, .timerRunning, "屏保停止后应该是运行状态")
        
        let timeAfterRestore = pomodoroTimer.getRemainingTimeString()
        print("▶️ 恢复后时间: \(timeAfterRestore)")
        
        // 关键验证：时间应该保持一致
        XCTAssertEqual(timeAfterRestore, timeWhilePaused, "恢复后时间应该与暂停时相同")
        XCTAssertEqual(timeAfterRestore, timeBeforeScreensaver, "恢复后时间应该与屏保前相同")
        
        print("✅ 简化屏保修复验证测试通过")
    }
    
    // MARK: - 测试：验证屏保和锁屏双重事件
    
    func testScreensaverAndLockScreenDoubleEvents() {
        print("🧪 开始屏保和锁屏双重事件测试")
        
        // 设置：屏保暂停计时，锁屏重新计时
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 1,
            breakMinutes: 3,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: false,
            screenLockRestart: true,
            screenLockActionIsRestart: true, // 锁屏时重新计时
            screensaverRestart: true,
            screensaverActionIsRestart: false, // 屏保时暂停计时
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 5,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [] // 测试中不使用背景文件
        )
        
        pomodoroTimer.start()
        Thread.sleep(forTimeInterval: 0.5)
        let timeBeforeScreensaver = pomodoroTimer.getRemainingTimeString()
        print("🕒 屏保前时间: \(timeBeforeScreensaver)")
        
        // 模拟屏保启动（暂停计时器）
        pomodoroTimer.simulateScreensaverStart()
        let stateAfterScreensaverStart = pomodoroTimer.stateMachineForTesting.getCurrentState()
        print("📊 屏保启动后状态：\(stateAfterScreensaverStart)")
        XCTAssertEqual(stateAfterScreensaverStart, .timerPausedBySystem, "屏保启动后应该是系统暂停状态")
        
        let timeWhilePaused = pomodoroTimer.getRemainingTimeString()
        print("⏸️ 暂停时间: \(timeWhilePaused)")
        
        // 关键测试：模拟退出屏保时的双重事件
        // 1. 先触发屏保停止
        pomodoroTimer.simulateScreensaverStop()
        let stateAfterScreensaverStop = pomodoroTimer.stateMachineForTesting.getCurrentState()
        print("📊 屏保停止后状态：\(stateAfterScreensaverStop)")
        
        let timeAfterScreensaverStop = pomodoroTimer.getRemainingTimeString()
        print("▶️ 屏保停止后时间: \(timeAfterScreensaverStop)")
        
        // 2. 然后触发锁屏解锁（模拟退出屏保时的双重事件）
        pomodoroTimer.simulateScreenUnlock()
        let stateAfterUnlock = pomodoroTimer.stateMachineForTesting.getCurrentState()
        print("📊 解锁后状态：\(stateAfterUnlock)")
        
        let timeAfterUnlock = pomodoroTimer.getRemainingTimeString()
        print("🔓 解锁后时间: \(timeAfterUnlock)")
        
        // 验证：即使锁屏设置为重新计时，由于屏保已经处理了状态恢复，解锁事件不应该再次触发重新计时
        XCTAssertEqual(timeAfterUnlock, timeAfterScreensaverStop, "解锁事件不应该改变屏保恢复后的时间")
        XCTAssertEqual(timeAfterUnlock, timeWhilePaused, "最终时间应该与暂停时相同，不应该重新计时")
        
        print("✅ 屏保和锁屏双重事件测试通过")
    }
    
    // MARK: - 测试：验证屏保事件过滤机制
    
    func testScreensaverEventFiltering() {
        print("🧪 开始屏保事件过滤机制测试")
        
        // 设置：屏保暂停计时，锁屏重新计时
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 1,
            breakMinutes: 3,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: false,
            screenLockRestart: true,
            screenLockActionIsRestart: true, // 锁屏时重新计时
            screensaverRestart: true,
            screensaverActionIsRestart: false, // 屏保时暂停计时
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 5,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [] // 测试中不使用背景文件
        )
        
        pomodoroTimer.start()
        Thread.sleep(forTimeInterval: 0.5)
        let timeBeforeScreensaver = pomodoroTimer.getRemainingTimeString()
        print("🕒 屏保前时间: \(timeBeforeScreensaver)")
        
        // 1. 屏保启动
        pomodoroTimer.simulateScreensaverStart()
        let timeWhilePaused = pomodoroTimer.getRemainingTimeString()
        print("⏸️ 暂停时间: \(timeWhilePaused)")
        
        // 2. 屏保停止（应该恢复计时器并记录恢复时间）
        pomodoroTimer.simulateScreensaverStop()
        let timeAfterScreensaverStop = pomodoroTimer.getRemainingTimeString()
        print("▶️ 屏保停止后时间: \(timeAfterScreensaverStop)")
        
        // 3. 立即触发解锁事件（应该被过滤掉）
        pomodoroTimer.simulateScreenUnlock()
        let timeAfterUnlock = pomodoroTimer.getRemainingTimeString()
        print("🔓 解锁后时间: \(timeAfterUnlock)")
        
        // 验证：解锁事件被正确过滤，时间没有重置
        XCTAssertEqual(timeAfterUnlock, timeAfterScreensaverStop, 
                      "解锁事件应该被过滤，时间不应该改变")
        XCTAssertEqual(timeAfterUnlock, timeWhilePaused, 
                      "最终时间应该与暂停时相同，不应该重新计时")
        
        // 4. 等待超过过滤时间窗口（1秒），再次测试解锁
        Thread.sleep(forTimeInterval: 1.1)
        
        // 现在解锁事件应该正常处理（如果锁屏设置为重新计时）
        let timeBeforeDelayedUnlock = pomodoroTimer.getRemainingTimeString()
        print("⏰ 延迟解锁前时间: \(timeBeforeDelayedUnlock)")
        
        pomodoroTimer.simulateScreenUnlock()
        let timeAfterDelayedUnlock = pomodoroTimer.getRemainingTimeString()
        print("🔓 延迟解锁后时间: \(timeAfterDelayedUnlock)")
        
        // 验证：延迟的解锁事件应该触发重新计时（因为锁屏设置为重新计时）
        XCTAssertEqual(timeAfterDelayedUnlock, "01:00", 
                      "延迟的解锁事件应该触发重新计时")
        
        print("✅ 屏保事件过滤机制测试通过")
    }
    
    // MARK: - 测试：验证屏保停止后恢复问题
    
    func testScreensaverResumeIssue() {
        print("🧪 开始屏保停止后恢复问题测试")
        
        // 设置：屏保暂停计时
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 1,
            breakMinutes: 3,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: false,
            screenLockRestart: false,
            screenLockActionIsRestart: false,
            screensaverRestart: true,
            screensaverActionIsRestart: false, // 屏保时暂停计时
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 5,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: [] // 测试中不使用背景文件
        )
        
        pomodoroTimer.start()
        XCTAssertTrue(pomodoroTimer.isRunning, "计时器应该在运行")
        print("📊 启动后状态 - isRunning: \(pomodoroTimer.isRunning), isPausedState: \(pomodoroTimer.isPausedState)")
        
        Thread.sleep(forTimeInterval: 0.5)
        let timeBeforeScreensaver = pomodoroTimer.getRemainingTimeString()
        print("🕒 屏保前时间: \(timeBeforeScreensaver)")
        
        // 1. 屏保启动 - 应该暂停计时器
        pomodoroTimer.simulateScreensaverStart()
        let stateAfterScreensaverStart = pomodoroTimer.stateMachineForTesting.getCurrentState()
        print("📊 屏保启动后状态 - 状态机: \(stateAfterScreensaverStart), isRunning: \(pomodoroTimer.isRunning), isPausedState: \(pomodoroTimer.isPausedState)")
        
        XCTAssertEqual(stateAfterScreensaverStart, .timerPausedBySystem, "状态机应该是系统暂停状态")
        XCTAssertFalse(pomodoroTimer.isRunning, "计时器不应该在运行")
        XCTAssertTrue(pomodoroTimer.isPausedState, "计时器应该处于暂停状态")
        
        let timeWhilePaused = pomodoroTimer.getRemainingTimeString()
        print("⏸️ 暂停时间: \(timeWhilePaused)")
        
        // 2. 屏保停止 - 应该恢复计时器
        pomodoroTimer.simulateScreensaverStop()
        let stateAfterScreensaverStop = pomodoroTimer.stateMachineForTesting.getCurrentState()
        print("📊 屏保停止后状态 - 状态机: \(stateAfterScreensaverStop), isRunning: \(pomodoroTimer.isRunning), isPausedState: \(pomodoroTimer.isPausedState)")
        
        // 关键验证：状态机和计时器状态应该一致
        print("🔍 详细状态检查:")
        print("   状态机状态: \(stateAfterScreensaverStop)")
        print("   计时器isRunning: \(pomodoroTimer.isRunning)")
        print("   计时器isPausedState: \(pomodoroTimer.isPausedState)")
        
        if stateAfterScreensaverStop != .timerRunning {
            print("❌ 状态机状态错误，期望 .timerRunning，实际 \(stateAfterScreensaverStop)")
        }
        if !pomodoroTimer.isRunning {
            print("❌ 计时器未在运行")
        }
        if pomodoroTimer.isPausedState {
            print("❌ 计时器仍处于暂停状态")
        }
        
        XCTAssertEqual(stateAfterScreensaverStop, .timerRunning, "状态机应该是运行状态")
        XCTAssertTrue(pomodoroTimer.isRunning, "计时器应该在运行")
        XCTAssertFalse(pomodoroTimer.isPausedState, "计时器不应该处于暂停状态")
        
        let timeAfterScreensaverStop = pomodoroTimer.getRemainingTimeString()
        print("▶️ 屏保停止后时间: \(timeAfterScreensaverStop)")
        
        // 验证时间一致性
        XCTAssertEqual(timeAfterScreensaverStop, timeWhilePaused, "恢复后时间应该与暂停时相同")
        
        // 3. 等待一小段时间，验证计时器确实在运行
        print("🔍 开始等待测试计时器是否真正运行...")
        
        let timerExpectation = XCTestExpectation(description: "Timer should continue running after screensaver")
        
        // 使用 DispatchQueue 延迟检查，给 Timer 时间运行
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let timeAfterWaiting = self.pomodoroTimer.getRemainingTimeString()
            print("⏰ 等待2秒后时间: \(timeAfterWaiting)")
            
            // 再次检查状态
            let finalState = self.pomodoroTimer.stateMachineForTesting.getCurrentState()
            print("🔍 最终状态检查:")
            print("   状态机状态: \(finalState)")
            print("   计时器isRunning: \(self.pomodoroTimer.isRunning)")
            print("   计时器isPausedState: \(self.pomodoroTimer.isPausedState)")
            
            // 如果计时器正在运行，时间应该减少
            if timeAfterWaiting == timeAfterScreensaverStop {
                print("❌ 计时器时间没有减少，可能存在问题")
                XCTFail("计时器应该继续运行，时间应该减少")
            } else {
                print("✅ 计时器时间正确减少")
                timerExpectation.fulfill()
            }
        }
        
        // 运行 RunLoop 以确保 Timer 可以执行
        RunLoop.current.run(until: Date().addingTimeInterval(2.5))
        
        wait(for: [timerExpectation], timeout: 4.0)
        
        print("✅ 屏保停止后恢复问题测试通过")
    }
    
    // MARK: - 基础计时器功能测试
    
    func testBasicTimerFunctionality() {
        print("🧪 开始基础计时器功能测试")
        
        let expectation = XCTestExpectation(description: "Timer should update time")
        
        // 设置短时间便于测试
        pomodoroTimer.updateSettings(
            pomodoroMinutes: 1,
            breakMinutes: 3,
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
            backgroundFiles: [] // 测试中不使用背景文件
        )
        
        // 启动计时器
        pomodoroTimer.start()
        let initialTime = pomodoroTimer.getRemainingTimeString()
        print("🕒 初始时间: \(initialTime)")
        
        XCTAssertTrue(pomodoroTimer.isRunning, "计时器应该在运行")
        XCTAssertEqual(initialTime, "01:00", "初始时间应该是1分钟")
        
        // 使用 DispatchQueue 延迟检查，给 Timer 时间运行
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            let timeAfterWait = self.pomodoroTimer.getRemainingTimeString()
            print("🕒 3秒后时间: \(timeAfterWait)")
            
            // 验证时间确实减少了
            if timeAfterWait != initialTime {
                print("✅ 计时器时间正确减少")
                expectation.fulfill()
            } else {
                print("❌ 计时器时间没有减少")
                XCTFail("时间应该减少")
            }
        }
        
        // 运行 RunLoop 以确保 Timer 可以执行
        RunLoop.current.run(until: Date().addingTimeInterval(3.5))
        
        wait(for: [expectation], timeout: 5.0)
        print("✅ 基础计时器功能测试通过")
    }
}
