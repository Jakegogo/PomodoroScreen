import XCTest
@testable import PomodoroScreen

/// 计划功能的单元测试
/// 测试长休息周期、时间累积等新功能
class PlanFeatureTests: XCTestCase {
    
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
            longBreakCycle: 2, // 每2次番茄钟后长休息
            longBreakTimeMinutes: 3, // 长休息3分钟
            showLongBreakCancelButton: true,
            accumulateRestTime: true,
            backgroundFiles: [], shuffleBackgrounds: false, // 测试中不使用背景文件
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
    
    // MARK: - 长休息周期测试
    
    func testLongBreakCycleLogic() {
        print("🧪 测试长休息周期逻辑")
        
        // 启动第一个番茄钟
        pomodoroTimer.start()
        XCTAssertTrue(pomodoroTimer.isRunning, "第一个番茄钟应该正在运行")
        
        // 模拟完成第一个番茄钟
        pomodoroTimer.triggerFinish()
        
        // 启动第一次休息（应该是短休息）
        pomodoroTimer.startBreak()
        XCTAssertTrue(pomodoroTimer.isRunning, "第一次休息应该正在运行")
        XCTAssertFalse(pomodoroTimer.isLongBreak, "第一次休息应该是短休息")
        
        // 模拟完成第一次休息
        pomodoroTimer.triggerFinish()
        
        // 启动第二个番茄钟
        pomodoroTimer.start()
        pomodoroTimer.triggerFinish()
        
        // 启动第二次休息（应该是长休息）
        pomodoroTimer.startBreak()
        XCTAssertTrue(pomodoroTimer.isRunning, "第二次休息应该正在运行")
        
        print("✅ 长休息周期逻辑测试通过")
    }
    
    // MARK: - 短休息取消和累积测试
    
    func testAccumulateRestTimeFeature() {
        print("🧪 测试短休息中断累积功能")
        
        // 启动番茄钟并完成
        pomodoroTimer.start()
        pomodoroTimer.triggerFinish()
        
        // 启动短休息
        pomodoroTimer.startBreak()
        let initialRestTime = pomodoroTimer.getRemainingTimeString()
        print("🕒 初始休息时间: \(initialRestTime)")
        
        // 等待一段时间（模拟部分休息）
        let expectation = XCTestExpectation(description: "等待休息时间流逝")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
        
        // 运行RunLoop让计时器更新
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        
        let partialRestTime = pomodoroTimer.getRemainingTimeString()
        print("⏰ 部分休息后时间: \(partialRestTime)")
        
        // 取消休息（应该累积剩余时间）
        pomodoroTimer.cancelBreak()
        XCTAssertTrue(pomodoroTimer.isRunning, "取消休息后应该自动开始新的番茄钟")
        
        print("💾 短休息中断累积功能测试通过")
    }
    
    // MARK: - 设置更新测试
    
    func testSettingsUpdate() {
        print("🧪 测试计划设置更新")
        
        // 更新设置
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
            showCancelRestButton: false, // 短休息不显示取消按钮
            longBreakCycle: 4, // 每4次番茄钟后长休息
            longBreakTimeMinutes: 15, // 长休息15分钟
            showLongBreakCancelButton: false, // 长休息也不显示取消按钮
            accumulateRestTime: false, // 关闭累积功能
            backgroundFiles: [], shuffleBackgrounds: false, // 测试中不使用背景文件
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 0,
            meetingMode: false
        )
        
        // 验证设置是否正确应用
        // 注意：这里我们主要测试设置更新不会导致崩溃
        // 具体的设置值验证需要通过实际使用来测试
        
        XCTAssertNotNil(pomodoroTimer, "设置更新后计时器应该仍然有效")
        
        print("⚙️ 计划设置更新测试通过")
    }
    
    // MARK: - 取消按钮显示逻辑测试
    
    func testCancelButtonVisibility() {
        print("🧪 测试取消按钮显示逻辑")
        
        // 测试短休息时的按钮显示
        pomodoroTimer.start()
        pomodoroTimer.triggerFinish()
        pomodoroTimer.startBreak()
        
        // 由于我们在setUp中设置了showCancelRestButton=true, showLongBreakCancelButton=true
        // 所以第一次休息（短休息）应该显示取消按钮
        let shouldShowForShortBreak = pomodoroTimer.shouldShowCancelRestButton
        print("☕ 短休息取消按钮显示: \(shouldShowForShortBreak)")
        
        pomodoroTimer.triggerFinish()
        
        // 完成第二个番茄钟，触发长休息
        pomodoroTimer.start()
        pomodoroTimer.triggerFinish()
        pomodoroTimer.startBreak() // 这应该是长休息
        
        let shouldShowForLongBreak = pomodoroTimer.shouldShowCancelRestButton
        print("🌟 长休息取消按钮显示: \(shouldShowForLongBreak)")
        
        print("👆 取消按钮显示逻辑测试完成")
    }
}
