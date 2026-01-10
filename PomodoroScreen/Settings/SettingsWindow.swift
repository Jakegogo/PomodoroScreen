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
    private var overlayRestMessageTemplateTextViews: [NSTextView] = []
    private var overlayRestMessageTemplatesStackView: NSStackView!
    private var overlayRestMessageTemplatesContainerView: NSView!
    private var overlayRestMessageTemplatesScrollView: NSScrollView!
    private var overlayRestMessageTemplatesDocumentView: NSView!
    private var overlayRestMessageTemplatesAddButton: NSButton!
    private var overlayMessageTabBottomY: CGFloat = 0
    private var overlayStayUpTemplateLabelForLayout: NSTextField!
    private var overlayStayUpTemplateHintForLayout: NSTextField!
    private var overlayStayUpInputContainerView: NSView!
    private var overlayStayUpMessageTemplateTextView: NSTextView!
    
    // 熬夜限制设置 UI 控件
    private var stayUpLimitCheckbox: NSButton!
    private var stayUpHourPopUpButton: NSPopUpButton!
    private var stayUpMinutePopUpButton: NSPopUpButton!
    private var stayUpTimeLabel: NSTextField!
    private var stayUpColonLabel: NSTextField!
    
    // 开机自启动设置 UI 控件
    private var launchAtLoginCheckbox: NSButton!
    
    // 状态栏显示设置 UI 控件
    private var showStatusBarTextCheckbox: NSButton!
    
    // 自动检测投屏设置 UI 控件
    private var autoDetectScreencastCheckbox: NSButton!
    
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
    private var previewButton: NSButton!  // 预览按钮
    private var backgroundTypeLabel: NSTextField!
    private var shuffleBackgroundsCheckbox: NSButton! // 随机播放复选框
    
    // 通用控件
    private var saveButton: NSButton!
    private var cancelButton: NSButton!
    
    // 设置值
    var autoStartEnabled: Bool = true
    var pomodoroTimeMinutes: Int = 25
    var breakTimeMinutes: Int = 3
    var idleRestartEnabled: Bool = true
    var idleTimeMinutes: Int = 10
    var idleActionIsRestart: Bool = false // true: 重新计时, false: 暂停计时
    var screenLockRestartEnabled: Bool = true
    var screenLockActionIsRestart: Bool = false // true: 重新计时, false: 暂停计时
    var screensaverRestartEnabled: Bool = true
    var screensaverActionIsRestart: Bool = false // true: 重新计时, false: 暂停计时
    var showCancelRestButton: Bool = true // 是否显示取消休息按钮
    var overlayRestMessageTemplate: String = "" // 遮罩层提示文案模板（兼容旧逻辑，保存时会同步为列表第一条）
    var overlayRestMessageTemplates: [String] = [] // 遮罩层提示文案模板列表（轮播）
    var overlayStayUpMessageTemplate: String = "" // 熬夜强制休息文案模板
    
    // 计划设置值
    var longBreakCycle: Int = 2 // 间隔N次后进行长休息
    var longBreakTimeMinutes: Int = 5 // 长休息时间（分钟）
    var showLongBreakCancelButton: Bool = true // 长休息是否显示取消按钮
    var accumulateRestTime: Bool = false // 是否将短休息中断后的时间累加到长休息
    
    // 背景设置值
    var backgroundFiles: [BackgroundFile] = [] // 背景文件列表
    var shuffleBackgrounds: Bool = false // 是否随机播放背景
    
    // 熬夜限制设置值
    var stayUpLimitEnabled: Bool = false // 是否启用熬夜限制
    var stayUpLimitHour: Int = 23 // 熬夜限制小时（21-1）
    var stayUpLimitMinute: Int = 0 // 熬夜限制分钟（0, 15, 30, 45）
    
    // 开机自启动设置值
    var launchAtLoginEnabled: Bool = false // 是否启用开机自启动
    
    // 状态栏显示设置值
    var showStatusBarText: Bool = false // 是否在状态栏显示倒计时文字
    
    // 自动检测投屏设置值
    var autoDetectScreencastEnabled: Bool = false // 是否启用自动检测投屏进入专注模式
    
    // 回调
    var onSettingsChanged: ((Bool, Int, Int, Bool, Int, Bool, Bool, Bool, Bool, Bool, Bool, Int, Int, Bool, Bool, [BackgroundFile], Bool, Bool, Int, Int, Bool) -> Void)?
    
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
        
        // 创建标签页（“文案”放到最后，避免打扰常用设置）
        setupBasicSettingsTab()
        setupAutoHandlingTab()
        setupPlanTab()
        setupBackgroundTab()
        setupOverlayMessageTab()
        
        // 添加保存和取消按钮
        setupButtons(in: contentView)
    }
    
    // MARK: - 标签页设置方法
    
    private func setupBasicSettingsTab() {
        let basicTabItem = NSTabViewItem(identifier: "basic")
        basicTabItem.label = "基础设置"
        
        let basicView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 460))
        basicTabItem.view = basicView
        
        var yPosition: CGFloat = 400
        
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
        yPosition -= 40
        
        // 状态栏文字显示设置
        showStatusBarTextCheckbox = NSButton(checkboxWithTitle: "在状态栏显示倒计时文字", target: self, action: #selector(showStatusBarTextChanged))
        showStatusBarTextCheckbox.frame = NSRect(x: 20, y: yPosition, width: 240, height: 25)
        showStatusBarTextCheckbox.state = showStatusBarText ? .on : .off
        basicView.addSubview(showStatusBarTextCheckbox)
        
        tabView.addTabViewItem(basicTabItem)
    }

    private func setupOverlayMessageTab() {
        let copyTabItem = NSTabViewItem(identifier: "copy")
        copyTabItem.label = "文案"

        let copyView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 460))
        copyTabItem.view = copyView

        var yPosition: CGFloat = 400

        // 普通休息/长休息提示文案（可自定义）
        let overlayTemplateLabel = NSTextField(labelWithString: "遮罩层提示文案:")
        overlayTemplateLabel.frame = NSRect(x: 20, y: yPosition, width: 200, height: 20)
        copyView.addSubview(overlayTemplateLabel)
        // 更紧凑：标题与占位符提示之间减少间距
        yPosition -= 14

        let overlayTemplateHint = NSTextField(labelWithString: "支持占位符：{breakType}、{breakMinutes}")
        overlayTemplateHint.frame = NSRect(x: 20, y: yPosition, width: 360, height: 14)
        overlayTemplateHint.font = NSFont.systemFont(ofSize: 10)
        overlayTemplateHint.textColor = NSColor.secondaryLabelColor
        copyView.addSubview(overlayTemplateHint)
        yPosition -= 16

        // 轮播文案列表：不使用滚动条，新增后向下挤压后续内容
        // 先用一个最小高度占位，后续根据内容高度动态调整 container 的 frame
        let listMinHeight: CGFloat = 56
        let listY = yPosition - listMinHeight
        let templatesContainerView = NSView(frame: NSRect(x: 20, y: listY, width: 390, height: listMinHeight))
        // Outer container does NOT need background; only each item has background.

        // Inner scroll view: <=3 items -> expand container (no scroller); >3 items -> fixed height + inner scroll.
        // 内部滚动区域加宽，给滚动条留空间，确保输入框内容宽度与“强制休息”一致
        let templatesScrollView = NSScrollView(frame: NSRect(x: 0, y: 6, width: 390, height: listMinHeight))
        templatesScrollView.hasVerticalScroller = false
        templatesScrollView.hasHorizontalScroller = false
        templatesScrollView.autohidesScrollers = false // 显式展示滚动条（当开启滚动时）
        templatesScrollView.borderType = .noBorder
        templatesScrollView.drawsBackground = false
        templatesScrollView.autoresizingMask = [.width, .height]
        templatesContainerView.addSubview(templatesScrollView)

        let templatesDocumentView = NSView(frame: NSRect(x: 0, y: 0, width: 390, height: 1))
        templatesScrollView.documentView = templatesDocumentView

        let templatesStackView = NSStackView()
        templatesStackView.orientation = .vertical
        templatesStackView.alignment = .leading
        templatesStackView.spacing = 4
        // 顶部/底部更紧凑一些
        templatesStackView.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 6, right: 0)
        templatesStackView.translatesAutoresizingMaskIntoConstraints = false
        templatesDocumentView.addSubview(templatesStackView)

        NSLayoutConstraint.activate([
            templatesStackView.leadingAnchor.constraint(equalTo: templatesDocumentView.leadingAnchor, constant: 0),
            templatesStackView.trailingAnchor.constraint(equalTo: templatesDocumentView.trailingAnchor, constant: 0),
            templatesStackView.topAnchor.constraint(equalTo: templatesDocumentView.topAnchor, constant: 0),
            // 与熬夜强制休息输入框内容宽度保持一致（364）
            templatesStackView.widthAnchor.constraint(equalToConstant: 390)
        ])

        copyView.addSubview(templatesContainerView)
        overlayRestMessageTemplatesStackView = templatesStackView
        overlayRestMessageTemplatesContainerView = templatesContainerView
        overlayRestMessageTemplatesScrollView = templatesScrollView
        overlayRestMessageTemplatesDocumentView = templatesDocumentView

        // 初始化列表（兼容：如果还没加载列表，就回退到旧单条文案）
        let initialTemplates = overlayRestMessageTemplates.isEmpty ? SettingsStore.overlayRestMessageTemplates : overlayRestMessageTemplates
        rebuildOverlayRestMessageTemplateInputs(templates: initialTemplates)

        // “+”按钮：在输入框下方新增一个文本框（确保完全显示）
        let addTemplateButton = NSButton(title: "+", target: self, action: #selector(addOverlayRestMessageTemplateField))
        addTemplateButton.frame = NSRect(x: 360, y: templatesContainerView.frame.minY - 30, width: 45, height: 28)
        addTemplateButton.bezelStyle = .rounded
        copyView.addSubview(addTemplateButton)
        overlayRestMessageTemplatesAddButton = addTemplateButton

        // 记录后续布局的基准线（用于动态挤压）
        overlayMessageTabBottomY = addTemplateButton.frame.minY - 30
        yPosition = overlayMessageTabBottomY

        // 熬夜强制休息提示文案（可自定义）
        let stayUpTemplateLabel = NSTextField(labelWithString: "熬夜强制休息提示文案:")
        stayUpTemplateLabel.frame = NSRect(x: 20, y: yPosition, width: 240, height: 20)
        copyView.addSubview(stayUpTemplateLabel)
        overlayStayUpTemplateLabelForLayout = stayUpTemplateLabel
        // 更紧凑：缩小标题与说明文字间距
        yPosition -= 14

        let stayUpTemplateHint = NSTextField(labelWithString: "强制休息时显示，留空则使用默认文案")
        stayUpTemplateHint.frame = NSRect(x: 20, y: yPosition, width: 360, height: 14)
        stayUpTemplateHint.font = NSFont.systemFont(ofSize: 10)
        stayUpTemplateHint.textColor = NSColor.secondaryLabelColor
        copyView.addSubview(stayUpTemplateHint)
        overlayStayUpTemplateHintForLayout = stayUpTemplateHint
        yPosition -= 16

        // 强制休息输入框（圆角背景，且不显示滚动条）
        let stayUpContainer = NSView(frame: NSRect(x: 20, y: yPosition - 40, width: 380, height: 56))
        stayUpContainer.wantsLayer = true
        stayUpContainer.layer?.cornerRadius = 10
        stayUpContainer.layer?.masksToBounds = true
        // White rounded background, no border (per requirement).
        stayUpContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.95).cgColor

        let stayUpTextView = NSTextView(frame: NSRect(x: 8, y: 8, width: 364, height: 40))
        stayUpTextView.isRichText = false
        stayUpTextView.isEditable = true
        stayUpTextView.font = NSFont.systemFont(ofSize: 13)
        stayUpTextView.string = overlayStayUpMessageTemplate
        stayUpTextView.drawsBackground = false
        stayUpTextView.textContainerInset = NSSize(width: 4, height: 4)
        stayUpTextView.autoresizingMask = [.width, .height]
        stayUpContainer.addSubview(stayUpTextView)
        copyView.addSubview(stayUpContainer)
        overlayStayUpInputContainerView = stayUpContainer
        overlayStayUpMessageTemplateTextView = stayUpTextView

        tabView.addTabViewItem(copyTabItem)
    }

    // MARK: - Overlay Message Templates (Rest) - Dynamic Inputs
    
    @objc private func addOverlayRestMessageTemplateField() {
        // 先收集当前内容，再整体重建（用于：从 1 条变 2 条时自动补上标题行）
        var templates = overlayRestMessageTemplateTextViews.map { $0.string }
        templates.append("")
        rebuildOverlayRestMessageTemplateInputs(templates: templates)
        relayoutOverlayMessageTabForTemplates()
    }

    @objc private func removeOverlayRestMessageTemplateField(_ sender: NSButton) {
        var templates = overlayRestMessageTemplateTextViews.map { $0.string }
        let idx = sender.tag
        guard idx >= 0 && idx < templates.count else { return }
        templates.remove(at: idx)
        
        // Ensure there is always at least 1 input row (empty allowed; save will normalize).
        if templates.isEmpty {
            templates = [""]
        }
        
        // Update in-memory state; persistence happens on Save (保持与现有“保存”按钮行为一致)
        overlayRestMessageTemplates = templates
        overlayRestMessageTemplate = templates.first ?? overlayRestMessageTemplate
        
        rebuildOverlayRestMessageTemplateInputs(templates: templates)
        relayoutOverlayMessageTabForTemplates()
    }
    
    private func rebuildOverlayRestMessageTemplateInputs(templates: [String]) {
        overlayRestMessageTemplateTextViews.removeAll()
        
        guard let stackView = overlayRestMessageTemplatesStackView else { return }
        
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        let initial = templates.isEmpty ? [OverlayMessageTemplateRenderer.defaultRestTemplate] : templates
        let shouldShowTitle = initial.count > 1
        for (idx, template) in initial.enumerated() {
            createOverlayRestMessageTemplateInputRow(initialText: template, index: idx, shouldShowTitle: shouldShowTitle)
        }
        
        relayoutOverlayMessageTabForTemplates()
    }
    
    @discardableResult
    private func createOverlayRestMessageTemplateInputRow(initialText: String, index: Int, shouldShowTitle: Bool) -> NSTextView {
        guard let stackView = overlayRestMessageTemplatesStackView else {
            let placeholder = NSTextView()
            return placeholder
        }
        
        // Row container to visually separate each template input.
        let rowContainer = NSStackView()
        rowContainer.orientation = .vertical
        rowContainer.alignment = .leading
        // 多条文案之间更紧凑
        rowContainer.spacing = shouldShowTitle ? 2 : 0
        rowContainer.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        rowContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 与熬夜强制休息输入框内容宽度保持一致（364）
            rowContainer.widthAnchor.constraint(equalToConstant: 380)
        ])
        
        if shouldShowTitle {
            let headerRow = NSStackView()
            headerRow.orientation = .horizontal
            headerRow.alignment = .centerY
            headerRow.spacing = 8
            headerRow.translatesAutoresizingMaskIntoConstraints = false
            
            let titleLabel = NSTextField(labelWithString: "文案 \(index + 1)")
            titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            titleLabel.textColor = NSColor.secondaryLabelColor
            
            let spacer = NSView()
            
            let deleteButton = NSButton(title: "−", target: self, action: #selector(removeOverlayRestMessageTemplateField(_:)))
            deleteButton.tag = index
            deleteButton.bezelStyle = .rounded
            deleteButton.setButtonType(.momentaryPushIn)
            deleteButton.font = NSFont.systemFont(ofSize: 14, weight: .bold)
            deleteButton.toolTip = "删除该文案"
            
            headerRow.addArrangedSubview(titleLabel)
            headerRow.addArrangedSubview(spacer)
            headerRow.addArrangedSubview(deleteButton)
            rowContainer.addArrangedSubview(headerRow)
        }

        // Rounded background container (no scrollbars)
        let inputContainer = NSView()
        inputContainer.wantsLayer = true
        inputContainer.layer?.cornerRadius = 10
        inputContainer.layer?.masksToBounds = true
        // White rounded background, no border (per requirement).
        inputContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.95).cgColor
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            inputContainer.widthAnchor.constraint(equalToConstant: 380),
            inputContainer.heightAnchor.constraint(equalToConstant: 52)
        ])
        
        // No scrollbars: use a plain NSTextView inside the rounded container.
        let textView = NSTextView(frame: NSRect(x: 8, y: 6, width: 380, height: 40))
        textView.isRichText = false
        textView.isEditable = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.string = initialText
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.autoresizingMask = [.width, .height]
        
        inputContainer.addSubview(textView)
        rowContainer.addArrangedSubview(inputContainer)
        stackView.addArrangedSubview(rowContainer)
        overlayRestMessageTemplateTextViews.append(textView)
        return textView
    }

    /// Re-layout the bottom section (stay-up template) after the rest-template list grows/shrinks.
    private func relayoutOverlayMessageTabForTemplates() {
        guard
            let container = overlayRestMessageTemplatesContainerView,
            let stackView = overlayRestMessageTemplatesStackView,
            let scrollView = overlayRestMessageTemplatesScrollView,
            let documentView = overlayRestMessageTemplatesDocumentView,
            let addButton = overlayRestMessageTemplatesAddButton,
            let stayUpLabel = overlayStayUpTemplateLabelForLayout,
            let stayUpHint = overlayStayUpTemplateHintForLayout,
            let stayUpInput = overlayStayUpInputContainerView
        else { return }

        stackView.layoutSubtreeIfNeeded()

        // Fit document view to stack content (for inner scrolling mode).
        let desiredDocumentHeight = max(56, stackView.fittingSize.height)
        var docFrame = documentView.frame
        docFrame.size.height = desiredDocumentHeight
        documentView.frame = docFrame

        // Up to 2 templates: expand container and push content down.
        // 3+ templates: keep container fixed height (2 rows) and enable inner scroll.
        let visibleRows = min(2, max(1, overlayRestMessageTemplateTextViews.count))
        let maxContainerHeight: CGFloat = {
            // Estimate max height by summing first N arranged subviews (row containers) + spacing + edge insets.
            let rows = Array(stackView.arrangedSubviews.prefix(visibleRows))
            rows.forEach { $0.layoutSubtreeIfNeeded() }
            let rowsHeight = rows.reduce(CGFloat(0)) { $0 + $1.fittingSize.height }
            let spacingHeight = stackView.spacing * CGFloat(max(0, rows.count - 1))
            let insetsHeight = stackView.edgeInsets.top + stackView.edgeInsets.bottom
            return max(56, rowsHeight + spacingHeight + insetsHeight)
        }()

        let shouldEnableInnerScroll = overlayRestMessageTemplateTextViews.count > 2
        scrollView.hasVerticalScroller = shouldEnableInnerScroll
        // 显式展示滚动条
        scrollView.autohidesScrollers = false
        scrollView.verticalScroller?.alphaValue = shouldEnableInnerScroll ? 1.0 : 0.0

        // Container height: either full content (<=3) or capped (4+).
        let contentHeight = max(56, desiredDocumentHeight)
        let desiredContainerHeight = shouldEnableInnerScroll ? min(contentHeight, maxContainerHeight) : contentHeight
        let containerTopY = container.frame.maxY
        container.frame = NSRect(x: container.frame.origin.x, y: containerTopY - desiredContainerHeight, width: container.frame.width, height: desiredContainerHeight)

        // Place "+" right under the list.
        // 顶部/底部更紧凑一些：缩短列表到底部按钮的距离
        addButton.frame.origin.y = container.frame.minY - 26

        // Push stay-up section down.
        // 注意：这里会覆盖 setupOverlayMessageTab() 中的 yPosition 计算，因此间距要在这里调整才会生效。
        let y0 = addButton.frame.minY - 22
        stayUpLabel.frame.origin.y = y0
        // 更紧凑：标题与说明文字间距
        let stayUpLabelToHintSpacing: CGFloat = 14
        // 说明文字与输入框间距
        let stayUpHintToInputSpacing: CGFloat = 16
        stayUpHint.frame.origin.y = y0 - stayUpLabelToHintSpacing
        stayUpInput.frame.origin.y = y0 - stayUpLabelToHintSpacing - stayUpHintToInputSpacing - 56
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
        idleTimeSlider.minValue = 1
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
        yPosition -= 60
        
        // 自动检测投屏设置
        autoDetectScreencastCheckbox = NSButton(checkboxWithTitle: "检测到投屏/外接显示器时自动启用专注模式", target: self, action: #selector(autoDetectScreencastChanged))
        autoDetectScreencastCheckbox.frame = NSRect(x: 20, y: yPosition, width: 380, height: 25)
        autoDetectScreencastCheckbox.state = autoDetectScreencastEnabled ? .on : .off
        autoView.addSubview(autoDetectScreencastCheckbox)
        
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
        buttonY -= 50  // 增加间距
        
        // 预览按钮
        previewButton = NSButton(title: "预览", target: self, action: #selector(previewBackground))
        previewButton.frame = NSRect(x: buttonX, y: buttonY, width: 80, height: 32)
        previewButton.bezelStyle = .rounded
        previewButton.keyEquivalent = "p"  // 快捷键 Cmd+P
        backgroundView.addSubview(previewButton)
        
        // 随机播放复选框（放在预览按钮下方）
        shuffleBackgroundsCheckbox = NSButton(checkboxWithTitle: "随机播放", target: self, action: #selector(shuffleBackgroundsChanged))
        shuffleBackgroundsCheckbox.frame = NSRect(x: 20, y: 120, width: 150, height: 20)
        backgroundView.addSubview(shuffleBackgroundsCheckbox)
        
        // 说明文字
        let infoLabel = NSTextField(labelWithString: "支持图片格式：jpg, png, gif\n支持视频格式：mp4, mov, avi\n随机播放：每轮播放所有文件一次，但顺序随机")
        infoLabel.frame = NSRect(x: 20, y: 20, width: 380, height: 80)
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
    
    @objc private func showStatusBarTextChanged() {
        showStatusBarText = showStatusBarTextCheckbox.state == .on
    }
    
    @objc private func autoDetectScreencastChanged() {
        autoDetectScreencastEnabled = autoDetectScreencastCheckbox.state == .on
        
        // 立即更新ScreenDetectionManager的设置
        ScreenDetectionManager.shared.isAutoDetectionEnabled = autoDetectScreencastEnabled
        
        print("📺 自动检测投屏设置已更改: \(autoDetectScreencastEnabled ? "开启" : "关闭")")
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
    
    @objc private func previewBackground() {
        guard !backgroundFiles.isEmpty else { return }
        
        let selectedRow = backgroundFilesList.selectedRow
        let selectedIndex = selectedRow >= 0 && selectedRow < backgroundFiles.count ? selectedRow : -1
        
        // 使用 OverlayWindow 的预览模式
        let previewOverlay = OverlayWindow(previewFiles: backgroundFiles, selectedIndex: selectedIndex)
        previewOverlay.showOverlay()
    }
    
    @objc private func shuffleBackgroundsChanged() {
        shuffleBackgrounds = shuffleBackgroundsCheckbox.state == .on
    }
    
    @objc private func saveSettings() {
        // 保存到 SettingsStore
        SettingsStore.autoStartEnabled = autoStartEnabled
        SettingsStore.pomodoroTimeMinutes = pomodoroTimeMinutes
        SettingsStore.breakTimeMinutes = breakTimeMinutes
        SettingsStore.idleRestartEnabled = idleRestartEnabled
        SettingsStore.idleTimeMinutes = idleTimeMinutes
        SettingsStore.idleActionIsRestart = idleActionIsRestart
        SettingsStore.screenLockRestartEnabled = screenLockRestartEnabled
        SettingsStore.screenLockActionIsRestart = screenLockActionIsRestart
        SettingsStore.screensaverRestartEnabled = screensaverRestartEnabled
        SettingsStore.screensaverActionIsRestart = screensaverActionIsRestart
        SettingsStore.showCancelRestButton = showCancelRestButton
        
        // 保存遮罩层文案列表（轮播）
        let templates = overlayRestMessageTemplateTextViews.map { $0.string }
        SettingsStore.overlayRestMessageTemplates = templates
        SettingsStore.overlayStayUpMessageTemplate = overlayStayUpMessageTemplateTextView?.string ?? overlayStayUpMessageTemplate
        
        // 保存计划设置
        SettingsStore.longBreakCycle = longBreakCycle
        SettingsStore.longBreakTimeMinutes = longBreakTimeMinutes
        SettingsStore.showLongBreakCancelButton = showLongBreakCancelButton
        SettingsStore.accumulateRestTime = accumulateRestTime
        
        // 保存背景设置
        if let backgroundData = try? JSONEncoder().encode(backgroundFiles) {
            SettingsStore.backgroundFilesData = backgroundData
        } else {
            SettingsStore.backgroundFilesData = nil
        }
        SettingsStore.shuffleBackgrounds = shuffleBackgrounds
        
        // 保存熬夜限制设置
        SettingsStore.stayUpLimitEnabled = stayUpLimitEnabled
        SettingsStore.stayUpLimitHour = stayUpLimitHour
        SettingsStore.stayUpLimitMinute = stayUpLimitMinute
        
        // 保存开机自启动设置（LaunchAtLogin类会自动处理系统级设置）
        SettingsStore.launchAtLoginEnabled = launchAtLoginEnabled
        
        // 保存状态栏文字显示设置
        SettingsStore.showStatusBarText = showStatusBarText
        SettingsStore.autoDetectScreencastEnabled = autoDetectScreencastEnabled
        LaunchAtLogin.shared.isEnabled = launchAtLoginEnabled
        
        // 通知回调
        onSettingsChanged?(autoStartEnabled, pomodoroTimeMinutes, breakTimeMinutes, idleRestartEnabled, idleTimeMinutes, idleActionIsRestart, screenLockRestartEnabled, screenLockActionIsRestart, screensaverRestartEnabled, screensaverActionIsRestart, showCancelRestButton, longBreakCycle, longBreakTimeMinutes, showLongBreakCancelButton, accumulateRestTime, backgroundFiles, shuffleBackgrounds, stayUpLimitEnabled, stayUpLimitHour, stayUpLimitMinute, showStatusBarText)
        
        close()
    }
    
    @objc private func cancelSettings() {
        // 恢复原始设置
        loadSettings()
        close()
    }
    
    private func loadSettings() {
        autoStartEnabled = SettingsStore.autoStartEnabled
        pomodoroTimeMinutes = SettingsStore.pomodoroTimeMinutes
        breakTimeMinutes = SettingsStore.breakTimeMinutes
        
        idleRestartEnabled = SettingsStore.idleRestartEnabled
        idleTimeMinutes = SettingsStore.idleTimeMinutes
        idleActionIsRestart = SettingsStore.idleActionIsRestart
        
        screenLockRestartEnabled = SettingsStore.screenLockRestartEnabled
        screenLockActionIsRestart = SettingsStore.screenLockActionIsRestart
        
        screensaverRestartEnabled = SettingsStore.screensaverRestartEnabled
        screensaverActionIsRestart = SettingsStore.screensaverActionIsRestart
        
        showCancelRestButton = SettingsStore.showCancelRestButton
        overlayRestMessageTemplates = SettingsStore.overlayRestMessageTemplates
        overlayRestMessageTemplate = overlayRestMessageTemplates.first ?? SettingsStore.overlayRestMessageTemplate
        overlayStayUpMessageTemplate = SettingsStore.overlayStayUpMessageTemplate
        
        // 加载计划设置
        longBreakCycle = SettingsStore.longBreakCycle
        longBreakTimeMinutes = SettingsStore.longBreakTimeMinutes
        
        showLongBreakCancelButton = SettingsStore.showLongBreakCancelButton
        accumulateRestTime = SettingsStore.accumulateRestTime
        
        // 加载背景设置
        if let backgroundData = SettingsStore.backgroundFilesData,
           let loadedBackgroundFiles = try? JSONDecoder().decode([BackgroundFile].self, from: backgroundData) {
            backgroundFiles = loadedBackgroundFiles
        } else {
            backgroundFiles = [] // 默认为空数组
        }
        shuffleBackgrounds = SettingsStore.shuffleBackgrounds
        
        // 加载熬夜限制设置
        stayUpLimitEnabled = SettingsStore.stayUpLimitEnabled
        stayUpLimitHour = SettingsStore.stayUpLimitHour
        stayUpLimitMinute = SettingsStore.stayUpLimitMinute
        
        // 加载开机自启动设置
        launchAtLoginEnabled = LaunchAtLogin.shared.isEnabled // 从LaunchAtLogin类获取当前状态
        
        // 加载状态栏文字显示设置
        showStatusBarText = SettingsStore.showStatusBarText
        
        // 加载自动检测投屏设置
        autoDetectScreencastEnabled = SettingsStore.autoDetectScreencastEnabled
        
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
        if overlayRestMessageTemplatesStackView != nil {
            rebuildOverlayRestMessageTemplateInputs(templates: overlayRestMessageTemplates)
        }
        if overlayStayUpMessageTemplateTextView != nil {
            overlayStayUpMessageTemplateTextView.string = overlayStayUpMessageTemplate
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
        if shuffleBackgroundsCheckbox != nil {
            shuffleBackgroundsCheckbox.state = shuffleBackgrounds ? .on : .off
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
        
        // 更新状态栏文字显示设置UI
        if showStatusBarTextCheckbox != nil {
            showStatusBarTextCheckbox.state = showStatusBarText ? .on : .off
        }
        if autoDetectScreencastCheckbox != nil {
            autoDetectScreencastCheckbox.state = autoDetectScreencastEnabled ? .on : .off
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

