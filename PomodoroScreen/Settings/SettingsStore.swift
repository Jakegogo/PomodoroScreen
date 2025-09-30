//
//  SettingsStore.swift
//  PomodoroScreen
//
//  Created by Assistant on 2025-09-30.
//

import Foundation

/// 集中管理 UserDefaults 读写，统一默认值
final class SettingsStore {
    private init() {}
    
    // MARK: - Keys
    private enum Key: String {
        case pomodoroTimeMinutes = "PomodoroTimeMinutes"
        case breakTimeMinutes = "BreakTimeMinutes"
        case longBreakCycle = "LongBreakCycle"
        case longBreakTimeMinutes = "LongBreakTimeMinutes"
        case meetingModeEnabled = "MeetingModeEnabled"
        // 按需继续补充集中管理的 Key
    }
    
    // MARK: - Typed Accessors with Defaults
    static var pomodoroTimeMinutes: Int {
        get { int(for: .pomodoroTimeMinutes, default: 25) }
        set { setInt(newValue, for: .pomodoroTimeMinutes) }
    }
    
    static var breakTimeMinutes: Int {
        get { int(for: .breakTimeMinutes, default: 3) }
        set { setInt(newValue, for: .breakTimeMinutes) }
    }
    
    static var longBreakCycle: Int {
        get { int(for: .longBreakCycle, default: 2) }
        set { setInt(newValue, for: .longBreakCycle) }
    }
    
    static var longBreakTimeMinutes: Int {
        get { int(for: .longBreakTimeMinutes, default: 5) }
        set { setInt(newValue, for: .longBreakTimeMinutes) }
    }
    
    static var meetingModeEnabled: Bool {
        get { bool(for: .meetingModeEnabled, default: false) }
        set { setBool(newValue, for: .meetingModeEnabled) }
    }
    
    // MARK: - Generic helpers
    private static func int(for key: Key, default def: Int) -> Int {
        let value = UserDefaults.standard.object(forKey: key.rawValue) as? NSNumber
        return value?.intValue ?? def
    }
    private static func setInt(_ value: Int, for key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
    private static func bool(for key: Key, default def: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key.rawValue) == nil { return def }
        return UserDefaults.standard.bool(forKey: key.rawValue)
    }
    private static func setBool(_ value: Bool, for key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}


