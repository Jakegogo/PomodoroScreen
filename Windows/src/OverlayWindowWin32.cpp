#include "OverlayWindowWin32.h"
#include "BackgroundSettingsWin32.h"

#include <iostream>
#include <gdiplus.h>

#pragma comment(lib, "gdiplus.lib")

namespace {

    const wchar_t* kOverlayWindowClassName = L"PomodoroOverlayWindowClass";
    constexpr UINT_PTR kTimerStartFadeText = 1;
    constexpr UINT_PTR kTimerFadeText = 2;
    constexpr int kIdCancelButton = 3001;

    // 全局 GDI+ 初始化
    ULONG_PTR g_gdiplusToken = 0;

    void EnsureGdiplusStarted() {
        if (g_gdiplusToken != 0) {
            return;
        }
        Gdiplus::GdiplusStartupInput input;
        if (Gdiplus::GdiplusStartup(&g_gdiplusToken, &input, nullptr) != Gdiplus::Ok) {
            g_gdiplusToken = 0;
        }
    }

    // 简单背景缓存：所有遮罩窗口共用一份背景图
    bool g_backgroundLoaded = false;
    std::unique_ptr<Gdiplus::Image> g_backgroundImage;

    void LoadBackgroundImageFromSettingsOnce() {
        if (g_backgroundLoaded) {
            return;
        }
        g_backgroundLoaded = true;

        pomodoro::BackgroundSettingsWin32 settings;
        const std::wstring settingsPath = pomodoro::BackgroundSettingsWin32::DefaultConfigPath();
        if (!settings.loadFromFile(settingsPath)) {
            return;
        }

        // 选择第一个图片类型的背景文件
        for (const auto& file : settings.files()) {
            if (file.type == pomodoro::BackgroundType::Image) {
                g_backgroundImage = std::make_unique<Gdiplus::Image>(file.path.c_str());
                if (g_backgroundImage && g_backgroundImage->GetLastStatus() == Gdiplus::Ok) {
                    return;
                }
                g_backgroundImage.reset();
                break;
            }
        }
    }

    // 注册窗口类（进程内只需一次）
    ATOM RegisterOverlayWindowClass(HINSTANCE hInstance) {
        static ATOM s_atom = 0;
        if (s_atom != 0) {
            return s_atom;
        }

        WNDCLASSEXW wc{};
        wc.cbSize = sizeof(WNDCLASSEXW);
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = pomodoro::OverlayWindowWin32::WndProc;
        wc.cbClsExtra = 0;
        wc.cbWndExtra = sizeof(LONG_PTR);
        wc.hInstance = hInstance;
        wc.hIcon = nullptr;
        wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
        wc.hbrBackground = nullptr; // 手动绘制背景
        wc.lpszMenuName = nullptr;
        wc.lpszClassName = kOverlayWindowClassName;
        wc.hIconSm = nullptr;

        s_atom = RegisterClassExW(&wc);
        return s_atom;
    }

} // namespace

namespace pomodoro {

    OverlayWindowWin32::OverlayWindowWin32() = default;

    OverlayWindowWin32::~OverlayWindowWin32() {
        if (hwnd_) {
            DestroyWindow(hwnd_);
            hwnd_ = nullptr;
        }
        if (fadeTimerId_ != 0 && hwnd_) {
            KillTimer(hwnd_, fadeTimerId_);
            fadeTimerId_ = 0;
        }
        if (startFadeTimerId_ != 0 && hwnd_) {
            KillTimer(hwnd_, startFadeTimerId_);
            startFadeTimerId_ = 0;
        }
        if (buttonFont_) {
            DeleteObject(buttonFont_);
            buttonFont_ = nullptr;
        }
    }

    bool OverlayWindowWin32::create(HINSTANCE hInstance, const RECT& bounds, DismissCallback onDismiss) {
        hInstance_ = hInstance;
        bounds_ = bounds;
        onDismiss_ = std::move(onDismiss);

        if (!RegisterOverlayWindowClass(hInstance_)) {
            return false;
        }

        const DWORD exStyle = WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_LAYERED;
        const DWORD style = WS_POPUP;

        hwnd_ = CreateWindowExW(
            exStyle,
            kOverlayWindowClassName,
            L"Pomodoro Overlay",
            style,
            bounds_.left,
            bounds_.top,
            bounds_.right - bounds_.left,
            bounds_.bottom - bounds_.top,
            nullptr,
            nullptr,
            hInstance_,
            this // lpParam -> WM_NCCREATE
        );

        if (!hwnd_) {
            DWORD err = GetLastError();
            std::cerr << "[OverlayWindow] CreateWindowExW failed, error=" << err << "\n";
            return false;
        }

        // 初始化 GDI+ 并尝试加载背景图（与 macOS 端逻辑对齐：由设置面板决定背景资源）
        EnsureGdiplusStarted();
        LoadBackgroundImageFromSettingsOnce();

        // 设置整体透明度（例如 80% 不透明）
        const BYTE alpha = static_cast<BYTE>(255 * 0.8);
        if (!SetLayeredWindowAttributes(hwnd_, 0, alpha, LWA_ALPHA)) {
            DWORD err = GetLastError();
            std::cerr << "[OverlayWindow] SetLayeredWindowAttributes failed, error=" << err << "\n";
        }

        return true;
    }

    void OverlayWindowWin32::show() {
        if (!hwnd_) {
            return;
        }
        ShowWindow(hwnd_, SW_SHOW);
        UpdateWindow(hwnd_);
        isVisible_ = true;

        // 初始化文本透明度并设置定时器：3 秒后隐藏文字
        textAlpha_ = 255;
        if (startFadeTimerId_ != 0) {
            KillTimer(hwnd_, startFadeTimerId_);
        }
        startFadeTimerId_ = SetTimer(hwnd_, kTimerStartFadeText, 3000, nullptr);
    }

    void OverlayWindowWin32::hide() {
        if (!hwnd_) {
            return;
        }
        ShowWindow(hwnd_, SW_HIDE);
        isVisible_ = false;
    }

    bool OverlayWindowWin32::isVisible() const {
        return isVisible_;
    }

    LRESULT CALLBACK OverlayWindowWin32::WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        OverlayWindowWin32* self = nullptr;

        if (msg == WM_NCCREATE) {
            auto* cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
            self = static_cast<OverlayWindowWin32*>(cs->lpCreateParams);
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
        } else {
            self = reinterpret_cast<OverlayWindowWin32*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
        }

        if (self) {
            switch (msg) {
            case WM_DESTROY:
                return 0;
            default:
                return self->handleMessage(hwnd, msg, wParam, lParam);
            }
        }

        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    LRESULT OverlayWindowWin32::handleMessage(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        switch (msg) {
        case WM_CREATE: {
            // 创建“取消休息”按钮，位于窗口底部中间
            RECT client{};
            GetClientRect(hwnd, &client);
            const int btnWidth = 120;
            const int btnHeight = 36;
            const int centerX = (client.right - client.left) / 2;
            const int bottom = client.bottom - 60;

            cancelButton_ = CreateWindowExW(
                0,
                L"BUTTON",
                L"\u53d6\u6d88\u4f11\u606f", // "取消休息"
                WS_CHILD | WS_VISIBLE | BS_OWNERDRAW | WS_TABSTOP,
                centerX - btnWidth / 2,
                bottom - btnHeight / 2,
                btnWidth,
                btnHeight,
                hwnd,
                reinterpret_cast<HMENU>(static_cast<INT_PTR>(kIdCancelButton)),
                hInstance_,
                nullptr
            );

            // 设置按钮字体，使其更接近 macOS 的粗体样式
            if (!buttonFont_) {
                LOGFONTW lf{};
                lf.lfHeight = -18; // 约 13~14pt
                lf.lfWeight = FW_SEMIBOLD;
                wcscpy_s(lf.lfFaceName, L"Segoe UI");
                buttonFont_ = CreateFontIndirectW(&lf);
            }
            if (cancelButton_ && buttonFont_) {
                SendMessageW(cancelButton_, WM_SETFONT, reinterpret_cast<WPARAM>(buttonFont_), TRUE);
            }
            return 0;
        }
        case WM_PAINT:
            paint();
            return 0;

        case WM_LBUTTONDOWN:
        case WM_RBUTTONDOWN:
        case WM_MBUTTONDOWN:
            // 点击遮罩其他区域不再隐藏遮罩层，保持遮罩存在
            return 0;

        case WM_KEYDOWN:
            // 仅在按 ESC 时关闭遮罩，与 macOS 行为保持一致
            if (wParam == VK_ESCAPE) {
                if (onDismiss_) {
                    onDismiss_();
                }
                return 0;
            }
            break;

        case WM_COMMAND: {
            const int id = LOWORD(wParam);
            const int code = HIWORD(wParam);
            if (id == kIdCancelButton && code == BN_CLICKED) {
                // 点击“取消休息”按钮：关闭遮罩层
                if (onDismiss_) {
                    onDismiss_();
                }
                return 0;
            }
            break;
        }

        case WM_DRAWITEM: {
            const int id = static_cast<int>(wParam);
            if (id == kIdCancelButton) {
                auto* dis = reinterpret_cast<LPDRAWITEMSTRUCT>(lParam);
                if (!dis) break;

                HDC hdc = dis->hDC;

                // 简化为矩形按钮样式：深色背景 + 白色描边 + 白色文字
                const bool isPressed = (dis->itemState & ODS_SELECTED) != 0;
                const COLORREF borderColor = RGB(255, 255, 255);
                const COLORREF fillColor = isPressed
                    ? RGB(255, 255, 255)
                    : RGB(0, 0, 0);

                HBRUSH bgBrush = CreateSolidBrush(fillColor);
                HPEN borderPen = CreatePen(PS_SOLID, 1, borderColor);

                HGDIOBJ oldBrush = SelectObject(hdc, bgBrush);
                HGDIOBJ oldPen = SelectObject(hdc, borderPen);

                RECT r = dis->rcItem;
                // 留一点内边距，避免贴边
                InflateRect(&r, -2, -2);
                Rectangle(hdc, r.left, r.top, r.right, r.bottom);

                SelectObject(hdc, oldBrush);
                SelectObject(hdc, oldPen);
                DeleteObject(bgBrush);
                DeleteObject(borderPen);

                // 绘制文字（使用 GDI+ 提升抗锯齿效果）
                if (g_gdiplusToken != 0) {
                    Gdiplus::Graphics graphics(hdc);
                    graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
                    graphics.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);

                    Gdiplus::FontFamily family(L"Segoe UI");
                    // 使用粗体近似 macOS 的半粗体效果
                    Gdiplus::Font font(&family, 14.0f, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);

                    Gdiplus::Color color(
                        255,
                        isPressed ? 0 : 255,
                        isPressed ? 0 : 255,
                        isPressed ? 0 : 255
                    );
                    Gdiplus::SolidBrush brush(color);

                    Gdiplus::StringFormat format;
                    format.SetAlignment(Gdiplus::StringAlignmentCenter);
                    format.SetLineAlignment(Gdiplus::StringAlignmentCenter);

                    const wchar_t* text = L"\u53d6\u6d88\u4f11\u606f"; // "取消休息"

                    Gdiplus::RectF rect(
                        static_cast<Gdiplus::REAL>(dis->rcItem.left),
                        static_cast<Gdiplus::REAL>(dis->rcItem.top),
                        static_cast<Gdiplus::REAL>(dis->rcItem.right - dis->rcItem.left),
                        static_cast<Gdiplus::REAL>(dis->rcItem.bottom - dis->rcItem.top)
                    );

                    graphics.DrawString(text, -1, &font, rect, &format, &brush);
                } else {
                    // 回退到 GDI 文本绘制
                    SetBkMode(hdc, TRANSPARENT);
                    SetTextColor(hdc, isPressed ? RGB(0, 0, 0) : RGB(255, 255, 255));

                    const wchar_t* text = L"\u53d6\u6d88\u4f11\u606f"; // "取消休息"

                    DrawTextW(
                        hdc,
                        text,
                        -1,
                        &dis->rcItem,
                        DT_CENTER | DT_VCENTER | DT_SINGLELINE
                    );
                }

                return TRUE;
            }
            break;
        }

        case WM_TIMER:
            if (wParam == kTimerStartFadeText) {
                KillTimer(hwnd, kTimerStartFadeText);
                startFadeTimerId_ = 0;
                // 直接隐藏文本，避免频繁重绘导致的闪烁
                textAlpha_ = 0;
                InvalidateRect(hwnd, nullptr, FALSE);
                return 0;
            }
            break;

        case WM_ERASEBKGND:
            // 由 WM_PAINT 完成背景绘制
            return 1;

        default:
            break;
        }

        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    void OverlayWindowWin32::paint() {
        if (!hwnd_) {
            return;
        }

        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd_, &ps);
        if (!hdc) {
            std::cerr << "[OverlayWindow] BeginPaint returned null HDC\n";
            return;
        }

        RECT client{};
        GetClientRect(hwnd_, &client);

        // 优先绘制用户配置的背景图片（填充模式，保持宽高比）
        if (g_backgroundImage && g_gdiplusToken != 0) {
            Gdiplus::Graphics graphics(hdc);

            const auto imgWidth = static_cast<float>(g_backgroundImage->GetWidth());
            const auto imgHeight = static_cast<float>(g_backgroundImage->GetHeight());

            if (imgWidth > 0.0f && imgHeight > 0.0f) {
                const float clientWidth = static_cast<float>(client.right - client.left);
                const float clientHeight = static_cast<float>(client.bottom - client.top);

                const float scaleX = clientWidth / imgWidth;
                const float scaleY = clientHeight / imgHeight;
                const float scale = (scaleX > scaleY) ? scaleX : scaleY; // 等价于 max(scaleX, scaleY)

                const float scaledWidth = imgWidth * scale;
                const float scaledHeight = imgHeight * scale;

                const float offsetX = (clientWidth - scaledWidth) * 0.5f;
                const float offsetY = (clientHeight - scaledHeight) * 0.5f;

                Gdiplus::RectF destRect(
                    static_cast<Gdiplus::REAL>(client.left + offsetX),
                    static_cast<Gdiplus::REAL>(client.top + offsetY),
                    static_cast<Gdiplus::REAL>(scaledWidth),
                    static_cast<Gdiplus::REAL>(scaledHeight));

                graphics.DrawImage(g_backgroundImage.get(), destRect);
            }
        } else {
            // 没有背景图时，退回到纯黑背景
            HBRUSH brush = CreateSolidBrush(RGB(0, 0, 0));
            FillRect(hdc, &client, brush);
            DeleteObject(brush);
        }

        // 绘制提示文本：初始全亮，随后通过 textAlpha_ 渐变消失
        if (textAlpha_ > 0 && g_gdiplusToken != 0) {
            Gdiplus::Graphics graphics(hdc);
            Gdiplus::FontFamily family(L"Segoe UI");
            Gdiplus::Font font(&family, 32.0f, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);

            Gdiplus::Color color(textAlpha_, 255, 255, 255);
            Gdiplus::SolidBrush brush(color);

            Gdiplus::StringFormat format;
            format.SetAlignment(Gdiplus::StringAlignmentCenter);
            format.SetLineAlignment(Gdiplus::StringAlignmentCenter);

            const wchar_t* text = L"Rest Time - PomodoroScreen";
            Gdiplus::RectF rect(
                static_cast<Gdiplus::REAL>(client.left),
                static_cast<Gdiplus::REAL>(client.top - 80), // 稍微上移，避免挡住按钮
                static_cast<Gdiplus::REAL>(client.right - client.left),
                static_cast<Gdiplus::REAL>(client.bottom - client.top)
            );

            graphics.DrawString(text, -1, &font, rect, &format, &brush);
        }

        EndPaint(hwnd_, &ps);
    }

} // namespace pomodoro


