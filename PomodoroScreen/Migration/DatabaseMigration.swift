//
//  DatabaseMigration.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-30.
//

import Foundation
import SQLite3

/// 负责对现有数据库执行增量迁移
/// 使用 PRAGMA user_version 管理架构版本
final class DatabaseMigration {
    static let shared = DatabaseMigration()
    private init() {}
    
    /// 最新的数据库版本
    private let latestVersion: Int32 = 2 // v2: 为 daily_statistics 添加 mood_* 字段
    
    func runMigrationsIfNeeded(db: OpaquePointer?) {
        guard let db = db else { return }
        let current = getUserVersion(db: db)
        if current >= latestVersion { return }
        
        // 逐步迁移，确保从任意低版本升级
        var version = current
        if version < 1 {
            // v1: 初始版本（占位，若需要可补充）
            setUserVersion(db: db, version: 1)
            version = 1
        }
        
        if version < 2 {
            migrateToV2_AddMoodColumns(db: db)
            setUserVersion(db: db, version: 2)
            version = 2
        }
    }
    
    // MARK: - v2
    /// 为 daily_statistics 添加心情相关字段：mood_level, mood_note, mood_updated_at
    private func migrateToV2_AddMoodColumns(db: OpaquePointer) {
        // 确保表存在
        guard tableExists(db: db, table: "daily_statistics") else { return }
        
        if !columnExists(db: db, table: "daily_statistics", column: "mood_level") {
            _ = exec(db: db, sql: "ALTER TABLE daily_statistics ADD COLUMN mood_level INTEGER;")
        }
        if !columnExists(db: db, table: "daily_statistics", column: "mood_note") {
            _ = exec(db: db, sql: "ALTER TABLE daily_statistics ADD COLUMN mood_note TEXT;")
        }
        if !columnExists(db: db, table: "daily_statistics", column: "mood_updated_at") {
            _ = exec(db: db, sql: "ALTER TABLE daily_statistics ADD COLUMN mood_updated_at INTEGER;")
        }
    }
    
    // MARK: - Helpers
    private func getUserVersion(db: OpaquePointer) -> Int32 {
        var statement: OpaquePointer?
        var version: Int32 = 0
        if sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                version = sqlite3_column_int(statement, 0)
            }
        }
        sqlite3_finalize(statement)
        return version
    }
    
    private func setUserVersion(db: OpaquePointer, version: Int32) {
        _ = exec(db: db, sql: "PRAGMA user_version = \(version);")
    }
    
    private func tableExists(db: OpaquePointer, table: String) -> Bool {
        var statement: OpaquePointer?
        let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name=?;"
        var exists = false
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, table, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            if sqlite3_step(statement) == SQLITE_ROW { exists = true }
        }
        sqlite3_finalize(statement)
        return exists
    }
    
    private func columnExists(db: OpaquePointer, table: String, column: String) -> Bool {
        var statement: OpaquePointer?
        let pragma = "PRAGMA table_info(\(table));"
        var found = false
        if sqlite3_prepare_v2(db, pragma, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let cName = sqlite3_column_text(statement, 1) {
                    let name = String(cString: cName)
                    if name == column { found = true; break }
                }
            }
        }
        sqlite3_finalize(statement)
        return found
    }
    
    @discardableResult
    private func exec(db: OpaquePointer, sql: String) -> Bool {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            if let cErr = sqlite3_errmsg(db) {
                let err = String(cString: cErr)
                print("❌ Migration SQL failed: \(sql) -> \(err)")
            }
            return false
        }
        return true
    }
}


