#include "TrayPopupWindowWin32.h"
#include "DpiUtilsWin32.h"

#include <gdiplus.h>
#include <shellapi.h>
#include <windowsx.h> // GET_X_LPARAM / GET_Y_LPARAM

#pragma comment(lib, "gdiplus.lib")

namespace {

    const wchar_t* kTrayPopupWindowClassName = L"PomodoroTrayPopupWindowClass";

    // Per-pixel alpha layered popup (single window):
    // - Background is semi-transparent (alpha)
    // - Text/buttons are drawn fully opaque on top
    constexpr BYTE kPopupBgAlpha = 209; // ~82% opaque
    constexpr BYTE kPopupBgR = 32;
    constexpr BYTE kPopupBgG = 32;
    constexpr BYTE kPopupBgB = 40;
    constexpr BYTE kPopupBorderR = 80;
    constexpr BYTE kPopupBorderG = 80;
    constexpr BYTE kPopupBorderB = 96;

    // GDI+ init (local, per-process)
    ULONG_PTR g_gdiplusToken = 0;
    void EnsureGdiplusStarted() {
        if (g_gdiplusToken != 0) return;
        Gdiplus::GdiplusStartupInput input;
        if (Gdiplus::GdiplusStartup(&g_gdiplusToken, &input, nullptr) != Gdiplus::Ok) {
            g_gdiplusToken = 0;
        }
    }

    enum class TaskbarEdge {
        Bottom,
        Top,
        Left,
        Right,
        Unknown
    };

    TaskbarEdge GetTaskbarEdge() {
        APPBARDATA abd{};
        abd.cbSize = sizeof(abd);
        if (!SHAppBarMessage(ABM_GETTASKBARPOS, &abd)) {
            return TaskbarEdge::Unknown;
        }

        switch (abd.uEdge) {
        case ABE_BOTTOM: return TaskbarEdge::Bottom;
        case ABE_TOP:    return TaskbarEdge::Top;
        case ABE_LEFT:   return TaskbarEdge::Left;
        case ABE_RIGHT:  return TaskbarEdge::Right;
        default:         return TaskbarEdge::Unknown;
        }
    }

    ATOM RegisterTrayPopupWindowClass(HINSTANCE hInstance) {
        static ATOM s_atom = 0;
        if (s_atom != 0) return s_atom;

        WNDCLASSEXW wc{};
        wc.cbSize = sizeof(WNDCLASSEXW);
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = pomodoro::TrayPopupWindowWin32::WndProc;
        wc.cbClsExtra = 0;
        wc.cbWndExtra = sizeof(LONG_PTR);
        wc.hInstance = hInstance;
        wc.hIcon = nullptr;
        wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
        wc.hbrBackground = nullptr; // layered: we draw ourselves
        wc.lpszMenuName = nullptr;
        wc.lpszClassName = kTrayPopupWindowClassName;
        wc.hIconSm = nullptr;

        s_atom = RegisterClassExW(&wc);
        return s_atom;
    }

} // namespace

namespace pomodoro {

    TrayPopupWindowWin32::TrayPopupWindowWin32() {
        statusText_ = L"\u5de5\u4f5c\u4e2d"; // "工作中"
        timeText_ = L"00:00";
    }

    TrayPopupWindowWin32::~TrayPopupWindowWin32() {
        if (hwnd_) {
            DestroyWindow(hwnd_);
            hwnd_ = nullptr;
        }
    }

    bool TrayPopupWindowWin32::create(HINSTANCE hInstance) {
        hInstance_ = hInstance;
        EnsureGdiplusStarted();

        if (!RegisterTrayPopupWindowClass(hInstance_)) {
            return false;
        }

        hwnd_ = CreateWindowExW(
            WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_LAYERED,
            kTrayPopupWindowClassName,
            L"Pomodoro Popup",
            WS_POPUP,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            260,
            160,
            nullptr,
            nullptr,
            hInstance_,
            this
        );

        if (!hwnd_) return false;

        dpi_ = pomodoro::win32::GetDpiForHwnd(hwnd_);
        applyDpiLayout(dpi_, nullptr);
        return true;
    }

    void TrayPopupWindowWin32::showNearCursor() {
        if (!hwnd_) return;

        dpi_ = pomodoro::win32::GetDpiForHwnd(hwnd_);
        applyDpiLayout(dpi_, nullptr);

        POINT pt{};
        GetCursorPos(&pt);

        const int width = pomodoro::win32::Scale(260, dpi_);
        const int height = pomodoro::win32::Scale(160, dpi_);

        TaskbarEdge edge = GetTaskbarEdge();

        int x = pt.x - width / 2;
        int y = pt.y - height - pomodoro::win32::Scale(10, dpi_);

        switch (edge) {
        case TaskbarEdge::Bottom:
            x = pt.x - width / 2;
            y = pt.y - height - pomodoro::win32::Scale(10, dpi_);
            break;
        case TaskbarEdge::Top:
            x = pt.x - width / 2;
            y = pt.y + pomodoro::win32::Scale(10, dpi_);
            break;
        case TaskbarEdge::Left:
            x = pt.x + pomodoro::win32::Scale(10, dpi_);
            y = pt.y - height / 2;
            break;
        case TaskbarEdge::Right:
            x = pt.x - width - pomodoro::win32::Scale(10, dpi_);
            y = pt.y - height / 2;
            break;
        case TaskbarEdge::Unknown:
        default:
            x = pt.x - width / 2;
            y = pt.y - height - pomodoro::win32::Scale(10, dpi_);
            break;
        }

        // Clamp into work area
        HMONITOR monitor = MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST);
        MONITORINFO mi{};
        mi.cbSize = sizeof(mi);
        if (GetMonitorInfoW(monitor, &mi)) {
            RECT work = mi.rcWork;
            if (x + width > work.right) x = work.right - width - 2;
            if (x < work.left) x = work.left + 2;
            if (y + height > work.bottom) y = work.bottom - height - 2;
            if (y < work.top) y = work.top + 2;
        }

        SetWindowPos(hwnd_, HWND_TOPMOST, x, y, width, height, SWP_NOACTIVATE);
        ShowWindow(hwnd_, SW_SHOWNOACTIVATE);

        // Render immediately (layered windows don't always repaint via WM_PAINT timing)
        renderLayered();
    }

    void TrayPopupWindowWin32::hide() {
        if (!hwnd_) return;
        ShowWindow(hwnd_, SW_HIDE);
    }

    void TrayPopupWindowWin32::updateContent(const std::wstring& statusText, const std::wstring& timeText) {
        statusText_ = statusText;
        timeText_ = timeText;
        if (hwnd_ && IsWindowVisible(hwnd_)) {
            renderLayered();
        }
    }

    LRESULT CALLBACK TrayPopupWindowWin32::WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        TrayPopupWindowWin32* self = nullptr;

        if (msg == WM_NCCREATE) {
            auto* cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
            self = static_cast<TrayPopupWindowWin32*>(cs->lpCreateParams);
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
        } else {
            self = reinterpret_cast<TrayPopupWindowWin32*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
        }

        if (self) {
            return self->handleMessage(hwnd, msg, wParam, lParam);
        }

        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    LRESULT TrayPopupWindowWin32::handleMessage(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        switch (msg) {
        case WM_CREATE:
            dpi_ = pomodoro::win32::GetDpiForHwnd(hwnd);
            applyDpiLayout(dpi_, nullptr);
            return 0;
        case WM_DPICHANGED: {
            const UINT newDpi = HIWORD(wParam);
            auto* suggested = reinterpret_cast<RECT*>(lParam);
            applyDpiLayout(newDpi, suggested);
            renderLayered();
            return 0;
        }
        case WM_SIZE:
            updateHitTestRects();
            renderLayered();
            return 0;
        case WM_ERASEBKGND:
            return 1;
        case WM_PAINT: {
            PAINTSTRUCT ps;
            BeginPaint(hwnd_, &ps);
            EndPaint(hwnd_, &ps);
            renderLayered();
            return 0;
        }
        case WM_LBUTTONDOWN: {
            POINT pt{ GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam) };
            pressedStart_ = hitTest(rcStart_, pt.x, pt.y);
            pressedReset_ = hitTest(rcReset_, pt.x, pt.y);
            pressedSettings_ = hitTest(rcSettings_, pt.x, pt.y);

            if (!pressedStart_ && !pressedReset_ && !pressedSettings_) {
                hide();
                return 0;
            }
            SetCapture(hwnd_);
            renderLayered();
            return 0;
        }
        case WM_LBUTTONUP: {
            if (GetCapture() == hwnd_) {
                ReleaseCapture();
            }
            POINT pt{ GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam) };
            const bool clickStart = pressedStart_ && hitTest(rcStart_, pt.x, pt.y);
            const bool clickReset = pressedReset_ && hitTest(rcReset_, pt.x, pt.y);
            const bool clickSettings = pressedSettings_ && hitTest(rcSettings_, pt.x, pt.y);

            pressedStart_ = false;
            pressedReset_ = false;
            pressedSettings_ = false;
            renderLayered();

            if (clickStart) {
                if (isRunning_) {
                    if (onPauseClicked_) onPauseClicked_();
                } else {
                    if (onStartClicked_) onStartClicked_();
                }
                return 0;
            }
            if (clickReset) {
                if (onResetClicked_) onResetClicked_();
                return 0;
            }
            if (clickSettings) {
                if (onSettingsClicked_) onSettingsClicked_();
                return 0;
            }
            return 0;
        }
        case WM_RBUTTONDOWN:
            hide();
            return 0;
        default:
            break;
        }

        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    void TrayPopupWindowWin32::paint() {
        renderLayered();
    }

    void TrayPopupWindowWin32::applyDpiLayout(UINT dpi, const RECT* suggestedWindowRect) {
        dpi_ = dpi ? dpi : 96;
        if (!hwnd_) return;

        auto S = [&](int v) { return pomodoro::win32::Scale(v, dpi_); };

        if (suggestedWindowRect) {
            SetWindowPos(
                hwnd_,
                nullptr,
                suggestedWindowRect->left,
                suggestedWindowRect->top,
                suggestedWindowRect->right - suggestedWindowRect->left,
                suggestedWindowRect->bottom - suggestedWindowRect->top,
                SWP_NOZORDER | SWP_NOACTIVATE
            );
        } else {
            SetWindowPos(hwnd_, nullptr, 0, 0, S(260), S(160), SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
        }

        windowSize_.cx = S(260);
        windowSize_.cy = S(160);
        updateHitTestRects();
    }

    void TrayPopupWindowWin32::setRunningState(bool running) {
        isRunning_ = running;
        if (hwnd_ && IsWindowVisible(hwnd_)) {
            renderLayered();
        }
    }

    bool TrayPopupWindowWin32::hitTest(const RECT& rc, int x, int y) const {
        return x >= rc.left && x < rc.right && y >= rc.top && y < rc.bottom;
    }

    void TrayPopupWindowWin32::updateHitTestRects() {
        if (!hwnd_) return;
        RECT client{};
        GetClientRect(hwnd_, &client);

        auto S = [&](int v) { return pomodoro::win32::Scale(v, dpi_); };

        const int btnW = S(90);
        const int btnH = S(28);
        const int gap = S(16);
        const int totalW = btnW * 2 + gap;
        const int startX = (client.right - client.left - totalW) / 2;
        const int y = (client.bottom - client.top) - btnH - S(14);

        rcStart_ = RECT{ startX, y, startX + btnW, y + btnH };
        rcReset_ = RECT{ startX + btnW + gap, y, startX + btnW + gap + btnW, y + btnH };

        const int pad = S(10);
        const int w = S(60);
        const int h = S(24);
        rcSettings_ = RECT{ client.right - w - pad, S(8), client.right - pad, S(8) + h };
    }

    void TrayPopupWindowWin32::renderLayered() {
        if (!hwnd_) return;
        EnsureGdiplusStarted();
        if (g_gdiplusToken == 0) return;

        RECT wndRc{};
        GetWindowRect(hwnd_, &wndRc);
        const int width = wndRc.right - wndRc.left;
        const int height = wndRc.bottom - wndRc.top;
        if (width <= 0 || height <= 0) return;

        HDC screenDC = GetDC(nullptr);
        HDC memDC = CreateCompatibleDC(screenDC);

        BITMAPINFO bmi{};
        bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
        bmi.bmiHeader.biWidth = width;
        bmi.bmiHeader.biHeight = -height; // top-down DIB
        bmi.bmiHeader.biPlanes = 1;
        bmi.bmiHeader.biBitCount = 32;
        bmi.bmiHeader.biCompression = BI_RGB;

        void* bits = nullptr;
        HBITMAP dib = CreateDIBSection(screenDC, &bmi, DIB_RGB_COLORS, &bits, nullptr, 0);
        if (!dib || !bits) {
            if (dib) DeleteObject(dib);
            DeleteDC(memDC);
            ReleaseDC(nullptr, screenDC);
            return;
        }

        HGDIOBJ oldBmp = SelectObject(memDC, dib);

        const int stride = width * 4;
        Gdiplus::Bitmap bmp(width, height, stride, PixelFormat32bppPARGB, static_cast<BYTE*>(bits));
        Gdiplus::Graphics g(&bmp);
        g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
        g.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHighQuality);
        g.SetCompositingQuality(Gdiplus::CompositingQualityHighQuality);
        // ClearType can fringe on transparent backgrounds; use grayscale AA (still anti-aliased, no color fringing)
        g.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);

        auto S = [&](int v) { return pomodoro::win32::Scale(v, dpi_); };

        // Background (semi-transparent)
        Gdiplus::SolidBrush bg(Gdiplus::Color(kPopupBgAlpha, kPopupBgR, kPopupBgG, kPopupBgB));
        g.FillRectangle(&bg, 0, 0, width, height);

        // Border (opaque)
        Gdiplus::Pen border(Gdiplus::Color(255, kPopupBorderR, kPopupBorderG, kPopupBorderB), 1.0f);
        g.DrawRectangle(&border, 0.5f, 0.5f, static_cast<Gdiplus::REAL>(width - 1), static_cast<Gdiplus::REAL>(height - 1));

        // Status text
        const int statusX = S(16);
        const int statusY = S(10);
        const int statusH = S(24);
        const int statusBottom = statusY + statusH;
        {
            Gdiplus::FontFamily family(L"Segoe UI");
            Gdiplus::Font font(&family, static_cast<Gdiplus::REAL>(S(14)), Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);
            Gdiplus::SolidBrush white(Gdiplus::Color(255, 255, 255, 255));
            Gdiplus::RectF rc(
                static_cast<Gdiplus::REAL>(statusX),
                static_cast<Gdiplus::REAL>(statusY),
                static_cast<Gdiplus::REAL>(width - statusX - S(16)),
                static_cast<Gdiplus::REAL>(statusH)
            );
            Gdiplus::StringFormat fmt;
            fmt.SetAlignment(Gdiplus::StringAlignmentNear);
            fmt.SetLineAlignment(Gdiplus::StringAlignmentCenter);
            g.DrawString(statusText_.c_str(), -1, &font, rc, &fmt, &white);
        }

        // Time text (bigger + vertically centered between status and bottom buttons)
        {
            const int top = statusBottom + S(10);
            const int bottom = rcStart_.top - S(10);
            const int availableH = (bottom > top) ? (bottom - top) : S(60);

            Gdiplus::FontFamily family(L"Segoe UI");
            Gdiplus::Font font(&family, static_cast<Gdiplus::REAL>(S(34)), Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
            Gdiplus::SolidBrush white(Gdiplus::Color(255, 255, 255, 255));

            Gdiplus::RectF rc(
                0.0f,
                static_cast<Gdiplus::REAL>(top),
                static_cast<Gdiplus::REAL>(width),
                static_cast<Gdiplus::REAL>(availableH)
            );
            Gdiplus::StringFormat fmt;
            fmt.SetAlignment(Gdiplus::StringAlignmentCenter);
            fmt.SetLineAlignment(Gdiplus::StringAlignmentCenter);
            g.DrawString(timeText_.c_str(), -1, &font, rc, &fmt, &white);
        }

        // Buttons
        auto drawButton = [&](const RECT& rc, const wchar_t* text, bool pressed) {
            const int pad = S(2);
            Gdiplus::RectF rcf(
                static_cast<Gdiplus::REAL>(rc.left + pad),
                static_cast<Gdiplus::REAL>(rc.top + pad),
                static_cast<Gdiplus::REAL>((rc.right - rc.left) - pad * 2),
                static_cast<Gdiplus::REAL>((rc.bottom - rc.top) - pad * 2)
            );
            Gdiplus::Color fill = pressed ? Gdiplus::Color(255, 255, 255, 255) : Gdiplus::Color(255, 50, 50, 60);
            Gdiplus::Color textColor = pressed ? Gdiplus::Color(255, 0, 0, 0) : Gdiplus::Color(255, 255, 255, 255);
            Gdiplus::SolidBrush fb(fill);
            g.FillRectangle(&fb, rcf);
            Gdiplus::Pen bp(Gdiplus::Color(255, 90, 90, 110), 1.0f);
            g.DrawRectangle(&bp, rcf);

            Gdiplus::FontFamily family(L"Segoe UI");
            Gdiplus::Font font(&family, static_cast<Gdiplus::REAL>(S(14)), Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);
            Gdiplus::SolidBrush tb(textColor);
            Gdiplus::StringFormat fmt;
            fmt.SetAlignment(Gdiplus::StringAlignmentCenter);
            fmt.SetLineAlignment(Gdiplus::StringAlignmentCenter);
            g.DrawString(text, -1, &font, rcf, &fmt, &tb);
        };

        const wchar_t* startText = isRunning_ ? L"\u6682\u505c" : L"\u542f\u52a8"; // "暂停"/"启动"
        drawButton(rcStart_, startText, pressedStart_);
        drawButton(rcReset_, L"\u91cd\u7f6e", pressedReset_); // "重置"

        // Settings button (gear): no border / no background, icon only
        {
            Gdiplus::RectF rcf(
                static_cast<Gdiplus::REAL>(rcSettings_.left),
                static_cast<Gdiplus::REAL>(rcSettings_.top),
                static_cast<Gdiplus::REAL>(rcSettings_.right - rcSettings_.left),
                static_cast<Gdiplus::REAL>(rcSettings_.bottom - rcSettings_.top)
            );

            // Press feedback: slightly brighter when pressed, still no background/border
            Gdiplus::Color fg = pressedSettings_
                ? Gdiplus::Color(255, 245, 245, 255)
                : Gdiplus::Color(255, 220, 220, 240);

            Gdiplus::FontFamily family(L"Segoe UI Symbol");
            Gdiplus::Font font(&family, static_cast<Gdiplus::REAL>(S(16)), Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);
            Gdiplus::SolidBrush tb(fg);
            Gdiplus::StringFormat fmt;
            fmt.SetAlignment(Gdiplus::StringAlignmentCenter);
            fmt.SetLineAlignment(Gdiplus::StringAlignmentCenter);
            const wchar_t* gear = L"\u2699";
            g.DrawString(gear, -1, &font, rcf, &fmt, &tb);
        }

        POINT ptPos{ wndRc.left, wndRc.top };
        SIZE sizeWnd{ width, height };
        POINT ptSrc{ 0, 0 };
        BLENDFUNCTION bf{};
        bf.BlendOp = AC_SRC_OVER;
        bf.SourceConstantAlpha = 255;
        bf.AlphaFormat = AC_SRC_ALPHA;

        UpdateLayeredWindow(hwnd_, screenDC, &ptPos, &sizeWnd, memDC, &ptSrc, 0, &bf, ULW_ALPHA);

        SelectObject(memDC, oldBmp);
        DeleteObject(dib);
        DeleteDC(memDC);
        ReleaseDC(nullptr, screenDC);
    }

} // namespace pomodoro


