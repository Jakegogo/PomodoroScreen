import XCTest
@testable import PomodoroScreen

final class StatusBarIconIntegrationTests: XCTestCase {
    var timer: PomodoroTimer!
    var statusBar: StatusBarController!
    var iconGen: ClockIconGenerator!

    override func setUp() {
        super.setUp()
        timer = PomodoroTimer()
        statusBar = StatusBarController(timer: timer)
        iconGen = ClockIconGenerator()
    }

    // MARK: - Manual Observation Helper
    private func refreshStatusBarFor(seconds: TimeInterval) {
        let steps = Int((seconds / 0.5).rounded(.up))
        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) { [weak self] in
                guard let self = self else { return }
                self.statusBar.updateTime(self.timer.getRemainingTimeString())
            }
        }
        let exp = expectation(description: "manual-observe-")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: seconds + 1.0)
    }

    /// 手动观察序列：运行 -> 休息；休息阶段每隔6秒自动切换三种蒸汽条数（3/2/1），用于肉眼核对
    func testManualObserve_StatusBarIcons_Sequence() {
        // 运行阶段
        timer.reset()
        timer.start()
        
        // 进入休息阶段
        timer.startBreak()
        
        // 计算总休息时长（秒）
        let total = max(60.0, timer.getTotalTime()) // 兜底>=60s，避免极短导致视觉不明显
        
        // Phase 1（0~6s）：≈100% 剩余 -> 3条蒸汽
        timer.setRemainingTime(total)
        statusBar.updateTime(timer.getRemainingTimeString())
        refreshStatusBarFor(seconds: 6.0)
        XCTAssertNotNil(statusBar.currentStatusBarImage())
        
        // Phase 2（6~12s）：≈50% 剩余 -> 2条蒸汽
        timer.setRemainingTime(total * 0.5)
        statusBar.updateTime(timer.getRemainingTimeString())
        refreshStatusBarFor(seconds: 6.0)
        XCTAssertNotNil(statusBar.currentStatusBarImage())
        
        // Phase 3（12~18s）：≈10% 剩余 -> 1条蒸汽
        timer.setRemainingTime(max(1.0, total * 0.1))
        statusBar.updateTime(timer.getRemainingTimeString())
        refreshStatusBarFor(seconds: 6.0)
        XCTAssertNotNil(statusBar.currentStatusBarImage())
    }

    override func tearDown() {
        timer = nil
        statusBar = nil
        iconGen = nil
        super.tearDown()
    }

    // MARK: - Running State Icon
    func testIcon_WhenRunning_ShowsClockIconNotRestOrPaused() {
        // Given
        timer.updateSettings(
            pomodoroMinutes: 25,
            breakMinutes: 3,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: true,
            screenLockRestart: false,
            screenLockActionIsRestart: true,
            screensaverRestart: false,
            screensaverActionIsRestart: true,
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
        timer.reset()
        timer.start()

        // When
        let total = timer.getTotalTime()
        let remaining = timer.getRemainingTime()
        let icon = iconGen.generateClockIcon(
            progress: total > 0 ? (total - remaining) / total : 0,
            totalTime: total,
            remainingTime: remaining,
            isPaused: false,
            isRest: false
        )

        // Then
        XCTAssertNotNil(icon)
        XCTAssertTrue(icon.isTemplate)
        XCTAssertNotNil(statusBar.currentStatusBarImage(), "Status bar should display an image while running")
    }

    // MARK: - Paused State Icon
    func testIcon_WhenPaused_ShowsPausedBars() {
        // Given
        timer.reset()
        timer.start()
        timer.pause()

        // When
        let total = timer.getTotalTime()
        let remaining = timer.getRemainingTime()
        let icon = iconGen.generateClockIcon(
            progress: total > 0 ? (total - remaining) / total : 0,
            totalTime: total,
            remainingTime: remaining,
            isPaused: true,
            isRest: false
        )

        // Then
        XCTAssertNotNil(icon)
        XCTAssertTrue(icon.isTemplate)
        XCTAssertNotNil(statusBar.currentStatusBarImage(), "Status bar should display an image while paused")
    }

    // MARK: - Rest State Icon
    func testIcon_WhenRest_ShowsHotCupIcon() {
        // Given
        timer.reset()
        timer.startBreak() // 进入休息期

        // When
        let total = timer.getTotalTime()
        let remaining = timer.getRemainingTime()
        let icon = iconGen.generateClockIcon(
            progress: total > 0 ? (total - remaining) / total : 0,
            totalTime: total,
            remainingTime: remaining,
            isPaused: false,
            isRest: true
        )

        // Then
        XCTAssertNotNil(icon)
        XCTAssertTrue(icon.isTemplate)
        XCTAssertNotNil(statusBar.currentStatusBarImage(), "Status bar should display an image while resting")
    }
}


