//
//  ShuffleBackgroundsTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2026-01-08.
//  功能: 测试背景随机播放队列的正确性
//

import XCTest
@testable import PomodoroScreen

/// 测试随机播放功能
final class ShuffleBackgroundsTests: XCTestCase {
    
    var timer: PomodoroTimer!
    
    override func setUp() {
        super.setUp()
        timer = PomodoroTimer()
    }
    
    override func tearDown() {
        timer = nil
        super.tearDown()
    }
    
    // MARK: - 基础功能测试
    
    /// 测试：禁用随机播放时，背景按顺序播放
    func testSequentialPlayback_WhenShuffleDisabled() {
        // Given: 3个背景文件，随机播放禁用
        let backgroundFiles = createTestBackgroundFiles(count: 3)
        timer.updateSettings(
            pomodoroMinutes: 25,
            breakMinutes: 5,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: true,
            screenLockRestart: false,
            screenLockActionIsRestart: true,
            screensaverRestart: false,
            screensaverActionIsRestart: true,
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 10,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: backgroundFiles,
            shuffleBackgrounds: false, // 禁用随机播放
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 30,
            meetingMode: false
        )
        
        // When: 连续获取下一个背景索引
        let indices = (0..<6).map { _ in timer.getNextBackgroundIndex() }
        
        // Then: 应该按顺序循环 [0, 1, 2, 0, 1, 2]
        XCTAssertEqual(indices, [0, 1, 2, 0, 1, 2], "禁用随机播放时应该按顺序循环")
    }
    
    /// 测试：启用随机播放时，每轮包含所有文件且不重复
    func testShufflePlayback_ContainsAllFilesOnce() {
        // Given: 5个背景文件，随机播放启用
        let backgroundFiles = createTestBackgroundFiles(count: 5)
        timer.updateSettings(
            pomodoroMinutes: 25,
            breakMinutes: 5,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: true,
            screenLockRestart: false,
            screenLockActionIsRestart: true,
            screensaverRestart: false,
            screensaverActionIsRestart: true,
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 10,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: backgroundFiles,
            shuffleBackgrounds: true, // 启用随机播放
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 30,
            meetingMode: false
        )
        
        // When: 获取一轮的5个索引
        let firstRound = (0..<5).map { _ in timer.getNextBackgroundIndex() }
        
        // Then: 应该包含所有索引 [0, 1, 2, 3, 4]，但顺序随机
        let sortedFirstRound = firstRound.sorted()
        XCTAssertEqual(sortedFirstRound, [0, 1, 2, 3, 4], "每轮应该包含所有文件索引")
        XCTAssertEqual(Set(firstRound).count, 5, "每轮不应该有重复的索引")
    }
    
    /// 测试：多轮随机播放，每轮都包含所有文件
    func testShufflePlayback_MultipleRounds() {
        // Given: 4个背景文件，随机播放启用
        let backgroundFiles = createTestBackgroundFiles(count: 4)
        timer.updateSettings(
            pomodoroMinutes: 25,
            breakMinutes: 5,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: true,
            screenLockRestart: false,
            screenLockActionIsRestart: true,
            screensaverRestart: false,
            screensaverActionIsRestart: true,
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 10,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: backgroundFiles,
            shuffleBackgrounds: true,
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 30,
            meetingMode: false
        )
        
        // When: 获取3轮，每轮4个索引
        let round1 = (0..<4).map { _ in timer.getNextBackgroundIndex() }
        let round2 = (0..<4).map { _ in timer.getNextBackgroundIndex() }
        let round3 = (0..<4).map { _ in timer.getNextBackgroundIndex() }
        
        // Then: 每轮都应该包含所有索引
        XCTAssertEqual(Set(round1), Set([0, 1, 2, 3]), "第1轮应该包含所有索引")
        XCTAssertEqual(Set(round2), Set([0, 1, 2, 3]), "第2轮应该包含所有索引")
        XCTAssertEqual(Set(round3), Set([0, 1, 2, 3]), "第3轮应该包含所有索引")
        
        // Then: 不同轮次的顺序应该不同（概率极高）
        XCTAssertFalse(round1 == round2 && round2 == round3, "不同轮次的顺序应该不同（随机性测试）")
    }
    
    /// 测试：只有1个文件时，随机播放和顺序播放结果相同
    func testSingleFile_ShuffleAndSequentialSame() {
        // Given: 只有1个背景文件
        let backgroundFiles = createTestBackgroundFiles(count: 1)
        
        // When: 启用随机播放
        timer.updateSettings(
            pomodoroMinutes: 25,
            breakMinutes: 5,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: true,
            screenLockRestart: false,
            screenLockActionIsRestart: true,
            screensaverRestart: false,
            screensaverActionIsRestart: true,
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 10,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: backgroundFiles,
            shuffleBackgrounds: true,
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 30,
            meetingMode: false
        )
        
        let shuffleIndices = (0..<5).map { _ in timer.getNextBackgroundIndex() }
        
        // Then: 应该总是返回索引0
        XCTAssertEqual(shuffleIndices, [0, 0, 0, 0, 0], "只有1个文件时，索引应该总是0")
    }
    
    /// 测试：从随机播放切换到顺序播放
    func testSwitchFromShuffleToSequential() {
        // Given: 3个背景文件，初始启用随机播放
        let backgroundFiles = createTestBackgroundFiles(count: 3)
        timer.updateSettings(
            pomodoroMinutes: 25,
            breakMinutes: 5,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: true,
            screenLockRestart: false,
            screenLockActionIsRestart: true,
            screensaverRestart: false,
            screensaverActionIsRestart: true,
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 10,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: backgroundFiles,
            shuffleBackgrounds: true,
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 30,
            meetingMode: false
        )
        
        // When: 先随机播放几个
        _ = (0..<3).map { _ in timer.getNextBackgroundIndex() }
        
        // Then: 切换到顺序播放
        timer.updateSettings(
            pomodoroMinutes: 25,
            breakMinutes: 5,
            idleRestart: false,
            idleTime: 10,
            idleActionIsRestart: true,
            screenLockRestart: false,
            screenLockActionIsRestart: true,
            screensaverRestart: false,
            screensaverActionIsRestart: true,
            showCancelRestButton: true,
            longBreakCycle: 2,
            longBreakTimeMinutes: 10,
            showLongBreakCancelButton: true,
            accumulateRestTime: false,
            backgroundFiles: backgroundFiles,
            shuffleBackgrounds: false, // 切换到顺序播放
            stayUpLimitEnabled: false,
            stayUpLimitHour: 23,
            stayUpLimitMinute: 30,
            meetingMode: false
        )
        
        // When: 获取后续索引
        let sequentialIndices = (0..<6).map { _ in timer.getNextBackgroundIndex() }
        
        // Then: 应该按顺序循环
        XCTAssertEqual(sequentialIndices, [0, 1, 2, 0, 1, 2], "切换后应该按顺序循环")
    }
    
    // MARK: - 辅助方法
    
    /// 创建测试用的背景文件列表
    private func createTestBackgroundFiles(count: Int) -> [BackgroundFile] {
        return (0..<count).map { i in
            BackgroundFile(
                path: "/test/background_\(i).mp4",
                type: .video,
                name: "Background \(i)",
                playbackRate: 1.0
            )
        }
    }
}
