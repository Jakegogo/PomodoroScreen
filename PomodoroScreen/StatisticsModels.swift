//
//  StatisticsModels.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-21.
//

import Foundation

// MARK: - 统计事件类型
enum StatisticsEventType: String, CaseIterable {
    case pomodoroCompleted = "pomodoro_completed"     // 番茄钟完成
    case shortBreakStarted = "short_break_started"    // 短休息开始
    case longBreakStarted = "long_break_started"      // 长休息开始
    case breakCancelled = "break_cancelled"           // 取消休息
    case screenLocked = "screen_locked"               // 息屏
    case screensaverActivated = "screensaver_activated" // 屏保激活
    case stayUpLateTriggered = "stay_up_late_triggered" // 熬夜模式触发
}

// MARK: - 统计事件数据结构
struct StatisticsEvent {
    let id: String
    let eventType: StatisticsEventType
    let timestamp: Date
    let duration: TimeInterval?  // 持续时间（秒），对于完成事件有效
    let metadata: [String: Any]? // 额外数据
    
    init(eventType: StatisticsEventType, duration: TimeInterval? = nil, metadata: [String: Any]? = nil) {
        self.id = UUID().uuidString
        self.eventType = eventType
        self.timestamp = Date()
        self.duration = duration
        self.metadata = metadata
    }
}

// MARK: - 日统计数据
struct DailyStatistics {
    let date: Date
    var completedPomodoros: Int = 0          // 完成的番茄钟数量
    var totalWorkTime: TimeInterval = 0      // 总工作时间（秒）
    var shortBreakCount: Int = 0             // 短休息次数
    var longBreakCount: Int = 0              // 长休息次数
    var totalBreakTime: TimeInterval = 0     // 总休息时间（秒）
    var cancelledBreakCount: Int = 0         // 取消休息次数
    var screenLockCount: Int = 0             // 息屏次数
    var screensaverCount: Int = 0            // 屏保次数
    var stayUpLateCount: Int = 0             // 熬夜次数
    var firstActivityTime: Date?             // 首次活动时间
    var lastActivityTime: Date?              // 最后活动时间
    
    // MARK: - 计算属性
    
    /// 工作强度评分 (0-100)
    var workIntensityScore: Double {
        let idealPomodoros = 8.0  // 理想的番茄钟数量
        let pomodoroScore = min(Double(completedPomodoros) / idealPomodoros, 1.0) * 50
        
        let workBreakRatio = totalWorkTime > 0 ? totalBreakTime / totalWorkTime : 0
        let idealBreakRatio = 0.25  // 理想的休息/工作比例
        let breakScore = min(workBreakRatio / idealBreakRatio, 1.0) * 30
        
        let consistencyScore = cancelledBreakCount == 0 ? 20.0 : max(0, 20 - Double(cancelledBreakCount) * 5)
        
        return pomodoroScore + breakScore + consistencyScore
    }
    
    /// 休息充足度评分 (0-100)
    var restAdequacyScore: Double {
        guard completedPomodoros > 0 else { return 100 }
        
        let expectedBreakTime = Double(completedPomodoros) * 5 * 60  // 每个番茄钟期望5分钟休息
        let actualBreakRatio = totalBreakTime / expectedBreakTime
        
        return min(actualBreakRatio, 1.0) * 100
    }
    
    /// 专注度评分 (0-100)
    var focusScore: Double {
        guard completedPomodoros > 0 else { return 0 }
        
        let interruptionPenalty = Double(cancelledBreakCount + screenLockCount) * 5
        let baseScore = Double(completedPomodoros) * 10
        
        return max(0, min(100, baseScore - interruptionPenalty))
    }
    
    /// 健康度评分 (0-100)
    var healthScore: Double {
        var score = 100.0
        
        // 熬夜扣分
        score -= Double(stayUpLateCount) * 20
        
        // 取消休息扣分
        score -= Double(cancelledBreakCount) * 5
        
        // 长时间工作扣分
        if totalWorkTime > 8 * 60 * 60 {  // 超过8小时
            score -= 20
        }
        
        return max(0, score)
    }
}

// MARK: - 周统计数据
struct WeeklyStatistics {
    let weekStartDate: Date
    var dailyStats: [DailyStatistics] = []
    
    // MARK: - 计算属性
    
    /// 本周总的番茄钟数量
    var totalPomodoros: Int {
        return dailyStats.reduce(0) { $0 + $1.completedPomodoros }
    }
    
    /// 本周总工作时间
    var totalWorkTime: TimeInterval {
        return dailyStats.reduce(0) { $0 + $1.totalWorkTime }
    }
    
    /// 本周总休息时间
    var totalBreakTime: TimeInterval {
        return dailyStats.reduce(0) { $0 + $1.totalBreakTime }
    }
    
    /// 平均工作强度评分
    var averageWorkIntensity: Double {
        guard !dailyStats.isEmpty else { return 0 }
        return dailyStats.reduce(0) { $0 + $1.workIntensityScore } / Double(dailyStats.count)
    }
    
    /// 平均健康度评分
    var averageHealthScore: Double {
        guard !dailyStats.isEmpty else { return 100 }
        return dailyStats.reduce(0) { $0 + $1.healthScore } / Double(dailyStats.count)
    }
    
    /// 工作日统计（周一到周五）
    var workdayStats: [DailyStatistics] {
        let calendar = Calendar.current
        return dailyStats.filter { stat in
            let weekday = calendar.component(.weekday, from: stat.date)
            return weekday >= 2 && weekday <= 6  // 周一(2)到周五(6)
        }
    }
    
    /// 周末统计
    var weekendStats: [DailyStatistics] {
        let calendar = Calendar.current
        return dailyStats.filter { stat in
            let weekday = calendar.component(.weekday, from: stat.date)
            return weekday == 1 || weekday == 7  // 周日(1)和周六(7)
        }
    }
}

// MARK: - 报告生成配置
struct ReportConfiguration {
    var includeCharts: Bool = true
    var includeTrends: Bool = true
    var includeRecommendations: Bool = true
    var chartTheme: ChartTheme = .light
    
    enum ChartTheme: String {
        case light = "light"
        case dark = "dark"
    }
}

// MARK: - 报告数据传输对象
struct ReportData {
    let dailyStats: DailyStatistics
    let weeklyStats: WeeklyStatistics
    let recentEvents: [StatisticsEvent]
    let configuration: ReportConfiguration
    
    /// 转换为JSON字符串，用于传递给HTML/JavaScript
    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let reportDict: [String: Any] = [
            "daily": [
                "date": ISO8601DateFormatter().string(from: dailyStats.date),
                "completedPomodoros": dailyStats.completedPomodoros,
                "totalWorkTime": dailyStats.totalWorkTime,
                "shortBreakCount": dailyStats.shortBreakCount,
                "longBreakCount": dailyStats.longBreakCount,
                "totalBreakTime": dailyStats.totalBreakTime,
                "cancelledBreakCount": dailyStats.cancelledBreakCount,
                "screenLockCount": dailyStats.screenLockCount,
                "screensaverCount": dailyStats.screensaverCount,
                "stayUpLateCount": dailyStats.stayUpLateCount,
                "workIntensityScore": dailyStats.workIntensityScore,
                "restAdequacyScore": dailyStats.restAdequacyScore,
                "focusScore": dailyStats.focusScore,
                "healthScore": dailyStats.healthScore
            ],
            "weekly": [
                "weekStartDate": ISO8601DateFormatter().string(from: weeklyStats.weekStartDate),
                "totalPomodoros": weeklyStats.totalPomodoros,
                "totalWorkTime": weeklyStats.totalWorkTime,
                "totalBreakTime": weeklyStats.totalBreakTime,
                "averageWorkIntensity": weeklyStats.averageWorkIntensity,
                "averageHealthScore": weeklyStats.averageHealthScore,
                "dailyTrend": weeklyStats.dailyStats.map { stat in
                    [
                        "date": ISO8601DateFormatter().string(from: stat.date),
                        "pomodoros": stat.completedPomodoros,
                        "workIntensity": stat.workIntensityScore,
                        "healthScore": stat.healthScore
                    ]
                }
            ],
            "configuration": [
                "includeCharts": configuration.includeCharts,
                "includeTrends": configuration.includeTrends,
                "includeRecommendations": configuration.includeRecommendations,
                "chartTheme": configuration.chartTheme.rawValue
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: reportDict, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("❌ 报告数据序列化失败: \(error)")
            return nil
        }
    }
}
