#pragma once

// OverlayWindowWin32
// -------------------
// Win32 版本的遮罩层窗口，实现思路参考 macOS 端的 `OverlayWindow`：
// - 全屏、无边框、最前置窗口
// - 半透明背景，用于强制用户休息（遮挡桌面）
// - 支持多屏：每个物理屏幕对应一个 OverlayWindowWin32 实例
//
// 为了保持与 Swift 逻辑的一致性，本类只负责“单块屏幕上的遮罩窗口”：
// - 创建 / 显示 / 隐藏
// - 处理基本输入（点击 / Esc 关闭）
// 多屏协调由 `MultiScreenOverlayManagerWin32` 负责。

#include <windows.h>
#include <functional>
#include <memory>

namespace pomodoro {

    struct OverlayVideoPlayerWin32;
    LRESULT CALLBACK OverlayUiWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);
    LRESULT CALLBACK OverlayPosterShieldWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

    class OverlayWindowWin32 {
    public:
        using DismissCallback = std::function<void()>;

        // Called once per rest cycle (before creating per-monitor overlays).
        // Picks the next background from settings and prepares shared resources (image/video/poster).
        static void PrepareNextBackgroundForRest();

        OverlayWindowWin32();
        ~OverlayWindowWin32();

        // 为给定矩形区域创建遮罩窗口（通常是某个显示器的工作区域）
        bool create(HINSTANCE hInstance, const RECT& bounds, DismissCallback onDismiss);

        // 显示 / 隐藏遮罩
        void show();
        void hide();

        bool isVisible() const;

        HWND hwnd() const { return hwnd_; }

        // 全局窗口过程（Win32 要求静态方法）
        static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

    private:
        friend LRESULT CALLBACK OverlayUiWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);
        friend LRESULT CALLBACK OverlayPosterShieldWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

        // 实例级别的消息处理（显式传入 hwnd，避免在 WM_NCCREATE 阶段 hwnd_ 仍为 null）
        LRESULT handleMessage(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

        void paint();
        void applyDpiLayout(UINT dpi, const RECT* suggestedWindowRect);
        void layoutCancelButton();
        void layoutUiOverlay();
        void renderUiOverlay();
        void renderPosterShield();

    private:
        HWND hwnd_{ nullptr };
        HINSTANCE hInstance_{ nullptr };
        RECT bounds_{};
        DismissCallback onDismiss_{};
        bool isVisible_{ false };

        // 文本淡出相关状态
        BYTE textAlpha_{ 255 };
        UINT_PTR startFadeTimerId_{ 0 };
        UINT_PTR fadeTimerId_{ 0 };
        UINT_PTR ensureTopmostTimerId_{ 0 };
        UINT_PTR revealUiAfterPosterTimerId_{ 0 };

        // 取消休息按钮
        HWND cancelButton_{ nullptr };
        HFONT buttonFont_{ nullptr };

        // Separate topmost UI overlay window (layered) to keep text/button above video.
        HWND uiOverlayWindow_{ nullptr };
        RECT uiCancelButtonRect_{};
        bool uiCancelPressed_{ false };

        // Poster shield window (non-layered) to cover transient black frames from video presenter.
        HWND posterShieldWindow_{ nullptr };
        bool posterVisible_{ false };
        UINT_PTR posterTimerId_{ 0 };
        ULONGLONG posterShownTick_{ 0 };

        UINT dpi_{ 96 };

        std::unique_ptr<OverlayVideoPlayerWin32> videoPlayer_{};
    };

} // namespace pomodoro


