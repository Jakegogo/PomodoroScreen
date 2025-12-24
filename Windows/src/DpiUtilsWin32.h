// DpiUtilsWin32.h
// Author: michael / GPT-5.2
// Created: 2025-12-24
//
// Small helpers for DPI scaling on Win32. We avoid hard-linking to newer APIs by
// dynamically resolving them at runtime with sensible fallbacks.

#pragma once

#include <windows.h>

namespace pomodoro::win32 {

    inline UINT GetDpiForHwnd(HWND hwnd) {
        if (!hwnd) return 96;

        HMODULE user32 = GetModuleHandleW(L"user32.dll");
        if (user32) {
            using GetDpiForWindowFn = UINT(WINAPI*)(HWND);
            auto fn = reinterpret_cast<GetDpiForWindowFn>(GetProcAddress(user32, "GetDpiForWindow"));
            if (fn) {
                UINT dpi = fn(hwnd);
                return dpi ? dpi : 96;
            }
        }

        HDC hdc = GetDC(hwnd);
        if (!hdc) return 96;
        const int dpiX = GetDeviceCaps(hdc, LOGPIXELSX);
        ReleaseDC(hwnd, hdc);
        return dpiX > 0 ? static_cast<UINT>(dpiX) : 96;
    }

    inline int Scale(int valueAt96Dpi, UINT dpi) {
        return MulDiv(valueAt96Dpi, static_cast<int>(dpi), 96);
    }

    inline HFONT CreateUiFontPx(int pxAt96Dpi, int weight, const wchar_t* faceName, UINT dpi) {
        LOGFONTW lf{};
        lf.lfHeight = -Scale(pxAt96Dpi, dpi);
        lf.lfWeight = weight;
        if (faceName) {
            wcscpy_s(lf.lfFaceName, faceName);
        } else {
            wcscpy_s(lf.lfFaceName, L"Segoe UI");
        }
        return CreateFontIndirectW(&lf);
    }

    inline void SetControlFont(HWND hwnd, HFONT font) {
        if (!hwnd || !font) return;
        SendMessageW(hwnd, WM_SETFONT, reinterpret_cast<WPARAM>(font), TRUE);
    }

} // namespace pomodoro::win32


