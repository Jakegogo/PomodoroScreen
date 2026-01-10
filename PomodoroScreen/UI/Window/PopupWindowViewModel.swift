//
//  PopupWindowViewModel.swift
//  PomodoroScreen
//
//  Created by Assistant on 2026-01-10.
//

import Foundation

/// Snapshot of popup-relevant values at the moment the popup is shown.
struct PopupWindowSnapshot: Equatable {
    /// Ring progress values in 0...1, order: [workIntensity, restAdequacy, focus, health].
    let ringProgress: [Double]
    let completedPomodoros: Int
    let totalWorkTime: TimeInterval
    let totalBreakTime: TimeInterval
    let healthScore: Double
}

struct PopupWindowDiff {
    /// Per-ring change flags, same order as `PopupWindowSnapshot.ringProgress`.
    let ringChanged: [Bool]
    /// Bottom metrics changed flags, order: [pomodoros, workTime, breakTime, healthScore].
    let metricChanged: [Bool]
}

/// ViewModel to decide which values changed between the last popup show and the current show.
final class PopupWindowViewModel {
    private(set) var lastShownSnapshot: PopupWindowSnapshot?
    
    func diffAndStoreForShow(current: PopupWindowSnapshot) -> PopupWindowDiff {
        let previous = lastShownSnapshot
        lastShownSnapshot = current
        return diff(previous: previous, current: current)
    }
    
    private func diff(previous: PopupWindowSnapshot?, current: PopupWindowSnapshot) -> PopupWindowDiff {
        guard let previous else {
            return PopupWindowDiff(
                ringChanged: Array(repeating: true, count: max(4, current.ringProgress.count)),
                metricChanged: [true, true, true, true]
            )
        }
        
        let eps = 0.001
        let ringCount = min(previous.ringProgress.count, current.ringProgress.count)
        var ringChanged = Array(repeating: true, count: max(previous.ringProgress.count, current.ringProgress.count))
        for i in 0..<ringCount {
            ringChanged[i] = abs(previous.ringProgress[i] - current.ringProgress[i]) > eps
        }
        
        let metricChanged: [Bool] = [
            previous.completedPomodoros != current.completedPomodoros,
            Int(previous.totalWorkTime) != Int(current.totalWorkTime),
            Int(previous.totalBreakTime) != Int(current.totalBreakTime),
            Int(round(previous.healthScore)) != Int(round(current.healthScore))
        ]
        
        return PopupWindowDiff(ringChanged: ringChanged, metricChanged: metricChanged)
    }
}

