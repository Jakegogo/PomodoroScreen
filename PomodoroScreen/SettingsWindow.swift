import Cocoa
import UniformTypeIdentifiers
import AVFoundation
import ServiceManagement

class SettingsWindow: NSWindow {
    
    // 标签页控件
    private var tabView: NSTabView!
    
    // 基础设置 UI 控件
    private var autoStartCheckbox: NSButton!
    private var pomodoroTimeSlider: NSSlider!
    private var pomodoroTimeLabel: NSTextField!
    private var breakTimeSlider: NSSlider!
    private var breakTimeLabel: NSTextField!
    private var showCancelRestButtonCheckbox: NSButton!
    
    // 熬夜限制设置 UI 控件
    private var stayUpLimitCheckbox: NSButton!
    private var stayUpHourPopUpButton: NSPopUpButton!
    private var stayUpMinutePopUpButton: NSPopUpButton!
    private var stayUpTimeLabel: NSTextField!
    private var stayUpColonLabel: NSTextField!
    
    // 开机自启动设置 UI 控件
    private var launchAtLoginCheckbox: NSButton!
    
    // 自动处理设置 UI 控件
    private var idleRestartCheckbox: NSButton!
    private var idleTimeSlider: NSSlider!
    private var idleTimeLabel: NSTextField!
    private var idleActionSegmentedControl: NSSegmentedControl!
    private var screenLockRestartCheckbox: NSButton!
    private var screenLockActionSegmentedControl: NSSegmentedControl!
    private var screensaverRestartCheckbox: NSButton!
    private var screensaverActionSegmentedControl: NSSegmentedControl!
    
    // 计划设置 UI 控件
    private var longBreakCycleSlider: NSSlider!
    private var longBreakCycleLabel: NSTextField!
    private var longBreakTimeSlider: NSSlider!
    private var longBreakTimeLabel: NSTextField!
    private var showLongBreakCancelButtonCheckbox: NSButton!
    private var accumulateRestTimeCheckbox: NSButton!
    
    // 背景设置 UI 控件
    private var backgroundFilesList: NSTableView!
    private var backgroundScrollView: NSScrollView!
    private var addImageButton: NSButton!
    private var addVideoButton: NSButton!
    private var removeBackgroundButton: NSButton!
    private var moveUpButton: NSButton!
    private var moveDownButton: NSButton!
    private var backgroundTypeLabel: NSTextField!
    
    // 通用控件
    private var saveButton: NSButton!
    private var cancelButton: NSButton!
    
    // 设置值
    var autoStartEnabled: Bool = true
    var pomodoroTimeMinutes: Int = 25
    var breakTimeMinutes: Int = 3
    var idleRestartEnabled: Bool = false
    var idleTimeMinutes: Int = 10
    var idleActionIsRestart: Bool = true // true: 重新计时, false: 暂停计时
    var screenLockRestartEnabled: Bool = false
    var screenLockActionIsRestart: Bool = true // true: 重新计时, false: 暂停计时
    var screensaverRestartEnabled: Bool = false
    var screensaverActionIsRestart: Bool = true // true: 重新计时, false: 暂停计时
    var showCancelRestButton: Bool = true // 是否显示取消休息按钮
    
    // 计划设置值
    var longBreakCycle: Int = 2 // 间隔N次后进行长休息
    var longBreakTimeMinutes: Int = 5 // 长休息时间（分钟）
    var showLongBreakCancelButton: Bool = true // 长休息是否显示取消按钮
    var accumulateRestTime: Bool = false // 是否将短休息中断后的时间累加到长休息
    
    // 背景设置值
    var backgroundFiles: [BackgroundFile] = [] // 背景文件列表
    
    // 熬夜限制设置值
    var stayUpLimitEnabled: Bool = false // 是否启用熬夜限制
    var stayUpLimitHour: Int = 23 // 熬夜限制小时（21-1）
    var stayUpLimitMinute: Int = 0 // 熬夜限制分钟（0, 15, 30, 45）
    
    // 开机自启动设置值
    var launchAtLoginEnabled: Bool = false // 是否启用开机自启动
    
    // 回调
    var onSettingsChanged: ((Bool, Int, Int, Bool, Int, Bool, Bool, Bool, Bool, Bool, Bool, Int, Int, Bool, Bool, [BackgroundFile], Bool, Int, Int) -> Void)?
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupWindow()
        setupUI()
        loadSettings()
    }
    
    private func setupWindow() {
        title = "番茄钟设置"
        isReleasedWhenClosed = false
        level = .floating
        styleMask = [.titled, .closable]
        
        // 设置窗口大小和位置（增加高度以适应标签页）
        setContentSize(NSSize(width: 480, height: 580))
        center()
    }
    
    private func setupUI() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 580))
        self.contentView = contentView
        
        // 创建标签页视图
        tabView = NSTabView(frame: NSRect(x: 20, y: 60, width: 440, height: 500))
        contentView.addSubview(tabView)
        
        // 创建四个标签页
        setupBasicSettingsTab()
        setupAutoHandlingTab()
        setupPlanTab()
        setupBackgroundTab()
        
        // 添加保存和取消按钮
        setupButtons(in: contentView)
    }
    
    // MARK: - 标签页设置方法
    
    private func setupBasicSettingsTab() {
        let basicTabItem = NSTabViewItem(identifier: "basic")
        basicTabItem.label = "基础设置"
        
        let basicView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 460))
        basicTabItem.view = basicView
        
        var yPosition = 400
        
        // 自动启动设置
        autoStartCheckbox = NSButton(checkboxWithTitle: "启动应用时自动开始番茄钟", target: self, action: #selector(autoStartChanged))
        autoStartCheckbox.frame = NSRect(x: 20, y: yPosition, width: 340, height: 25)
        autoStartCheckbox.state = autoStartEnabled ? .on : .off
        basicView.addSubview(autoStartCheckbox)
        yPosition -= 50
        
        // 番茄钟时间设置
        let pomodoroLabel = NSTextField(labelWithString: "番茄钟时间:")
        pomodoroLabel.frame = NSRect(x: 20, y: yPosition, width: 100, height: 20)
        basicView.addSubview(pomodoroLabel)
        
        pomodoroTimeSlider = NSSlider(frame: NSRect(x: 130, y: yPosition, width: 180, height: 20))
        pomodoroTimeSlider.minValue = 15
        pomodoroTimeSlider.maxValue = 60
        pomodoroTimeSlider.integerValue = pomodoroTimeMinutes
        pomodoroTimeSlider.target = self
        pomodoroTimeSlider.action = #selector(pomodoroTimeChanged)
        basicView.addSubview(pomodoroTimeSlider)
        
        pomodoroTimeLabel = NSTextField(labelWithString: "\(pomodoroTimeMinutes) 分钟")
        pomodoroTimeLabel.frame = NSRect(x: 320, y: yPosition, width: 80, height: 20)
        pomodoroTimeLabel.alignment = .center
        basicView.addSubview(pomodoroTimeLabel)
        yPosition -= 40
        
        // 休息时间设置
        let breakLabel = NSTextField(labelWithString: "短休息时间:")
        breakLabel.frame = NSRect(x: 20, y: yPosition, width: 100, height: 20)
        basicView.addSubview(breakLabel)
        
        breakTimeSlider = NSSlider(frame: NSRect(x: 130, y: yPosition, width: 180, height: 20))
        breakTimeSlider.minValue = 1
        breakTimeSlider.maxValue = 15
        breakTimeSlider.integerValue = breakTimeMinutes
        breakTimeSlider.target = self
        breakTimeSlider.action = #selector(breakTimeChanged)
        basicView.addSubview(breakTimeSlider)
        
        breakTimeLabel = NSTextField(labelWithString: "\(breakTimeMinutes) 分钟")
        breakTimeLabel.frame = NSRect(x: 320, y: yPosition, width: 80, height: 20)
        breakTimeLabel.alignment = .center
        basicView.addSubview(breakTimeLabel)
        yPosition -= 50
        
        // 取消休息按钮显示设置
        showCancelRestButtonCheckbox = NSButton(checkboxWithTitle: "在短休息遮罩层显示取消休息按钮", target: self, action: #selector(showCancelRestButtonChanged))
        showCancelRestButtonCheckbox.frame = NSRect(x: 20, y: yPosition, width: 340, height: 25)
        showCancelRestButtonCheckbox.state = showCancelRestButton ? .on : .off
        basicView.addSubview(showCancelRestButtonCheckbox)
        yPosition -= 50
        
        // 开机自启动设置
        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "开机时自动启动应用", target: self, action: #selector(launchAtLoginChanged))
        launchAtLoginCheckbox.frame = NSRect(x: 20, y: yPosition, width: 200, height: 25)
        launchAtLoginCheckbox.state = launchAtLoginEnabled ? .on : .off
        basicView.addSubview(launchAtLoginCheckbox)
        
        tabView.addTabViewItem(basicTabItem)
    }
    
    private func setupAutoHandlingTab() {
        let autoTabItem = NSTabViewItem(identifier: "auto")
        autoTabItem.label = "自动处理"
        
        let autoView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 460))
        autoTabItem.view = autoView
        
        var yPosition = 400
        
        // 无操作自动重新计时设置
        idleRestartCheckbox = NSButton(checkboxWithTitle: "无操作时自动处理", target: self, action: #selector(idleRestartChanged))
        idleRestartCheckbox.frame = NSRect(x: 20, y: yPosition, width: 200, height: 25)
        idleRestartCheckbox.state = idleRestartEnabled ? .on : .off
        autoView.addSubview(idleRestartCheckbox)
        
        idleActionSegmentedControl = NSSegmentedControl(labels: ["重新计时", "暂停计时"], trackingMode: .selectOne, target: self, action: #selector(idleActionChanged))
        idleActionSegmentedControl.frame = NSRect(x: 240, y: yPosition, width: 150, height: 25)
        idleActionSegmentedControl.selectedSegment = idleActionIsRestart ? 0 : 1
        idleActionSegmentedControl.isEnabled = idleRestartEnabled
        autoView.addSubview(idleActionSegmentedControl)
        yPosition -= 40
        
        let idleLabel = NSTextField(labelWithString: "无操作时间:")
        idleLabel.frame = NSRect(x: 40, y: yPosition, width: 100, height: 20)
        autoView.addSubview(idleLabel)
        
        idleTimeSlider = NSSlider(frame: NSRect(x: 150, y: yPosition, width: 160, height: 20))
        idleTimeSlider.minValue = 5
        idleTimeSlider.maxValue = 30
        idleTimeSlider.integerValue = idleTimeMinutes
        idleTimeSlider.target = self
        idleTimeSlider.action = #selector(idleTimeChanged)
        idleTimeSlider.isEnabled = idleRestartEnabled
        autoView.addSubview(idleTimeSlider)
        
        idleTimeLabel = NSTextField(labelWithString: "\(idleTimeMinutes) 分钟")
        idleTimeLabel.frame = NSRect(x: 320, y: yPosition, width: 80, height: 20)
        idleTimeLabel.alignment = .center
        autoView.addSubview(idleTimeLabel)
        yPosition -= 60
        
        // 屏保自动重新计时设置 - 移到第二位
        screensaverRestartCheckbox = NSButton(checkboxWithTitle: "进入屏保时自动处理", target: self, action: #selector(screensaverRestartChanged))
        screensaverRestartCheckbox.frame = NSRect(x: 20, y: yPosition, width: 200, height: 25)
        screensaverRestartCheckbox.state = screensaverRestartEnabled ? .on : .off
        autoView.addSubview(screensaverRestartCheckbox)
        
        screensaverActionSegmentedControl = NSSegmentedControl(labels: ["重新计时", "暂停计时"], trackingMode: .selectOne, target: self, action: #selector(screensaverActionChanged))
        screensaverActionSegmentedControl.frame = NSRect(x: 240, y: yPosition, width: 150, height: 25)
        screensaverActionSegmentedControl.selectedSegment = screensaverActionIsRestart ? 0 : 1
        screensaverActionSegmentedControl.isEnabled = screensaverRestartEnabled
        autoView.addSubview(screensaverActionSegmentedControl)
        yPosition -= 60
        
        // 锁屏自动重新计时设置 - 移到第三位
        screenLockRestartCheckbox = NSButton(checkboxWithTitle: "进入锁屏时自动处理", target: self, action: #selector(screenLockRestartChanged))
        screenLockRestartCheckbox.frame = NSRect(x: 20, y: yPosition, width: 200, height: 25)
        screenLockRestartCheckbox.state = screenLockRestartEnabled ? .on : .off
        autoView.addSubview(screenLockRestartCheckbox)
        
        screenLockActionSegmentedControl = NSSegmentedControl(labels: ["重新计时", "暂停计时"], trackingMode: .selectOne, target: self, action: #selector(screenLockActionChanged))
        screenLockActionSegmentedControl.frame = NSRect(x: 240, y: yPosition, width: 150, height: 25)
        screenLockActionSegmentedControl.selectedSegment = screenLockActionIsRestart ? 0 : 1
        screenLockActionSegmentedControl.isEnabled = screenLockRestartEnabled
        autoView.addSubview(screenLockActionSegmentedControl)
        
        tabView.addTabViewItem(autoTabItem)
    }
    
    private func setupPlanTab() {
        let planTabItem = NSTabViewItem(identifier: "plan")
        planTabItem.label = "计划"
        
        let planView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 460))
        planTabItem.view = planView
        
        var yPosition = 400
        
        // 长休息周期设置
        let cycleLabel = NSTextField(labelWithString: "长休息周期:")
        cycleLabel.frame = NSRect(x: 20, y: yPosition, width: 100, height: 20)
        planView.addSubview(cycleLabel)
        
        longBreakCycleSlider = NSSlider(frame: NSRect(x: 130, y: yPosition, width: 180, height: 20))
        longBreakCycleSlider.minValue = 2
        longBreakCycleSlider.maxValue = 10
        longBreakCycleSlider.integerValue = longBreakCycle
        longBreakCycleSlider.target = self
        longBreakCycleSlider.action = #selector(longBreakCycleChanged)
        planView.addSubview(longBreakCycleSlider)
        
        longBreakCycleLabel = NSTextField(labelWithString: "每 \(longBreakCycle) 次")
        longBreakCycleLabel.frame = NSRect(x: 320, y: yPosition, width: 80, height: 20)
        longBreakCycleLabel.alignment = .center
        planView.addSubview(longBreakCycleLabel)
        yPosition -= 40
        
        // 长休息时间设置
        let longBreakLabel = NSTextField(labelWithString: "长休息时间:")
        longBreakLabel.frame = NSRect(x: 20, y: yPosition, width: 100, height: 20)
        planView.addSubview(longBreakLabel)
        
        longBreakTimeSlider = NSSlider(frame: NSRect(x: 130, y: yPosition, width: 180, height: 20))
        longBreakTimeSlider.minValue = 5
        longBreakTimeSlider.maxValue = 30
        longBreakTimeSlider.integerValue = longBreakTimeMinutes
        longBreakTimeSlider.target = self
        longBreakTimeSlider.action = #selector(longBreakTimeChanged)
        planView.addSubview(longBreakTimeSlider)
        
        longBreakTimeLabel = NSTextField(labelWithString: "\(longBreakTimeMinutes) 分钟")
        longBreakTimeLabel.frame = NSRect(x: 320, y: yPosition, width: 80, height: 20)
        longBreakTimeLabel.alignment = .center
        planView.addSubview(longBreakTimeLabel)
        yPosition -= 50
        
        // 长休息取消按钮设置
        showLongBreakCancelButtonCheckbox = NSButton(checkboxWithTitle: "在长休息遮罩层显示取消休息按钮", target: self, action: #selector(showLongBreakCancelButtonChanged))
        showLongBreakCancelButtonCheckbox.frame = NSRect(x: 20, y: yPosition, width: 340, height: 25)
        showLongBreakCancelButtonCheckbox.state = showLongBreakCancelButton ? .on : .off
        planView.addSubview(showLongBreakCancelButtonCheckbox)
        yPosition -= 50
        
        // 累加休息时间设置
        accumulateRestTimeCheckbox = NSButton(checkboxWithTitle: "将短休息中断后的剩余时间累加到长休息", target: self, action: #selector(accumulateRestTimeChanged))
        accumulateRestTimeCheckbox.frame = NSRect(x: 20, y: yPosition, width: 340, height: 25)
        accumulateRestTimeCheckbox.state = accumulateRestTime ? .on : .off
        planView.addSubview(accumulateRestTimeCheckbox)
        yPosition -= 50
        
        // 熬夜限制设置 - 移到计划标签页
        stayUpLimitCheckbox = NSButton(checkboxWithTitle: "启用熬夜限制（强制休息）", target: self, action: #selector(stayUpLimitChanged))
        stayUpLimitCheckbox.frame = NSRect(x: 20, y: yPosition, width: 200, height: 25)
        stayUpLimitCheckbox.state = stayUpLimitEnabled ? .on : .off
        planView.addSubview(stayUpLimitCheckbox)
        yPosition -= 35
        
        // 熬夜时间设置
        stayUpTimeLabel = NSTextField(labelWithString: "最晚时间:")
        stayUpTimeLabel.frame = NSRect(x: 40, y: yPosition, width: 80, height: 20)
        planView.addSubview(stayUpTimeLabel)
        
        // 小时选择 - 只显示数字
        stayUpHourPopUpButton = NSPopUpButton(frame: NSRect(x: 130, y: yPosition - 2, width: 60, height: 25))
        stayUpHourPopUpButton.target = self
        stayUpHourPopUpButton.action = #selector(stayUpTimeChanged)
        
        // 添加21-01的小时选项，只显示数字
        for hour in 21...23 {
            stayUpHourPopUpButton.addItem(withTitle: String(format: "%02d", hour))
        }
        for hour in 0...1 {
            stayUpHourPopUpButton.addItem(withTitle: String(format: "%02d", hour))
        }
        
        // 设置当前选中的小时
        if stayUpLimitHour >= 21 {
            stayUpHourPopUpButton.selectItem(at: stayUpLimitHour - 21)
        } else {
            stayUpHourPopUpButton.selectItem(at: stayUpLimitHour + 3)
        }
        
        planView.addSubview(stayUpHourPopUpButton)
        
        // 冒号标签
        stayUpColonLabel = NSTextField(labelWithString: ":")
        stayUpColonLabel.frame = NSRect(x: 195, y: yPosition, width: 10, height: 20)
        stayUpColonLabel.alignment = .center
        stayUpColonLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        planView.addSubview(stayUpColonLabel)
        
        // 分钟选择 - 只显示数字
        stayUpMinutePopUpButton = NSPopUpButton(frame: NSRect(x: 210, y: yPosition - 2, width: 60, height: 25))
        stayUpMinutePopUpButton.target = self
        stayUpMinutePopUpButton.action = #selector(stayUpTimeChanged)
        
        // 添加0, 15, 30, 45分钟选项，只显示数字
        let minutes = [0, 15, 30, 45]
        for minute in minutes {
            stayUpMinutePopUpButton.addItem(withTitle: String(format: "%02d", minute))
        }
        
        // 设置当前选中的分钟
        if let minuteIndex = minutes.firstIndex(of: stayUpLimitMinute) {
            stayUpMinutePopUpButton.selectItem(at: minuteIndex)
        }
        
        planView.addSubview(stayUpMinutePopUpButton)
        
        // 根据启用状态设置控件可用性
        updateStayUpControlsEnabled()
        
        tabView.addTabViewItem(planTabItem)
    }
    
    private func setupBackgroundTab() {
        let backgroundTabItem = NSTabViewItem(identifier: "background")
        backgroundTabItem.label = "背景"
        
        let backgroundView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 460))
        backgroundTabItem.view = backgroundView
        
        var yPosition = 420
        
        // 标题
        backgroundTypeLabel = NSTextField(labelWithString: "遮罩层背景文件")
        backgroundTypeLabel.font = NSFont.boldSystemFont(ofSize: 14)
        backgroundTypeLabel.frame = NSRect(x: 20, y: yPosition, width: 200, height: 20)
        backgroundView.addSubview(backgroundTypeLabel)
        yPosition -= 30
        
        // 文件列表
        backgroundScrollView = NSScrollView(frame: NSRect(x: 20, y: yPosition - 200, width: 280, height: 200))
        backgroundScrollView.hasVerticalScroller = true
        backgroundScrollView.hasHorizontalScroller = false
        backgroundScrollView.borderType = .bezelBorder
        
        backgroundFilesList = NSTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("BackgroundFile"))
        column.title = "背景文件"
        column.width = 260
        backgroundFilesList.addTableColumn(column)
        backgroundFilesList.headerView = nil
        backgroundFilesList.delegate = self
        backgroundFilesList.dataSource = self
        
        backgroundScrollView.documentView = backgroundFilesList
        backgroundView.addSubview(backgroundScrollView)
        
        // 按钮组
        let buttonX = 320
        var buttonY = yPosition - 20
        
        addImageButton = NSButton(title: "添加图片", target: self, action: #selector(addImageBackground))
        addImageButton.frame = NSRect(x: buttonX, y: buttonY, width: 80, height: 32)
        addImageButton.bezelStyle = .rounded
        backgroundView.addSubview(addImageButton)
        buttonY -= 40
        
        addVideoButton = NSButton(title: "添加视频", target: self, action: #selector(addVideoBackground))
        addVideoButton.frame = NSRect(x: buttonX, y: buttonY, width: 80, height: 32)
        addVideoButton.bezelStyle = .rounded
        backgroundView.addSubview(addVideoButton)
        buttonY -= 40
        
        removeBackgroundButton = NSButton(title: "删除", target: self, action: #selector(removeBackground))
        removeBackgroundButton.frame = NSRect(x: buttonX, y: buttonY, width: 80, height: 32)
        removeBackgroundButton.bezelStyle = .rounded
        backgroundView.addSubview(removeBackgroundButton)
        buttonY -= 40
        
        moveUpButton = NSButton(title: "上移", target: self, action: #selector(moveBackgroundUp))
        moveUpButton.frame = NSRect(x: buttonX, y: buttonY, width: 80, height: 32)
        moveUpButton.bezelStyle = .rounded
        backgroundView.addSubview(moveUpButton)
        buttonY -= 40
        
        moveDownButton = NSButton(title: "下移", target: self, action: #selector(moveBackgroundDown))
        moveDownButton.frame = NSRect(x: buttonX, y: buttonY, width: 80, height: 32)
        moveDownButton.bezelStyle = .rounded
        backgroundView.addSubview(moveDownButton)
        
        // 说明文字
        let infoLabel = NSTextField(labelWithString: "支持图片格式：jpg, png, gif\n支持视频格式：mp4, mov, avi\n多个文件将按顺序轮播显示")
        infoLabel.frame = NSRect(x: 20, y: 50, width: 380, height: 60)
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = NSColor.secondaryLabelColor
        backgroundView.addSubview(infoLabel)
        
        tabView.addTabViewItem(backgroundTabItem)
    }
    
    private func setupButtons(in contentView: NSView) {
        // 保存和取消按钮
        saveButton = NSButton(title: "保存", target: self, action: #selector(saveSettings))
        saveButton.frame = NSRect(x: 280, y: 20, width: 80, height: 32)
        saveButton.bezelStyle = .rounded
        contentView.addSubview(saveButton)
        
        cancelButton = NSButton(title: "取消", target: self, action: #selector(cancelSettings))
        cancelButton.frame = NSRect(x: 180, y: 20, width: 80, height: 32)
        cancelButton.bezelStyle = .rounded
        contentView.addSubview(cancelButton)
        
        // 设置默认按钮
        defaultButtonCell = saveButton.cell as? NSButtonCell
    }
    
    // MARK: - 事件处理方法
    
    @objc private func autoStartChanged() {
        autoStartEnabled = autoStartCheckbox.state == .on
    }
    
    @objc private func pomodoroTimeChanged() {
        pomodoroTimeMinutes = pomodoroTimeSlider.integerValue
        pomodoroTimeLabel.stringValue = "\(pomodoroTimeMinutes) 分钟"
    }
    
    @objc private func breakTimeChanged() {
        breakTimeMinutes = breakTimeSlider.integerValue
        breakTimeLabel.stringValue = "\(breakTimeMinutes) 分钟"
    }
    
    @objc private func idleRestartChanged() {
        idleRestartEnabled = idleRestartCheckbox.state == .on
        idleTimeSlider.isEnabled = idleRestartEnabled
        idleActionSegmentedControl.isEnabled = idleRestartEnabled
    }
    
    @objc private func idleActionChanged() {
        idleActionIsRestart = idleActionSegmentedControl.selectedSegment == 0
    }
    
    @objc private func idleTimeChanged() {
        idleTimeMinutes = idleTimeSlider.integerValue
        idleTimeLabel.stringValue = "\(idleTimeMinutes) 分钟"
    }
    
    @objc private func screenLockRestartChanged() {
        screenLockRestartEnabled = screenLockRestartCheckbox.state == .on
        screenLockActionSegmentedControl.isEnabled = screenLockRestartEnabled
    }
    
    @objc private func screenLockActionChanged() {
        screenLockActionIsRestart = screenLockActionSegmentedControl.selectedSegment == 0
    }
    
    @objc private func screensaverRestartChanged() {
        screensaverRestartEnabled = screensaverRestartCheckbox.state == .on
        screensaverActionSegmentedControl.isEnabled = screensaverRestartEnabled
    }
    
    @objc private func screensaverActionChanged() {
        screensaverActionIsRestart = screensaverActionSegmentedControl.selectedSegment == 0
    }
    
    @objc private func showCancelRestButtonChanged() {
        showCancelRestButton = showCancelRestButtonCheckbox.state == .on
    }
    
    // MARK: - 计划设置事件处理方法
    
    @objc private func longBreakCycleChanged() {
        longBreakCycle = longBreakCycleSlider.integerValue
        longBreakCycleLabel.stringValue = "每 \(longBreakCycle) 次"
    }
    
    @objc private func longBreakTimeChanged() {
        longBreakTimeMinutes = longBreakTimeSlider.integerValue
        longBreakTimeLabel.stringValue = "\(longBreakTimeMinutes) 分钟"
    }
    
    @objc private func showLongBreakCancelButtonChanged() {
        showLongBreakCancelButton = showLongBreakCancelButtonCheckbox.state == .on
    }
    
    @objc private func accumulateRestTimeChanged() {
        accumulateRestTime = accumulateRestTimeCheckbox.state == .on
    }
    
    @objc private func stayUpLimitChanged() {
        stayUpLimitEnabled = stayUpLimitCheckbox.state == .on
        updateStayUpControlsEnabled()
    }
    
    @objc private func stayUpTimeChanged() {
        // 获取选中的小时
        let selectedHourIndex = stayUpHourPopUpButton.indexOfSelectedItem
        if selectedHourIndex < 3 {
            // 21:00-23:00
            stayUpLimitHour = 21 + selectedHourIndex
        } else {
            // 00:00-01:00
            stayUpLimitHour = selectedHourIndex - 3
        }
        
        // 获取选中的分钟
        let minutes = [0, 15, 30, 45]
        let selectedMinuteIndex = stayUpMinutePopUpButton.indexOfSelectedItem
        if selectedMinuteIndex < minutes.count {
            stayUpLimitMinute = minutes[selectedMinuteIndex]
        }
    }
    
    private func updateStayUpControlsEnabled() {
        let enabled = stayUpLimitEnabled
        stayUpTimeLabel.isEnabled = enabled
        stayUpHourPopUpButton.isEnabled = enabled
        stayUpColonLabel.isEnabled = enabled
        stayUpMinutePopUpButton.isEnabled = enabled
    }
    
    @objc private func launchAtLoginChanged() {
        launchAtLoginEnabled = launchAtLoginCheckbox.state == .on
        
        // 立即应用开机自启动设置
        LaunchAtLogin.shared.isEnabled = launchAtLoginEnabled
        
        // 延迟验证设置状态，给系统时间处理权限请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.validateLaunchAtLoginStatus()
        }
    }
    
    /// 验证开机自启动设置状态
    private func validateLaunchAtLoginStatus() {
        let status = LaunchAtLogin.shared.validateStatus()
        
        print("🔍 开机自启动状态验证: \(status.message)")
        
        // 检查是否需要用户批准
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if service.status == .requiresApproval {
                // 需要用户批准，显示指导信息
                showLaunchAtLoginAlert(
                    success: false, 
                    message: "需要用户批准开机自启动权限",
                    showSystemPreferences: true
                )
                return
            }
        }
        
        // 检查设置是否与预期一致
        if status.enabled != launchAtLoginEnabled {
            // 设置可能失败，显示警告
            showLaunchAtLoginAlert(
                success: false, 
                message: status.message,
                showSystemPreferences: true
            )
        } else {
            print("✅ 开机自启动设置验证成功: \(launchAtLoginEnabled)")
            
            // 如果是首次成功设置，可以显示成功提示
            if launchAtLoginEnabled {
                showLaunchAtLoginAlert(
                    success: true, 
                    message: "开机自启动已成功启用",
                    showSystemPreferences: false
                )
            }
        }
    }
    
    /// 显示开机自启动设置结果提示
    private func showLaunchAtLoginAlert(success: Bool, message: String, showSystemPreferences: Bool = true) {
        let alert = NSAlert()
        alert.messageText = success ? "设置成功" : "权限请求"
        
        if success {
            alert.informativeText = message
            alert.alertStyle = .informational
        } else {
            // 根据macOS版本提供不同的指导信息
            var instructions = ""
            if #available(macOS 13.0, *) {
                instructions = """
                \(message)
                
                请按以下步骤操作：
                1. 打开"系统设置" > "常规" > "登录项"
                2. 在"允许在后台"部分找到PomodoroScreen
                3. 确保开关已打开
                
                或者在"打开时"部分添加PomodoroScreen应用。
                """
            } else {
                instructions = """
                \(message)
                
                请按以下步骤手动设置：
                1. 打开"系统偏好设置" > "用户与群组"
                2. 选择您的用户账户
                3. 点击"登录项"标签
                4. 点击"+"按钮添加PomodoroScreen应用
                """
            }
            alert.informativeText = instructions
            alert.alertStyle = .warning
        }
        
        alert.addButton(withTitle: "确定")
        
        if !success && showSystemPreferences {
            if #available(macOS 13.0, *) {
                alert.addButton(withTitle: "打开系统设置")
            } else {
                alert.addButton(withTitle: "打开系统偏好设置")
            }
        }
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn && !success && showSystemPreferences {
            // 根据macOS版本打开相应的设置页面
            if #available(macOS 13.0, *) {
                // macOS 13+ 使用新的系统设置
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
            } else {
                // 旧版本使用系统偏好设置
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.users")!)
            }
        }
    }
    
    // MARK: - 背景设置事件处理方法
    
    @objc private func addImageBackground() {
        let openPanel = NSOpenPanel()
        openPanel.title = "选择图片文件"
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.jpeg, .png, .gif, .bmp, .tiff]
        
        if openPanel.runModal() == .OK {
            for url in openPanel.urls {
                let backgroundFile = BackgroundFile(
                    path: url.path,
                    type: .image,
                    name: url.lastPathComponent,
                    playbackRate: 1.0 // 图片不需要播放速率，设为默认值
                )
                backgroundFiles.append(backgroundFile)
            }
            backgroundFilesList.reloadData()
        }
    }
    
    @objc private func addVideoBackground() {
        let openPanel = NSOpenPanel()
        openPanel.title = "选择视频文件"
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie, .avi]
        
        if openPanel.runModal() == .OK {
            for url in openPanel.urls {
                let backgroundFile = BackgroundFile(
                    path: url.path,
                    type: .video,
                    name: url.lastPathComponent,
                    playbackRate: 1.0 // 默认播放速率
                )
                backgroundFiles.append(backgroundFile)
            }
            backgroundFilesList.reloadData()
        }
    }
    
    @objc private func removeBackground() {
        let selectedRow = backgroundFilesList.selectedRow
        if selectedRow >= 0 && selectedRow < backgroundFiles.count {
            backgroundFiles.remove(at: selectedRow)
            backgroundFilesList.reloadData()
        }
    }
    
    @objc private func moveBackgroundUp() {
        let selectedRow = backgroundFilesList.selectedRow
        if selectedRow > 0 {
            backgroundFiles.swapAt(selectedRow, selectedRow - 1)
            backgroundFilesList.reloadData()
            backgroundFilesList.selectRowIndexes(IndexSet(integer: selectedRow - 1), byExtendingSelection: false)
        }
    }
    
    @objc private func moveBackgroundDown() {
        let selectedRow = backgroundFilesList.selectedRow
        if selectedRow >= 0 && selectedRow < backgroundFiles.count - 1 {
            backgroundFiles.swapAt(selectedRow, selectedRow + 1)
            backgroundFilesList.reloadData()
            backgroundFilesList.selectRowIndexes(IndexSet(integer: selectedRow + 1), byExtendingSelection: false)
        }
    }
    
    @objc private func saveSettings() {
        // 保存到 UserDefaults
        UserDefaults.standard.set(autoStartEnabled, forKey: "AutoStartEnabled")
        UserDefaults.standard.set(pomodoroTimeMinutes, forKey: "PomodoroTimeMinutes")
        UserDefaults.standard.set(breakTimeMinutes, forKey: "BreakTimeMinutes")
        UserDefaults.standard.set(idleRestartEnabled, forKey: "IdleRestartEnabled")
        UserDefaults.standard.set(idleTimeMinutes, forKey: "IdleTimeMinutes")
        UserDefaults.standard.set(idleActionIsRestart, forKey: "IdleActionIsRestart")
        UserDefaults.standard.set(screenLockRestartEnabled, forKey: "ScreenLockRestartEnabled")
        UserDefaults.standard.set(screenLockActionIsRestart, forKey: "ScreenLockActionIsRestart")
        UserDefaults.standard.set(screensaverRestartEnabled, forKey: "ScreensaverRestartEnabled")
        UserDefaults.standard.set(screensaverActionIsRestart, forKey: "ScreensaverActionIsRestart")
        UserDefaults.standard.set(showCancelRestButton, forKey: "ShowCancelRestButton")
        
        // 保存计划设置
        UserDefaults.standard.set(longBreakCycle, forKey: "LongBreakCycle")
        UserDefaults.standard.set(longBreakTimeMinutes, forKey: "LongBreakTimeMinutes")
        UserDefaults.standard.set(showLongBreakCancelButton, forKey: "ShowLongBreakCancelButton")
        UserDefaults.standard.set(accumulateRestTime, forKey: "AccumulateRestTime")
        
        // 保存背景设置
        if let backgroundData = try? JSONEncoder().encode(backgroundFiles) {
            UserDefaults.standard.set(backgroundData, forKey: "BackgroundFiles")
        }
        
        // 保存熬夜限制设置
        UserDefaults.standard.set(stayUpLimitEnabled, forKey: "StayUpLimitEnabled")
        UserDefaults.standard.set(stayUpLimitHour, forKey: "StayUpLimitHour")
        UserDefaults.standard.set(stayUpLimitMinute, forKey: "StayUpLimitMinute")
        
        // 保存开机自启动设置（LaunchAtLogin类会自动处理系统级设置）
        UserDefaults.standard.set(launchAtLoginEnabled, forKey: "LaunchAtLoginEnabled")
        LaunchAtLogin.shared.isEnabled = launchAtLoginEnabled
        
        // 通知回调
        onSettingsChanged?(autoStartEnabled, pomodoroTimeMinutes, breakTimeMinutes, idleRestartEnabled, idleTimeMinutes, idleActionIsRestart, screenLockRestartEnabled, screenLockActionIsRestart, screensaverRestartEnabled, screensaverActionIsRestart, showCancelRestButton, longBreakCycle, longBreakTimeMinutes, showLongBreakCancelButton, accumulateRestTime, backgroundFiles, stayUpLimitEnabled, stayUpLimitHour, stayUpLimitMinute)
        
        close()
    }
    
    @objc private func cancelSettings() {
        // 恢复原始设置
        loadSettings()
        close()
    }
    
    private func loadSettings() {
        autoStartEnabled = UserDefaults.standard.bool(forKey: "AutoStartEnabled") != false // 默认为 true
        pomodoroTimeMinutes = UserDefaults.standard.integer(forKey: "PomodoroTimeMinutes")
        if pomodoroTimeMinutes == 0 { pomodoroTimeMinutes = 25 } // 默认25分钟
        
        breakTimeMinutes = UserDefaults.standard.integer(forKey: "BreakTimeMinutes")
        if breakTimeMinutes == 0 { breakTimeMinutes = 3 } // 默认3分钟
        
        idleRestartEnabled = UserDefaults.standard.bool(forKey: "IdleRestartEnabled") // 默认为 false
        idleTimeMinutes = UserDefaults.standard.integer(forKey: "IdleTimeMinutes")
        if idleTimeMinutes == 0 { idleTimeMinutes = 10 } // 默认10分钟
        idleActionIsRestart = UserDefaults.standard.bool(forKey: "IdleActionIsRestart") != false // 默认为 true
        
        screenLockRestartEnabled = UserDefaults.standard.bool(forKey: "ScreenLockRestartEnabled") // 默认为 false
        screenLockActionIsRestart = UserDefaults.standard.bool(forKey: "ScreenLockActionIsRestart") != false // 默认为 true
        
        screensaverRestartEnabled = UserDefaults.standard.bool(forKey: "ScreensaverRestartEnabled") // 默认为 false
        screensaverActionIsRestart = UserDefaults.standard.bool(forKey: "ScreensaverActionIsRestart") != false // 默认为 true
        
        showCancelRestButton = UserDefaults.standard.bool(forKey: "ShowCancelRestButton") != false // 默认为 true
        
        // 加载计划设置
        longBreakCycle = UserDefaults.standard.integer(forKey: "LongBreakCycle")
        if longBreakCycle == 0 { longBreakCycle = 2 } // 默认2次
        
        longBreakTimeMinutes = UserDefaults.standard.integer(forKey: "LongBreakTimeMinutes")
        if longBreakTimeMinutes == 0 { longBreakTimeMinutes = 5 } // 默认5分钟
        
        showLongBreakCancelButton = UserDefaults.standard.bool(forKey: "ShowLongBreakCancelButton") != false // 默认为 true
        accumulateRestTime = UserDefaults.standard.bool(forKey: "AccumulateRestTime") // 默认为 false
        
        // 加载背景设置
        if let backgroundData = UserDefaults.standard.data(forKey: "BackgroundFiles"),
           let loadedBackgroundFiles = try? JSONDecoder().decode([BackgroundFile].self, from: backgroundData) {
            backgroundFiles = loadedBackgroundFiles
        } else {
            backgroundFiles = [] // 默认为空数组
        }
        
        // 加载熬夜限制设置
        stayUpLimitEnabled = UserDefaults.standard.bool(forKey: "StayUpLimitEnabled") // 默认为 false
        stayUpLimitHour = UserDefaults.standard.integer(forKey: "StayUpLimitHour")
        if stayUpLimitHour == 0 { stayUpLimitHour = 23 } // 默认23:00
        stayUpLimitMinute = UserDefaults.standard.integer(forKey: "StayUpLimitMinute") // 默认为0分钟
        
        // 加载开机自启动设置
        launchAtLoginEnabled = LaunchAtLogin.shared.isEnabled // 从LaunchAtLogin类获取当前状态
        
        // 更新UI
        if autoStartCheckbox != nil {
            autoStartCheckbox.state = autoStartEnabled ? .on : .off
        }
        if pomodoroTimeSlider != nil {
            pomodoroTimeSlider.integerValue = pomodoroTimeMinutes
            pomodoroTimeLabel.stringValue = "\(pomodoroTimeMinutes) 分钟"
        }
        if breakTimeSlider != nil {
            breakTimeSlider.integerValue = breakTimeMinutes
            breakTimeLabel.stringValue = "\(breakTimeMinutes) 分钟"
        }
        if idleRestartCheckbox != nil {
            idleRestartCheckbox.state = idleRestartEnabled ? .on : .off
            idleTimeSlider.isEnabled = idleRestartEnabled
            idleActionSegmentedControl.isEnabled = idleRestartEnabled
            idleActionSegmentedControl.selectedSegment = idleActionIsRestart ? 0 : 1
        }
        if idleTimeSlider != nil {
            idleTimeSlider.integerValue = idleTimeMinutes
            idleTimeLabel.stringValue = "\(idleTimeMinutes) 分钟"
        }
        if screenLockRestartCheckbox != nil {
            screenLockRestartCheckbox.state = screenLockRestartEnabled ? .on : .off
            screenLockActionSegmentedControl.isEnabled = screenLockRestartEnabled
            screenLockActionSegmentedControl.selectedSegment = screenLockActionIsRestart ? 0 : 1
        }
        if screensaverRestartCheckbox != nil {
            screensaverRestartCheckbox.state = screensaverRestartEnabled ? .on : .off
            screensaverActionSegmentedControl.isEnabled = screensaverRestartEnabled
            screensaverActionSegmentedControl.selectedSegment = screensaverActionIsRestart ? 0 : 1
        }
        if showCancelRestButtonCheckbox != nil {
            showCancelRestButtonCheckbox.state = showCancelRestButton ? .on : .off
        }
        
        // 更新计划设置UI
        if longBreakCycleSlider != nil {
            longBreakCycleSlider.integerValue = longBreakCycle
            longBreakCycleLabel.stringValue = "每 \(longBreakCycle) 次"
        }
        if longBreakTimeSlider != nil {
            longBreakTimeSlider.integerValue = longBreakTimeMinutes
            longBreakTimeLabel.stringValue = "\(longBreakTimeMinutes) 分钟"
        }
        if showLongBreakCancelButtonCheckbox != nil {
            showLongBreakCancelButtonCheckbox.state = showLongBreakCancelButton ? .on : .off
        }
        if accumulateRestTimeCheckbox != nil {
            accumulateRestTimeCheckbox.state = accumulateRestTime ? .on : .off
        }
        
        // 更新背景设置UI
        if backgroundFilesList != nil {
            backgroundFilesList.reloadData()
        }
        
        // 更新熬夜限制设置UI
        if stayUpLimitCheckbox != nil {
            stayUpLimitCheckbox.state = stayUpLimitEnabled ? .on : .off
            
            // 更新小时选择
            if stayUpLimitHour >= 21 {
                stayUpHourPopUpButton.selectItem(at: stayUpLimitHour - 21)
            } else {
                stayUpHourPopUpButton.selectItem(at: stayUpLimitHour + 3)
            }
            
            // 更新分钟选择
            let minutes = [0, 15, 30, 45]
            if let minuteIndex = minutes.firstIndex(of: stayUpLimitMinute) {
                stayUpMinutePopUpButton.selectItem(at: minuteIndex)
            }
            
            updateStayUpControlsEnabled()
        }
        
        // 更新开机自启动设置UI
        if launchAtLoginCheckbox != nil {
            launchAtLoginCheckbox.state = launchAtLoginEnabled ? .on : .off
        }
    }
    
    func showSettings() {
        loadSettings()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NSTableView DataSource and Delegate
extension SettingsWindow: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return backgroundFiles.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < backgroundFiles.count else { return nil }
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("BackgroundFileCell")
        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? BackgroundFileCellView
        
        if cellView == nil {
            cellView = BackgroundFileCellView()
            cellView?.identifier = cellIdentifier
        }
        
        let file = backgroundFiles[row]
        cellView?.configure(with: file) { [weak self] updatedFile, newRate in
            // 更新背景文件列表中的播放速率
            self?.backgroundFiles[row] = updatedFile
        }
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 75 // 增加行高以容纳预览图和播放速率控件
    }
}

// MARK: - BackgroundFileCellView
class BackgroundFileCellView: NSView {
    private var thumbnailImageView: NSImageView!
    private var nameLabel: NSTextField!
    private var typeLabel: NSTextField!
    private var playbackRateLabel: NSTextField!
    private var playbackRateSlider: NSSlider!
    
    // 当前文件引用，用于更新播放速率
    private var currentFile: BackgroundFile?
    private var onPlaybackRateChanged: ((BackgroundFile, Double) -> Void)?
    
    // 缩略图缓存
    private static var thumbnailCache: [String: NSImage] = [:]
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // 缩略图视图
        thumbnailImageView = NSImageView()
        thumbnailImageView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailImageView.wantsLayer = true
        thumbnailImageView.layer?.cornerRadius = 4
        thumbnailImageView.layer?.borderWidth = 1
        thumbnailImageView.layer?.borderColor = NSColor.separatorColor.cgColor
        addSubview(thumbnailImageView)
        
        // 文件名标签
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.font = NSFont.systemFont(ofSize: 12)
        nameLabel.textColor = NSColor.labelColor
        addSubview(nameLabel)
        
        // 类型标签
        typeLabel = NSTextField(labelWithString: "")
        typeLabel.font = NSFont.systemFont(ofSize: 10)
        typeLabel.textColor = NSColor.secondaryLabelColor
        addSubview(typeLabel)
        
        // 播放速率标签
        playbackRateLabel = NSTextField(labelWithString: "")
        playbackRateLabel.font = NSFont.systemFont(ofSize: 9)
        playbackRateLabel.textColor = NSColor.tertiaryLabelColor
        addSubview(playbackRateLabel)
        
        // 播放速率滑块
        playbackRateSlider = NSSlider()
        playbackRateSlider.minValue = 0.1
        playbackRateSlider.maxValue = 8.0
        playbackRateSlider.doubleValue = 1.0
        playbackRateSlider.target = self
        playbackRateSlider.action = #selector(playbackRateChanged)
        playbackRateSlider.isHidden = true // 默认隐藏，只对视频显示
        playbackRateSlider.toolTip = "拖动调整视频播放速率 (0.1x - 8.0x)" // 设置初始tooltip
        addSubview(playbackRateSlider)
        
        // 设置约束
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        playbackRateLabel.translatesAutoresizingMaskIntoConstraints = false
        playbackRateSlider.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 缩略图约束 - 左侧，垂直居中，固定大小
            thumbnailImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            thumbnailImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 44),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 44),
            
            // 文件名标签约束 - 缩略图右侧，上部分
            nameLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            
            // 类型标签约束 - 缩略图右侧，中部分
            typeLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 8),
            typeLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            typeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            
            // 播放速率标签约束 - 缩略图右侧，下部分
            playbackRateLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 8),
            playbackRateLabel.widthAnchor.constraint(equalToConstant: 60),
            playbackRateLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 2),
            
            // 播放速率滑块约束 - 播放速率标签右侧
            playbackRateSlider.leadingAnchor.constraint(equalTo: playbackRateLabel.trailingAnchor, constant: 4),
            playbackRateSlider.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            playbackRateSlider.centerYAnchor.constraint(equalTo: playbackRateLabel.centerYAnchor),
            playbackRateSlider.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func configure(with file: BackgroundFile, onPlaybackRateChanged: @escaping (BackgroundFile, Double) -> Void) {
        self.currentFile = file
        self.onPlaybackRateChanged = onPlaybackRateChanged
        
        nameLabel.stringValue = file.name
        typeLabel.stringValue = file.type.displayName
        
        // 根据文件类型显示/隐藏播放速率控件
        switch file.type {
        case .image:
            playbackRateLabel.isHidden = true
            playbackRateSlider.isHidden = true
            loadImageThumbnail(from: file.path)
        case .video:
            playbackRateLabel.isHidden = false
            playbackRateSlider.isHidden = false
            playbackRateSlider.doubleValue = file.playbackRate
            playbackRateLabel.stringValue = String(format: "%.1fx", file.playbackRate)
            // 更新tooltip显示当前播放速率
            playbackRateSlider.toolTip = String(format: "当前播放速率: %.1fx\n拖动调整 (0.1x - 8.0x)", file.playbackRate)
            loadVideoThumbnail(from: file.path)
        }
    }
    
    @objc private func playbackRateChanged() {
        guard let file = currentFile, file.type == .video else { return }
        
        let newRate = playbackRateSlider.doubleValue
        playbackRateLabel.stringValue = String(format: "%.1fx", newRate)
        
        // 实时更新tooltip显示当前播放速率
        playbackRateSlider.toolTip = String(format: "当前播放速率: %.1fx\n拖动调整 (0.1x - 8.0x)", newRate)
        
        // 创建更新的文件对象
        let updatedFile = BackgroundFile(
            path: file.path,
            type: file.type,
            name: file.name,
            playbackRate: newRate
        )
        
        // 通知父视图更新
        onPlaybackRateChanged?(updatedFile, newRate)
    }
    
    private func loadImageThumbnail(from path: String) {
        // 检查缓存
        if let cachedThumbnail = BackgroundFileCellView.thumbnailCache[path] {
            thumbnailImageView.image = cachedThumbnail
            return
        }
        
        // 先显示默认图标
        thumbnailImageView.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let image = NSImage(contentsOfFile: path) else {
                DispatchQueue.main.async {
                    self?.thumbnailImageView.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
                }
                return
            }
            
            // 创建缩略图
            let thumbnailSize = NSSize(width: 44, height: 44)
            let thumbnail = NSImage(size: thumbnailSize)
            thumbnail.lockFocus()
            
            let imageRect = NSRect(origin: .zero, size: thumbnailSize)
            image.draw(in: imageRect, from: NSRect.zero, operation: .copy, fraction: 1.0)
            
            thumbnail.unlockFocus()
            
            // 缓存缩略图
            BackgroundFileCellView.thumbnailCache[path] = thumbnail
            
            DispatchQueue.main.async {
                self?.thumbnailImageView.image = thumbnail
            }
        }
    }
    
    private func loadVideoThumbnail(from path: String) {
        // 检查缓存
        if let cachedThumbnail = BackgroundFileCellView.thumbnailCache[path] {
            thumbnailImageView.image = cachedThumbnail
            return
        }
        
        // 先显示默认图标
        thumbnailImageView.image = NSImage(systemSymbolName: "video", accessibilityDescription: nil)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let url = URL(fileURLWithPath: path)
            
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: path) else {
                DispatchQueue.main.async {
                    self?.thumbnailImageView.image = NSImage(systemSymbolName: "video.slash", accessibilityDescription: nil)
                }
                return
            }
            
            // 使用 AVFoundation 生成视频缩略图
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 44, height: 44)
            
            let time = CMTime(seconds: 1.0, preferredTimescale: 600) // 获取第1秒的帧
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: 44, height: 44))
                
                // 缓存缩略图
                BackgroundFileCellView.thumbnailCache[path] = thumbnail
                
                DispatchQueue.main.async {
                    self?.thumbnailImageView.image = thumbnail
                }
            } catch {
                print("生成视频缩略图失败: \(error)")
                DispatchQueue.main.async {
                    self?.thumbnailImageView.image = NSImage(systemSymbolName: "video", accessibilityDescription: nil)
                }
            }
        }
    }
}
