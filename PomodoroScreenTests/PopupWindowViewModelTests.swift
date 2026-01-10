//
//  PopupWindowViewModelTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2026-01-10.
//

import XCTest
@testable import PomodoroScreen

final class PopupWindowViewModelTests: XCTestCase {
    func testDiff_FirstShow_AllChanged() {
        let vm = PopupWindowViewModel()
        let snapshot = PopupWindowSnapshot(
            ringProgress: [0.1, 0.2, 0.3, 0.4],
            completedPomodoros: 1,
            totalWorkTime: 60,
            totalBreakTime: 120,
            healthScore: 80
        )
        
        let diff = vm.diffAndStoreForShow(current: snapshot)
        XCTAssertEqual(diff.metricChanged, [true, true, true, true])
        XCTAssertEqual(diff.ringChanged.prefix(4), [true, true, true, true])
    }
    
    func testDiff_SecondShow_OnlyChangedItemsTrue() {
        let vm = PopupWindowViewModel()
        _ = vm.diffAndStoreForShow(current: PopupWindowSnapshot(
            ringProgress: [0.1, 0.2, 0.3, 0.4],
            completedPomodoros: 1,
            totalWorkTime: 60,
            totalBreakTime: 120,
            healthScore: 80
        ))
        
        let diff = vm.diffAndStoreForShow(current: PopupWindowSnapshot(
            ringProgress: [0.1, 0.25, 0.3, 0.4],
            completedPomodoros: 2,
            totalWorkTime: 60,
            totalBreakTime: 180,
            healthScore: 80
        ))
        
        XCTAssertEqual(diff.metricChanged, [true, false, true, false])
        XCTAssertEqual(diff.ringChanged.prefix(4), [false, true, false, false])
    }
}

