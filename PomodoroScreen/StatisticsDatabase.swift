//
//  StatisticsDatabase.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-21.
//

import Foundation
import SQLite3

class StatisticsDatabase {
    private var db: OpaquePointer?
    private let dbPath: String
    
    // 单例模式
    static let shared = StatisticsDatabase()
    
    private init() {
        // 数据库文件路径：~/Library/Application Support/PomodoroScreen/statistics.db
        let fileManager = FileManager.default
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupportDir.appendingPathComponent("PomodoroScreen")
        
        // 创建应用目录
        do {
            try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ 创建应用目录失败: \(error)")
        }
        
        dbPath = appDir.appendingPathComponent("statistics.db").path
        print("📁 数据库路径: \(dbPath)")
        
        openDatabase()
        createTables()
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - 数据库连接管理
    
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ 无法打开数据库")
            return
        }
        print("✅ 数据库连接成功")
        // 连接成功后执行数据库迁移
        DatabaseMigration.shared.runMigrationsIfNeeded(db: db)
    }
    
    private func closeDatabase() {
        if sqlite3_close(db) != SQLITE_OK {
            print("❌ 无法关闭数据库")
        }
        db = nil
    }
    
    // MARK: - 创建表结构
    
    private func createTables() {
        createEventsTable()
        createDailyStatsTable()
    }
    
    private func createEventsTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS statistics_events (
                id TEXT PRIMARY KEY,
                event_type TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                duration REAL,
                metadata TEXT,
                created_at INTEGER DEFAULT (strftime('%s', 'now'))
            );
        """
        AppLogger.shared.logSQL(createTableSQL, tag: "DDL")
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("❌ 创建events表失败: \(errmsg)")
        } else {
            print("✅ Events表创建成功")
        }
        
        // 创建索引
        let createIndexSQL = """
            CREATE INDEX IF NOT EXISTS idx_events_timestamp ON statistics_events(timestamp);
            CREATE INDEX IF NOT EXISTS idx_events_type ON statistics_events(event_type);
        """
        AppLogger.shared.logSQL(createIndexSQL, tag: "DDL")
        
        if sqlite3_exec(db, createIndexSQL, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("❌ 创建events索引失败: \(errmsg)")
        }
    }
    
    private func createDailyStatsTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS daily_statistics (
                date TEXT PRIMARY KEY,
                completed_pomodoros INTEGER DEFAULT 0,
                total_work_time REAL DEFAULT 0,
                short_break_count INTEGER DEFAULT 0,
                long_break_count INTEGER DEFAULT 0,
                total_break_time REAL DEFAULT 0,
                cancelled_break_count INTEGER DEFAULT 0,
                screen_lock_count INTEGER DEFAULT 0,
                screensaver_count INTEGER DEFAULT 0,
                stay_up_late_count INTEGER DEFAULT 0,
                mood_level INTEGER,
                mood_note TEXT,
                mood_updated_at INTEGER,
                first_activity_time INTEGER,
                last_activity_time INTEGER,
                updated_at INTEGER DEFAULT (strftime('%s', 'now'))
            );
        """
        AppLogger.shared.logSQL(createTableSQL, tag: "DDL")
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("❌ 创建daily_statistics表失败: \(errmsg)")
        } else {
            print("✅ Daily statistics表创建成功")
        }
    }
    
    // MARK: - 事件记录
    
    func recordEvent(_ event: StatisticsEvent) {
        let insertSQL = """
            INSERT INTO statistics_events (id, event_type, timestamp, duration, metadata)
            VALUES (?, ?, ?, ?, ?);
        """
        // 预记录SQL与参数（便于定位绑定位置和数据）
        var logParams: [Any?] = [event.id, event.eventType.rawValue, Int64(event.timestamp.timeIntervalSince1970)]
        logParams.append(event.duration)
        logParams.append(event.metadata)
        AppLogger.shared.logSQL(insertSQL, params: logParams, tag: "INSERT events")
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, event.id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, event.eventType.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_int64(statement, 3, Int64(event.timestamp.timeIntervalSince1970))
            
            if let duration = event.duration {
                sqlite3_bind_double(statement, 4, duration)
            } else {
                sqlite3_bind_null(statement, 4)
            }
            
            if let metadata = event.metadata {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: metadata)
                    let jsonString = String(data: jsonData, encoding: .utf8)
                    sqlite3_bind_text(statement, 5, jsonString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                } catch {
                    sqlite3_bind_null(statement, 5)
                }
            } else {
                sqlite3_bind_null(statement, 5)
            }
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ 事件记录成功: \(event.eventType.rawValue)")
            } else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("❌ 事件记录失败: \(errmsg)")
            }
        }
        
        sqlite3_finalize(statement)
        
        // 同时更新日统计
        updateDailyStatistics(for: event)
    }
    
    // MARK: - 日统计更新
    
    private func updateDailyStatistics(for event: StatisticsEvent) {
        let calendar = Calendar.current
        let dateKey = calendar.dateInterval(of: .day, for: event.timestamp)?.start ?? event.timestamp
        
        // 首先获取或创建当日记录
        var dailyStats = getDailyStatistics(for: dateKey) ?? DailyStatistics(date: dateKey)
        
        // 更新统计数据
        switch event.eventType {
        case .pomodoroCompleted:
            dailyStats.completedPomodoros += 1
            if let duration = event.duration {
                dailyStats.totalWorkTime += duration
            }
            
        case .shortBreakStarted:
            dailyStats.shortBreakCount += 1

        case .longBreakStarted:
            dailyStats.longBreakCount += 1
            
        case .breakCancelled:
            // 仅计入用户主动取消的次数，系统自动关闭不记为“取消休息”
            if let src = event.metadata?["source"] as? String, src == "user" {
                dailyStats.cancelledBreakCount += 1
            }
            
        case .breakFinished:
            // 休息完成：只累计实际休息时长，不增加取消次数
            if let duration = event.duration {
                dailyStats.totalBreakTime += duration
            } else if let md = event.metadata, let actual = md["actual_duration"] as? Double {
                dailyStats.totalBreakTime += actual
            }
            
        case .screenLocked:
            dailyStats.screenLockCount += 1
            
        case .screensaverActivated:
            dailyStats.screensaverCount += 1
            
        case .stayUpLateTriggered:
            dailyStats.stayUpLateCount += 1
        case .moodUpdated:
            if let metadata = event.metadata {
                if let level = metadata["mood_level"] as? Int {
                    dailyStats.moodLevel = level
                }
                if let note = metadata["mood_note"] as? String {
                    dailyStats.moodNote = note
                }
            }
            dailyStats.moodUpdatedAt = event.timestamp
        }
        
        // 更新活动时间
        if dailyStats.firstActivityTime == nil {
            dailyStats.firstActivityTime = event.timestamp
        }
        dailyStats.lastActivityTime = event.timestamp
        
        // 保存到数据库
        saveDailyStatistics(dailyStats)
    }

    
    
    private func saveDailyStatistics(_ stats: DailyStatistics) {
        let dateString = DateFormatter.dateKey.string(from: stats.date)
        
        let upsertSQL = """
            INSERT OR REPLACE INTO daily_statistics 
            (date, completed_pomodoros, total_work_time, short_break_count, long_break_count, 
             total_break_time, cancelled_break_count, screen_lock_count, screensaver_count, 
             stay_up_late_count, mood_level, mood_note, mood_updated_at, first_activity_time, last_activity_time)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        // 预记录SQL与参数（把 Optional 直观输出）
        var params: [Any?] = [
            dateString,
            stats.completedPomodoros,
            stats.totalWorkTime,
            stats.shortBreakCount,
            stats.longBreakCount,
            stats.totalBreakTime,
            stats.cancelledBreakCount,
            stats.screenLockCount,
            stats.screensaverCount,
            stats.stayUpLateCount,
            stats.moodLevel,
            stats.moodNote ?? NSNull(),
            stats.moodUpdatedAt != nil ? Int64(stats.moodUpdatedAt!.timeIntervalSince1970) : NSNull(),
            stats.firstActivityTime != nil ? Int64(stats.firstActivityTime!.timeIntervalSince1970) : NSNull(),
            stats.lastActivityTime != nil ? Int64(stats.lastActivityTime!.timeIntervalSince1970) : NSNull()
        ]
        AppLogger.shared.logSQL(upsertSQL, params: params, tag: "UPSERT daily_statistics")
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, upsertSQL, -1, &statement, nil) == SQLITE_OK {
            // 使用SQLITE_TRANSIENT确保字符串被正确复制
            sqlite3_bind_text(statement, 1, dateString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_int(statement, 2, Int32(stats.completedPomodoros))
            sqlite3_bind_double(statement, 3, stats.totalWorkTime)
            sqlite3_bind_int(statement, 4, Int32(stats.shortBreakCount))
            sqlite3_bind_int(statement, 5, Int32(stats.longBreakCount))
            sqlite3_bind_double(statement, 6, stats.totalBreakTime)
            sqlite3_bind_int(statement, 7, Int32(stats.cancelledBreakCount))
            sqlite3_bind_int(statement, 8, Int32(stats.screenLockCount))
            sqlite3_bind_int(statement, 9, Int32(stats.screensaverCount))
            sqlite3_bind_int(statement, 10, Int32(stats.stayUpLateCount))
            // mood_level
            if let moodLevel = stats.moodLevel {
                sqlite3_bind_int(statement, 11, Int32(moodLevel))
            } else {
                sqlite3_bind_null(statement, 11)
            }
            // mood_note
            if let moodNote = stats.moodNote {
                sqlite3_bind_text(statement, 12, moodNote, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else {
                sqlite3_bind_null(statement, 12)
            }
            // mood_updated_at
            if let moodUpdatedAt = stats.moodUpdatedAt {
                sqlite3_bind_int64(statement, 13, Int64(moodUpdatedAt.timeIntervalSince1970))
            } else {
                sqlite3_bind_null(statement, 13)
            }
            // first_activity_time
            if let firstActivity = stats.firstActivityTime {
                sqlite3_bind_int64(statement, 14, Int64(firstActivity.timeIntervalSince1970))
            } else {
                sqlite3_bind_null(statement, 14)
            }
            // last_activity_time
            if let lastActivity = stats.lastActivityTime {
                sqlite3_bind_int64(statement, 15, Int64(lastActivity.timeIntervalSince1970))
            } else {
                sqlite3_bind_null(statement, 15)
            }
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ 日统计更新成功: \(dateString) mood_level=\(stats.moodLevel != nil ? String(stats.moodLevel!) : "nil") mood_note=\(stats.moodNote ?? "") mood_updated_at=\(stats.moodUpdatedAt != nil ? String(Int64(stats.moodUpdatedAt!.timeIntervalSince1970)) : "nil")")
            } else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("❌ 日统计更新失败: \(errmsg)")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    // MARK: - 数据查询
    
    func getDailyStatistics(for date: Date) -> DailyStatistics? {
        let dateString = DateFormatter.dateKey.string(from: date)
        let selectSQL = """
            SELECT 
                date,
                completed_pomodoros,
                total_work_time,
                short_break_count,
                long_break_count,
                total_break_time,
                cancelled_break_count,
                screen_lock_count,
                screensaver_count,
                stay_up_late_count,
                mood_level,
                mood_note,
                mood_updated_at,
                first_activity_time,
                last_activity_time
            FROM daily_statistics 
            WHERE date = ?;
        """
        AppLogger.shared.logSQL(selectSQL, params: [dateString], tag: "SELECT daily_statistics")
        
        var statement: OpaquePointer?
        var result: DailyStatistics?
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, dateString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            
            if sqlite3_step(statement) == SQLITE_ROW {
                result = parseDailyStatistics(from: statement!)
            }
        }
        
        sqlite3_finalize(statement)
        return result
    }
    
    func getWeeklyStatistics(for weekStartDate: Date) -> WeeklyStatistics {
        let calendar = Calendar.current
        var weekStats = WeeklyStatistics(weekStartDate: weekStartDate)
        
        // 获取一周的7天数据
        for dayOffset in 0..<7 {
            if let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStartDate) {
                if let dailyStats = getDailyStatistics(for: dayDate) {
                    weekStats.dailyStats.append(dailyStats)
                } else {
                    // 如果没有数据，创建空的统计
                    weekStats.dailyStats.append(DailyStatistics(date: dayDate))
                }
            }
        }
        
        return weekStats
    }
    
    func getRecentEvents(limit: Int = 50) -> [StatisticsEvent] {
        let selectSQL = """
            SELECT * FROM statistics_events 
            ORDER BY timestamp DESC 
            LIMIT ?;
        """
        AppLogger.shared.logSQL(selectSQL, params: [limit], tag: "SELECT recent_events")
        
        var statement: OpaquePointer?
        var events: [StatisticsEvent] = []
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(limit))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let event = parseStatisticsEvent(from: statement!) {
                    events.append(event)
                }
            }
        }
        
        sqlite3_finalize(statement)
        return events
    }
    
    func getEvents(from startDate: Date, to endDate: Date) -> [StatisticsEvent] {
        let selectSQL = """
            SELECT * FROM statistics_events 
            WHERE timestamp >= ? AND timestamp < ?
            ORDER BY timestamp DESC;
        """
        AppLogger.shared.logSQL(selectSQL, params: [Int64(startDate.timeIntervalSince1970), Int64(endDate.timeIntervalSince1970)], tag: "SELECT events_range")
        
        var statement: OpaquePointer?
        var events: [StatisticsEvent] = []
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, Int64(startDate.timeIntervalSince1970))
            sqlite3_bind_int64(statement, 2, Int64(endDate.timeIntervalSince1970))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let event = parseStatisticsEvent(from: statement!) {
                    events.append(event)
                }
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("❌ 查询周事件失败: \(errmsg)")
        }
        
        sqlite3_finalize(statement)
        print("📅 获取到本周事件数量: \(events.count)")
        return events
    }
    
    // MARK: - 数据解析
    
    private func parseDailyStatistics(from statement: OpaquePointer) -> DailyStatistics {
        let dateString = String(cString: sqlite3_column_text(statement, 0))
        let date = DateFormatter.dateKey.date(from: dateString) ?? Date()
        
        var stats = DailyStatistics(date: date)
        stats.completedPomodoros = Int(sqlite3_column_int(statement, 1))
        stats.totalWorkTime = sqlite3_column_double(statement, 2)
        stats.shortBreakCount = Int(sqlite3_column_int(statement, 3))
        stats.longBreakCount = Int(sqlite3_column_int(statement, 4))
        stats.totalBreakTime = sqlite3_column_double(statement, 5)
        stats.cancelledBreakCount = Int(sqlite3_column_int(statement, 6))
        stats.screenLockCount = Int(sqlite3_column_int(statement, 7))
        stats.screensaverCount = Int(sqlite3_column_int(statement, 8))
        stats.stayUpLateCount = Int(sqlite3_column_int(statement, 9))
        // mood_level (index 10)
        if sqlite3_column_type(statement, 10) != SQLITE_NULL {
            stats.moodLevel = Int(sqlite3_column_int(statement, 10))
        }
        // mood_note (index 11)
        if sqlite3_column_type(statement, 11) != SQLITE_NULL, let cStr = sqlite3_column_text(statement, 11) {
            stats.moodNote = String(cString: cStr)
        }
        // mood_updated_at (index 12)
        if sqlite3_column_type(statement, 12) != SQLITE_NULL {
            stats.moodUpdatedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 12))
        }
        // first_activity_time (index 13)
        if sqlite3_column_type(statement, 13) != SQLITE_NULL {
            stats.firstActivityTime = Date(timeIntervalSince1970: sqlite3_column_double(statement, 13))
        }
        // last_activity_time (index 14)
        if sqlite3_column_type(statement, 14) != SQLITE_NULL {
            stats.lastActivityTime = Date(timeIntervalSince1970: sqlite3_column_double(statement, 14))
        }
        
        return stats
    }
    
    private func parseStatisticsEvent(from statement: OpaquePointer) -> StatisticsEvent? {
        guard let eventTypeString = sqlite3_column_text(statement, 1),
              let eventType = StatisticsEventType(rawValue: String(cString: eventTypeString)) else {
            return nil
        }
        
        let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
        let duration = sqlite3_column_type(statement, 3) != SQLITE_NULL ? sqlite3_column_double(statement, 3) : nil
        
        var metadata: [String: Any]? = nil
        if sqlite3_column_type(statement, 4) != SQLITE_NULL,
           let metadataString = sqlite3_column_text(statement, 4) {
            let jsonString = String(cString: metadataString)
            if let jsonData = jsonString.data(using: .utf8) {
                do {
                    metadata = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                } catch {
                    print("❌ 解析事件元数据失败: \(error)")
                }
            }
        }
        
        // 从数据库恢复事件对象，使用正确的ID和时间戳
        let id = String(cString: sqlite3_column_text(statement, 0))
        let event = StatisticsEvent(id: id, eventType: eventType, timestamp: timestamp, duration: duration, metadata: metadata)
        return event
    }
}

// MARK: - 调试扩展
extension StatisticsDatabase {
    /// 统计指定日期某小时的事件类型计数（仅用于调试日志）
    func debugEventTypeCounts(for date: Date, hour: Int) -> [String: Int] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let hourStart = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart),
              let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) else {
            return [:]
        }
        let events = getEvents(from: hourStart, to: hourEnd)
        var counts: [String: Int] = [:]
        for e in events {
            let key = e.eventType.rawValue
            counts[key] = (counts[key] ?? 0) + 1
        }
        return counts
    }
}

// MARK: - DateFormatter扩展

extension DateFormatter {
    static let dateKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}
