## PomodoroScreen Windows Port (C++ 核心逻辑)

本目录是 macOS 版 PomodoroScreen 的 **Windows/C++ 迁移工程雏形**，目标是：

- **无平台依赖地复用核心计时与自动重启状态机逻辑**
- 为后续接入 Windows UI（托盘图标、桌面浮窗、遮罩层、统计视图）提供稳定的业务内核

当前状态（第一阶段）：

- 已完成：
  - `AutoRestartStateMachine`：从 Swift 状态机抽象出的 C++ 版，实现同样的状态/事件/动作模型
  - `PomodoroTimer`：精简版计时器逻辑，支持：
    - 番茄钟/短休息/长休息切换
    - 计时开始/停止/暂停/恢复
    - 与状态机联动的自动重启/熬夜管控接口（Windows 端通过事件回调触发）
  - `main.cpp`：简单的控制台 UI，用于在 Windows 下验证核心逻辑是否正常工作
- 未完成（TODO）：
  - Windows 托盘图标（替代 macOS 状态栏图标）
  - Windows 桌面浮窗（替代 `StatusBarPopupWindow`）
  - 全屏或半透明遮罩层（替代 `OverlayWindow` / `MultiScreenOverlayManager`）
  - 统计与报表 UI

### 架构设计概览

- `AutoRestartStateMachine.[h|cpp]`
  - 移植自 Swift `AutoRestartStateMachine`（`PomodoroScreen/AutoRestartStateMachine.swift`）
  - 保留核心枚举：
    - `AutoRestartState` / `AutoRestartEvent` / `AutoRestartAction` / `TimerType`
  - 对外接口：
    - `processEvent(AutoRestartEvent)`：输入事件，返回需要执行的动作（由上层 Windows UI/壳层决定是否以及如何执行）
    - 一组查询方法：`isInRestPeriod()`、`isInRunningState()` 等
  - **不依赖** Swift / Cocoa / macOS API

- `PomodoroTimer.[h|cpp]`
  - 对应 Swift `PomodoroTimer` 的 **业务子集**：
    - 计时剩余时间、番茄钟/休息切换、长休息周期控制
    - 把屏保、锁屏、无操作等系统事件转成 `AutoRestartEvent` 并交给状态机
  - 完全不直接操作 UI：
    - 通过回调暴露给 UI 层：
      - `onTimeUpdate(std::string)`：每秒更新时间文本
      - `onTimerFinished()`：一次工作阶段完成
      - `onForcedSleepEnded()`：强制睡眠结束

- `main.cpp`
  - 临时控制台壳层：
    - 每秒调用 `tickOneSecond()` 驱动计时逻辑
    - 从标准输入接收 `s/p/r/q` 命令做开始/暂停/继续/退出
  - 用于验证 Windows 编译运行是否正常

### 后续 Windows UI 方案建议

> 下面是针对你提出的 1–4 点需求的 Windows 方向设计建议，具体 UI 框架可以根据你的偏好选择（Win32 / WinUI3 / Qt）。

- **1. Swift → C++ 无损转换**
  - 核心业务逻辑（计时、状态机）已经用 C++ 抽象成平台无关模块
  - 后续如果需要，可以按模块逐步把其他 Swift 逻辑（统计/配置）迁移到 C++

- **2. SwiftUI/AppKit 替换为 Windows 可用库**
  - 推荐两个方向：
    - **Win32 + GDI/D2D**：最原生，但代码量较大，适合追求极致原生体验
    - **Qt 6 (C++)**：跨平台 UI，支持托盘图标、透明窗口、动画，开发效率高
  - 迁移策略：
    - 所有 UI 只通过 `PomodoroTimer` 和未来的统计模块获取数据，不直接操作业务状态

- **3. popup window → Windows 桌面浮窗**
  - 在 Windows 上可以用：
    - 托盘图标 + 小尺寸无边框窗口（置顶），显示当前番茄钟状态和控制按钮
  - 技术选型示例：
    - Win32：使用 `WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_LAYERED` 组合实现桌面浮窗
    - Qt：使用 `Qt::Tool | Qt::WindowStaysOnTopHint | Qt::FramelessWindowHint`

- **4. 遮罩层 / 统计报告**
  - 遮罩层：
    - 使用全屏透明窗口 + 半透明背景 + 文本/动画
    - 多屏可枚举所有显示器，在每个屏幕创建一个全屏窗口（类似 macOS `MultiScreenOverlayManager`）
  - 统计报告：
    - 先在 C++ 里实现统计数据结构与持久化（JSON/SQLite）
    - UI 层用普通窗口（Win32 对话框 / Qt 对话框）展示统计图表

### 如何在 Windows 上编译运行当前示例

```bash
cd Windows
cmake -S . -B build
cmake --build build --config Release
./build/PomodoroScreenWin.exe   # 在 PowerShell / cmd 中运行
```

运行后按提示输入：

- `s`：开始一个 1 分钟的番茄钟
- `p`：暂停
- `r`：继续
- `q`：退出

> 一旦你确认 C++ 逻辑方向 OK，我们可以继续：
> - 选定 Windows UI 技术栈（Win32 或 Qt）
> - 逐步实现：托盘图标 → 桌面浮窗 → 遮罩层 → 统计视图，并保持与 Swift 版行为一致。


