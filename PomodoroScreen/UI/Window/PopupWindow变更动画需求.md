## 需求：PopupWindow 打开时播放数值变更动画

### 目标
每次打开 `StatusBarPopupWindow` 时，为“健康环数值变化”与“底部四个指标数值变化”播放变更动画，让用户获得即时反馈。

### 动画范围
- 健康环（4 个环）：数值变化时平滑过渡
- 底部四个指标（完成番茄钟 / 工作时间 / 休息时间 / 健康评分）：数值变化时淡入淡出

### 变更判断（ViewModel）
- 新增 `PopupWindowViewModel`：保存“上一次打开弹窗时”的快照
- 每次打开弹窗时对比本次快照与上次快照：
  - 仅对发生变化的项播放动画

### 触发时机
- 在 `StatusBarController.showPopup()` 中，在 `popup.showPopup()` 之后调用更新方法并开启动画。

