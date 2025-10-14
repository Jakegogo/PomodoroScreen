//
//  ReportConfigurationTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2025-10-13.
//

import XCTest
@testable import PomodoroScreen

final class ReportConfigurationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure default known state for relevant settings
        SettingsStore.stayUpLimitEnabled = false
        SettingsStore.stayUpLimitHour = 23
        SettingsStore.stayUpLimitMinute = 30
    }

    override func tearDown() {
        // Reset any changes we made to not affect other tests
        SettingsStore.stayUpLimitEnabled = false
        super.tearDown()
    }

    func testReportConfigurationPropagatesStayUpSettings() {
        // Given: enable stay-up with a custom start time
        SettingsStore.stayUpLimitEnabled = true
        SettingsStore.stayUpLimitHour = 22
        SettingsStore.stayUpLimitMinute = 15

        let manager = StatisticsManager()

        // When: generating today report
        let report = manager.generateTodayReport()

        // Then: configuration contains stay-up window fields
        XCTAssertTrue(report.configuration.stayUpLimitEnabled)
        XCTAssertEqual(report.configuration.stayUpStartHour, 22)
        XCTAssertEqual(report.configuration.stayUpStartMinute, 15)

        // End time should follow StayUpConstants
        XCTAssertEqual(report.configuration.stayUpEndHour, StayUpConstants.endHour)
        XCTAssertEqual(report.configuration.stayUpEndMinute, StayUpConstants.endMinute)
    }
}



