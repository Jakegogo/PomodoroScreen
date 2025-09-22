# PomodoroScreen 状态行为表

## 📋 概述

本文档详细记录了 PomodoroScreen 应用在不同状态下的行为表现，包括菜单显示、设置处理、自动启动等功能的具体行为。

## 🔍 状态属性说明

### 核心状态属性

| 属性 | 类型 | 描述 |
|------|------|------|
| `isRunning` | `Bool` | 计时器是否正在运行（`timer != nil && !isPaused`） |
| `isPausedState` | `Bool` | 计时器是否处于暂停状态（传统暂停逻辑） |
| `canResume` | `Bool` | 计时器是否可以继续（包括暂停和停止但未重置状态） |

### 状态机状态

| 状态机状态 | 描述 |
|------------|------|
| `.idle` | 空闲状态，等待事件 |
| `.timerRunning` | 计时器运行中 |
| `.timerPausedByIdle` | 因无操作而暂停 |
| `.timerPausedBySystem` | 因系统事件（锁屏、屏保）而暂停 |
| `.awaitingRestart` | 等待重新启动 |
| `.restPeriod` | 休息期间 |
| `.restTimerRunning` | 休息计时器运行中 |
| `.restTimerPausedBySystem` | 休息计时器因系统事件暂停 |

## 📊 完整状态行为表

| 场景 | 状态机状态 | `isRunning` | `isPausedState` | `canResume` | 菜单显示 | 设置重置剩余时间 | 自动启动 | 备注 |
|------|------------|-------------|-----------------|-------------|----------|------------------|----------|------|
| **全新启动** | `.idle` | `false` | `false` | `false` | "开始" | ✅ 是 | ✅ 是 | `remainingTime == getTotalTime()` |
| **计时器运行中** | `.timerRunning` | `true` | `false` | `false` | "停止" | ❌ 否 | ❌ 否 | 正常计时状态 |
| **手动暂停** | `.timerPausedBySystem` | `false` | `true` | `true` | "继续" | ❌ 否 | ❌ 否 | 用户主动暂停 |
| **无操作暂停** | `.timerPausedByIdle` | `false` | `true` | `true` | "继续" | ❌ 否 | ❌ 否 | 系统检测到无操作 |
| **锁屏暂停** | `.timerPausedBySystem` | `false` | `true` | `true` | "继续" | ❌ 否 | ❌ 否 | 屏幕锁定触发 |
| **屏保暂停** | `.timerPausedBySystem` | `false` | `true` | `true` | "继续" | ❌ 否 | ❌ 否 | 屏保启动触发 |
| **用户停止** | `.idle` | `false` | `false` | `true` | "继续" | ❌ 否 | ❌ 否 | `remainingTime > 0 && remainingTime < getTotalTime()` - 优化后 |
| **重置后** | `.idle` | `false` | `false` | `false` | "开始" | ✅ 是 | ✅ 是 | `remainingTime == getTotalTime()` |
| **休息期间** | `.restPeriod` | `false` | `false` | `false` | "开始" | ✅ 是 | ✅ 是 | 等待用户开始休息 |
| **休息计时中** | `.restTimerRunning` | `true` | `false` | `false` | "停止" | ❌ 否 | ❌ 否 | 休息计时器运行 |

## 🚀 状态优化总结 (v1.0.1)

### 优化目标
解决用户停止计时器后菜单显示和设置行为的不一致问题。

### 主要改进

#### 1. 菜单显示逻辑优化
- **问题**: 用户停止后菜单显示"开始"，但用户期望"继续"
- **解决**: 引入 `canResume` 属性，区分"完全空闲"和"停止但可继续"状态
- **结果**: 停止后菜单正确显示"继续"

#### 2. 设置更新行为优化  
- **问题**: 用户停止后修改设置会重置剩余时间，不符合预期
- **解决**: 修改设置更新逻辑，使用 `canResume` 判断是否保留进度
- **结果**: 停止状态下设置更改不会丢失计时进度

#### 3. 代码可读性提升
- **改进**: 添加详细的状态注释和文档
- **结果**: 状态逻辑更清晰，便于维护和扩展

### 优化前后对比

| 场景 | 优化前菜单 | 优化后菜单 | 优化前设置行为 | 优化后设置行为 |
|------|-----------|-----------|---------------|---------------|
| 用户停止 | "开始" ❌ | "继续" ✅ | 重置剩余时间 ❌ | 保留剩余时间 ✅ |
| 全新启动 | "开始" ✅ | "开始" ✅ | 重置为新时间 ✅ | 重置为新时间 ✅ |
| 暂停状态 | "继续" ✅ | "继续" ✅ | 保留剩余时间 ✅ | 保留剩余时间 ✅ |

## 🎯 关键逻辑说明

### 1. `isPausedState` 判断逻辑

```swift
var isPausedState: Bool {
    let currentState = autoRestartStateMachine.getCurrentState()
    
    // 如果手动暂停或系统暂停，返回true
    if isPaused || currentState == .timerPausedByIdle || currentState == .timerPausedBySystem {
        return true
    }
    
    return false
}
```

**触发条件**：
- `isPaused == true` (手动暂停)
- 状态机处于 `.timerPausedByIdle` (无操作暂停)
- 状态机处于 `.timerPausedBySystem` (系统事件暂停)

### 2. `canResume` 判断逻辑

```swift
var canResume: Bool {
    // 传统暂停状态
    if isPausedState {
        return true
    }
    
    // 停止但未重置状态（idle状态下有剩余时间）
    let currentState = autoRestartStateMachine.getCurrentState()
    if currentState == .idle && remainingTime > 0 && remainingTime < getTotalTime() {
        return true
    }
    
    return false
}
```

**触发条件**：
- 满足 `isPausedState` 的所有条件
- **或者** 状态机处于 `.idle` 且 `remainingTime > 0` 且 `remainingTime < getTotalTime()`

### 3. 菜单显示逻辑

```swift
if pomodoroTimer.isRunning {
    // 计时器正在运行 - 显示"停止"
    title = "停止"
    action = #selector(stopTimer)
} else if pomodoroTimer.canResume {
    // 计时器可以继续（暂停或停止但未重置） - 显示"继续"
    title = "继续"
    action = #selector(startTimer)
} else {
    // 计时器未运行且不可继续 - 显示"开始"
    title = "开始"
    action = #selector(startTimer)
}
```

## 🔄 状态转换流程

### 正常使用流程

```
全新启动 → 开始计时 → 运行中 → 停止 → 可继续 → 继续计时 → 运行中
   ↓                                    ↓
 "开始"                               "继续"
```

### 暂停恢复流程

```
运行中 → 系统暂停 → 暂停状态 → 恢复 → 运行中
         (锁屏/屏保/无操作)
            ↓
          "继续"
```

### 重置流程

```
任意状态 → 重置 → 全新启动
                   ↓
                 "开始"
```

## ⚙️ 设置更新行为

### 剩余时间更新规则

| 条件 | 行为 | 说明 |
|------|------|------|
| `!isRunning && !isPausedState` | 更新为新的番茄钟时间 | 空闲状态，允许重置 |
| `isRunning \|\| isPausedState` | 保持当前剩余时间 | 活跃状态，保持进度 |

**注意**：用户停止状态下，由于 `isPausedState == false`，设置更改会重置剩余时间。

### 自动启动规则

```swift
if autoStart && !wasRunning && !wasPaused {
    startTimer() // 只有完全空闲时才自动启动
}
```

**触发条件**：
- 启用自动启动
- 计时器未运行 (`!wasRunning`)
- 计时器未暂停 (`!wasPaused`)

## 🧪 测试场景

### 基本功能测试

1. **启动 → 停止 → 继续**
   - 验证菜单文字正确显示
   - 验证剩余时间保持

2. **启动 → 暂停 → 继续**
   - 验证系统暂停机制
   - 验证恢复后状态正确

3. **停止 → 设置更改 → 重置确认**
   - 验证设置更改重置剩余时间
   - 验证菜单显示回到"开始"

### 边界条件测试

1. **剩余时间为0时的行为**
2. **状态机异常状态的处理**
3. **快速状态切换的稳定性**

## 📝 设计原则

### 1. 关注点分离
- `isPausedState`：传统暂停逻辑，用于设置和自动启动
- `canResume`：UI显示逻辑，用于菜单文字判断

### 2. 向后兼容
- 保持现有 `isPausedState` 的语义不变
- 不影响现有功能和测试用例

### 3. 用户体验优先
- 停止后显示"继续"而不是"开始"
- 保持设置更新的灵活性

## 🔧 维护注意事项

1. **状态一致性**：确保状态机状态与计时器状态保持同步
2. **测试覆盖**：新增状态需要相应的测试用例
3. **文档更新**：状态变更时及时更新此文档

---

*最后更新：2025年9月22日*  
*版本：v1.0.0*
