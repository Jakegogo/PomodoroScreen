#pragma once

#include <windows.h>

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

        // 全局窗口过程需要从窗口类注册函数中访问，因此放在 public 区域
        static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

    private:
        LRESULT handleMessage(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

        void onCreate(HWND hwnd);
        void onDestroy();

        void onAddImage();
        void onAddVideo();
        void onRemove();
        void onMoveUp();
        void onMoveDown();
        void onAutoHideChanged();
        void switchToTab(int index);

        void refreshList();

        HINSTANCE hInstance_{ nullptr };
        HWND hwnd_{ nullptr };
        HWND listBox_{ nullptr };
        HWND autoHideCheckbox_{ nullptr };
        HWND behaviorTabButton_{ nullptr };
        HWND backgroundTabButton_{ nullptr };
        HWND behaviorGroupBox_{ nullptr };
        HWND addImageButton_{ nullptr };
        HWND addVideoButton_{ nullptr };
        HWND removeButton_{ nullptr };
        HWND moveUpButton_{ nullptr };
        HWND moveDownButton_{ nullptr };
        int activeTabIndex_{ 0 };
        BackgroundSettingsWin32& settings_;
    };

} // namespace pomodoro



