#pragma once

#include <windows.h>
#include <functional>

#include "BackgroundSettingsWin32.h"

namespace pomodoro {

    // 简单的 Win32 设置面板窗口：
    // - 左侧 ListBox 显示背景文件列表
    // - 右侧按钮：添加图片 / 添加视频 / 删除 / 上移 / 下移
    class SettingsWindowWin32 {
    public:
        SettingsWindowWin32(HINSTANCE hInstance, BackgroundSettingsWin32& settings);
        ~SettingsWindowWin32() = default;

        void show();
        bool isOpen() const { return hwnd_ != nullptr; }

        void setPomodoroMinutesChangedHandler(std::function<void(int)> handler) { onPomodoroMinutesChanged_ = std::move(handler); }
        void setBreakMinutesChangedHandler(std::function<void(int)> handler) { onBreakMinutesChanged_ = std::move(handler); }
        void setAutoStartNextPomodoroAfterRestChangedHandler(std::function<void(bool)> handler) { onAutoStartNextPomodoroAfterRestChanged_ = std::move(handler); }

        // 全局窗口过程需要从窗口类注册函数中访问，因此放在 public 区域
        static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

    private:
        LRESULT handleMessage(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

        void onCreate(HWND hwnd);
        void onDestroy();
        void applyDpiLayout(UINT dpi, const RECT* suggestedWindowRect);

        void onAddImage();
        void onAddVideo();
        void onRemove();
        void onMoveUp();
        void onMoveDown();
        void onAutoStartNextPomodoroAfterRestChanged();
        void onPomodoroSliderChanged(bool commit);
        void onBreakSliderChanged(bool commit);
        void switchToTab(int index);

        void refreshList();

        HINSTANCE hInstance_{ nullptr };
        HWND hwnd_{ nullptr };
        HWND listBox_{ nullptr };
        HWND autoHideCheckbox_{ nullptr };
        HWND pomodoroMinutesLabel_{ nullptr };
        HWND pomodoroSlider_{ nullptr };
        HWND breakMinutesLabel_{ nullptr };
        HWND breakSlider_{ nullptr };
        HWND behaviorTabButton_{ nullptr };
        HWND backgroundTabButton_{ nullptr };
        HWND behaviorGroupBox_{ nullptr };
        HWND addImageButton_{ nullptr };
        HWND addVideoButton_{ nullptr };
        HWND removeButton_{ nullptr };
        HWND moveUpButton_{ nullptr };
        HWND moveDownButton_{ nullptr };
        HWND overlayMessageLabel_{ nullptr };
        HWND overlayMessageEdit_{ nullptr };
        int activeTabIndex_{ 0 };
        BackgroundSettingsWin32& settings_;
        std::function<void(int)> onPomodoroMinutesChanged_{};
        std::function<void(int)> onBreakMinutesChanged_{};
        std::function<void(bool)> onAutoStartNextPomodoroAfterRestChanged_{};

        UINT dpi_{ 96 };
        HFONT uiFont_{ nullptr };
        HFONT bigFont_{ nullptr };
    };

} // namespace pomodoro



