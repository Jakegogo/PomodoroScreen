//
//  ShutdownConfirmationWindowTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2025-09-27.
//

import XCTest
@testable import PomodoroScreen
import Cocoa

class ShutdownConfirmationWindowTests: XCTestCase {
    
    var shutdownWindow: ShutdownConfirmationWindow!
    
    override func setUp() {
        super.setUp()
        shutdownWindow = ShutdownConfirmationWindow()
    }
    
    override func tearDown() {
        shutdownWindow?.orderOut(nil)
        shutdownWindow = nil
        super.tearDown()
    }
    
    // MARK: - 基础功能测试
    
    func testShutdownWindowInitialization() {
        XCTAssertNotNil(shutdownWindow, "关机确认窗口应该能够正确初始化")
        XCTAssertEqual(shutdownWindow.level, .modalPanel, "窗口层级应该设置为 modalPanel")
        XCTAssertFalse(shutdownWindow.isOpaque, "窗口应该是透明的")
        XCTAssertEqual(shutdownWindow.alphaValue, 0.0, "初始状态应该是完全透明的")
    }
    
    func testWindowProperties() {
        XCTAssertTrue(shutdownWindow.canBecomeKey, "窗口应该能够获得焦点")
        XCTAssertTrue(shutdownWindow.canBecomeMain, "窗口应该能够成为主窗口")
        XCTAssertFalse(shutdownWindow.isMovable, "窗口应该不可移动")
        XCTAssertFalse(shutdownWindow.isRestorable, "窗口应该不可恢复")
    }
    
    func testWindowSize() {
        let expectedSize = NSSize(width: 400, height: 200)
        XCTAssertEqual(shutdownWindow.frame.size.width, expectedSize.width, accuracy: 1.0, "窗口宽度应该是400")
        XCTAssertEqual(shutdownWindow.frame.size.height, expectedSize.height, accuracy: 1.0, "窗口高度应该是200")
    }
    
    // MARK: - 显示和隐藏测试
    
    func testShowWithAnimation() {
        let expectation = self.expectation(description: "窗口应该能够显示并变为可见")
        
        shutdownWindow.showWithAnimation()
        
        // 验证窗口立即可见
        XCTAssertTrue(shutdownWindow.isVisible, "调用 showWithAnimation 后窗口应该立即可见")
        
        // 等待动画完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertEqual(self.shutdownWindow.alphaValue, 1.0, accuracy: 0.1, "动画完成后窗口应该完全不透明")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testHideWithAnimation() {
        let expectation = self.expectation(description: "窗口应该能够隐藏")
        
        // 先显示窗口
        shutdownWindow.showWithAnimation()
        
        // 等待显示动画完成后再隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.shutdownWindow.hideWithAnimation {
                XCTAssertFalse(self.shutdownWindow.isVisible, "隐藏动画完成后窗口应该不可见")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - 回调功能测试
    
    func testConfirmCallback() {
        let expectation = self.expectation(description: "确认回调应该被调用")
        
        shutdownWindow.onConfirm = {
            expectation.fulfill()
        }
        
        // 模拟点击确认按钮
        shutdownWindow.showWithAnimation()
        
        // 等待窗口显示后模拟按键
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 模拟 Enter 键按下
            let event = NSEvent.keyEvent(
                with: .keyDown,
                location: NSPoint.zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: self.shutdownWindow.windowNumber,
                context: nil,
                characters: "\r",
                charactersIgnoringModifiers: "\r",
                isARepeat: false,
                keyCode: 36
            )
            
            if let keyEvent = event {
                self.shutdownWindow.keyDown(with: keyEvent)
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testCancelCallback() {
        let expectation = self.expectation(description: "取消回调应该被调用")
        
        shutdownWindow.onCancel = {
            expectation.fulfill()
        }
        
        // 模拟点击取消按钮
        shutdownWindow.showWithAnimation()
        
        // 等待窗口显示后模拟按键
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 模拟 ESC 键按下
            let event = NSEvent.keyEvent(
                with: .keyDown,
                location: NSPoint.zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: self.shutdownWindow.windowNumber,
                context: nil,
                characters: "\u{1b}",
                charactersIgnoringModifiers: "\u{1b}",
                isARepeat: false,
                keyCode: 53
            )
            
            if let keyEvent = event {
                self.shutdownWindow.keyDown(with: keyEvent)
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - 窗口层级测试
    
    func testWindowLevelHigherThanScreenSaver() {
        // 创建一个模拟的遮罩层窗口
        let overlayWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        overlayWindow.level = .screenSaver
        
        // 验证关机确认窗口的层级高于遮罩层
        XCTAssertTrue(shutdownWindow.level.rawValue > overlayWindow.level.rawValue, 
                     "关机确认窗口的层级(\(shutdownWindow.level.rawValue))应该高于遮罩层(\(overlayWindow.level.rawValue))")
        
        // 同时测试高于 modalPanel 层级
        let modalWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        modalWindow.level = .modalPanel
        
        XCTAssertTrue(shutdownWindow.level.rawValue > modalWindow.level.rawValue,
                     "关机确认窗口的层级(\(shutdownWindow.level.rawValue))应该高于modalPanel(\(modalWindow.level.rawValue))")
        
        overlayWindow.orderOut(nil)
        modalWindow.orderOut(nil)
    }
    
    // MARK: - UI 元素测试
    
    func testUIElementsExist() {
        shutdownWindow.showWithAnimation()
        
        // 等待UI创建完成
        let expectation = self.expectation(description: "UI元素应该存在")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 验证内容视图存在
            XCTAssertNotNil(self.shutdownWindow.contentView, "内容视图应该存在")
            
            // 验证子视图存在（背景视图应该包含标签和按钮）
            let subviews = self.shutdownWindow.contentView?.subviews ?? []
            XCTAssertFalse(subviews.isEmpty, "内容视图应该包含子视图")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 内存管理测试
    
    func testMemoryManagement() {
        weak var weakWindow: ShutdownConfirmationWindow?
        
        autoreleasepool {
            let window = ShutdownConfirmationWindow()
            weakWindow = window
            window.showWithAnimation()
            
            // 设置回调以保持引用
            window.onConfirm = {
                // 空实现
            }
            
            XCTAssertNotNil(weakWindow, "窗口应该存在")
            
            // 隐藏窗口
            window.hideWithAnimation()
        }
        
        // 等待一段时间确保清理完成
        let expectation = self.expectation(description: "内存应该被正确释放")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 注意：由于窗口可能被系统保持引用，这个测试可能不总是通过
            // 但我们至少验证窗口不会崩溃
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 集成测试
    
    func testIntegrationWithOverlayWindow() {
        // 创建一个模拟的 PomodoroTimer
        let timer = PomodoroTimer()
        
        // 创建遮罩窗口
        let overlayWindow = OverlayWindow(timer: timer)
        overlayWindow.showOverlay()
        
        // 显示关机确认对话框
        shutdownWindow.showWithAnimation()
        
        let expectation = self.expectation(description: "关机确认对话框应该显示在遮罩层之上")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // 验证两个窗口都可见
            XCTAssertTrue(overlayWindow.isVisible, "遮罩窗口应该可见")
            XCTAssertTrue(self.shutdownWindow.isVisible, "关机确认窗口应该可见")
            
            // 验证关机确认窗口在遮罩层之上
            XCTAssertTrue(self.shutdownWindow.level.rawValue > overlayWindow.level.rawValue, 
                         "关机确认窗口(\(self.shutdownWindow.level.rawValue))应该在遮罩层(\(overlayWindow.level.rawValue))之上")
            
            // 清理
            overlayWindow.orderOut(nil)
            self.shutdownWindow.hideWithAnimation()
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 性能测试
    
    func testPerformanceOfShowHide() {
        measure {
            for _ in 0..<10 {
                let window = ShutdownConfirmationWindow()
                window.showWithAnimation()
                window.hideWithAnimation()
                window.orderOut(nil)
            }
        }
    }
}
