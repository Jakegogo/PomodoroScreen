## 需求：PopupWindow 底部四个指标展示调整

### 目标
在状态栏弹窗（`StatusBarPopupWindow`）底部的四个指标区域，展示以下四项：
- 完成番茄钟
- 工作时间
- 休息时间
- 健康评分

### 说明
- 数据来源：`StatisticsManager.shared.generateTodayReport().dailyStats`
  - `completedPomodoros`
  - `totalWorkTime`
  - `totalBreakTime`
  - `healthScore`
- 仅修改展示文案与值格式，不改统计口径/计算逻辑。

### 值格式
- 完成番茄钟：整数（例如 `3`）
- 工作时间 / 休息时间：`Hh Mm`（例如 `2h 15m`）
- 健康评分：四舍五入整数（例如 `86`）

