#include "MultiScreenOverlayManagerWin32.h"

namespace pomodoro {

    MultiScreenOverlayManagerWin32::MultiScreenOverlayManagerWin32(HINSTANCE hInstance)
        : hInstance_(hInstance) {
    }

    MultiScreenOverlayManagerWin32::~MultiScreenOverlayManagerWin32() {
        hideAllOverlays();
    }

    void MultiScreenOverlayManagerWin32::showOverlaysOnAllScreens() {
        hideAllOverlays();

        // 枚举所有显示器，为每个显示器创建一个遮罩窗口
        EnumDisplayMonitors(nullptr, nullptr, MonitorEnumProc, reinterpret_cast<LPARAM>(this));

        // 显示所有遮罩窗口
        for (auto& overlay : overlays_) {
            overlay->show();
        }
    }

    void MultiScreenOverlayManagerWin32::hideAllOverlays() {
        for (auto& overlay : overlays_) {
            overlay->hide();
        }
        overlays_.clear();
    }

    BOOL CALLBACK MultiScreenOverlayManagerWin32::MonitorEnumProc(HMONITOR hMonitor, HDC /*hdc*/, LPRECT lprcMonitor, LPARAM dwData) {
        auto* self = reinterpret_cast<MultiScreenOverlayManagerWin32*>(dwData);
        if (!self || !lprcMonitor) return TRUE;

        self->createOverlayForRect(*lprcMonitor);
        return TRUE;
    }

    void MultiScreenOverlayManagerWin32::createOverlayForRect(const RECT& rect) {
        auto overlay = std::make_unique<OverlayWindowWin32>();

        auto dismissHandler = [this]() {
            // 当前简单策略：任意一个遮罩被“点击/按键关闭”时，隐藏所有遮罩。
            hideAllOverlays();
        };

        if (overlay->create(hInstance_, rect, dismissHandler)) {
            overlays_.push_back(std::move(overlay));
        }
    }

} // namespace pomodoro


