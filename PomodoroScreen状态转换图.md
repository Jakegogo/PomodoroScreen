# PomodoroScreen 状态转换图

基于代码分析构建的完整状态转换图，展示了番茄钟应用的所有状态转换和交互关系。

## 系统整体架构状态图

```mermaid
graph TB
    %% 应用启动流程
    AppStart([应用启动]) --> LaunchCheck{检查开机自启动}
    LaunchCheck --> OnboardingCheck{检查是否首次启动}
    OnboardingCheck -->|首次启动| OnboardingFlow[新手引导流程]
    OnboardingCheck -->|非首次启动| SystemInit[系统初始化]
    OnboardingFlow --> SystemInit
    
    %% 系统初始化
    SystemInit --> InitTimer[初始化PomodoroTimer]
    SystemInit --> InitStatusBar[初始化StatusBarController]
    SystemInit --> InitScreenDetection[初始化ScreenDetectionManager]
    SystemInit --> LoadSettings[加载用户设置]
    LoadSettings --> ReadyState[系统就绪状态]
    
    %% 系统就绪后的状态分支
    ReadyState --> TimerStateMachine[番茄钟状态机]
    ReadyState --> UIStateMachine[UI状态机]
    ReadyState --> ScreenDetection[屏幕检测状态机]
    ReadyState --> SettingsFlow[设置管理流程]
```

## 核心番茄钟状态机 (PomodoroTimer + AutoRestartStateMachine)

```mermaid
stateDiagram-v2
    [*] --> Idle : 应用启动
    
    %% 番茄钟循环：工作 → 休息 → 工作 → 休息...
    
    %% 主要状态
    Idle --> TimerRunning : start() / processAutoRestartEvent(.timerStarted)
    TimerRunning --> TimerPausedByIdle : 无操作超时 / performPause()
    TimerRunning --> TimerPausedBySystem : 锁屏/屏保 / performPause()
    TimerRunning --> RestPeriod : 番茄钟完成 / timerFinished()
    TimerRunning --> Idle : stop() / processAutoRestartEvent(.timerStopped)
    
    %% 暂停状态的恢复
    TimerPausedByIdle --> TimerRunning : 检测到用户活动 / performResume()或performRestart()
    TimerPausedBySystem --> TimerRunning : 解锁/屏保结束 / performResume()或performRestart()
    TimerPausedByIdle --> Idle : stop() / processAutoRestartEvent(.timerStopped)
    TimerPausedBySystem --> Idle : stop() / processAutoRestartEvent(.timerStopped)
    
    %% 休息期间状态
    RestPeriod --> RestTimerRunning : 开始休息计时 / startShortBreak()或startLongBreak()
    RestPeriod --> Idle : 取消休息 / cancelBreak()
    RestTimerRunning --> RestTimerPausedBySystem : 锁屏/屏保 / performPause()
    RestTimerRunning --> Idle : 休息完成 / timerFinished()
    Idle --> TimerRunning : 自动启动下一个番茄钟 / performStartNextPomodoro()
    RestTimerRunning --> Idle : 取消休息 / cancelBreak()
    RestTimerPausedBySystem --> RestTimerRunning : 解锁/屏保结束 / performResume()或performRestart()
    
    %% 特殊状态：强制睡眠（不可取消）
    TimerRunning --> ForcedSleep : 状态机检测到熬夜时间 / triggerStayUpOverlay()
    RestTimerRunning --> ForcedSleep : 状态机检测到熬夜时间 / triggerStayUpOverlay()
    Idle --> ForcedSleep : 启动时检测到熬夜时间 / triggerStayUpOverlay()
    ForcedSleep --> Idle : 熬夜时间结束（自动退出） / performExitForcedSleep()
    ForcedSleep --> Idle : 屏幕解锁时检测到非熬夜时间 / screenUnlocked + isInStayUpTime()=false
    
    %% 状态内部细节
    state TimerRunning {
        [*] --> PomodoroMode
        PomodoroMode --> [*] : 25分钟完成
    }
    
    state RestTimerRunning {
        [*] --> ShortBreakMode
        [*] --> LongBreakMode
        ShortBreakMode --> [*] : 3-15分钟完成，回到空闲状态
        LongBreakMode --> [*] : 5-30分钟完成，回到空闲状态
    }
```

## UI状态机 (StatusBarController + StatusBarPopupWindow)

```mermaid
stateDiagram-v2
    [*] --> StatusBarReady : 初始化完成
    
    StatusBarReady --> PopupHidden : 默认状态
    PopupHidden --> PopupVisible : 点击状态栏图标 / showPopup()
    PopupVisible --> PopupHidden : 点击外部区域 / hidePopup()
    PopupVisible --> ContextMenuVisible : 点击菜单按钮 / showContextMenu()
    ContextMenuVisible --> PopupHidden : 选择菜单项 / executeMenuAction()
    
    %% 弹窗内部状态
    state PopupVisible {
        [*] --> UpdateHealthRings : 显示弹窗
        UpdateHealthRings --> ShowTimerControls : 更新健康环数据
        ShowTimerControls --> ShowRoundIndicator : 显示控制按钮
        ShowRoundIndicator --> ShowMeetingModeSwitch : 显示轮数指示器
        ShowMeetingModeSwitch --> PopupReady : 显示会议模式开关
        
        PopupReady --> TimerControlAction : 点击控制按钮 / start()或pause()或resume()
        PopupReady --> ResetAction : 点击重置按钮 / reset()
        PopupReady --> MeetingModeToggle : 切换会议模式 / handleMeetingModeSwitchChanged()
        PopupReady --> HealthRingsClick : 点击健康环 / showTodayReport()
        
        TimerControlAction --> PopupReady : 执行操作完成
        ResetAction --> PopupReady : 重置完成
        MeetingModeToggle --> PopupReady : 状态已切换
        HealthRingsClick --> [*] : 跳转到报告页面
    }
    
    %% 会议模式特殊状态
    PopupHidden --> MeetingModeRestIndicator : 会议模式休息开始 / showMeetingModeRestIndicator()
    MeetingModeRestIndicator --> PopupHidden : 会议模式休息结束 / hideMeetingModeRestIndicator()
```

## 遮罩层状态机 (OverlayWindow)

```mermaid
stateDiagram-v2
    [*] --> OverlayHidden : 初始状态
    
    OverlayHidden --> CheckMeetingMode : 计时器完成触发 / onTimerFinished()
    CheckMeetingMode --> MeetingModeRest : 会议模式开启 / showMeetingModeRestIndicator()
    CheckMeetingMode --> CreateOverlay : 会议模式关闭 / showOverlay()
    
    %% 会议模式静默休息
    MeetingModeRest --> OverlayHidden : 休息时间结束 / hideMeetingModeRestIndicator()
    
    %% 正常遮罩层流程
    CreateOverlay --> SetupBackground : 创建遮罩窗口 / OverlayWindow.init()
    SetupBackground --> VideoBackground : 有视频文件 / setupVideoBackground()
    SetupBackground --> ImageBackground : 有图片文件 / setupImageBackground()
    SetupBackground --> DefaultBackground : 无背景文件 / setupDefaultBackground()
    
    VideoBackground --> ShowOverlay : 视频加载完成 / showWithFadeIn()
    ImageBackground --> ShowOverlay : 图片加载完成 / showWithFadeIn()
    DefaultBackground --> ShowOverlay : 使用默认背景 / showWithFadeIn()
    
    ShowOverlay --> OverlayVisible : 淡入动画完成
    
    state OverlayVisible {
        [*] --> ShowMessage : 显示休息消息
        ShowMessage --> MessageFadeOut : 3秒后淡出
        MessageFadeOut --> ShowCancelButton : 显示取消按钮
        ShowCancelButton --> ButtonFadeOut : 3秒后半透明
        ButtonFadeOut --> WaitingForAction : 等待用户操作
        
        WaitingForAction --> ButtonHover : 鼠标悬停 / onMouseEnter()
        ButtonHover --> WaitingForAction : 鼠标离开 / onMouseExit()
        WaitingForAction --> AutoDismiss : 3分钟自动关闭（非强制睡眠） / dismissTimer触发
        WaitingForAction --> UserDismiss : 用户点击取消/ESC键（非强制睡眠） / dismissOverlay()
        WaitingForAction --> ForcedSleepWaiting : 强制睡眠模式 / checkForcedSleepMode()
        
        %% 强制睡眠特殊状态
        state ForcedSleepWaiting {
            [*] --> BlockedInteraction : 禁用所有退出方式
            BlockedInteraction --> BlockedInteraction : ESC键被禁用
            BlockedInteraction --> BlockedInteraction : 取消按钮隐藏
            BlockedInteraction --> BlockedInteraction : 自动关闭禁用
            BlockedInteraction --> [*] : 仅当熬夜时间结束
        }
    }
    
    OverlayVisible --> OverlayHidden : 关闭遮罩层
```

## 熬夜状态管理机 (AutoRestartStateMachine 熬夜功能)

```mermaid
stateDiagram-v2
    [*] --> StayUpMonitoringReady : 状态机初始化
    
    StayUpMonitoringReady --> CheckStayUpEnabled : 检查熬夜限制是否启用
    CheckStayUpEnabled --> MonitoringDisabled : 熬夜限制关闭
    CheckStayUpEnabled --> StartMonitoring : 熬夜限制开启
    
    MonitoringDisabled --> StartMonitoring : 用户启用熬夜限制
    StartMonitoring --> TimeChecking : 开始定时检查
    
    state TimeChecking {
        [*] --> NormalTime : 当前非熬夜时间
        NormalTime --> StayUpTime : 到达熬夜限制时间
        StayUpTime --> NormalTime : 熬夜时间结束
        
        %% 时间检查逻辑
        state StayUpTime {
            [*] --> TriggerForcedSleep : 触发强制睡眠事件
            TriggerForcedSleep --> WaitingForTimeEnd : 等待熬夜时间结束
            WaitingForTimeEnd --> [*] : 时间结束，自动退出
            WaitingForTimeEnd --> [*] : 屏幕解锁时检测到时间已过，立即退出
        }
    }
    
    TimeChecking --> MonitoringDisabled : 用户关闭熬夜限制
    
    %% 状态机回调事件
    note right of TimeChecking : onStayUpTimeChanged(true) → PomodoroTimer.triggerStayUpOverlay()
    note right of TimeChecking : onStayUpTimeChanged(false) → PomodoroTimer.forcedSleepEnded()
```

## 屏幕检测状态机 (ScreenDetectionManager)

```mermaid
stateDiagram-v2
    [*] --> ScreenDetectionReady : 初始化完成
    
    ScreenDetectionReady --> MonitoringScreens : 开始监控
    
    state MonitoringScreens {
        [*] --> SingleScreen : 检测当前屏幕状态
        SingleScreen --> MultipleScreens : 检测到外部屏幕
        MultipleScreens --> SingleScreen : 外部屏幕断开
        
        MultipleScreens --> CheckAutoDetection : 屏幕变化 / handleScreenConfigurationChanged()
        CheckAutoDetection --> EnableMeetingMode : 自动检测开启 / shouldAutoEnableMeetingMode()
        CheckAutoDetection --> IgnoreChange : 自动检测关闭
        
        EnableMeetingMode --> AutoMeetingModeOn : 自动启用会议模式 / enableMeetingModeAutomatically()
        SingleScreen --> CheckAutoDisable : 屏幕断开 / handleScreenConfigurationChanged()
        CheckAutoDisable --> DisableMeetingMode : 是自动启用的 / wasAutoEnabled()
        CheckAutoDisable --> IgnoreChange : 手动启用的
        DisableMeetingMode --> AutoMeetingModeOff : 自动关闭会议模式 / disableMeetingModeAutomatically()
        
        AutoMeetingModeOn --> MultipleScreens : 状态已更新
        AutoMeetingModeOff --> SingleScreen : 状态已更新
        IgnoreChange --> [*] : 无状态变化
    }
```

## 设置管理状态机 (SettingsWindow)

```mermaid
stateDiagram-v2
    [*] --> SettingsHidden : 初始状态
    
    SettingsHidden --> LoadSettings : 用户打开设置 / showSettings()
    LoadSettings --> SettingsVisible : 加载完成 / loadSettings()
    
    state SettingsVisible {
        [*] --> BasicTab : 显示基础设置
        BasicTab --> AutoHandlingTab : 切换标签页 / selectTab()
        AutoHandlingTab --> PlanTab : 切换标签页 / selectTab()
        PlanTab --> BackgroundTab : 切换标签页 / selectTab()
        BackgroundTab --> BasicTab : 切换标签页 / selectTab()
        
        %% 各标签页内部状态
        state BackgroundTab {
            [*] --> BackgroundList : 显示背景列表
            BackgroundList --> AddingFile : 添加文件 / addBackgroundFile()
            BackgroundList --> RemovingFile : 删除文件 / removeBackgroundFile()
            BackgroundList --> PreviewMode : 预览背景 / previewBackground()
            AddingFile --> BackgroundList : 文件已添加
            RemovingFile --> BackgroundList : 文件已删除
            PreviewMode --> BackgroundList : 预览结束 / stopPreview()
        }
    }
    
    SettingsVisible --> ValidateSettings : 点击保存 / saveButtonClicked()
    SettingsVisible --> SettingsHidden : 点击取消 / cancelButtonClicked()
    ValidateSettings --> ApplySettings : 验证通过 / validateSettings()
    ValidateSettings --> SettingsVisible : 验证失败 / showValidationError()
    ApplySettings --> SettingsHidden : 设置已保存 / applySettings()
```

## 数据流和组件交互

```mermaid
graph LR
    %% 数据存储层
    UserDefaults[(UserDefaults<br/>用户设置)]
    StatisticsDB[(StatisticsDatabase<br/>统计数据)]
    
    %% 核心业务层
    PomodoroTimer[PomodoroTimer<br/>核心计时逻辑]
    AutoRestartSM[AutoRestartStateMachine<br/>自动重启状态机]
    StatisticsManager[StatisticsManager<br/>统计管理]
    
    %% UI控制层
    StatusBarController[StatusBarController<br/>状态栏控制]
    StatusBarPopup[StatusBarPopupWindow<br/>弹窗界面]
    OverlayWindow[OverlayWindow<br/>遮罩层]
    SettingsWindow[SettingsWindow<br/>设置界面]
    
    %% 外部服务层
    ScreenDetection[ScreenDetectionManager<br/>屏幕检测]
    LaunchAtLogin[LaunchAtLogin<br/>开机自启动]
    
    %% 数据流向
    UserDefaults --> PomodoroTimer
    UserDefaults --> ScreenDetection
    UserDefaults --> StatusBarController
    
    PomodoroTimer --> AutoRestartSM
    PomodoroTimer --> StatisticsManager
    StatisticsManager --> StatisticsDB
    
    StatusBarController --> StatusBarPopup
    StatusBarController --> OverlayWindow
    StatusBarController --> SettingsWindow
    
    ScreenDetection --> StatusBarController
    ScreenDetection --> UserDefaults
    
    SettingsWindow --> UserDefaults
    SettingsWindow --> LaunchAtLogin
    
    %% 事件流向
    AutoRestartSM -.->|状态变化| PomodoroTimer
    AutoRestartSM -.->|熬夜时间变化| PomodoroTimer
    PomodoroTimer -.->|计时完成| StatusBarController
    StatusBarController -.->|显示遮罩| OverlayWindow
    OverlayWindow -.->|用户操作| PomodoroTimer
    ScreenDetection -.->|屏幕变化| StatusBarController
    StatusBarPopup -.->|用户操作| PomodoroTimer
```

## 关键事件和触发条件

### 计时器事件
- **timerStarted**: 计时器启动
- **timerStopped**: 计时器停止
- **timerPaused**: 计时器暂停
- **pomodoroFinished**: 番茄钟完成 → 触发休息期间
- **restStarted**: 休息开始
- **restFinished**: 休息完成 → 回到空闲状态 → 自动开始下一个番茄钟
- **restCancelled**: 休息被取消 → 回到空闲状态

### 系统事件
- **idleTimeExceeded**: 无操作时间超时
- **userActivityDetected**: 检测到用户活动
- **screenLocked**: 屏幕锁定
- **screenUnlocked**: 屏幕解锁（在强制睡眠状态下会智能检测是否还在熬夜时间）
- **screensaverStarted**: 屏保启动
- **screensaverStopped**: 屏保停止

### 特殊事件
- **forcedSleepTriggered**: 强制睡眠触发（状态机检测到熬夜时间）
- **forcedSleepEnded**: 强制睡眠结束（熬夜时间结束，自动退出）
- **stayUpTimeEntered**: 进入熬夜时间（状态机监控）
- **stayUpTimeExited**: 退出熬夜时间（状态机监控）
- **screenConfigurationChanged**: 屏幕配置变化
- **meetingModeToggled**: 会议模式切换

## 状态持久化

### UserDefaults 存储的状态
- 基础设置：番茄钟时间、休息时间、自动启动等
- 自动处理设置：无操作重启、锁屏处理、屏保处理等
- 计划设置：长休息周期、累积时间等
- 背景设置：背景文件列表和播放参数
- 熬夜限制：启用状态和时间设置（通过状态机管理）
- 会议模式：启用状态和自动检测设置
- 界面设置：状态栏文字显示、开机自启动等

### 运行时状态
- 计时器当前状态和剩余时间
- 已完成的番茄钟次数
- 累积的休息时间
- 当前背景文件索引
- 屏幕检测状态
- 熬夜状态（由状态机管理）
- UI组件的显示状态

## 错误处理和恢复机制

### 自动恢复
- 计时器异常时自动重置到安全状态
- 背景文件加载失败时使用默认背景
- 屏幕检测异常时禁用自动切换
- 设置加载失败时使用默认值
- 强制睡眠状态在屏幕解锁时智能检测时间，自动退出过期的强制睡眠

### 用户干预
- 强制睡眠状态不可被用户取消（仅当熬夜时间结束时自动退出）
- 遮罩层提供ESC键快速退出（强制睡眠期间除外）
- 设置界面提供取消和重置功能
- 状态栏右键菜单提供紧急控制

这个状态转换图展示了PomodoroScreen应用的完整状态管理架构，包括了所有主要组件的状态转换逻辑、数据流向和交互关系。
