//
//  StatisticsManager.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-21.
//

import Foundation
// import Combine // No longer needed

// 使用集中封装的设置
// 访问用户设置集中封装
// SettingsStore 在同一模块内，无需额外依赖

class StatisticsManager {
    
    // 单例模式
    static let shared = StatisticsManager()
    
    internal let database = StatisticsDatabase.shared
    
    // Make init public for mocking
    public init() {
        print("📊 统计管理器初始化完成")
    }
    
    // MARK: - 事件记录接口
    
    /// 记录番茄钟完成事件
    open func recordPomodoroCompleted(duration: TimeInterval) {
        let event = StatisticsEvent(
            eventType: .pomodoroCompleted,
            duration: duration,
            metadata: [
                "actual_duration": duration,
                "completion_rate": duration >= (25 * 60) ? 1.0 : duration / (25 * 60)
            ]
        )
        database.recordEvent(event)
        print("🍅 记录番茄钟完成: \(Int(duration/60))分钟")
    }
    
    /// 记录短休息开始事件
    open func recordShortBreakStarted(duration: TimeInterval? = nil) {
        // 如果未传入时长，使用用户设置
        let plannedSeconds = duration ?? TimeInterval(SettingsStore.breakTimeMinutes * 60)
        let event = StatisticsEvent(
            eventType: .shortBreakStarted,
            duration: duration,
            metadata: [
                "break_type": "short",
                "planned_duration": plannedSeconds
            ]
        )
        database.recordEvent(event)
        print("☕ 记录短休息开始")
    }
    
    /// 记录长休息开始事件
    open func recordLongBreakStarted(duration: TimeInterval? = nil) {
        let plannedSeconds = duration ?? TimeInterval(SettingsStore.longBreakTimeMinutes * 60)
        let event = StatisticsEvent(
            eventType: .longBreakStarted,
            duration: duration,
            metadata: [
                "break_type": "long",
                "planned_duration": plannedSeconds
            ]
        )
        database.recordEvent(event)
        print("🛋️ 记录长休息开始")
    }
     
    /// 记录休息完成事件（短或长）
    /// - Parameters:
    ///   - breakType: "short" | "long"
    ///   - plannedDuration: 计划时长（秒）
    ///   - actualDuration: 实际时长（秒）
    func recordBreakFinished(breakType: String, plannedDuration: TimeInterval, actualDuration: TimeInterval) {
        let event = StatisticsEvent(
            eventType: .breakFinished,
            duration: actualDuration,
            metadata: [
                "break_type": breakType,
                "planned_duration": plannedDuration,
                "actual_duration": actualDuration,
                "completion_rate": plannedDuration > 0 ? (actualDuration / plannedDuration) : 1.0
            ]
        )
        database.recordEvent(event)
        print("✅ 记录休息完成: \(breakType)")
    }
    
    /// 记录取消休息事件
    func recordBreakCancelled(breakType: String, plannedDuration: TimeInterval, actualDuration: TimeInterval, source: String = "user") {
        let event = StatisticsEvent(
            eventType: .breakCancelled,
            duration: actualDuration,
            metadata: [
                "break_type": breakType,
                "planned_duration": plannedDuration,
                "actual_duration": actualDuration,
                "completion_rate": actualDuration / plannedDuration,
                "source": source
            ]
        )
        database.recordEvent(event)
        print("❌ 记录取消休息: \(breakType)")
    }

    /// 更新/记录今日心情（级别与文本）
    /// - Parameters:
    ///   - moodLevel: 1-6 之间的整数，表示心情强度或级别（可选）
    ///   - moodNote: 文本感受（可选）
    func updateTodayMood(moodLevel: Int?, moodNote: String?) {
        var metadata: [String: Any] = [:]
        if let moodLevel {
            metadata["mood_level"] = moodLevel
        }
        if let moodNote {
            metadata["mood_note"] = moodNote
        }
        let event = StatisticsEvent(eventType: .moodUpdated, duration: nil, metadata: metadata)
        database.recordEvent(event)
        print("📝 记录今日心情: level=\(moodLevel ?? -1), note=\(moodNote ?? "")")
    }
    
    /// 记录息屏事件
    func recordScreenLocked() {
        let event = StatisticsEvent(
            eventType: .screenLocked,
            metadata: [
                "source": "system"
            ]
        )
        database.recordEvent(event)
        print("🔒 记录息屏事件")
    }
    
    /// 记录屏保激活事件
    func recordScreensaverActivated(duration: TimeInterval? = nil) {
        let event = StatisticsEvent(
            eventType: .screensaverActivated,
            duration: duration,
            metadata: [
                "source": "system"
            ]
        )
        database.recordEvent(event)
        print("🌙 记录屏保激活")
    }
    
    /// 记录熬夜模式触发事件
    func recordStayUpLateTriggered(triggerTime: Date, limitTime: String) {
        // 去重：同一自然日仅记录一次，防止夜间重复触发导致数据爆增
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: triggerTime)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? triggerTime
        let todayEvents = database.getEvents(from: dayStart, to: dayEnd)
        if todayEvents.contains(where: { $0.eventType == .stayUpLateTriggered }) {
            print("🛑 跳过重复的熬夜触发记录（同日已存在）")
            return
        }

        let event = StatisticsEvent(
            eventType: .stayUpLateTriggered,
            metadata: [
                "trigger_time": ISO8601DateFormatter().string(from: triggerTime),
                "limit_time": limitTime,
                "severity": "high"
            ]
        )
        database.recordEvent(event)
        print("🌃 记录熬夜模式触发: \(limitTime)")
    }

    /// 记录实际熬夜活动（用于热力图标记，每半小时一次）
    func recordStayUpLateActivity() {
        let event = StatisticsEvent(
            eventType: .stayUpLateActivity,
            duration: nil,
            metadata: [
                "source": "auto",
                "note": "half_hour_slot"
            ]
        )
        database.recordEvent(event)
        print("🌙 记录熬夜活动(半小时)")
    }
    
    // MARK: - 数据查询接口
    
    /// 获取今日统计数据
    func getTodayStatistics() -> DailyStatistics {
        let today = Date()
        return database.getDailyStatistics(for: today) ?? DailyStatistics(date: today)
    }
    
    /// 获取指定日期的统计数据
    func getDailyStatistics(for date: Date) -> DailyStatistics {
        return database.getDailyStatistics(for: date) ?? DailyStatistics(date: date)
    }
    
    /// 获取本周统计数据（过去7天，包括今天）
    func getThisWeekStatistics() -> WeeklyStatistics {
        let calendar = Calendar.current
        let today = Date()
        // 计算过去7天的开始日期（6天前）
        let weekStartDate = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        return database.getWeeklyStatistics(for: weekStartDate)
    }
    
    /// 获取指定周的统计数据
    func getWeeklyStatistics(weekStartDate: Date) -> WeeklyStatistics {
        return database.getWeeklyStatistics(for: weekStartDate)
    }
    
    /// 获取最近的事件列表
    func getRecentEvents(limit: Int = 50) -> [StatisticsEvent] {
        return database.getRecentEvents(limit: limit)
    }
    
    /// 获取指定周的所有事件
    func getWeekEvents(for weekStartDate: Date) -> [StatisticsEvent] {
        let calendar = Calendar.current
        let weekEndDate = calendar.date(byAdding: .day, value: 7, to: weekStartDate) ?? weekStartDate
        return database.getEvents(from: weekStartDate, to: weekEndDate)
    }

    // 调试：打印指定小时事件分布
    func debugPrintHourEventCounts(date: Date, hour: Int) {
        let counts = database.debugEventTypeCounts(for: date, hour: hour)
        print("[Debug] \(DateFormatter.dateKey.string(from: date)) @\(hour):00 -> \(counts)")
    }
    
    // MARK: - 报告生成
    
    /// 生成今日报告数据
    func generateTodayReport(configuration: ReportConfiguration = ReportConfiguration()) -> ReportData {
        let dailyStats = getTodayStatistics()
        let weeklyStats = getThisWeekStatistics()
        let weekEvents = getWeekEvents(for: weeklyStats.weekStartDate)
        #if DEBUG
        // 调试：打印今天11:00的事件分布，便于排查“取消休息”误判
        debugPrintHourEventCounts(date: dailyStats.date, hour: 11)
        #endif
        
        // Populate stay-up configuration from SettingsStore
        var cfg = configuration
        cfg.stayUpLimitEnabled = SettingsStore.stayUpLimitEnabled
        cfg.stayUpStartHour = SettingsStore.stayUpLimitHour
        cfg.stayUpStartMinute = SettingsStore.stayUpLimitMinute
        // End time aligned with AutoRestartStateMachine (next day)
        cfg.stayUpEndHour = StayUpConstants.endHour
        cfg.stayUpEndMinute = StayUpConstants.endMinute

        return ReportData(
            dailyStats: dailyStats,
            weeklyStats: weeklyStats,
            recentEvents: weekEvents,
            configuration: cfg
        )
    }
    
    /// 生成健康建议
    func generateHealthRecommendations(for stats: DailyStatistics) -> [String] {
        var recommendations: [String] = []
        
        // 工作强度建议
        if stats.workIntensityScore < 50 {
            recommendations.append("💪 建议增加番茄钟数量，提高工作效率")
        } else if stats.workIntensityScore > 80 {
            recommendations.append("⚠️ 工作强度较高，注意适当休息")
        }
        
        // 休息建议
        if stats.restAdequacyScore < 60 {
            recommendations.append("☕ 休息时间不足，建议严格执行休息计划")
        }
        
        // 专注度建议
        if stats.cancelledBreakCount > 2 {
            recommendations.append("🎯 频繁取消休息会影响专注度，建议坚持休息")
        }
        
        // 健康建议
        if stats.stayUpLateCount > 0 {
            recommendations.append("🌙 检测到熬夜行为，建议调整作息时间")
        }
        
        if stats.screenLockCount > 10 {
            recommendations.append("📱 频繁息屏可能表示注意力分散，建议专注工作")
        }
        
        // 积极反馈
        if stats.healthScore >= 80 {
            recommendations.append("🎉 今日工作状态良好，继续保持！")
        }
        
        if stats.focusScore >= 80 {
            recommendations.append("🏆 专注度很高，工作效率优秀！")
        }
        
        if recommendations.isEmpty {
            recommendations.append("👍 工作状态正常，继续保持良好的工作节奏")
        }
        
        return recommendations
    }
    
    /// 生成趋势分析
    func generateTrendAnalysis(for weeklyStats: WeeklyStatistics) -> [String] {
        var analysis: [String] = []
        
        let dailyStats = weeklyStats.dailyStats
        guard dailyStats.count >= 2 else {
            analysis.append("📈 数据不足，无法进行趋势分析")
            return analysis
        }
        
        // 番茄钟数量趋势
        let pomodoroTrend = calculateTrend(dailyStats.map { Double($0.completedPomodoros) })
        if pomodoroTrend > 0.1 {
            analysis.append("📈 番茄钟完成数量呈上升趋势，工作积极性提升")
        } else if pomodoroTrend < -0.1 {
            analysis.append("📉 番茄钟完成数量呈下降趋势，建议调整工作计划")
        }
        
        // 健康度趋势
        let healthTrend = calculateTrend(dailyStats.map { $0.healthScore })
        if healthTrend > 5 {
            analysis.append("💚 健康度评分持续改善，生活习惯越来越好")
        } else if healthTrend < -5 {
            analysis.append("⚠️ 健康度评分有下降趋势，需要关注作息规律")
        }
        
        // 工作强度趋势
        let intensityTrend = calculateTrend(dailyStats.map { $0.workIntensityScore })
        if intensityTrend > 5 {
            analysis.append("⚡ 工作强度逐步提升，保持良好的工作节奏")
        } else if intensityTrend < -5 {
            analysis.append("📊 工作强度有所下降，可能需要重新规划时间")
        }
        
        return analysis
    }
    
    /// 计算趋势斜率（简单线性回归）
    private func calculateTrend(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        
        let n = Double(values.count)
        let x = Array(0..<values.count).map { Double($0) }
        let y = values
        
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumXX = x.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        return slope
    }
    
    // MARK: - 数据清理
    
    /// 清理过期数据（保留最近30天）
    func cleanupOldData() {
        // 这里可以实现数据清理逻辑
        // 由于SQLite比较轻量，暂时不实现自动清理
        print("🧹 数据清理功能待实现")
    }
    
    /// 导出数据（用于备份）
    func exportData() -> [String: Any]? {
        let todayStats = getTodayStatistics()
        let weeklyStats = getThisWeekStatistics()
        let recentEvents = getRecentEvents(limit: 100)
        
        let exportData: [String: Any] = [
            "export_date": ISO8601DateFormatter().string(from: Date()),
            "daily_stats": [
                "date": ISO8601DateFormatter().string(from: todayStats.date),
                "completed_pomodoros": todayStats.completedPomodoros,
                "total_work_time": todayStats.totalWorkTime,
                "health_score": todayStats.healthScore
            ],
            "weekly_stats": [
                "week_start": ISO8601DateFormatter().string(from: weeklyStats.weekStartDate),
                "total_pomodoros": weeklyStats.totalPomodoros,
                "average_health": weeklyStats.averageHealthScore
            ],
            "events_count": recentEvents.count
        ]
        
        return exportData
    }
}
