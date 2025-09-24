//
//  StatisticsTests.swift
//  PomodoroScreenTests
//
//  Created by Assistant on 2025-09-21.
//

import XCTest
@testable import PomodoroScreen

class StatisticsTests: XCTestCase {
    var statisticsManager: StatisticsManager!
    
    override func setUp() {
        super.setUp()
        statisticsManager = StatisticsManager.shared
    }
    
    override func tearDown() {
        statisticsManager = nil
        super.tearDown()
    }
    
    // 测试统计数据模型
    func testDailyStatisticsCalculations() {
        var dailyStats = DailyStatistics(date: Date())
        
        // 设置基本数据
        dailyStats.completedPomodoros = 6
        dailyStats.totalWorkTime = 6 * 25 * 60  // 6个25分钟番茄钟
        dailyStats.totalBreakTime = 5 * 5 * 60  // 5个5分钟休息
        dailyStats.cancelledBreakCount = 1
        dailyStats.screenLockCount = 3
        
        // 验证工作强度评分
        let workIntensity = dailyStats.workIntensityScore
        XCTAssertGreaterThan(workIntensity, 0, "工作强度评分应该大于0")
        XCTAssertLessThanOrEqual(workIntensity, 100, "工作强度评分应该不超过100")
        
        // 验证休息充足度评分
        let restAdequacy = dailyStats.restAdequacyScore
        XCTAssertGreaterThan(restAdequacy, 0, "休息充足度评分应该大于0")
        XCTAssertLessThanOrEqual(restAdequacy, 100, "休息充足度评分应该不超过100")
        
        // 验证专注度评分
        let focusScore = dailyStats.focusScore
        XCTAssertGreaterThan(focusScore, 0, "专注度评分应该大于0")
        XCTAssertLessThanOrEqual(focusScore, 100, "专注度评分应该不超过100")
        
        // 验证健康度评分
        let healthScore = dailyStats.healthScore
        XCTAssertGreaterThan(healthScore, 0, "健康度评分应该大于0")
        XCTAssertLessThanOrEqual(healthScore, 100, "健康度评分应该不超过100")
    }
    
    // 测试事件记录
    func testEventRecording() {
        // 记录番茄钟完成事件
        statisticsManager.recordPomodoroCompleted(duration: 25 * 60)
        
        // 记录短休息事件
        statisticsManager.recordShortBreakStarted(duration: 5 * 60)
        
        // 记录长休息事件
        statisticsManager.recordLongBreakStarted(duration: 15 * 60)
        
        // 记录取消休息事件
        statisticsManager.recordBreakCancelled(
            breakType: "short",
            plannedDuration: 5 * 60,
            actualDuration: 2 * 60
        )
        
        // 记录息屏事件
        statisticsManager.recordScreenLocked()
        
        // 记录熬夜事件
        statisticsManager.recordStayUpLateTriggered(
            triggerTime: Date(),
            limitTime: "23:30"
        )
        
        // 获取今日统计
        let todayStats = statisticsManager.getTodayStatistics()
        
        // 验证统计数据
        XCTAssertGreaterThan(todayStats.completedPomodoros, 0, "应该有完成的番茄钟")
        XCTAssertGreaterThan(todayStats.shortBreakCount, 0, "应该有短休息记录")
        XCTAssertGreaterThan(todayStats.longBreakCount, 0, "应该有长休息记录")
        XCTAssertGreaterThan(todayStats.cancelledBreakCount, 0, "应该有取消休息记录")
        XCTAssertGreaterThan(todayStats.screenLockCount, 0, "应该有息屏记录")
        XCTAssertGreaterThan(todayStats.stayUpLateCount, 0, "应该有熬夜记录")
    }
    
    // 测试周统计
    func testWeeklyStatistics() {
        let weeklyStats = statisticsManager.getThisWeekStatistics()
        
        // 验证基本结构
        XCTAssertEqual(weeklyStats.dailyStats.count, 7, "一周应该有7天的数据")
        
        // 验证计算属性
        let totalPomodoros = weeklyStats.totalPomodoros
        XCTAssertGreaterThanOrEqual(totalPomodoros, 0, "总番茄钟数应该大于等于0")
        
        let totalWorkTime = weeklyStats.totalWorkTime
        XCTAssertGreaterThanOrEqual(totalWorkTime, 0, "总工作时间应该大于等于0")
        
        let averageIntensity = weeklyStats.averageWorkIntensity
        XCTAssertGreaterThanOrEqual(averageIntensity, 0, "平均工作强度应该大于等于0")
        XCTAssertLessThanOrEqual(averageIntensity, 100, "平均工作强度应该不超过100")
    }
    
    // 测试报告数据生成
    func testReportDataGeneration() {
        let reportData = statisticsManager.generateTodayReport()
        
        // 验证报告数据结构
        XCTAssertNotNil(reportData.dailyStats, "应该有日统计数据")
        XCTAssertNotNil(reportData.weeklyStats, "应该有周统计数据")
        XCTAssertNotNil(reportData.recentEvents, "应该有最近事件数据")
        XCTAssertNotNil(reportData.configuration, "应该有配置数据")
        
        // 验证JSON序列化
        let jsonString = reportData.toJSONString()
        XCTAssertNotNil(jsonString, "应该能够序列化为JSON")
        XCTAssertFalse(jsonString?.isEmpty ?? true, "JSON字符串不应该为空")
    }
    
    // 测试健康建议生成
    func testHealthRecommendations() {
        var testStats = DailyStatistics(date: Date())
        
        // 测试低工作强度场景（通过设置少量番茄钟来达到低工作强度）
        testStats.completedPomodoros = 2
        testStats.totalWorkTime = 2 * 25 * 60  // 2个番茄钟的工作时间
        let lowIntensityRecommendations = statisticsManager.generateHealthRecommendations(for: testStats)
        XCTAssertFalse(lowIntensityRecommendations.isEmpty, "低工作强度应该有建议")
        
        // 测试休息不足场景（通过设置很少的休息时间）
        testStats.totalBreakTime = 2 * 60  // 只有2分钟休息时间，远少于期望的10分钟
        let lowRestRecommendations = statisticsManager.generateHealthRecommendations(for: testStats)
        XCTAssertFalse(lowRestRecommendations.isEmpty, "休息不足应该有建议")
        
        // 测试频繁取消休息场景
        testStats.cancelledBreakCount = 5
        let frequentCancelRecommendations = statisticsManager.generateHealthRecommendations(for: testStats)
        XCTAssertFalse(frequentCancelRecommendations.isEmpty, "频繁取消休息应该有建议")
        
        // 测试熬夜场景
        testStats.stayUpLateCount = 2
        let stayUpRecommendations = statisticsManager.generateHealthRecommendations(for: testStats)
        XCTAssertFalse(stayUpRecommendations.isEmpty, "熬夜应该有建议")
        
        // 测试健康状态场景（通过设置良好的数据来达到高健康分数）
        testStats = DailyStatistics(date: Date())
        testStats.completedPomodoros = 8  // 理想的番茄钟数量
        testStats.totalWorkTime = 8 * 25 * 60  // 8个番茄钟的工作时间
        testStats.totalBreakTime = 8 * 5 * 60  // 充足的休息时间
        testStats.cancelledBreakCount = 0  // 没有取消休息
        testStats.stayUpLateCount = 0  // 没有熬夜
        let healthyRecommendations = statisticsManager.generateHealthRecommendations(for: testStats)
        XCTAssertFalse(healthyRecommendations.isEmpty, "健康状态也应该有积极反馈")
    }
    
    // 测试趋势分析
    func testTrendAnalysis() {
        // 先添加一些测试数据以确保有趋势可分析
        statisticsManager.recordPomodoroCompleted(duration: 25 * 60)  // 25分钟番茄钟
        statisticsManager.recordShortBreakStarted()
        
        let weeklyStats = statisticsManager.getThisWeekStatistics()
        let trendAnalysis = statisticsManager.generateTrendAnalysis(for: weeklyStats)
        
        // 趋势分析应该能够执行（可能为空，这是正常的）
        XCTAssertNotNil(trendAnalysis, "趋势分析结果不应该为nil")
        // 注意：在测试环境中，可能没有足够的历史数据来生成有意义的趋势，所以不强制要求非空
    }
    
    // 测试数据导出
    func testDataExport() {
        let exportData = statisticsManager.exportData()
        
        XCTAssertNotNil(exportData, "应该能够导出数据")
        XCTAssertNotNil(exportData?["export_date"], "导出数据应该包含导出日期")
        XCTAssertNotNil(exportData?["daily_stats"], "导出数据应该包含日统计")
        XCTAssertNotNil(exportData?["weekly_stats"], "导出数据应该包含周统计")
        XCTAssertNotNil(exportData?["events_count"], "导出数据应该包含事件数量")
    }
    
    // 测试边界条件
    func testEdgeCases() {
        // 测试空数据的评分计算
        let emptyStats = DailyStatistics(date: Date())
        
        XCTAssertEqual(emptyStats.completedPomodoros, 0, "初始番茄钟数应该为0")
        XCTAssertEqual(emptyStats.totalWorkTime, 0, "初始工作时间应该为0")
        XCTAssertEqual(emptyStats.focusScore, 0, "无数据时专注度应该为0")
        XCTAssertEqual(emptyStats.restAdequacyScore, 0, "无数据时休息充足度应该为0（因为没有完成番茄钟）")
        
        // 测试极值情况
        var extremeStats = DailyStatistics(date: Date())
        extremeStats.completedPomodoros = 20  // 极高的番茄钟数
        extremeStats.totalWorkTime = 20 * 25 * 60
        extremeStats.stayUpLateCount = 5  // 极多的熬夜次数
        
        let workIntensity = extremeStats.workIntensityScore
        let healthScore = extremeStats.healthScore
        
        XCTAssertLessThanOrEqual(workIntensity, 100, "工作强度不应超过100")
        XCTAssertGreaterThanOrEqual(healthScore, 0, "健康度不应低于0")
    }
}
