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
}

