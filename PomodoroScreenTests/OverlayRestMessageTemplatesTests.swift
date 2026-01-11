//
//  OverlayRestMessageTemplatesTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2026-01-10.
//

import XCTest
@testable import PomodoroScreen

final class OverlayRestMessageTemplatesTests: XCTestCase {
    private let templatesKey = "OverlayRestMessageTemplates"
    private let rotationIndexKey = "OverlayRestMessageTemplateRotationIndex"
    private let legacyTemplateKey = "OverlayRestMessageTemplate"
    
    override func setUp() {
        super.setUp()
        clearUserDefaults()
    }
    
    override func tearDown() {
        clearUserDefaults()
        super.tearDown()
    }
    
    func testOverlayRestMessageTemplates_DefaultWhenNoStoredValues() {
        let templates = SettingsStore.overlayRestMessageTemplates
        XCTAssertFalse(templates.isEmpty, "默认应至少有一条文案")
        XCTAssertTrue(templates.first?.contains("{breakType}") == true, "默认文案应包含占位符")
    }
    
    func testOverlayRestMessageTemplates_MigratesFromLegacySingleTemplate() {
        UserDefaults.standard.set("旧文案", forKey: legacyTemplateKey)
        
        let templates = SettingsStore.overlayRestMessageTemplates
        XCTAssertEqual(templates, ["旧文案"])
    }
    
    func testNextOverlayRestMessageTemplate_RotatesRoundRobin() {
        SettingsStore.overlayRestMessageTemplates = ["A", "B", "C"]
        UserDefaults.standard.set(0, forKey: rotationIndexKey)
        
        XCTAssertEqual(SettingsStore.nextOverlayRestMessageTemplate(), "A")
        XCTAssertEqual(SettingsStore.nextOverlayRestMessageTemplate(), "B")
        XCTAssertEqual(SettingsStore.nextOverlayRestMessageTemplate(), "C")
        XCTAssertEqual(SettingsStore.nextOverlayRestMessageTemplate(), "A")
    }
    
    func testOverlayRestMessageTemplates_NormalizesEmptyAndKeepsAtLeastOne() {
        SettingsStore.overlayRestMessageTemplates = ["   ", "\n", "X"]
        XCTAssertEqual(SettingsStore.overlayRestMessageTemplates, ["X"])
        XCTAssertEqual(UserDefaults.standard.string(forKey: legacyTemplateKey), "X", "应同步 legacy key 为第一条")
    }
    
    private func clearUserDefaults() {
        UserDefaults.standard.removeObject(forKey: templatesKey)
        UserDefaults.standard.removeObject(forKey: rotationIndexKey)
        UserDefaults.standard.removeObject(forKey: legacyTemplateKey)
    }
}

