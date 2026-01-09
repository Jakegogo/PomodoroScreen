//
//  OverlayMessageTemplateRendererTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2026-01-09.
//

import XCTest
@testable import PomodoroScreen

final class OverlayMessageTemplateRendererTests: XCTestCase {
    func testRenderRestMessage_UsesDefault_WhenTemplateEmpty() {
        let result = OverlayMessageTemplateRenderer.renderRestMessage(
            template: "   \n",
            breakType: "休息",
            breakMinutes: 18
        )

        XCTAssertTrue(result.contains("休息"), "应包含 breakType")
        XCTAssertTrue(result.contains("18"), "应包含 breakMinutes")
    }

    func testRenderRestMessage_ReplacesPlaceholders() {
        let template = "A{breakType}B{breakMinutes}C"
        let result = OverlayMessageTemplateRenderer.renderRestMessage(
            template: template,
            breakType: "长休息",
            breakMinutes: 6
        )

        XCTAssertEqual(result, "A长休息B6C")
    }

    func testRenderStayUpMessage_UsesDefault_WhenTemplateEmpty() {
        let result = OverlayMessageTemplateRenderer.renderStayUpMessage(template: "  \n")
        XCTAssertTrue(result.contains("熬夜时间到了"), "空模板应回退到默认熬夜文案")
    }

    func testRenderStayUpMessage_UsesCustomTemplate() {
        let result = OverlayMessageTemplateRenderer.renderStayUpMessage(template: "自定义熬夜提示")
        XCTAssertEqual(result, "自定义熬夜提示")
    }
}

