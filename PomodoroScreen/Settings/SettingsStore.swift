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
        // Core durations
        case pomodoroTimeMinutes = "PomodoroTimeMinutes"
        case breakTimeMinutes = "BreakTimeMinutes"
        case longBreakCycle = "LongBreakCycle"
        case longBreakTimeMinutes = "LongBreakTimeMinutes"
        // Auto start / status bar
        case autoStartEnabled = "AutoStartEnabled"
        case showStatusBarText = "ShowStatusBarText"
        case launchAtLoginEnabled = "LaunchAtLoginEnabled"
        // Auto handling (idle/screen lock/screensaver)
        case idleRestartEnabled = "IdleRestartEnabled"
        case idleTimeMinutes = "IdleTimeMinutes"
        case idleActionIsRestart = "IdleActionIsRestart"
        case screenLockRestartEnabled = "ScreenLockRestartEnabled"
        case screenLockActionIsRestart = "ScreenLockActionIsRestart"
        case screensaverRestartEnabled = "ScreensaverRestartEnabled"
        case screensaverActionIsRestart = "ScreensaverActionIsRestart"
        // Overlay and plan
        case showCancelRestButton = "ShowCancelRestButton"
        case showLongBreakCancelButton = "ShowLongBreakCancelButton"
        case accumulateRestTime = "AccumulateRestTime"
        // Background resources
        case backgroundFiles = "BackgroundFiles"
        // Stay up limit
        case stayUpLimitEnabled = "StayUpLimitEnabled"
        case stayUpLimitHour = "StayUpLimitHour"
        case stayUpLimitMinute = "StayUpLimitMinute"
        // Meeting mode
        case meetingModeEnabled = "MeetingModeEnabled"
        case meetingModeAutoEnabled = "MeetingModeAutoEnabled"
        // Auto detect screencast
        case autoDetectScreencastEnabled = "AutoDetectScreencastEnabled"
        // Onboarding
        case onboardingCompleted = "OnboardingCompleted"
    }
    
    // MARK: - Typed Accessors with Defaults
    static var autoStartEnabled: Bool {
        get { bool(for: .autoStartEnabled, default: true) }
        set { setBool(newValue, for: .autoStartEnabled) }
    }
    
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
    
    static var meetingModeAutoEnabled: Bool {
        get { bool(for: .meetingModeAutoEnabled, default: false) }
        set { setBool(newValue, for: .meetingModeAutoEnabled) }
    }
    
    static var idleRestartEnabled: Bool {
        get { bool(for: .idleRestartEnabled, default: true) }
        set { setBool(newValue, for: .idleRestartEnabled) }
    }
    
    static var idleTimeMinutes: Int {
        get { int(for: .idleTimeMinutes, default: 5) }
        set { setInt(newValue, for: .idleTimeMinutes) }
    }
    
    static var idleActionIsRestart: Bool {
        get { bool(for: .idleActionIsRestart, default: false) }
        set { setBool(newValue, for: .idleActionIsRestart) }
    }
    
    static var screenLockRestartEnabled: Bool {
        get { bool(for: .screenLockRestartEnabled, default: true) }
        set { setBool(newValue, for: .screenLockRestartEnabled) }
    }
    
    static var screenLockActionIsRestart: Bool {
        get { bool(for: .screenLockActionIsRestart, default: false) }
        set { setBool(newValue, for: .screenLockActionIsRestart) }
    }
    
    static var screensaverRestartEnabled: Bool {
        get { bool(for: .screensaverRestartEnabled, default: true) }
        set { setBool(newValue, for: .screensaverRestartEnabled) }
    }
    
    static var screensaverActionIsRestart: Bool {
        get { bool(for: .screensaverActionIsRestart, default: false) }
        set { setBool(newValue, for: .screensaverActionIsRestart) }
    }
    
    static var showCancelRestButton: Bool {
        get { bool(for: .showCancelRestButton, default: true) }
        set { setBool(newValue, for: .showCancelRestButton) }
    }
    
    static var showLongBreakCancelButton: Bool {
        get { bool(for: .showLongBreakCancelButton, default: false) }
        set { setBool(newValue, for: .showLongBreakCancelButton) }
    }
    
    static var accumulateRestTime: Bool {
        get { bool(for: .accumulateRestTime, default: true) }
        set { setBool(newValue, for: .accumulateRestTime) }
    }
    
    static var backgroundFilesData: Data? {
        get { data(for: .backgroundFiles) }
        set { setData(newValue, for: .backgroundFiles) }
    }
    
    static var stayUpLimitEnabled: Bool {
        get { bool(for: .stayUpLimitEnabled, default: false) }
        set { setBool(newValue, for: .stayUpLimitEnabled) }
    }
    
    static var stayUpLimitHour: Int {
        get { int(for: .stayUpLimitHour, default: 23) }
        set { setInt(newValue, for: .stayUpLimitHour) }
    }
    
    static var stayUpLimitMinute: Int {
        get { int(for: .stayUpLimitMinute, default: 30) }
        set { setInt(newValue, for: .stayUpLimitMinute) }
    }
    
    static var launchAtLoginEnabled: Bool {
        get { bool(for: .launchAtLoginEnabled, default: false) }
        set { setBool(newValue, for: .launchAtLoginEnabled) }
    }
    
    static var showStatusBarText: Bool {
        get { bool(for: .showStatusBarText, default: false) }
        set { setBool(newValue, for: .showStatusBarText) }
    }
    
    static var autoDetectScreencastEnabled: Bool {
        get { bool(for: .autoDetectScreencastEnabled, default: false) }
        set { setBool(newValue, for: .autoDetectScreencastEnabled) }
    }
    
    static var onboardingCompleted: Bool {
        get { bool(for: .onboardingCompleted, default: false) }
        set { setBool(newValue, for: .onboardingCompleted) }
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
    private static func data(for key: Key) -> Data? {
        return UserDefaults.standard.data(forKey: key.rawValue)
    }
    private static func setData(_ value: Data?, for key: Key) {
        if let value = value {
            UserDefaults.standard.set(value, forKey: key.rawValue)
        } else {
            UserDefaults.standard.removeObject(forKey: key.rawValue)
        }
    }
    
    // Utility
    static func remove(_ key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
}


