//
//  StatusBarPopupWindowBottomMetricsTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2026-01-10.
//

import XCTest
@testable import PomodoroScreen

final class StatusBarPopupWindowBottomMetricsTests: XCTestCase {
    func testBottomMetricLabels_AreUpdatedToRequestedFourItems() {
        let labels = StatusBarPopupWindow.bottomMetricItems.map { $0.0 }
        XCTAssertEqual(labels, ["完成番茄钟", "工作时间", "休息时间", "健康评分"])
    }

    func testBottomMetricFormatting_DurationCountScore() {
        XCTAssertEqual(StatusBarPopupWindow.formatDurationChinese(10 * 3600 + 50 * 60), "10小时50分钟")
        XCTAssertEqual(StatusBarPopupWindow.formatDurationChinese(50 * 60), "50分钟")
        
        XCTAssertEqual(StatusBarPopupWindow.formatPomodoroCount(26), "26 个")
        XCTAssertEqual(StatusBarPopupWindow.formatScore(6), "6分")
    }
}

