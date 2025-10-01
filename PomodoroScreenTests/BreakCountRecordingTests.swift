import XCTest
@testable import PomodoroScreen

/// 验证：番茄钟完成后展示 overlay 时，会正确触发 startBreak 并记录短/长休息开始；
/// 同时本周趋势的当日休息次数应 > 0。
/// 作者: AI Assistant  创建: 2025-10-01
final class BreakCountRecordingTests: XCTestCase {
    var appDelegate: AppDelegate!

    override func setUp() {
        super.setUp()
        appDelegate = AppDelegate()
        appDelegate.applicationDidFinishLaunching(Notification(name: Notification.Name(rawValue: "test")))
    }

    override func tearDown() {
        appDelegate = nil
        super.tearDown()
    }

    func testBreakCountsRecorded() {
        let exp = expectation(description: "break counts should be recorded")

        // 触发一次番茄钟完成 -> AppDelegate 回调里会 showOverlay()
        appDelegate.triggerPomodoroFinishForTesting()
        // 再显式调用一次，确保覆盖触发路径
        appDelegate.showOverlayForTesting()

        // 等待主线程异步路径与数据库写入完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let todayStats = StatisticsManager.shared.getTodayStatistics()
            XCTAssertGreaterThanOrEqual(todayStats.shortBreakCount + todayStats.longBreakCount, 1, "今日应记录至少一次休息开始")

            // 验证周趋势的当日数据
            let weekly = StatisticsManager.shared.getThisWeekStatistics()
            guard let last = weekly.dailyStats.last else {
                XCTFail("缺少本周每日统计数据")
                return
            }
            XCTAssertGreaterThanOrEqual(last.shortBreakCount + last.longBreakCount, 1, "周趋势当日休息次数应 ≥ 1")

            exp.fulfill()
        }

        waitForExpectations(timeout: 3.0)
    }
}


