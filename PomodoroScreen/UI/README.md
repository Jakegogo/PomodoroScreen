# UI 组件目录

本目录包含了PomodoroScreen应用的用户界面组件，按功能模块进行组织，便于维护和扩展。

## 目录结构

```
UI/
├── Components/          # 可重用的UI组件
│   └── HoverButton.swift   # 支持悬停效果的自定义按钮
└── README.md           # 本说明文档
```

## 组件说明

### HoverButton.swift

**功能**: 支持悬停效果和美化样式的自定义按钮组件

**特性**:
- ✨ 平滑的鼠标悬停颜色变化动画
- 🎨 支持自定义正常和悬停状态的背景色
- 🔧 自动处理 layer 和 tracking area 的设置
- 🌓 兼容 macOS 浅色/深色模式
- 📱 提供预设的主要和次要按钮样式
- 🔗 支持SF Symbol图标集成

**使用示例**:

```swift
// 基础使用
let button = HoverButton(frame: NSRect(x: 0, y: 0, width: 100, height: 40))
button.setBackgroundColors(
    normal: NSColor.controlAccentColor.cgColor,
    hover: NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
)

// 使用预设样式
let primaryButton = HoverButton(frame: buttonFrame)
primaryButton.configurePrimaryStyle(title: "开始")
primaryButton.setIcon("play.fill")

let secondaryButton = HoverButton(frame: buttonFrame)
secondaryButton.configureSecondaryStyle(title: "重置")
secondaryButton.setIcon("arrow.counterclockwise")
```

**扩展方法**:
- `configurePrimaryStyle(title:)`: 配置为主要按钮样式（蓝色背景）
- `configureSecondaryStyle(title:)`: 配置为次要按钮样式（灰色背景）
- `setIcon(_:pointSize:weight:)`: 设置SF Symbol图标

## 使用指南

### 1. 导入组件
HoverButton已经集成到项目中，可以直接在其他Swift文件中使用，无需额外导入。

### 2. 创建按钮
```swift
let button = HoverButton(frame: NSRect(x: 50, y: 200, width: 90, height: 40))
```

### 3. 配置样式
```swift
// 方式1: 使用预设样式
button.configurePrimaryStyle(title: "确认")

// 方式2: 自定义颜色
button.setBackgroundColors(
    normal: NSColor.systemBlue.cgColor,
    hover: NSColor.systemBlue.withAlphaComponent(0.8).cgColor
)
```

### 4. 添加图标
```swift
button.setIcon("checkmark.circle.fill", pointSize: 14, weight: .semibold)
```

### 5. 设置事件
```swift
button.target = self
button.action = #selector(buttonClicked)
```

## 设计原则

### 可重用性
- 组件设计为通用可重用，不依赖特定的业务逻辑
- 通过参数和扩展方法提供灵活的配置选项

### 一致性
- 遵循macOS Human Interface Guidelines
- 保持与系统UI风格的一致性
- 支持系统强调色和深色模式

### 性能优化
- 高效的鼠标追踪机制
- 平滑的动画效果（200ms过渡时间）
- 合理的内存管理和资源释放

## 扩展建议

### 未来可添加的组件
- `AnimatedLabel`: 支持动画效果的标签
- `ProgressRing`: 自定义进度环组件
- `FloatingPanel`: 浮动面板容器
- `GlassButton`: 毛玻璃效果按钮
- `StatusIndicator`: 状态指示器组件

### 目录结构扩展
```
UI/
├── Components/         # 基础组件
├── Panels/            # 面板类组件
├── Controls/          # 控件类组件
├── Animations/        # 动画效果
└── Themes/           # 主题和样式
```

## 维护说明

### 版本历史
- v1.0.0 (2025-09-22): 初始版本，包含HoverButton组件
  - 支持悬停效果
  - 预设主要和次要样式
  - SF Symbol图标集成

### 贡献指南
1. 新组件应该放在合适的子目录中
2. 每个组件都应该有完整的文档注释
3. 提供使用示例和测试用例
4. 遵循项目的代码风格规范
5. 更新README文档

---

*创建时间: 2025-09-22*  
*最后更新: 2025-09-22*
